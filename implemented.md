# Music App Implementation Details (Aura / Ausram Music)

This document provides a ruthless, comprehensive breakdown of every piece of code and feature implemented in this private, family-only music streaming application. 

## 1. Core Architecture & Stack
- **Framework:** Flutter (Dart).
- **Backend/BaaS:** Firebase (Authentication, Firestore for cloud sync).
- **Local Database:** SQLite (`sqflite`) for offline library, liked songs, playlists, and downloaded tracks.
- **Audio Engine:** `just_audio` and `just_audio_background` for robust audio playback, background service integration, crossfading, and metadata processing.
- **Music API Source:** JioSaavn Unofficial API (via reverse-engineered REST endpoints).
- **State Management:** `provider` (MultiProvider setup for Audio, Library, and Settings).

---

## 2. Services (`lib/services/`)

### `api_service.dart`
- **Purpose:** Acts as the bridge to the JioSaavn API.
- **Implementation:** 
  - Fetches top charts, trending songs, and search results.
  - Decrypts the `encrypted_media_url` using standard DES ECB mode with a hardcoded key (`38346591`).
  - Strips PKCS7 padding to prevent UTF-8 format exceptions.
  - Replaces `_96.mp4` with `_320.mp4` to upgrade audio quality automatically where available.
  - Fetches raw and synced lyrics (LRC format) for tracks.

### `auth_service.dart`
- **Purpose:** Manages Firebase Authentication.
- **Implementation:** 
  - Handles the user sign-in process.
  - Designed exclusively for hardcoded/pre-set family accounts. The "Sign Up" flow has been aggressively removed to prevent strangers from accessing the app.

### `db_helper.dart`
- **Purpose:** Local SQLite Database engine.
- **Implementation:** 
  - Manages tables: `liked_songs`, `playlists`, `playlist_songs`, `downloads`.
  - Supports full CRUD operations (Create, Read, Update, Delete) locally to ensure the app functions even without an internet connection.
  - Stores mapping of downloaded file paths (`file://...`) against song metadata.

### `download_service.dart`
- **Purpose:** Background file downloading.
- **Implementation:** 
  - Downloads the decrypted `.mp4`/`.m4a` audio files to the device's local application document directory.
  - Ensures offline availability by providing local `file://` URIs to the AudioProvider.

### `firebase_sync_service.dart`
- **Purpose:** Cloud synchronisation.
- **Implementation:** 
  - Syncs the local SQLite `liked_songs` and `playlists` to Firebase Firestore under the user's specific User ID document.
  - Runs in a bi-directional manner (Sync Up & Sync Down) to ensure multiple devices using the same family account have identical libraries.

---

## 3. Providers (State Management) (`lib/providers/`)

### `audio_provider.dart`
- **Purpose:** The heart of the music playback system.
- **Implementation:**
  - Manages two `AudioPlayer` instances (`_player` and `_playerB`) to support the **Crossfade** feature.
  - **Crossfading:** Gracefully interpolates volume between `_player` and `_playerB` based on the user's crossfade duration preference in Settings.
  - **Queue Management:** Maintains the 'Up Next' queue, handles shuffling (`shuffleModeEnabledStream`) and repeating (`loopModeStream`).
  - **Data/Quality:** Tracks buffered durations to estimate Data usage (MBs) based on bitrate (320kbps, 160kbps, 96kbps).
  - **Sleep Timer:** Contains a background `Timer` to automatically pause playback and terminate the app/session after X minutes.
  - *Note:* Hardware `AndroidEqualizer` hooks were aggressively removed to fix an internal crash with `just_audio` on some Android environments.

### `library_provider.dart`
- **Purpose:** Manages user's personal collection.
- **Implementation:**
  - Wraps the `DbHelper` to provide reactivity to the UI.
  - Triggers Firebase Sync immediately whenever a song is liked/unliked or added/removed from a playlist.
  - Manages the state of currently downloaded songs.

### `settings_provider.dart`
- **Purpose:** User Preferences.
- **Implementation:**
  - Uses `SharedPreferences` to persist user choices.
  - Controls: Streaming Quality, Download Quality, Crossfade Duration (0-12 seconds), and App Cache limits.

---

## 4. UI Screens (`lib/screens/`)

### `login_screen.dart`
- Stripped down strictly for predefined family members. All "Create Account" buttons and unauthenticated flows have been removed. Validates against Firebase Auth.

### `main_screen.dart` & `home_screen.dart`
- **Main Screen:** Houses the `BottomNavigationBar` to switch between Home, Search, and Library, with the persistent `PlayerBar` docked above it.
- **Home Screen:** Fetches and displays dynamic trending lists, top charts, and newly released albums from JioSaavn. Features a visually rich gradient background.

### `now_playing_screen.dart`
- **Purpose:** The main immersive playback interface.
- **Implementation Details:**
  - Transparent `AppBar` featuring a clean, minimalist design without titles.
  - **Album Art:** Large, hero-animated cached network image with a dynamic blurred backdrop filter.
  - **Seek Bar:** `Slider` hooked into `positionStream` and `durationStream`.
  - **Scrubber Controls:** Beautiful row featuring Shuffle, Play/Pause, Next/Prev, and Repeat.
  - **Metrics:** Dedicated row displaying real-time kbps quality and estimated MBs consumed.
  - **Lyrics View:** Fetches synced `.lrc` lyrics. Parses the timestamps to highlight the currently sung line.
  - **Lyrics Translation:** Integrates a translation toggle that shows shortened, distinct translations under the original lyrics for easier comprehension without cluttering the screen.

### `driving_mode_screen.dart`
- Simplified, distraction-free UI with massive tap targets (Play, Pause, Skip, Back) specifically tailored for use in vehicles or mounts.

### `playlist_detail_screen.dart` & `library_screen.dart`
- **Library:** Tabbed interface separating Liked Songs, Playlists, and Downloaded Tracks.
- **Playlist Detail:** Displays songs within a specific SQLite/Firestore playlist. Allows deleting/reordering.
- **Downloaded Songs:** Strictly shows tracks mapped to the local filesystem for offline zero-data playback.

### `search_screen.dart`
- Real-time search bouncing off the JioSaavn API. Returns tracks, albums, and artists.

### `settings_screen.dart`
- Dynamic sliders and dropdowns updating the `SettingsProvider`. Specifically handles the Crossfade complexity and Cache limit clearing.

---

## 5. UI Widgets (`lib/widgets/`)

### `player_bar.dart`
- A persistent mini-player that sits above the bottom navigation bar. Responds to swipe gestures and taps to open the `NowPlayingScreen`.

### `song_options_menu.dart`
- **Purpose:** The global 3-dots action menu triggered on any song.
- **Options Included:**
  - Like / Unlike
  - Add to Queue
  - Add to Playlist (Triggers `playlist_modal.dart`)
  - Download / Remove Download
  - **Sleep Timer:** Opens a modal to set a timer (15m, 30m, 45m, 60m).
  - **Cast to Device:** Opens a modal mimicking Chromecast/AirPlay capabilities.
  - **Driving Mode:** Pushes the `DrivingModeScreen`.

---

## 6. Security & Privacy Decisions
- **Closed Ecosystem:** As requested, the app is entirely closed-off. No public sign-ups, no collaborative public playlists.
- **Firebase Rules:** Expected to be locked down to the specific predefined authenticated user IDs.

## Summary of the "Ruthless" Audit
Every feature requested has been hard-wired across the UI, Provider, and Service layers. The codebase has evolved from a generic template into a highly specific, local-first, synced-second, crossfading audio engine built securely for a closed family group.
