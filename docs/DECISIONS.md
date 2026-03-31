# Minacast — Architectural Decisions

---

## Home feed shows only unlistened/in-progress episodes

- **Date:** 2026-03-30
- **Status:** Active
- **Decision:** `getAllEpisodesSortedByDate` filters `is_completed = 0`. Completed episodes are hidden from the home feed.
- **Why:** The home feed is a listening queue, not a listening history. Showing completed episodes clutters the feed and makes "Play All" less useful (you'd re-queue things you've already heard).
- **Alternatives considered:** A separate "History" tab (out of scope for v1); a toggle to show/hide completed (added complexity for marginal gain).
- **Consequences:** Users have no in-app way to re-listen to a completed episode from the home feed. If re-listening becomes a requested feature, the episode detail screen (accessible from Podcast Detail) still shows all episodes including completed ones.
- **Revisit if:** Users want a history/re-listen flow.

---

## Sort toggle is ephemeral (not persisted to settings)

- **Date:** 2026-03-30
- **Status:** Active
- **Decision:** `feedSortProvider` is an in-memory `NotifierProvider`. Sort order resets to newest-first on cold start.
- **Why:** Keeps the implementation simple — no settings table write needed, no migration risk. The sort order is a session preference, not a long-lived user setting like dark mode or playback speed.
- **Revisit if:** Users consistently complain about losing their sort preference on restart.

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

## Downloads — Light-Touch Visible System

- **Date:** 2026-03-29 (revised 2026-03-31)
- **Status:** Active
- **Decision:** Downloads are automatic but now lightly visible. Three mechanisms work together: (1) a daily WorkManager background task downloads one episode per podcast silently; (2) on app open over WiFi, up to 3 queue/feed episodes are downloaded automatically; (3) users can long-press any home feed episode to manually trigger a download. Episode list tiles show a pin icon when an episode is downloaded and a progress spinner during a manual download. Local files are automatically deleted when an episode finishes playing. There is no download management screen, cancel button, or per-podcast storage breakdown.
- **Why:** Real usage showed value in knowing which episodes are available offline. The light indicator (pin icon) requires no user action but answers "is this ready offline?" at a glance. The long-press manual trigger covers the case where a user wants to guarantee a specific episode is ready. Auto-delete on completion keeps storage from growing unbounded without requiring any user decision-making.
- **Alternatives considered:** A full download management UI (cancel, per-podcast breakdown, storage usage) was ruled out — too much scope for the value it adds. WiFi-only download constraint was chosen over cellular to protect data plans; no user toggle for this in v1.
- **Consequences:** Users on cellular only will never see auto-downloads and will see "Connect to WiFi" on manual download attempts. Storage is managed automatically. Orphaned partial downloads (e.g. app killed mid-download) will remain on disk but won't be referenced in the DB; they are harmless but not cleaned up in v1.
- **Revisit if:** Users request cellular download control, or orphaned partial files become a storage concern.

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

## App Color Scheme

- **Date:** 2026-03-29
- **Status:** Active
- **Decision:** Dark & minimal theme with electric blue accent.
  - Accent / primary: `#1DB9FF`
  - Scaffold background: `#111318`
  - Surface: `#1E2028`
  - On-surface text: `#E4E6EF`
- **Why:** Developer chose dark & minimal as the overall vibe (content-first, similar to Pocket Casts dark mode) and electric blue as the accent.
- **Consequences:** ThemeData is set up in `main.dart` using `ColorScheme.dark()` overrides with `useMaterial3: true`. The app logo SVG is at `assets/images/minacast.svg` — the accent color may be revisited during Phase 7 if it conflicts with brand colors in the final logo.
- **Revisit if:** Final logo introduces a different primary color that conflicts with `#1DB9FF`.

## Android Desugaring for Notifications

- **Date:** 2026-03-29
- **Status:** Active
- **Decision:** Enable core library desugaring in the Android app module and include `com.android.tools:desugar_jdk_libs`.
- **Why:** `flutter_local_notifications` requires core library desugaring in this project setup, and the Android build failed at `:app:checkDebugAarMetadata` until it was enabled.
- **Consequences:** `android/app/build.gradle.kts` now enables `isCoreLibraryDesugaringEnabled` in `compileOptions` and declares the desugaring library dependency. This is now part of the baseline Android build configuration for Minacast.
- **Revisit if:** The notification plugin changes its requirements or the Android Gradle setup is upgraded in a way that makes the explicit desugaring dependency unnecessary.

## Pass `Episode` Directly Into Episode Detail

