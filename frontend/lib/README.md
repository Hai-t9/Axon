# Flutter Frontend Structure

## Overview
The `frontend/` folder contains the Flutter/Dart web and mobile application. Flutter allows us to build both iOS, Android, and Web apps from a single codebase with ~70% code reuse.

## Purpose

- ✅ Cross-platform UI (Web, iOS, Android)
- ✅ Type-safe Dart code
- ✅ Reactive state management (Riverpod)
- ✅ API integration with FastAPI backend
- ✅ Offline support with local storage

## Architecture

Flutter app uses **Clean Architecture** with **feature-first structure**:

```
frontend/lib/
├── main.dart                    # App entry point
│
├── app/                         # App-level configuration
│   ├── router.dart              # go_router navigation setup
│   └── theme.dart               # Material Design theme
│
├── core/                        # Shared infrastructure
│   ├── api/                     # HTTP client setup
│   ├── auth/                    # Authentication state
│   └── utils/                   # Helpers, validators
│
├── features/                    # Feature modules (7 features)
│   ├── competitions/            # Feature-specific structure
│   ├── teams/
│   ├── datasets/
│   ├── labeling/
│   ├── model_submission/
│   ├── evaluation/
│   └── leaderboard/
│
└── shared/                      # Shared components
    ├── widgets/                 # Reusable UI components
    ├── constants/               # App-wide constants
    └── utilities/               # Shared utility functions
```

## File Organization Breakdown

### **main.dart**
Entry point of the application:

```dart
void main() {
  runApp(
    ProviderScope(  // Riverpod state management
      child: MyApp(),
    ),
  );
}

class MyApp extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      routerConfig: ref.watch(routerProvider),
      theme: AppTheme.lightTheme,
    );
  }
}
```

---

### **app/ Folder**

#### **router.dart**
Navigation setup using go_router:

```dart
final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);
  
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => HomeScreen(),
      ),
      GoRoute(
        path: '/competitions',
        builder: (context, state) => CompetitionsScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => LoginScreen(),
      ),
    ],
    redirect: (context, state) {
      // Redirect unauthenticated users
      if (!authState.isAuthenticated) {
        return '/login';
      }
      return null;
    },
  );
});
```

#### **theme.dart**
Material Design theme:

```dart
class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.blue,
      ),
      // Custom styles...
    );
  }
}
```

---

### **core/ Folder**

#### **api/**
HTTP client and API configuration:

- `api_client.dart` - Dio HTTP client with JWT interceptor
- `endpoints.dart` - API base URLs and constants

```dart
// api_client.dart
final apiClientProvider = Provider<Dio>((ref) {
  final authState = ref.watch(authProvider);
  
  final dio = Dio(
    BaseOptions(
      baseUrl: 'http://localhost:8000/api',
      connectTimeout: Duration(seconds: 5),
    ),
  );
  
  // Add JWT token to all requests
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        if (authState.isAuthenticated) {
          options.headers['Authorization'] = 'Bearer ${authState.token}';
        }
        return handler.next(options);
      },
    ),
  );
  
  return dio;
});
```

#### **auth/**
Authentication state management:

- `auth_provider.dart` - Riverpod provider for auth state
- `token_storage.dart` - Secure local token storage

```dart
// auth_provider.dart
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref);
});

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier(this.ref) : super(AuthState.initial());
  
  final Ref ref;
  
  Future<void> login(String email, String password) async {
    try {
      final response = await ref.read(apiClientProvider).post(
        '/auth/login',
        data: {'email': email, 'password': password},
      );
      
      final token = response.data['access_token'];
      await TokenStorage.saveToken(token);
      
      state = AuthState(
        isAuthenticated: true,
        token: token,
      );
    } catch (e) {
      state = AuthState.error(e.toString());
    }
  }
}
```

#### **utils/**
Helper functions and validators:

```dart
// validators.dart
class Validators {
  static String? validateEmail(String? email) {
    if (email == null || email.isEmpty) {
      return 'Email is required';
    }
    if (!email.contains('@')) {
      return 'Invalid email format';
    }
    return null;
  }
}
```

---

### **features/ Folder** (7 Feature Modules)

Each feature follows **Clean Architecture** with 3 layers:

```
features/competitions/
├── data/
│   ├── datasource.dart      # API calls
│   └── repository.dart      # Repository implementation
│
├── domain/
│   ├── entity.dart          # Business logic entities
│   └── usecase.dart         # Use cases (operations)
│
└── presentation/
    ├── provider.dart        # Riverpod state
    └── screens/
        ├── competitions_screen.dart
        └── competition_detail_screen.dart
```

#### **Data Layer**
API calls and data fetching:

