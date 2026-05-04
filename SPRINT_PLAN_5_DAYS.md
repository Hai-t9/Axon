# 🚀 Axon 5-Day Accelerated Sprint Plan (Hybrid Tech + Domain)

## 📌 Context & Execution Strategy
**Team Size:** 4 Developers (Mustafa, Bouzian, Abderrahman, Danil)
**Velocity Limit:** 10 hours/day for 5 days (200 Total Developer Hours).
**Acceleration:** The team is fully utilizing AI tooling (GitHub Copilot, LLM Prompting). Boilerplate and standard CRUD generation will take minutes, meaning the 10 hours/day will be focused on **complex architecture, wiring, edge cases, strict UI state management, and high-fidelity testing.** 

### 🎭 Role Assignments
- **Mustafa:** Core Auth, Competitions, Teams, Phases 👉 **Web Admin Frontend**
- **Bouzian:** Submissions, Evaluator, Evaluations, Task Queue 👉 **Web Admin Frontend**
- **Abderrahman (Lead):** Image Pipeline, Cleaner System 👉 **Flutter Mobile Frontend**
- **Danil:** Labels, Leaderboard, Validation, Dashboard 👉 **Flutter Mobile Frontend**

---

## 📅 Day 1: Backend Foundation & Data Modeling
**Goal:** The entire database schema is pushed to a live local/dev database, and all foundational CRUD endpoints and Docker containers are running.

### 🧑‍💻 Mustafa
* **Objective:** Scaffold the monolithic backend (Node/Express/Prisma) and establish the Auth perimeter.
* **Deliverables:** Working backend repo, `users` and `teams` endpoints, JWT middleware.
* **To-Dos:**
  - [ ] Initialize Node.js + Prisma environment. Export Prisma schema definitions.
  - [ ] Implement `POST /auth/register` and `POST /auth/login`.
  - [ ] Prompt Copilot to build the `AuthGuard` and `RoleGuard` middlewares.
  - [ ] Build basic CRUD controllers for `Team`.

### 🧑‍💻 Bouzian
* **Objective:** Setup the asynchronous infrastructure.
* **Deliverables:** Running Redis/BullMQ instance, `Submission` API endpoints.
* **To-Dos:**
  - [ ] Provision Redis via Docker Compose.
  - [ ] Set up BullMQ or equivalent Task Queue in the Node.js backend.
  - [ ] Scaffold Prisma schemas for `Submission`, `Model`, and `Evaluation`.
  - [ ] Write the `POST /submissions` endpoint that adds a job to the queue.

### 🧑‍💻 Abderrahman
* **Objective:** Ingest files reliably.
* **Deliverables:** Working `Image` upload endpoint storing binaries to disk/S3 and logging metadata.
* **To-Dos:**
  - [ ] Set up `multer` interceptors for file validation (size/format).
  - [ ] Prompt Copilot to generate EXIF-extraction (`exifreader`) middleware.
  - [ ] Build `POST /teams/:id/images` and store physical files securely.
  - [ ] Seed dummy image data for tomorrow's Cleaner testing.

### 🧑‍💻 Danil
* **Objective:** Establish the Labeling constraints and Competition read-models.
* **Deliverables:** Working `Label` endpoints and skeletal `Leaderboard` aggregation logic.
* **To-Dos:**
  - [ ] Implement `Label` and `Validation` schema in Prisma.
  - [ ] Build endpoints for submitting labels linked to an Image ID.
  - [ ] Write complex aggregation SQL/Prisma-queries for `GET /leaderboard` scoring.
  - [ ] Setup `Dashboard` metric aggregations (total images, verified vs on-hold).

---

## 📅 Day 2: Advanced Backend Logic & Inter-Module Wiring
**Goal:** Your independent APIs start talking to each other. The Task Queue processes images, validations trigger status updates, and phases restrict access.

### 🧑‍💻 Mustafa
* **Objective:** Phase management and complex access control.
* **Deliverables:** Competitors mapped to Competitions, bounded by strict time Phases.
* **To-Dos:**
  - [ ] Build `Phase` module logic (e.g., stopping uploads if the competition phase is "closed").
  - [ ] Inject Phase-checks into Abderrahman's Image Upload route.
  - [ ] Build endpoints for Admin overrides.

### 🧑‍💻 Bouzian
* **Objective:** Evaluator workers.
* **Deliverables:** The Task Queue actively picks up submissions and changes their scores.
* **To-Dos:**
  - [ ] Write `Evaluator` worker logic to read a submission payload from the queue.
  - [ ] Create mock scripts that simulate automated AI evaluation.
  - [ ] Update `Evaluation` database schemas asynchronously.

### 🧑‍💻 Abderrahman
* **Objective:** The Cleaner Pipeline.
* **Deliverables:** A high-performance, synchronous data-cleaning hook.
* **To-Dos:**
  - [ ] Implement `sharp` library to dynamically resize uploaded images to standard formats.
  - [ ] Build hash-comparison functions to find exact duplicate images.
  - [ ] Build `POST /competitions/:id/cleaner/run` to sweep the database and optimize storage.

### 🧑‍💻 Danil
* **Objective:** Validation state-machines.
* **Deliverables:** Labels transition cleanly based on Administrator actions.
* **To-Dos:**
  - [ ] Build logic that ties Bouzian’s `Task Queue` triggers into `Validation` status changes.
  - [ ] Ensure `Leaderboard` cache invalidates or updates instantly upon new validations.
  - [ ] Generate comprehensive mock data matching the real schemas.

---

## 📅 Day 3: Platform Split & UI Bootstrapping
**Goal:** The Backend is frozen (mocking any missing parts). The 4 developers split into Team Web and Team Mobile to build out frontends.