- **Date:** 2026-03-29
- **Status:** Active
- **Decision:** `EpisodeDetailScreen` receives an `Episode` object directly from the existing list screens instead of introducing a dedicated provider or lookup layer for Session 3.1.
- **Why:** The app already has the full episode payload available at the tap site, and Session 3.1 only needs presentation plus placeholder actions. Passing the model directly keeps the implementation small, avoids premature state plumbing, and leaves playback integration free to evolve in Session 3.2 if it needs a richer source of truth.
- **Consequences:** Home and Podcast Detail own navigation into Episode Detail and pass the selected episode through the route constructor. If playback, queue, or progress persistence later require fresh DB reads or reactive updates, we may introduce a provider then rather than carrying that complexity before it is needed.
- **Revisit if:** Episode Detail needs live-updating playback state, DB-backed mutations, or data that is not already present on the `Episode` model.

## Single App-Wide Playback Controller

- **Date:** 2026-03-29
- **Status:** Active
- **Decision:** Minacast uses one app-wide `PodcastAudioHandler` initialized through `AudioService.init()` before `runApp()`, and Riverpod providers bridge its streams into the UI.
- **Why:** Playback state needs to survive navigation changes, drive both the Mini Player and Full Player, and remain the Android MediaSession source of truth for notification and lock screen controls. A single handler keeps playback, progress, speed, and current media metadata centralized instead of splitting those responsibilities across widgets.
- **Consequences:** UI screens call a thin playback command surface rather than constructing `just_audio` objects directly. Mini Player, Full Player, and persistence listeners all observe the same shared playback state. Future queue/autoplay work should extend this handler rather than add a parallel playback path.
- **Revisit if:** Queue playback or background sync requires a more explicit playlist abstraction than the current single-item handler model.

## Sleep Timer Default Aligned to Spec

- **Date:** 2026-03-29
- **Status:** Active
- **Decision:** Seed `settings.sleep_timer_default_minutes` as `30` instead of `0`.
- **Why:** `SPEC.md` defines the default sleep timer duration as 30 minutes, and Phase 3 began reading that value directly from SQLite when opening the Full Player sleep timer flow.
- **Consequences:** New installs default the sleep timer button to a 30-minute countdown. Tests now assert the seeded value is `30`, and later Settings work should treat that as the baseline default unless the user changes it.
- **Revisit if:** Product direction changes and the desired default becomes “off” instead of a preselected duration.

## Android Entry Activity Uses `AudioServiceActivity`

- **Date:** 2026-03-29
- **Status:** Active
- **Decision:** `MainActivity` extends `com.ryanheise.audioservice.AudioServiceActivity` instead of plain `FlutterActivity`.
- **Why:** The app initializes `audio_service` at startup, and the default `FlutterActivity` did not provide the cached Flutter engine integration that `audio_service` expects. On-device startup failed with `The Activity class declared in your AndroidManifest.xml is wrong` until the activity class matched the plugin contract.
- **Consequences:** Android startup now aligns with the `audio_service` integration guide, and `AudioService.init()` can complete without the manifest/activity mismatch crash seen during Phase 3 verification. Future Android activity customization should preserve the `AudioServiceActivity` behavior or explicitly reimplement its engine-provision methods.
- **Revisit if:** We later need a `FlutterFragmentActivity` subclass for another plugin, in which case we should move to `AudioServiceFragmentActivity` or an equivalent custom activity that still provides the correct engine hooks.

---

## Transaction-Wrapped Batch Inserts

- **Date:** 2026-03-29
- **Status:** Active
- **Decision:** All operations that insert a podcast plus its episodes use a single SQLite transaction via `DatabaseHelper.insertPodcastWithEpisodes`.
- **Why:** The subscribe flow previously inserted the podcast row and then looped through episodes one at a time. If the app crashed or an error occurred mid-loop, the database would contain a podcast with a partial episode set and no rollback. Phase 5's background sync will perform the same pattern.
- **Alternatives considered:** Keeping individual inserts with retry logic — rejected because a transaction is simpler, atomic, and matches the existing `replaceQueueOrder` pattern.
- **Consequences:** One new `DatabaseHelper` method wraps the insert in `db.transaction()`. The subscribe provider calls this instead of looping. Phase 5 background sync should reuse the same method.
- **Revisit if:** Never — transactional batch inserts are strictly better than non-transactional loops.

---

## WAL Mode for SQLite (Phase 5 Prerequisite)

