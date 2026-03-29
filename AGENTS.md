# Minacast — Agent Rules

This file is the source of truth for every AI coding session on this project.
Read it fully before writing any code.

---

## Project Context

Read these files at the start of every session:

- `docs/SPEC.md` — product requirements, data models, screens, user journeys, and out-of-scope items
- `docs/PROGRESS.md` — what is built, what is in progress, and what is next
- `docs/DECISIONS.md` — all architectural decisions made and the reasoning behind them

---

## Session Start Ritual

Follow these steps in order before touching any files:

1. `git log --oneline -10` — understand what was done recently
2. `git status` — check for uncommitted changes or unexpected state
3. Read `docs/PROGRESS.md` — confirm what is built and what is next
4. **Ask the user what we are working on today.** Do not assume. Do not start coding until the user has confirmed the session goal.

---

## Tech Stack

Never deviate from this stack without explicit user approval. If a new package is needed, see the Forbidden section below.

| Layer | Technology / Package |
|---|---|
| Framework | Flutter (Dart), Android only |
| Local database | `sqflite` (raw SQL, no ORM) |
| State management | `riverpod` |
| Audio engine | `just_audio` |
| Background audio / MediaSession | `audio_service` |
| Background tasks | `workmanager` |
| Local notifications | `flutter_local_notifications` |
| RSS parsing | `dart_rss` |
| Networking | `http` |
| Image caching | `cached_network_image` |
| HTML rendering | `flutter_html` |
| External APIs | iTunes Search API (podcast discovery), RSS feed URLs (episode data) |

---

## Code Rules

### Type Safety

- Always declare explicit types on function signatures, class fields, and provider return types. Do not rely on `var` or `dynamic` except where inference is unambiguous and local.
- Prefer `sealed` classes or explicit enum types for domain states (e.g., playback state, load state). Do not use bare strings or magic numbers to represent state.
- Never silence analyzer warnings with `// ignore:` without a comment explaining why.

### Error Handling

- All async functions that touch the network or the database must handle errors explicitly. Do not let exceptions propagate silently to the framework.
- In Riverpod providers, use `AsyncValue` (`AsyncData`, `AsyncLoading`, `AsyncError`) to represent async state. Screens should handle all three cases.
- WorkManager task callbacks must catch all exceptions and return `Future.value(false)` on failure — never let an uncaught exception crash the background isolate.
- Do not show raw exception messages to the user. Map errors to human-readable strings at the UI boundary.

### Testing

- Every new non-trivial function must have a corresponding unit test.
- Riverpod providers should be tested with `ProviderContainer` and overrides — do not test providers by rendering widgets unless UI behavior is what's being tested.
- Database helpers should be tested against an in-memory SQLite instance (`:memory:` path in `sqflite`).
- Do not ship a session's work without running the test suite.

### Security

- Never hardcode API keys, credentials, or secrets in source files. (The iTunes Search API requires no key — if a key is ever needed for a future API, use `flutter_dotenv` or equivalent and add the file to `.gitignore`.)
- Never log user data, episode content, or file paths at `INFO` level or above in production builds. Use `kDebugMode` guards around any diagnostic logging.
- File paths for downloaded audio must be stored in the app's sandboxed files directory (`getApplicationDocumentsDirectory()` or `getApplicationSupportDirectory()`). Never write to shared external storage without explicit permission.
- Validate all data read from RSS feeds before inserting into the database — null-check required fields, truncate unexpectedly large strings.

---

## Testing Configuration

- **Test framework:** Flutter's built-in `flutter_test` package (ships with the SDK). For widget tests, use `flutter_test`. For unit tests, plain Dart `test` package.
- **Run full suite:** `flutter test`
- **Run a single file:** `flutter test test/path/to/file_test.dart`
- **Database tests:** Use `sqflite_common_ffi` with `databaseFactoryFfi` and an in-memory database (pass `inMemoryDatabasePath` as the database path) to avoid touching the real filesystem.
- **Audio tests:** Mock the `AudioHandler` with a fake implementation. Do not instantiate `just_audio` or `audio_service` in unit tests — they require platform channels.
- **Environment setup needed:** None for unit/widget tests. Integration tests require a connected Android device or emulator.

---

## Forbidden

### New Dependencies

Before installing any new package:

1. Explain why it is needed and what problem it solves.
2. Confirm that the same thing cannot be done with a package already in the stack.
3. Get explicit user approval before running `flutter pub add` or editing `pubspec.yaml`.

### Database Schema Changes

Do not alter the `podcasts`, `episodes`, `queue`, or `settings` table schema without confirming with the user first. Schema changes affect existing installs and require migration logic in `onUpgrade`.

### Refactoring Working Code

Do not rewrite working code to use a different pattern, rename established conventions, or restructure files unless the user has explicitly asked for it. A working implementation that is slightly imperfect is better than an unnecessary rewrite that introduces new bugs.

### Out-of-Stack Patterns

Do not introduce `bloc`, `get_it`, `provider` (the old package), `GetX`, `MobX`, or any state management approach other than Riverpod. Do not introduce an ORM or query builder over `sqflite`.

### Secrets in CI/CD

Never echo, print, or persist secrets in logs, build artifacts, or committed files. If a pipeline step requires a secret, use the platform's secret store. Fail the build if a required secret is missing rather than silently continuing. Validate environment variables at startup or build time, not lazily at first use.

---

## Developer Context

The developer is a content creator and developer comfortable with AI-assisted agentic coding. They understand technical concepts and architectural decisions but rely on Claude Code to write, debug, and iterate on implementation. This means:

- **Explain non-obvious choices as you make them** — a one-sentence note on why you structured something a particular way is always welcome.
- **Do not over-explain basics** — skip "here's what a Riverpod provider is" and go straight to what this specific provider does and why.
- **Flag risks proactively** — if a choice has a known gotcha (e.g., `audio_service` and Dart isolates), mention it before the user hits it.
- **Keep responses concise** — lead with the code or the answer, then explain if needed.

---

## Disagreements

If the user asks you to do something that would:

- Violate a rule in this file
- Introduce a security risk
- Create meaningful technical debt
- Go against established best practices for the Flutter/Dart stack

…say so before proceeding. State clearly what the concern is and what you would recommend instead. Then let the user decide. Do not silently comply with something you believe is a mistake. A brief "I'd push back on this because X — want me to proceed anyway?" is always appropriate.

---

## End of Session

When the user says "we're done" or "end session", follow this process in order:

1. **Update `docs/PROGRESS.md`:** Move completed items from Not Started → Implemented. Move anything partially done to In Progress. Add any newly discovered tasks to Not Started. Add any blockers or open questions to the Blocked section.
2. **Suggest a git commit message** using this format:
   ```
   type: short summary

   - bullet describing change 1
   - bullet describing change 2
   ```
   Valid types: `feat`, `fix`, `refactor`, `test`, `chore`, `docs`.
3. **Update `docs/DECISIONS.md`** if any architectural decisions were made during the session (new package adopted, schema change, pattern chosen). Append to the "Decisions Made During Development" section.
4. **Recommend what to tackle first next session** — one sentence, referencing the specific PROGRESS.md item.
