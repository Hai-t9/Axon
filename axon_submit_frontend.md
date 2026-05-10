## Current State

The existing `ModelSubmissionPage` at `frontend/website/lib/features/model_submission/` only has a **read-only list view** — no upload functionality. The backend supports full submission with validation, but the frontend never calls the submit endpoint.

## Backend API Contract

**`POST /competitions/{comp_id}/models/submit`**
| Param | Type | Location | Required |
|---|---|---|---|
| `comp_id` | UUID | Path | ✓ |
| `team_id` | UUID | Query | ✓ |
| `model_name` | string | Query | ✓ |
| `framework` | enum | Query | ✓ |
| `python_version` | string | Query | ✓ |
| `framework_version` | string | Query | ✗ |
| `description` | string | Query | ✗ |
| `file` | `.zip` | Multipart | ✓ |

Returns `ModelSubmitResponse` + 10-step validation pipeline (Dockerfile, inference.py, requirements.txt, model/ dir, data/ dir, zip size, SHA-256 dedup).

## Suggested Frontend Architecture

### 1. New Files to Create

```
lib/features/model_submission/
├── data/
│   ├── model_submission_models.dart      ← add submit request/response models
│   └── model_submission_repository.dart  ← add submitModel()
├── state/
│   ├── model_submission_controller.dart  ← add submit state provider
│   └── model_submission_form_state.dart  ← NEW: form state
├── presentation/
│   ├── model_submission_page.dart        ← existing list page, add FAB/link to upload
│   ├── model_submission_upload_page.dart ← NEW: upload form page
│   └── widgets/
│       ├── submission_spec_card.dart     ← NEW: detailed spec breakdown
│       ├── submission_form.dart          ← NEW: form with all fields
│       └── submission_progress.dart      ← NEW: upload progress indicator
```

### 2. Data Model Changes

Add to `model_submission_models.dart`:
```dart
class SubmitModelRequest {
  final String teamId;
  final String modelName;
  final String framework;
  final String pythonVersion;
  final String? frameworkVersion;
  final String? description;
}

class SubmitModelResponse {
  final String id;
  final String teamId;
  final String competitionId;
  final String filename;
  final String status;
  final int version;
}
```

Extend `ModelSpec` with all fields from the backend's `model_spec` JSON:
```dart
class ModelSpec {
  final int maxSizeMb;
  final List<String> supportedFormats;
  final List<String> requiredFiles;       // e.g. ["Dockerfile", "inference.py", "requirements.txt"]
  final String inferenceFunction;         // e.g. "predict"
  final String? pythonVersionMin;
  final List<String> requiredPackages;
}
```

### 3. Repository — Add Submit Method

```dart
Future<SubmitModelResponse> submitModel(
  String competitionId, {
  required SubmitModelRequest request,
  required String filePath,        // path to the .zip on disk
  onProgress(double sent, double total)?,
}) async {
  final uri = Uri.parse('$_baseUrl/competitions/$competitionId/models/submit')
      .replace(queryParameters: {
        'team_id': request.teamId,
        'model_name': request.modelName,
        'framework': request.framework,
        'python_version': request.pythonVersion,
        if (request.frameworkVersion != null) 'framework_version': request.frameworkVersion,
        if (request.description != null) 'description': request.description,
      });
  // Multipart upload via http.MultipartRequest
}
```

### 4. Page Layout

```
┌─────────────────────────────────────────────┐
│  ← Back to Models         Model Submission  │
├─────────────────────────────────────────────┤
│  ┌── Requirements ────────────────────────┐ │
│  │  Max size:       500 MB                │ │
│  │  Formats:        PyTorch, TensorFlow…  │ │
│  │  Required files: Dockerfile,           │ │
│  │                   inference.py, …       │ │
│  │  Inference fn:   predict()              │ │
│  └─────────────────────────────────────────┘ │
│                                              │
│  ┌── Upload Model ─────────────────────────┐ │
│  │  Team:        [dropdown ▼]              │ │
│  │  Model name:  [___________________]     │ │
│  │  Framework:   [dropdown ▼]              │ │
│  │  Python ver:  [dropdown: 3.9/3.10/3.11]│ │
│  │  Framework v: [___________________]     │ │
│  │  Description: [___________________]     │ │
│  │                                         │ │
│  │  ┌────────────────────────────────┐     │ │
│  │  │  📦 Drag & drop your .zip or   │     │ │
│  │  │     click to browse            │     │ │
│  │  │     submission.zip             │     │ │
│  │  └────────────────────────────────┘     │ │
│  │                                         │ │
│  │  [← Cancel]              [Submit ➜]    │ │
│  └─────────────────────────────────────────┘ │
│                                              │
│  Latest submission: v3 — completed ✅        │
└─────────────────────────────────────────────┘
```

### 5. Key UX Details

- **Team selector**: Fetch user's teams in this comp from `GET /competitions/{id}/my-team` (returns their team, so it's auto-filled, not a dropdown)
- **File validation client-side**: Check `.zip` extension + size < `maxSizeMb` before uploading
- **Upload progress**: Use `http.MultipartRequest` with `onProgress` callback
- **Status polling**: After submit success, auto-refresh the model list to show the new entry
- **Error states**: ValidationError (400) → show which file is missing; AuthError (401/403) → redirect login; ServerError (500) → generic retry
- **Empty state on upload page**: If no team, show "You must join a competition team first"

### 6. Route

```
/competitions/:id/models/submit  →  ModelSubmissionUploadPage
```

Add a FAB or button on the existing `ModelSubmissionPage` → navigate to upload page.

### 7. State Management (Riverpod)

```dart
// New providers needed:
final submitModelProvider = FutureProvider.family<SubmitModelResponse, SubmitModelParams>(...);
final modelFormProvider = StateNotifierProvider<ModelFormNotifier, ModelFormState>(...);
final uploadProgressProvider = StateProvider<double>((ref) => 0.0);
```

---

Want me to implement any part of this? I can start with the data layer (models + repository) and the upload page UI.