- **Date:** 2026-03-29
- **Status:** Planned — implement when Phase 5 begins
- **Decision:** Enable `PRAGMA journal_mode=WAL` in `DatabaseHelper._initDb` alongside the existing `PRAGMA foreign_keys = ON`.
- **Why:** Phase 5 introduces a WorkManager background isolate that will read and write the database concurrently with the main isolate. WAL mode allows concurrent reads during writes, reducing the risk of `DatabaseException` from write-lock contention. The current default journal mode (DELETE) serializes all access.
- **Alternatives considered:** None — WAL is the standard recommendation for read-heavy workloads with occasional writes.
- **Consequences:** No downside for this use case. WAL is the SQLite default on most modern platforms.
- **Revisit if:** Never — WAL is strictly better for this workload.

---

## Schema Migration Deferred

- **Date:** 2026-03-29
- **Status:** Active (tech debt acknowledged)
- **Decision:** Defer `onUpgrade` implementation until the first schema change is needed. Current `_dbVersion` remains 1.
- **Why:** No schema changes are planned for Phase 5 or Phase 6. Adding migration infrastructure before it is needed would be speculative.
- **Alternatives considered:** Implementing a migration framework now — rejected as premature given no planned schema changes.
- **Consequences:** The first session that requires a schema change must implement `onUpgrade` in `lib/data/database_helper.dart` and bump `_dbVersion` before making the change. Skipping this will crash existing installs on app update. This is a prerequisite, not optional.
- **Revisit if:** Any phase unexpectedly needs a new column or table — implement `onUpgrade` first.

---

## Centralized App Settings Controller

- **Date:** 2026-03-29
- **Status:** Active
- **Decision:** Phase 6 settings are managed through one typed Riverpod `AsyncNotifier` that loads and persists all three app settings (`dark_mode`, `playback_speed`, `sleep_timer_default_minutes`) from SQLite, with small derived providers consumed by the UI.
- **Why:** All three values live in the same key-value table and are needed across multiple surfaces (`MaterialApp` theme, Settings screen, Full Player). A single controller avoids duplicated database reads, keeps parsing/serialization in one place, and gives the app one source of truth for persisted user preferences.
- **Alternatives considered:** Separate async providers for each setting were possible, but would duplicate SQLite access patterns and spread fallback/default parsing logic across multiple files.
- **Consequences:** Theme switching is now driven from app state instead of hard-coded theme constants in `main.dart`, and the Settings screen can update all preferences through a consistent API. Future settings should default to extending this controller unless they have a clear reason to live elsewhere.
- **Revisit if:** The settings surface grows enough that independent refresh lifecycles or feature-scoped settings modules become meaningfully easier to maintain.

---

## applicationId set to `com.developingwoot.minacast`

- **Date:** 2026-03-29
- **Status:** Active (permanent — cannot change after Play Store submission)
- **Decision:** Android `applicationId` (and Gradle `namespace`) set to `com.developingwoot.minacast`.
- **Why:** Google Play rejects apps with `com.example.*` application IDs. The chosen ID uses the developer's brand namespace (`developingwoot`) which matches other published projects.
- **Alternatives considered:** `io.minacast.app`, `com.minacast.app` — rejected in favour of the developer's existing brand namespace.
- **Consequences:** This ID is permanent. Changing it after Play Store submission creates a new app listing and cannot migrate existing installs. Any future deeplinks, Firebase config, or OAuth credentials must reference `com.developingwoot.minacast`.
- **Revisit if:** Never — treat as frozen once the app is live on the Play Store.

---

## SVG → PNG conversion via `cairosvg`

- **Date:** 2026-03-29
- **Status:** Active (one-time conversion, artefact committed)
- **Decision:** `assets/images/minacast.png` is generated from `minacast.svg` at 1024×1024 RGBA using the Python `cairosvg` library, not committed as a hand-crafted file or produced via an SVG rendering Flutter package.
- **Why:** `flutter_launcher_icons` and `flutter_native_splash` both require a raster PNG input. The existing PNG was a 1×1 placeholder. `cairosvg` was the fastest available tool in the WSL2 environment. The generated PNG only needs to be regenerated if the SVG logo changes.
- **Alternatives considered:** Inkscape, ImageMagick (not installed); adding an SVG Flutter package to the runtime app (unnecessary complexity for a one-time build step).
- **Consequences:** If the SVG logo ever changes, re-run `cairosvg` to regenerate the PNG, then re-run `dart run flutter_launcher_icons` and `dart run flutter_native_splash:create`.
- **Revisit if:** Logo redesign is needed.
