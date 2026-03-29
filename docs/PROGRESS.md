# Minacast — Build Progress

## Implemented

- [x] **1.1 — Flutter project init + all dependencies declared**
- [x] **1.2 — SQLite schema + database helper**
  - `DatabaseHelper` singleton with all four tables (`podcasts`, `episodes`, `queue`, `settings`), `PRAGMA foreign_keys = ON`, default settings seed, and 20 query methods
  - Typed model classes: `Podcast`, `Episode`, `QueueEntry`
  - 23 database unit tests passing against in-memory SQLite (`sqflite_common_ffi`)
  - App logo SVG added at `assets/images/minacast.svg`
- [x] **Android build config: core library desugaring enabled**
  - Added `isCoreLibraryDesugaringEnabled = true` and `desugar_jdk_libs` to `android/app/build.gradle.kts` to satisfy `flutter_local_notifications`
  - Verified the original `:app:checkDebugAarMetadata` failure is resolved
  - Ran `flutter test` successfully at the time: 35 tests passed
- [x] **2.1 — iTunes Search API integration + Search Results screen**
  - `PodcastSearchService` calls the iTunes Search API with typed parsing and safe fallback-to-empty behavior on network and JSON errors
  - `SearchScreen` is wired from Home, uses a debounced Riverpod `searchProvider`, and renders podcast cards with artwork, title, and author
  - Search service and provider coverage added in `test/features/search/services/podcast_search_service_test.dart` and `test/features/providers/providers_test.dart`
- [x] **2.2 — RSS fetch + parse + Podcast Detail screen**
  - `RssFeedService` fetches RSS, parses feed description plus valid episodes, and skips malformed items safely
  - `PodcastDetailScreen` loads artwork, metadata, description, and episode list from the feed
  - Subscribe / Unsubscribe is wired through `podcastDetailProvider` and persists podcast plus episode rows to SQLite
  - RSS service and provider coverage added in `test/features/podcast_detail/services/rss_feed_service_test.dart` and `test/features/providers/providers_test.dart`
- [x] **2.3 — Home / Feed screen + navigation shell**
  - `AppShell` provides Home and Settings tabs via bottom navigation
  - `HomeScreen` reads from `feedProvider`, shows an empty state with search CTA, and renders subscribed episodes newest-first
  - Feed provider coverage added in `test/features/providers/providers_test.dart`
- [x] **3.1 — Episode Detail screen**
  - Added `EpisodeDetailScreen` under `features/episode_detail` with title, pub date, duration, and show notes rendered through `flutter_html`
  - Episode rows from Home and Podcast Detail now navigate into Episode Detail
  - `Play` and `Add to Queue` buttons are present as explicit placeholders, keeping playback and queue work scoped to later sessions
  - Added widget coverage for detail rendering and Home → Episode Detail navigation
- [x] **3.2 — Audio playback: streaming + `audio_service` + `just_audio` integration**
  - Added a single app-wide `PodcastAudioHandler` backed by `just_audio`, initialized through `AudioService.init()` before `runApp()`
  - Episode Detail `Play` now starts playback from `local_file_path` when present, otherwise from `audio_url`
  - Android media service and foreground playback manifest entries were added so notification and lock screen controls can register correctly on device
- [x] **3.3 — Mini Player**
  - Added a persistent `MiniPlayer` above the bottom nav that appears whenever a current episode exists, including paused playback
  - Mini Player shows artwork, title, play/pause, and skip-forward controls and persists while navigating between app screens
- [x] **3.4 — Full Player screen**
  - Added a dedicated Full Player route with seek bar, elapsed / remaining time, skip ±30s, playback rate controls, sleep timer trigger, and a link back to show notes
  - Playback speed is applied live and persisted immediately to the `settings` table for future episodes
- [x] **3.5 — Playback position persistence**
  - Added a playback persistence coordinator that writes listened position to SQLite roughly every 5 seconds during playback and flushes on pause/background
  - Episode playback resumes from saved position for unfinished episodes and marks episodes complete while clearing saved progress at end of playback
- [x] **4.1 — Queue data layer + Add to Queue**
  - Added queue-specific service/provider plumbing on top of SQLite so Episode Detail can append episodes at the end of the queue with stable `sort_order`
  - Duplicate queue inserts are skipped, and multi-episode queue additions sort oldest-to-newest before insertion
  - Added queue service and provider coverage in `test/features/queue/queue_service_test.dart` and `test/features/providers/providers_test.dart`
- [x] **4.2 — Queue screen (list, drag-to-reorder, swipe-to-remove)**
  - Added a dedicated Queue screen accessible from the Home app bar
  - Queue rows render joined episode + podcast metadata, support drag-to-reorder with persisted `sort_order`, and swipe-to-remove with order normalization
- [x] **4.3 — Autoplay through the queue**
  - Added a queue autoplay service that marks finished episodes complete, removes them from `queue`, and starts the next queued episode automatically when available
  - Added autoplay coverage in `test/features/playback/queue_autoplay_service_test.dart`
- [x] **Foundational data helpers completed ahead of later UI phases**
  - Queue CRUD exists in `DatabaseHelper` (`enqueue`, `getQueue`, `updateQueueOrder`, `removeFromQueue`, `clearQueue`)
  - Settings persistence exists in `DatabaseHelper` via `getSetting` / `setSetting`
  - Episode progress helpers exist in `DatabaseHelper` for listened position, completion state, and local file path updates
