<div align="center">
  <h1>Aura Music App</h1>
  <p>A premium, production-ready music streaming application built with Flutter.</p>
</div>

---

## Overview

Aura is a high-fidelity, cross-platform music streaming application engineered to deliver a seamless and personalized audio experience. Moving beyond standard media players, Aura integrates advanced state management, secure multi-tenant local data isolation, and a highly reactive UI driven by modern design paradigms like dynamic color extraction and hardware-accelerated glassmorphism.

## Core Features & Architecture

### 1. Robust State Management & Multi-Tenant Data Isolation
- **Dependency Injection via ProxyProvider:** Implements dynamic dependency injection where local SQLite instances (`DbHelper`) are strictly bound to the authenticated Firebase `User ID`.
- **Zero-Bleed Authentication:** Ensuring true multi-tenancy on a single device, logging out and logging in as a different user instantly swaps the underlying database layer, preventing any cross-contamination of user data, search history, or custom playlists.

### 2. Advanced Audio Engine & Global Playback
- **Persistent Global Player:** Utilizes a decoupled `AudioProvider` built on top of `just_audio` that broadcasts playback state (duration, position, buffer, playing status) across the entire application navigation stack.
- **Queue & Queue Management:** Supports dynamic queue generation (e.g., shuffling trending hits or playing a custom playlist) with seamless track-to-track transitions.

### 3. Highly Reactive, Premium UI/UX
- **Dynamic Palette Generation:** Album art is asynchronously processed using `palette_generator` to extract the dominant colors of the currently playing track, dynamically shifting the application's ambient gradient backgrounds in real-time.
- **Native Glassmorphism:** Leverages Flutter's `BackdropFilter` and `ImageFilter.blur` to create expensive, premium frosted-glass overlays (specifically engineered to prevent hit-testing bugs during stack transitions).
- **Custom UI Tooling:** Replaced standard system menus with custom-built Bottom Sheets and sleek `PopupMenuButton` implementations for playlist management.

### 4. Intelligent Search & Discovery
- **Debounced Live Search:** The search engine features an asynchronous 500ms debounce timer that intercepts user keystrokes to prevent API rate-limiting while providing instantaneous, live search suggestions.
- **Local History Caching:** Recent search queries are cached in the isolated SQLite database and instantly surface when the user focuses the search bar.

### 5. Comprehensive Library & Playlist CRUD
- **Full CRUD Operations:** Users can create new playlists, rename existing ones, and delete them.
- **Reorderable Tracks:** Playlists support manual reordering via drag-and-drop handles (`ReorderableListView`), allowing users to curate their exact listening experience.
- **Offline Download Manager:** Integrated a dedicated `DownloadService` capable of fetching MP3 binaries from URLs and writing them directly to device storage for offline playback.

### 6. Cloud Profile Synchronization
- **Firebase Auth & Storage:** Users can authenticate via secure Email/Password pipelines.
- **Gallery Integration:** Using `image_picker`, users can select custom profile avatars from their local device. These binaries are compressed, uploaded to Firebase Cloud Storage, and seamlessly synced with their Firebase `photoURL` for global retrieval across the app.

## Technology Stack

| Domain | Technology / Package | Purpose |
| :--- | :--- | :--- |
| **Framework** | Flutter (Dart) | Cross-platform UI toolkit |
| **State Management** | `provider` | Reactive state propagation |
| **Audio Processing** | `just_audio` | Core audio playback engine |
| **Local Persistence** | `sqflite` | Relational local databases |
| **Authentication** | `firebase_auth` | User identity management |
| **Cloud Storage** | `firebase_storage` | Remote binary storage (Avatars) |
| **Image Processing** | `palette_generator` | Dominant color extraction |
| **Media Handling** | `image_picker` | Local device gallery access |
| **Network** | `http` | RESTful API integrations |

## Installation & Environment Setup

1. **Clone the Repository**
   ```bash
   git clone https://github.com/yourusername/aura-music-app.git
   cd aura-music-app
   ```

2. **Acquire Dependencies**
   ```bash
   flutter pub get
   ```

3. **Configure Firebase Infrastructure**
   - Provision a new project in the [Firebase Console](https://console.firebase.google.com/).
   - Enable **Authentication** (Email/Password provider).
   - Provision a **Cloud Storage** bucket and configure security rules to allow read/write access for authenticated users.
   - Download the generated `google-services.json` and inject it into the `android/app/` directory.

4. **Compile and Execute**
   ```bash
   # Clean previous build artifacts (recommended after adding native plugins)
   flutter clean
   flutter pub get
   
   # Run on connected device or emulator
   flutter run
   ```

## License
Distributed under the MIT License. See `LICENSE` for more information.
