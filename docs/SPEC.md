# Minacast — Product Specification

## What This App Is

Minacast is a free, no-ads Android podcast app built with Flutter. Users search for podcasts, subscribe to them, stream episodes on demand, and listen offline — all with zero recurring infrastructure cost. Every piece of data lives on the device; there is no backend, no server, and no cloud sync.

---

## Who the Users Are and How They Authenticate

- **Single user per device.** There are no accounts, no sign-up, and no login flow of any kind.
- All data is stored locally in a SQLite database on the device.
- There is no authentication layer.

---

## Features

### Podcast Discovery & Subscription

- A **search bar** on the Home screen allows the user to search for podcasts by name.
- Search queries hit the **iTunes Search API**; results are displayed as podcast cards (artwork, title, author).
- Tapping a result opens the **Podcast Detail** screen, which fetches and parses the podcast's RSS feed.
- A **Subscribe / Unsubscribe** button toggles the subscription state persisted in SQLite.
- Subscribed podcasts feed episodes into the **Home / Feed** screen.

### Home Feed

- Displays the latest episodes from all subscribed podcasts sorted by **publication date descending** (newest first).
- Empty state prompts the user to search for a podcast.

### Episode Playback

- Tapping an episode begins **streaming** via `just_audio`; playback continues in the background via `audio_service`.
- **Lock screen controls** and **notification shade controls** work correctly.
- A **Mini Player** bar is pinned to the bottom of every screen when audio is active.
- Tapping the Mini Player opens the **Full Player** screen.
- The app saves the **playback position** of every episode so listening can resume after the app is closed or the episode is paused.
- Episodes with a saved local file (`local_file_path` not null) play from the local file; otherwise they stream.

### Full Player Controls

- Seek bar with elapsed / remaining time display
- Skip ±30 seconds buttons
- Playback speed selector: 0.5×, 1×, 1.5×, 2× (default stored in settings)
- Sleep timer button (uses the default duration from settings)
- Link to episode show notes

### Up Next Queue

- Users can **Add to Queue** from the Episode Detail screen.
- The Queue screen shows an ordered list of upcoming episodes.
- Episodes can be **reordered by dragging** and **removed by swiping**.
- **Autoplay** advances through the queue automatically.
- When a single podcast's episodes are added to the queue, they are ordered **oldest-to-newest** so the user works through a backlog in order.

### Silent Background Downloads

- **WorkManager** runs a daily background task with no UI.
- The task fetches RSS feeds for all subscribed podcasts and checks for new episodes.
- If new episodes exist, a **local notification** is fired via `flutter_local_notifications`.
- If the device has **≥ 500 MB free storage**, the task silently downloads the **oldest unlistened episode** from each subscription and stores the file path in the `episodes.local_file_path` column.
- Downloaded episodes play from the local file automatically; the user never sees or manages download state.

### Settings

- **Dark mode** toggle (persisted in the `settings` key-value table)
- **Default playback speed** selector
- **Sleep timer default duration** selector

---

## Main User Journeys

### Journey 1 — Discover and Subscribe

1. User opens the app for the first time → sees the Home / Feed empty state.
2. User taps the search bar → types a podcast name.
3. App queries the iTunes Search API → Search Results screen shows podcast cards.
4. User taps a card → Podcast Detail screen loads (artwork, description, episode list from RSS).
5. User taps **Subscribe** → podcast and its episodes are written to SQLite.
6. User navigates back → Home / Feed now shows episodes from the subscribed podcast.

### Journey 2 — Stream an Episode

1. User taps an episode on the Home / Feed (or Podcast Detail) screen → Episode Detail screen opens.
2. User taps **Play** → audio begins streaming; Mini Player appears at the bottom.
3. User locks the screen → audio continues; lock screen controls are active.
4. User pulls down the notification shade → playback controls are shown.
5. User returns to the app → taps the Mini Player → Full Player opens with seek bar and speed controls.
6. User closes the app mid-episode → position is saved; next open resumes from the same position.

### Journey 3 — Build and Work Through a Queue

1. User opens Podcast Detail for a podcast with a backlog.
2. User taps **Add to Queue** on multiple episodes → they are appended in oldest-to-newest order.
3. User taps the Queue icon → Queue screen shows the ordered list.
4. User drags an episode to reorder it.
5. User swipes an episode to remove it.
6. Audio finishes the current episode → autoplay begins the next episode in the queue.

---

## Data Models

### `podcasts`