- [x] **Pre-Phase-5 architectural cleanup**
  - Added `DatabaseHelper.insertPodcastWithEpisodes` — wraps podcast + episodes inserts in a single transaction; subscribe flow and Phase 5 background sync should use this
  - Added `RefreshIndicator` to Home feed so users (and Phase 5 background inserts) can pull to refresh
  - Fixed `PlaybackStateNotifier` subscription list accumulation on rebuild (was minor memory leak)
  - Added explanatory comment to `podcastDetailProvider` noting Riverpod does not export the family provider type for explicit annotation
  - Removed stale "no tests exist" note from AGENTS.md Testing Configuration section
  - Current suite is green: `flutter test` passes with 51 tests and `flutter analyze` passes with no issues
- [x] **5.1 — WorkManager daily task: RSS sync + new-episode notification**
  - Added `BackgroundSyncService` plus WorkManager callback registration and periodic daily scheduling on app launch
  - Background task fetches RSS for all subscribed podcasts, inserts only genuinely new episodes, updates `last_checked_at`, and fires a local notification when new episodes are found
  - Added `POST_NOTIFICATIONS` and `RECEIVE_BOOT_COMPLETED` manifest permissions and pre-created the Android notification channel at startup
  - Added automated coverage in `test/background/background_sync_task_test.dart`
- [x] **5.2 — Silent background download of oldest unlistened episode**
  - Added WAL mode in SQLite configuration before background-isolate DB access
  - Added `getOldestUnlistenedEpisodeWithoutLocalFile` to the data layer and background download logic that stores audio under the app support directory, then writes `episodes.local_file_path`
  - Download flow handles HTTP and filesystem failures safely so playback falls back to streaming when needed
  - Added database and background sync coverage for selection and download behavior
- [x] **Phase 5 verification + compatibility fixes**
  - Updated WorkManager periodic registration to use the current plugin API
  - Updated `flutter_local_notifications` calls to the current named-parameter API used by the installed package version
  - Re-ran the full quality gates successfully: `flutter test` passes with 65 tests and `flutter analyze` passes with no issues
- [x] **6.1 — Settings screen: dark mode, playback speed, sleep timer default**
  - Added a typed app-settings model plus Riverpod-backed settings controller that loads and persists `dark_mode`, `playback_speed`, and `sleep_timer_default_minutes` from SQLite
  - Replaced the Settings placeholder with real controls for dark mode, default playback speed, and default sleep timer duration, including loading/error handling
  - Wired `MaterialApp` theme switching through the persisted dark mode setting and updated the Full Player sleep timer button to show the saved default duration
  - Fixed the SQLite open-time PRAGMA call so `journal_mode=WAL` uses `rawQuery`, resolving the Android settings crash seen while opening the database
  - Normalized legacy unsupported settings values (for example `sleep_timer_default_minutes = 0`) back to supported dropdown options so the Settings screen no longer asserts on older persisted data
  - Added provider and widget coverage for settings persistence, theme wiring, and Settings screen interactions
  - Re-ran the full quality gates successfully: `flutter test` passes with 71 tests and `flutter analyze` passes with no issues
- [x] **7.1 — App icon, splash screen, app name**
  - Discovered `assets/images/minacast.png` was a 1×1 placeholder; converted `minacast.svg` to a proper 1024×1024 RGBA PNG using `cairosvg`
  - Re-ran `flutter_launcher_icons` to regenerate all mipmap icons with the real Minacast logo
  - Ran `flutter_native_splash:create` — splash screen now shows `#1A1A1A` dark background with the Minacast logo centered
  - App name "Minacast" was already correct in `AndroidManifest.xml`
- [x] **7.2 — Android permissions, manifest hardening, release build**
  - Removed `REQUEST_INSTALL_PACKAGES` permission (not required by any app feature)
  - Fixed broken `proguardFiles` call in `build.gradle.kts` (function call was embedded inside a string literal)
  - Removed hardcoded fallback keystore credentials (`"minacast123"`) from source — signing config now only activates when `key.properties` is present
  - Changed `applicationId` and `namespace` from `com.example.minacast` to `com.developingwoot.minacast`
  - Fixed `key.properties` keystore path (`app/release-key.jks` → `release-key.jks`)
  - `flutter build appbundle --release` succeeds — signed AAB at `build/app/outputs/bundle/release/app-release.aab` (52.2 MB)
  - All 74 tests pass

---

## In Progress

_(nothing yet)_

---

## Not Started

Items are ordered so each session builds on the last and ends with something verifiable on a real device or emulator. Journey 2 (Streaming) is now implemented in code, so the next unfinished work starts with Journey 3 (Queue).

---

### Phase 7 — Polish & Release Prep

- [ ] **7.3 — Play Store listing and submission**
  - Sessions: 1
  - What gets built: Play Store developer account (one-time $25 fee), app listing with description, screenshots, content rating questionnaire completed, privacy policy (simple hosted page noting all data is local-only). AAB uploaded and submitted for review.
  - Blocks: nothing.
  - Verify: App appears in the Play Console internal test track and can be installed by a test account.

---

## Blocked / Open Questions

- `./gradlew :app:assembleDebug` still fails at `:app:configureCMakeDebug[armeabi-v7a]` in the local Android NDK/CMake toolchain. `flutter build appbundle --release` succeeds via the Flutter toolchain, so this only affects direct Gradle invocations.
- Phase 3 / 4 still need manual Android verification for real audio playback, lock screen controls, notification shade controls, background resume behavior, queue reordering, and autoplay on an emulator or physical device.
- Phase 5 code is implemented and automated tests are green, but manual Android verification is still pending: trigger the WorkManager task on a device or emulator, confirm the notification appears, and confirm an auto-downloaded episode plays offline.
