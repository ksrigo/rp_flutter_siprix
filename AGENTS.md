# Repository Guidelines

## Project Structure & Module Organization

The Flutter app centers on `lib/main.dart`, which bootstraps modules housed under `lib/core` (foundations such as config, services), `lib/features` (feature-specific screens, cubits, and widgets), and `lib/shared` (reusable UI and utilities). Assets (icons, sounds, translations) live under `assets/`; update `pubspec.yaml` when adding files. Platform scaffolding sits in `android`, `ios`, `web`, `macos`, `linux`, and `windows`. Place design references in `mockup/` and keep experimental snippets inside `sample_siprix.dart` rather than shipping them. Tests reside in `test/unit`, `test/widget`, and `test/integration`; mirror the lib folder layout when adding new coverage.

## Build, Test, and Development Commands

- `flutter pub get` downloads declared packages; run after editing dependencies.
- `flutter run` launches the default development build on the attached device or emulator.
- `flutter build apk --release` (or `ipa`, `web`, etc.) creates distributable binaries; prefer CI for official artifacts.
- `flutter analyze` enforces the lint rules in `analysis_options.yaml`.
- `flutter test` executes all unit and widget suites; append a directory path (e.g., `flutter test test/integration`) to scope runs.
- `dart format lib test` applies canonical formatting before commits.

## Coding Style & Naming Conventions

Dart files use two-space indentation and must satisfy the Flutter lint set. Name classes and enums in `PascalCase`, methods and variables in `camelCase`, and files in `snake_case.dart`. Keep widgets small and composable inside `lib/shared` when reused in multiple features. Prefer dependency injection through constructors, and document non-trivial logic with concise comments. Avoid storing secrets in-source; use per-platform secure storage.

## Testing Guidelines

Add new tests alongside the code they cover using the `_test.dart` suffix. Widget and integration tests should mock SIP endpoints where practical to keep runs deterministic. Target at least parity coverage with the affected feature and block merges when `flutter test --coverage` reports regressions. Use golden tests for consistent UI when updating shared components, and record reproduction steps in `SIPRIX_TROUBLESHOOTING.md` when you fix call-handling regressions.

## Commit & Pull Request Guidelines

Write imperative, present-tense commit subjects ("Fix push notification hang") and include brief bodies for context when touching signaling flows. Reference issue IDs or ticket URLs when available. Pull requests should summarize behavior changes, list test commands executed, note platform-specific impacts, and attach screenshots for UI tweaks. Include call-flow traces or logs if the change touches `core` SIP handling so reviewers can spot regressions quickly.

## 🟢 1. API Agent

- **Purpose**: Handles all API-related development (FastAPI, SQLModel, authentication, error handling).
- **Responsibilities**:
  - Generate endpoints from specifications.
  - Integrate with database models.
  - Implement token refresh logic.
- **Inputs**: Endpoint specs, DB schemas, authentication rules.
- **Outputs**: FastAPI code (routers, models, services).
- **Notes**: Must follow project’s PEP8 style and include type hints.

---

## 🟠 2. Softphone Agent

- **Purpose**: Develops Flutter + Siprix SDK softphone features.
- **Responsibilities**:
  - Implement UI pages (Dialer, Recents, Settings).
  - Implement using Siprix SDK
- **Inputs**: UI mockups, SDK docs, navigation structure.
- **Outputs**: Flutter code for widgets and pages.

---

## 🟡 3. Docs Agent

- **Purpose**: Prepares documentation and guides.
- **Responsibilities**:
  - Write README, API docs, and developer onboarding.
  - Maintain consistency with code examples.
- **Inputs**: Existing code, dev notes.
- **Outputs**: Markdown docs.

---

# ⚙️ Execution Rules

- Agents **must not overlap** responsibilities.
- All generated code must be **idempotent** (safe to re-run).
- Style guide:
  - Python → PEP8, type hints
  - Flutter → null-safety, provider or Riverpod for state management
- Persistence:
  - API + DB must be production-safe.
  - Flutter code must compile without modification.
