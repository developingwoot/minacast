# Minacast — Build Progress

## Implemented

_(nothing yet)_

---

## In Progress

_(nothing yet)_

---

## Not Started

Items are ordered so each session builds on the last and ends with something verifiable on a real device or emulator. Journey 1 (Discover → Subscribe) is completed end-to-end before Journey 2 (Streaming) begins, and Journey 2 before Journey 3 (Queue).

---

### Phase 1 — Project Scaffold & Data Layer

- [ ] **1.1 — Flutter project init + all dependencies declared**
  - Sessions: 1
  - What gets built: `flutter create` for Android-only target; add all packages to `pubspec.yaml` (`sqflite`, `riverpod`, `just_audio`, `audio_service`, `workmanager`, `flutter_local_notifications`, `dart_rss`, `http`, `cached_network_image`, `flutter_html`); confirm the app compiles and launches to a blank screen.
  - Blocks: everything.
  - Verify: App launches on emulator/device without errors.

- [ ] **1.2 — SQLite schema + database helper**
  - Sessions: 1
  - What gets built: `DatabaseHelper` singleton that opens the database, runs `CREATE TABLE` migrations for `podcasts`, `episodes`, `queue`, and `settings`, and seeds default settings rows. DAOs (or plain query methods) for basic CRUD on each table.
  - Blocks: all data-reading UI and all Riverpod providers.
  - Verify: Add a debug button or use Flutter DevTools to confirm tables exist and default settings rows are present after first launch.

---

### Phase 2 — Journey 1: Discover and Subscribe

- [ ] **2.1 — iTunes Search API integration + Search Results screen**
  - Sessions: 1
  - What gets built: `PodcastSearchService` that calls the iTunes Search API and deserializes results into a `Podcast` model. Search Results screen showing podcast cards (artwork via `cached_network_image`, title, author). Search bar wired up with debounce.
  - Blocks: Podcast Detail screen.
  - Verify: Type a podcast name → cards appear with artwork, title, and author.

- [ ] **2.2 — RSS fetch + parse + Podcast Detail screen**
  - Sessions: 1
  - What gets built: `RssFeedService` that fetches a feed URL and parses it with `dart_rss` into a list of `Episode` models. Podcast Detail screen showing artwork, title, author, description, and scrollable episode list. Subscribe / Unsubscribe button that writes/removes the podcast and its episodes to SQLite.
  - Blocks: Home Feed screen, background sync.
  - Verify: Tap a search result → detail screen loads with episode list → tap Subscribe → row appears in `podcasts` table (confirm via debug log or DevTools).

- [ ] **2.3 — Home / Feed screen + navigation shell**
  - Sessions: 1
  - What gets built: Bottom navigation or app shell with Home and Settings tabs. Home Feed screen that reads all episodes from subscribed podcasts, sorts newest-first, and renders an episode list. Empty state shown when no subscriptions exist. Riverpod provider powering the feed.
  - Blocks: Episode Detail screen, Mini Player placement.
  - Verify: Subscribe to a podcast → navigate to Home → episode list populates sorted newest-first. Unsubscribe → list empties.

---

### Phase 3 — Journey 2: Stream an Episode

- [ ] **3.1 — Episode Detail screen**
  - Sessions: 1
  - What gets built: Episode Detail screen (artwork, title, pub date, show notes rendered with `flutter_html`). Play button that is wired up but can just log for now. Add to Queue button placeholder.
  - Blocks: nothing on its own — unlocks the Play integration in the next session.
  - Verify: Tap an episode from the feed → detail screen opens with rendered HTML show notes.

- [ ] **3.2 — Audio playback: streaming + `audio_service` + `just_audio` integration**
  - Sessions: 2
  - What gets built: `AudioHandler` subclassing `BaseAudioHandler` from `audio_service`, backed by `just_audio`. Handles `play`, `pause`, `seek`, `stop`, `skipForward` (+30s), `skipBackward` (−30s). Android MediaSession registration so lock screen and notification shade controls work. Play button on Episode Detail triggers streaming playback.
  - Blocks: Mini Player, Full Player, position saving, speed control, sleep timer.
  - Verify: Tap Play → audio streams. Lock the screen → controls appear on lock screen. Pull down notification shade → playback controls visible. Pause and resume work.

- [ ] **3.3 — Mini Player**
  - Sessions: 1
  - What gets built: Persistent `MiniPlayer` widget pinned above the bottom nav bar, visible on all screens when audio is active. Shows episode artwork, title, play/pause button, and skip-forward button. Tapping the body of the Mini Player navigates to the Full Player.
  - Blocks: Full Player.
  - Verify: Start playback → Mini Player appears. Navigate between screens → Mini Player persists. Pause/resume from Mini Player works.

- [ ] **3.4 — Full Player screen**
  - Sessions: 1
  - What gets built: Full Player screen (expanded from Mini Player tap). Seek bar with elapsed / remaining time. Skip ±30s buttons. Playback speed selector (0.5×, 1×, 1.5×, 2×) wired to `just_audio`. Sleep timer button (countdown that calls `stop` when elapsed). Link that opens Episode Detail show notes.
  - Blocks: nothing further.
  - Verify: Open Full Player → seek bar moves in real time → dragging the thumb seeks correctly. Speed selector changes playback rate audibly. Sleep timer fires after the set duration.

- [ ] **3.5 — Playback position persistence**
  - Sessions: 1
  - What gets built: Riverpod listener (or `AudioHandler` callback) that writes `listened_position_seconds` to SQLite every ~5 seconds during playback and on pause/stop. On episode load, checks the DB for a saved position and resumes from it. Marks `is_completed = 1` when the episode finishes.
  - Blocks: background download logic (which targets unlistened episodes).
  - Verify: Play an episode to a mid-point → close the app fully → reopen → tap the episode → playback resumes from the saved position, not from zero.

---

### Phase 4 — Journey 3: Queue

- [ ] **4.1 — Queue data layer + Add to Queue**
  - Sessions: 1
  - What gets built: DAO methods for inserting, reordering, and removing rows from the `queue` table. `Add to Queue` button on Episode Detail is wired up; inserts the episode at the end of the queue with correct `sort_order`. When adding multiple episodes from a single podcast, they are sorted oldest-to-newest before insertion.
  - Blocks: Queue screen, autoplay.
  - Verify: Tap `Add to Queue` on several episodes → query the `queue` table and confirm rows appear in correct order.

- [ ] **4.2 — Queue screen (list, drag-to-reorder, swipe-to-remove)**
  - Sessions: 1
  - What gets built: Queue screen accessible from a Queue icon in the app bar or nav. Renders queued episodes using `ReorderableListView`. Drag handle allows reordering (updates `sort_order` in DB). Swipe-to-dismiss removes the row. Riverpod provider watches the queue table.
  - Blocks: autoplay.
  - Verify: Add episodes to queue → open Queue screen → drag to reorder → swipe to remove → DB reflects changes in real time.

- [ ] **4.3 — Autoplay through the queue**
  - Sessions: 1
  - What gets built: `AudioHandler` listens for `processingState == completed` and automatically loads and plays the next episode from the queue, then removes the finished episode from the `queue` table. If the queue is empty, playback stops.
  - Blocks: nothing further.
  - Verify: Queue two episodes → play the first → let it finish → second episode begins automatically without user interaction. Queue screen shows the first episode removed.

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
  - What gets built: Launcher icon and splash screen assets added via `flutter_launcher_icons` and `flutter_native_splash`. App name set to "Minacast" in `AndroidManifest.xml`.
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

_(nothing yet — add items here during development when a decision, external dependency, or missing information is blocking progress)_