### 🧑‍💻 Mustafa (Web Admin)
* **Objective:** Scaffold the Admin dashboard.
* **Deliverables:** Running React/Vue portal with Authentication.
* **To-Dos:**
  - [ ] Prompt Copilot to build a modern Admin layout (Sidebar, Navbar, routing).
  - [ ] Implement login gateway linking to your JWT backend.
  - [ ] Build CRUD UI for managing Users and creating a new `Competition`.

### 🧑‍💻 Bouzian (Web Admin)
* **Objective:** Async monitoring views.
* **Deliverables:** Queue and Submission status datatables.
* **To-Dos:**
  - [ ] Build real-time (or polled) datatables showing all Active Submissions.
  - [ ] Create the UI for the `Evaluation` log, showing successes vs errors.
  - [ ] Build visual indicators (spinners, progress bars) for queue health.

### 🧑‍💻 Abderrahman (Flutter Mobile)
* **Objective:** Camera and storage.
* **Deliverables:** Competitors can open the app, log in, and snap a native photo.
* **To-Dos:**
  - [ ] Scaffold Flutter App structure (Bloc/Riverpod/GetX).
  - [ ] Integrate `camera` package to take high-res photos natively.
  - [ ] Build the local Flutter UI to preview the photo before labeling.

### 🧑‍💻 Danil (Flutter Mobile)
* **Objective:** The manual Labeling Canvas.
* **Deliverables:** An interactive screen to draw bounding boxes or tag images.
* **To-Dos:**
  - [ ] Build interactive Flutter widgets allowing bounding-box dragging or category selection over Abderrahman's photo preview.
  - [ ] Structure the complex JSON payload representing the 'Label'.
  - [ ] Scaffold empty Leaderboard screen with a mockup UI.

---

## 📅 Day 4: Deep UI Wiring & Error Handling
**Goal:** Frontends connect seamlessly to the Backend. Edges cases (bad wifi, giant files, unauthorized access) are mapped and handled.

### 🧑‍💻 Mustafa (Web Admin)
* **Objective:** Phase transitioning and system controls.
* **Deliverables:** Admins can fully manipulate the competition lifecycle.
* **To-Dos:**
  - [ ] Wire UI buttons that advance the Competition `Phase`.
  - [ ] Create UI for viewing Team hierarchies.
  - [ ] Handle 401/403 API errors effectively (bumping users back to login).

### 🧑‍💻 Bouzian (Web Admin)
* **Objective:** Interactive Validation and Dashboard tools.
* **Deliverables:** Admins manually overriding or reviewing evaluations.
* **To-Dos:**
  - [ ] Build the specific "Review Image" screen where Admins see Danil's labels and Bouzian's evaluations, and can click "Approve" or "Reject".
  - [ ] Wire up charts/graphs using Danil's Dashboard aggregate APIs.

### 🧑‍💻 Abderrahman (Flutter Mobile)
* **Objective:** Secure, robust networking.
* **Deliverables:** Uploads perfectly survive bad internet and hit the backend securely.
* **To-Dos:**
  - [ ] Implement Flutter HTTP interceptors for automatic JWT injection.
  - [ ] Build multipart-form uploader tying the Photo + Danil's Label payload together to hit `POST /teams/:team/images`.
  - [ ] Handle Server Rejections nicely (e.g. telling the user "This image is a duplicate").

### 🧑‍💻 Danil (Flutter Mobile)
* **Objective:** Real-time Leaderboard & Validation streaming.
* **Deliverables:** The Competitor experiences a polished status pipeline.
* **To-Dos:**
  - [ ] Finish hooking the `GET /leaderboard` data into beautiful Flutter lists/cards.
  - [ ] Add a "My Images" screen where the user can see if their submissions are "Verified" or "On Hold".

---

## 📅 Day 5: End-to-End Integration, Bug-Bash & Deployment
**Goal:** The complete flow—Capture → Label → Upload → Queue → Evaluate → Admin Validation → Leaderboard—runs flawlessly.

### 👨‍👩‍👦‍👦 Group Integration Testing (Hours 1-4)
- **The Core Loop:** Abderrahman (App) logs in -> Snaps Photo -> Danil (App) tags it -> Submits. Bouzian (Queue) parses it -> Logs evaluation. Mustafa (Admin) views the dashboard -> Validates it -> Danil (App) sees his Leaderboard rank jump.
- Identify all crashes, CORS issues, and misaligned JSON structures.

### 👨‍👩‍👦‍👦 Bug Bash & Polish (Hours 5-8)
- **Mustafa:** Deploy Backend & Web Frontend (e.g., Vercel, Render, AWS). Fix CORS.
- **Bouzian:** Ensure Task Queue survives server restarts.
- **Abderrahman:** Polish Camera loading stutters and compress logic on mobile before upload.
- **Danil:** Fix padding, UI overlays, and state-management glitches in Flutter.

### 👨‍👩‍👦‍👦 Final Presentation Prep (Hours 9-10)
- Ensure realistic dummy data exists in the production database.
- Document demo scripts.

---

## 💡 AI / Copilot Tips for 10x Speed
1. **Never hand-write Models/Interfaces:** Give Copilot the DBML schema or Markdown specs directly and say `Generate Prisma Schema and TypeScript interfaces for these`. 
2. **Bulk UI Generation:** For Web, provide Copilot with a screenshot or detailed prompt: `Create a Tailwind React component for a data table showing fields X, Y, Z with an Approve/Reject button`.
3. **Flutter State:** Use rigorous prompts like: `Create a Riverpod Notifier that handles multipart image uploads, yielding states: Initial, Loading, Success, Error(message)`.
