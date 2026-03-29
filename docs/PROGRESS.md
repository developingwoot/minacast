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
  - Current suite is green: `flutter test` passes with 48 tests and `flutter analyze` passes with no issues

---

## In Progress

_(nothing yet)_

---

## Not Started

Items are ordered so each session builds on the last and ends with something verifiable on a real device or emulator. Journey 2 (Streaming) is now implemented in code, so the next unfinished work starts with Journey 3 (Queue).

---

### Phase 5 — Background Sync & Notifications

- [ ] **5.1 — WorkManager daily task: RSS sync + new-episode notification**
  - Sessions: 1
  - What gets built: WorkManager task registered on app launch (periodic, ~24 h). Task fetches RSS for all subscribed podcasts, compares guids against the `episodes` table, inserts new rows, updates `last_checked_at`. If any new episodes are found, fires a local notification via `flutter_local_notifications` ("New episodes available").
  - Blocks: silent download step.
  - Verify: Trigger the WorkManager task manually (use `workmanager` one-shot for testing) after subscribing to a podcast that has published new content → notification appears in the notification shade.

- [ ] **5.2 — Silent background download of oldest unlistened episode**
  - Sessions: 1
  - What gets built: Within the same WorkManager task: check free storage (`> 500 MB`); for each subscription, find the oldest episode where `is_completed = 0` and `local_file_path IS NULL`; download the audio file to the app's files directory; write the local path back to `episodes.local_file_path`. Playback layer already checks `local_file_path` first (from 3.2).
  - Blocks: nothing further.
  - Verify: Trigger the task manually with a subscribed podcast that has unlistened episodes and ≥ 500 MB free → inspect the `episodes` table to confirm `local_file_path` is populated → tap that episode → confirm it plays without a network connection (airplane mode test).

---

### Phase 6 — Settings Screen

- [ ] **6.1 — Settings screen: dark mode, playback speed, sleep timer default**
  - Sessions: 1
  - What gets built: Settings screen with a dark mode toggle (reads/writes `dark_mode` from the `settings` table and rebuilds the `MaterialApp` theme), a default playback speed selector, and a sleep timer default duration selector. Riverpod providers for each setting consumed app-wide.
  - Blocks: nothing — polish only.
  - Verify: Toggle dark mode → entire app switches theme instantly. Change default playback speed → open Full Player on a new episode → speed selector pre-selects the saved value. Change sleep timer default → open Full Player → timer button shows the saved duration.

---

### Phase 7 — Polish & Release Prep

- [ ] **7.1 — App icon, splash screen, app name**
  - Sessions: 1
  - What gets built: Launcher icon and splash screen assets added via `flutter_launcher_icons` and `flutter_native_splash`. App name set to "Minacast" in `AndroidManifest.xml`. Source logo SVG is already at `assets/images/minacast.svg` — export it to PNG as input for `flutter_launcher_icons`.
  - Blocks: Play Store listing.
  - Verify: Install the APK → launcher shows the correct icon and name → splash screen displays on cold launch.

- [ ] **7.2 — Android permissions, manifest hardening, release build**
  - Sessions: 1
  - What gets built: `AndroidManifest.xml` declares `INTERNET`, `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_MEDIA_PLAYBACK`, `POST_NOTIFICATIONS`, `RECEIVE_BOOT_COMPLETED`, and `REQUEST_INSTALL_PACKAGES` (if needed). `minSdkVersion` set to 21 (Android 5). Release keystore generated, `build.gradle` configured for signed APK/AAB. `flutter build appbundle --release` succeeds.
  - Blocks: Play Store submission.
  - Verify: Signed AAB builds without errors. Install on a physical device and run through all three user journeys.

- [ ] **7.3 — Play Store listing and submission**
  - Sessions: 1
  - What gets built: Play Store developer account (one-time $25 fee), app listing with description, screenshots, content rating questionnaire completed, privacy policy (simple hosted page noting all data is local-only). AAB uploaded and submitted for review.
  - Blocks: nothing.
  - Verify: App appears in the Play Console internal test track and can be installed by a test account.

---

## Blocked / Open Questions

- `./gradlew :app:assembleDebug` now fails later at `:app:configureCMakeDebug[armeabi-v7a]` in the local Android NDK/CMake toolchain after the desugaring fix. Next session should determine whether to constrain supported ABIs or fix the local native toolchain configuration.
- Phase 3 / 4 still need manual Android verification for real audio playback, lock screen controls, notification shade controls, background resume behavior, queue reordering, and autoplay on an emulator or physical device.
- The Minacast SVG logo exists at `assets/images/minacast.svg`, but in-app usage still needs either a PNG export or approval to add an SVG rendering package before we can place it in Flutter UI.