```dart
// features/competitions/data/datasource.dart
class CompetitionsDataSource {
  final Dio dio;
  
  Future<List<Competition>> getCompetitions() async {
    final response = await dio.get('/competitions');
    return (response.data as List)
        .map((c) => Competition.fromJson(c))
        .toList();
  }
}

// features/competitions/data/repository.dart
class CompetitionsRepository {
  final CompetitionsDataSource dataSource;
  
  Future<List<Competition>> getCompetitions() async {
    return await dataSource.getCompetitions();
  }
}
```

#### **Domain Layer**
Business logic entities:

```dart
// features/competitions/domain/entity.dart
class Competition {
  final int id;
  final String name;
  final String description;
  final DateTime startDate;
  final DateTime endDate;
  
  Competition({
    required this.id,
    required this.name,
    required this.description,
    required this.startDate,
    required this.endDate,
  });
  
  factory Competition.fromJson(Map<String, dynamic> json) {
    return Competition(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      startDate: DateTime.parse(json['start_date']),
      endDate: DateTime.parse(json['end_date']),
    );
  }
}
```

#### **Presentation Layer**
UI and state management:

```dart
// features/competitions/presentation/provider.dart
final competitionsProvider = FutureProvider<List<Competition>>((ref) async {
  final repository = ref.watch(competitionsRepositoryProvider);
  return repository.getCompetitions();
});

// features/competitions/presentation/screens/competitions_screen.dart
class CompetitionsScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final competitions = ref.watch(competitionsProvider);
    
    return competitions.when(
      loading: () => CircularProgressIndicator(),
      error: (err, stack) => Text('Error: $err'),
      data: (data) => ListView(
        children: data.map((c) => CompetitionCard(c)).toList(),
      ),
    );
  }
}
```

---

### **shared/ Folder**

Reusable components:

```dart
// shared/widgets/primary_button.dart
class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  
  PrimaryButton({
    required this.label,
    required this.onPressed,
  });
  
  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      child: Text(label),
    );
  }
}
```

---

## 7 Feature Modules

### **1. Competitions** - Browse and manage competitions
### **2. Teams** - Team registration and management
### **3. Datasets** - Image upload and dataset browsing
### **4. Labeling** - Image labeling and validation
### **5. Model Submission** - Model upload and versioning
### **6. Evaluation** - Evaluation progress tracking
### **7. Leaderboard** - Real-time rankings display

Each follows the same data/domain/presentation structure.

---

## State Management (Riverpod)

Riverpod providers for each concern:

```dart
// Providers manage state
final userProvider = StateNotifierProvider<UserNotifier, User>((ref) {
  return UserNotifier(ref);
});

final competitionsProvider = FutureProvider<List<Competition>>((ref) {
  return ref.watch(competitionsRepositoryProvider).getAll();
});

// Use in widgets
ref.watch(userProvider)        // Reactive state
ref.read(userProvider)         // One-time read
ref.invalidate(userProvider)   // Force refresh
```

---

## Platform-Specific Code

Platform configurations:

```
frontend/
├── ios/           # iOS-specific build files
├── android/       # Android-specific build files
├── web/           # Web-specific build files
└── pubspec.yaml   # Dependencies
```

---

## Navigation Pattern

Using go_router for type-safe navigation:

```dart
// Simple navigation
context.go('/competitions');

// With parameters
context.go('/competitions/${competitionId}');

// With extra data
context.push('/detail', extra: competition);

// Back navigation
context.pop();
```

---

## HTTP Requests Example

```dart
// GET request
final data = await ref.read(apiClientProvider).get('/competitions');

// POST request
await ref.read(apiClientProvider).post(
  '/teams',
  data: {'name': 'My Team'},
);

// File upload
await ref.read(apiClientProvider).post(
  '/upload/image',
  data: FormData.fromMap({'image': MultipartFile.fromBytes(imageData)}),
);
```

---

## Testing in Flutter

```dart
// test/features/competitions/competitions_test.dart
void main() {
  group('CompetitionsScreen', () {
    testWidgets('Shows competitions list', (WidgetTester tester) async {
      await tester.pumpWidget(MyApp());
      
      expect(find.byType(ListView), findsOneWidget);
    });
  });
}
```

---

## Development Workflow

```bash
# Run app (hot reload enabled)
flutter run

# Run on specific device
flutter run -d chrome  # Web
flutter run -d emulator-5554  # Android

# Build for production
flutter build web
flutter build apk
flutter build ios
```

---

## Dependencies (pubspec.yaml)

```yaml
dependencies:
  flutter: sdk: flutter
  dio: ^5.0.0              # HTTP client
  riverpod: ^2.0.0         # State management
  go_router: ^10.0.0       # Navigation
  hive: ^2.0.0             # Local storage
  flutter_test:
    sdk: flutter
```

Frontend = User Interface Layer 🎨
