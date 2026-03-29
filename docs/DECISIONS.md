# Minacast — Architectural Decisions

---

## Flutter for Android

- **Date:** 2026-03-29
- **Status:** Active
- **Decision:** Build the app in Flutter (Dart), targeting Android only.
- **Why:** The developer works with AI-assisted coding tools and wanted a single, well-documented framework that Claude Code handles well. Flutter's widget library, hot reload, and large ecosystem of audio/background packages made it a practical fit. iOS is explicitly out of scope for v1, so cross-platform capability is a future bonus, not a current requirement.
- **Alternatives considered:** Brought in as a prior choice.
- **Consequences:** All UI is Flutter widgets, not native Android views. The team gains hot reload and a future path to iOS at the cost of a Dart learning curve and occasional platform-channel friction for deep Android features (MediaSession, WorkManager). Android-specific configuration (manifest, Gradle) is still required.
- **Revisit if:** iOS support becomes a v2 requirement (Flutter already covers it); or if a feature requires deep native Android integration that can't be bridged via an existing package.

---

## SQLite via `sqflite` (no ORM)

- **Date:** 2026-03-29
- **Status:** Active
- **Decision:** Use `sqflite` for local persistence with hand-written SQL. No ORM.
- **Why:** The data model is small and stable (4 tables, no complex joins). An ORM like `drift` adds code-generation overhead and a steeper learning curve. Raw `sqflite` queries are straightforward, easy to read back, and sufficient for the query patterns needed (feed sort, queue order, unlistened-episode lookup).
- **Alternatives considered:** `drift` (formerly Moor) was noted as an option. It offers type-safe queries and migration helpers but requires a build runner and generated files, adding setup friction that isn't justified by the app's query complexity.
- **Consequences:** Migrations must be managed manually via `onUpgrade`. Schema changes require care to avoid breaking existing installs. No compile-time query safety — SQL errors surface at runtime.
- **Revisit if:** The schema grows significantly (new tables, complex reporting queries) or migration complexity becomes a maintenance burden.

---

## No Backend, No Server

- **Date:** 2026-03-29
- **Status:** Active
- **Decision:** There is no backend, API server, or cloud infrastructure of any kind. All data lives in SQLite on the device.
- **Why:** The primary constraint is zero recurring infrastructure cost. A backend would require a hosted service, a domain, and ongoing maintenance. The app's use case (personal podcast client, single user per device) has no need for cross-device sync, shared state, or server-side computation.
- **Alternatives considered:** Brought in as a prior choice.
- **Consequences:** All data is permanently device-local. Uninstalling the app destroys all subscriptions, history, and downloaded files. There is no account recovery, no backup mechanism, and no sync if the user switches devices. These are accepted trade-offs.
- **Revisit if:** Users request cross-device sync or backup. Would require introducing a backend or a third-party sync service (e.g., iCloud, Google Drive export).

---

## No Authentication

- **Date:** 2026-03-29
- **Status:** Active
- **Decision:** No authentication of any kind. No accounts, no login, no sign-up.
- **Why:** There is no backend to authenticate against, and a single-user local app has no need to verify identity. Adding auth would create friction with no benefit.
- **Alternatives considered:** None. This follows directly from the no-backend decision.
- **Consequences:** Any person with physical access to the device has full access to the app and its data. This is the expected behavior for a local personal app and is consistent with how native Android apps like Podcast Addict behave.
- **Revisit if:** A backend is ever introduced (see No Backend decision above).

---

## Android-Only Deployment

- **Date:** 2026-03-29
- **Status:** Active
- **Decision:** v1 targets Android only. The Play Store is the sole distribution channel, with a one-time $25 developer registration fee.
- **Why:** The developer is targeting Android first. iOS development requires an Apple Developer account ($99/year recurring), a Mac build environment, and App Store review. The Play Store's one-time fee and simpler sideloading options make Android the lower-friction starting point.
- **Alternatives considered:** Brought in as a prior choice.
- **Consequences:** No iOS build targets, no platform-specific iOS code, no TestFlight. The Flutter codebase is written to be iOS-compatible in principle (no hard Android-only Dart code), but the `audio_service` and `workmanager` Android-specific manifest configuration is not mirrored for iOS.
- **Revisit if:** There is meaningful demand for an iOS version.

---

## Riverpod for State Management

- **Date:** 2026-03-29
- **Status:** Active
- **Decision:** Use `riverpod` (code-gen flavor) for all state management and dependency injection.
- **Why:** Riverpod is compile-safe, async-first, and avoids the global mutable state pitfalls of `Provider`. It handles the async database reads and audio state streams that this app depends on without boilerplate. It is well-suited to AI-assisted development because its patterns are widely represented in training data and documentation.
- **Alternatives considered:** `provider` (the predecessor — less safe, not chosen), `flutter_bloc` (more boilerplate, steeper learning curve for this use case), `get_it` + manual state (no reactive UI updates out of the box). None offered a better fit for the async-heavy, reactive data flow this app requires.
- **Consequences:** All shared state (current episode, queue, feed, settings) lives in Riverpod providers. Screens rebuild reactively when provider state changes. Provider testing is straightforward with `ProviderContainer` overrides.
- **Revisit if:** Stable for v1.