| Column | Type | Notes |
|---|---|---|
| `rss_url` | TEXT | Primary key |
| `title` | TEXT | |
| `author` | TEXT | |
| `description` | TEXT | |
| `artwork_url` | TEXT | |
| `last_checked_at` | INTEGER | Unix timestamp (milliseconds) |

### `episodes`

| Column | Type | Notes |
|---|---|---|
| `guid` | TEXT | Primary key |
| `podcast_rss_url` | TEXT | Foreign key → `podcasts.rss_url` |
| `title` | TEXT | |
| `audio_url` | TEXT | |
| `description_html` | TEXT | Raw HTML from RSS `<description>` or `<content:encoded>` |
| `duration_seconds` | INTEGER | Nullable |
| `pub_date` | INTEGER | Unix timestamp (milliseconds) |
| `listened_position_seconds` | INTEGER | Default 0 |
| `is_completed` | INTEGER | 0 or 1 (SQLite boolean) |
| `local_file_path` | TEXT | Nullable — null means not downloaded |

### `queue`

| Column | Type | Notes |
|---|---|---|
| `id` | INTEGER | Primary key (autoincrement) |
| `episode_guid` | TEXT | Foreign key → `episodes.guid` |
| `sort_order` | INTEGER | Lower value = plays sooner |

### `settings`

| Column | Type | Notes |
|---|---|---|
| `key` | TEXT | Primary key |
| `value` | TEXT | |

**Default settings keys:** `dark_mode` (`"true"`/`"false"`), `playback_speed` (`"1.0"`), `sleep_timer_default_minutes` (`"30"`)

---

## External API Integrations

There is no internal REST API (no backend). The app integrates with two external services:

| Method | URL Pattern | Purpose |
|---|---|---|
| GET | `https://itunes.apple.com/search?term={query}&media=podcast&limit=20` | Podcast search — returns JSON array of podcast metadata including artwork URL and RSS feed URL |
| GET | `{rss_url}` | Fetch and parse podcast RSS feed — used on Podcast Detail load and during the daily WorkManager sync task |

---

## What This Is NOT (v1 Out of Scope)

- **No iOS support** — Android only. No iOS build targets, no platform-specific iOS code.
- **No backend or server** — no REST API, no cloud database, no authentication service, no infrastructure costs.
- **No cloud sync** — data lives only on the device; uninstalling the app destroys all data.
- **No download management UI** — no progress bars, cancel buttons, or per-episode download state badges. Downloads are completely silent and automatic.
- **No YouTube integration** — the app does not ingest, play, or link to YouTube content.
- **No push notifications** — no FCM, no APNs, no external notification service. Local notifications only.
- **No video podcast support** — audio only.
- **No bookmarks or chapter support.**
- **No custom playlists** beyond the single Up Next queue.
- **No social features** of any kind (sharing, follows, comments, ratings).
- **No personalized recommendations** — no collaborative filtering, no embedding-based suggestions, no ML of any kind.
- **No podcast creation or hosting tools.**

---

## Tech Stack Decisions

| Technology | Package | Reason |
|---|---|---|
| **Flutter (Dart)** | — | Cross-platform UI toolkit; single codebase targets Android with native performance and rich widget library |
| **Local persistence** | `sqflite` | Lightweight SQLite wrapper; zero server cost; sufficient for relational episode/queue data |
| **State management** | `riverpod` | Compile-safe, testable, async-first; avoids the boilerplate of BLoC and the global-state risks of Provider |
| **Audio playback** | `just_audio` | Supports streaming and local file playback, gapless audio, and speed control with a single API |
| **Background audio** | `audio_service` | Integrates `just_audio` with the Android MediaSession API for lock screen and notification shade controls |
| **Background sync** | `workmanager` | Schedules the daily RSS fetch/download task using Android WorkManager; survives app restarts |
| **Local notifications** | `flutter_local_notifications` | Fires new-episode notifications from the WorkManager task; no FCM dependency |
| **RSS parsing** | `dart_rss` | Pure-Dart RSS/Atom parser; handles `<enclosure>`, `<itunes:*>`, and `<content:encoded>` tags |
| **Networking** | `http` | Lightweight HTTP client sufficient for RSS fetches and iTunes API calls |
| **Image caching** | `cached_network_image` | Disk-caches podcast artwork to avoid re-fetching on every render |
| **HTML rendering** | `flutter_html` | Renders episode `<description>` HTML in the Episode Detail / Full Player show notes view |