---

## `just_audio` + `audio_service` for Playback

- **Date:** 2026-03-29
- **Status:** Active
- **Decision:** Use `just_audio` as the audio engine and `audio_service` as the Android MediaSession integration layer.
- **Why:** `just_audio` is the de facto standard Flutter audio package. It supports streaming URLs, local file playback, speed control, and seeking with a single consistent API. `audio_service` is the companion package that bridges `just_audio` to the Android MediaSession API, enabling lock screen and notification shade controls without custom platform code. The two packages are designed to be used together.
- **Alternatives considered:** `audioplayers` is simpler but does not support background playback or MediaSession integration without significant custom native code. No serious alternative to `audio_service` exists for this requirement.
- **Consequences:** Audio runs in a foreground service (required by Android for background playback). This requires `FOREGROUND_SERVICE` and `FOREGROUND_SERVICE_MEDIA_PLAYBACK` permissions in `AndroidManifest.xml`. The `AudioHandler` class becomes the single source of truth for all playback state.
- **Revisit if:** Either package becomes unmaintained. Both are actively maintained as of the decision date.

---

## WorkManager for Background Sync

- **Date:** 2026-03-29
- **Status:** Active
- **Decision:** Use `workmanager` (Flutter wrapper for Android WorkManager) to run a daily background task that checks for new episodes and silently downloads audio files.
- **Why:** Android restricts background execution aggressively. WorkManager is the platform-recommended approach for deferrable background tasks that must survive app restarts and device reboots. The `workmanager` Flutter package wraps it with a Dart-callable API. No viable alternative exists for reliable periodic background work on Android.
- **Alternatives considered:** `flutter_background` and raw `Isolate`-based approaches do not survive app kill or device restart. WorkManager is the only realistic option.
- **Consequences:** Background tasks run in a separate Dart isolate and cannot directly call Riverpod providers or update Flutter UI. Database reads/writes in the task must use `sqflite` directly. Task scheduling is approximate (Android may defer tasks for battery optimization). The daily cadence is a best-effort interval, not an exact timer.
- **Revisit if:** Users report significant delays in new-episode notifications, suggesting a shorter polling interval is needed.

---

## Silent Downloads (No Download Management UI)

- **Date:** 2026-03-29
- **Status:** Active
- **Decision:** Downloads are fully automatic and invisible. There is no per-episode download state indicator, progress bar, cancel button, or manual download trigger in the UI.
- **Why:** Simplicity. A download management UI requires tracking download state in the DB, surfacing that state in episode list items, and handling partial/failed downloads gracefully. The silent approach keeps the UI clean and the implementation scope contained. The automatic logic (oldest unlistened, ≥ 500 MB free) covers the common case without requiring user decisions.
- **Alternatives considered:** Explicit per-episode download buttons were considered and explicitly ruled out for v1 as scope reduction.
- **Consequences:** Users have no visibility into what is or isn't downloaded. They cannot force a download, cancel one, or see storage usage per podcast. If a download fails silently, the episode falls back to streaming with no indication. The 500 MB threshold is a hard-coded heuristic with no user-facing control.
- **Revisit if:** User feedback indicates frustration with not knowing what's downloaded, or if storage management becomes a complaint.

---

## iTunes Search API for Podcast Discovery

- **Date:** 2026-03-29
- **Status:** Active
- **Decision:** Use the iTunes Search API as the podcast discovery endpoint. No alternative search backend.
- **Why:** The iTunes Search API is free, requires no API key, has no rate-limit documentation that would affect a single-user app, and returns the RSS feed URL alongside podcast metadata. It covers the vast majority of podcasts in existence. It is the standard approach used by independent podcast clients.
- **Alternatives considered:** `podcastindex.org` has a more modern API with richer metadata but requires API key registration. The iTunes API requires nothing and has been stable for over a decade.
- **Consequences:** Search quality and catalog coverage depend entirely on Apple's index. Podcasts not listed in the iTunes directory are not discoverable (RSS URL direct-entry is out of scope for v1). The API has no formal SLA and could change without notice.
- **Revisit if:** The iTunes API degrades, or users request direct RSS URL entry (a common power-user feature in v2).

---

## Local Notifications Only (No FCM)

- **Date:** 2026-03-29
- **Status:** Active
- **Decision:** Use `flutter_local_notifications` for all notifications. No Firebase Cloud Messaging or any external push notification service.
- **Why:** Push notifications require a backend to send them, which this project explicitly does not have. All notification triggers (new episodes found) originate on-device from the WorkManager task. Local notifications are sufficient and require no server, no SDK key, and no recurring cost.
- **Alternatives considered:** None viable — FCM requires a backend to send messages, which contradicts the no-backend constraint.
- **Consequences:** Notifications only fire when the WorkManager task runs (approximately daily). There is no real-time push for new episodes. Users will not be notified of new episodes more frequently than the task cadence.
- **Revisit if:** A backend is introduced and real-time notification delivery becomes a requirement.

---

## Decisions Made During Development

_This section is for architectural decisions made after the project has started. Each decision should follow the same format above. New entries are appended here during the end-of-session process whenever a meaningful technical choice is made during a working session._

_(empty to start)_
