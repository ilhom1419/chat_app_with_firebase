# Firebase Chat Application (Detailed Technical Documentation)

A fully-featured, cross-platform real-time messaging application developed in Flutter utilizing Firebase services. This application is architected using **Clean Architecture** principles and leverages **BLoC (Business Logic Component)** for robust state management.

---

## 🛠 1. Tech Stack & Infrastructure

The application leverages modern Dart, Flutter, and Firebase technologies:

*   **UI Framework**: [Flutter SDK](https://flutter.dev) (Dart language) with adaptive UI design supporting both Android & iOS.
*   **Database & Backend Services**:
    *   **Cloud Firestore**: NoSQL cloud database storing real-time user profiles, chats, messages, and presence statuses.
    *   **Firebase Authentication**: Provides secure email/password sign-in and registration flow.
    *   **Firebase Storage / Base64 Data**: Utilized for media uploads and photo storage.
*   **State Management**: [flutter_bloc](https://pub.dev/packages/flutter_bloc) (BLoC pattern) to separate presentation from business logic.
*   **Local Caching & Storage**: [Hive](https://pub.dev/packages/hive) for fast, lightweight key-value storage (used for localization, wallpapers, app lock settings, passcodes).
*   **Maps & Location**: [flutter_map](https://pub.dev/packages/flutter_map) + [OpenStreetMap (OSM / Nominatim API)](https://nominatim.org/) for interactive location picking and address geocoding.
*   **Voice Recording & Playback**: [record](https://pub.dev/packages/record) for high-performance audio recording and [audioplayers](https://pub.dev/packages/audioplayers) for voice messages playback.
*   **Security & Encryption**: [local_auth](https://pub.dev/packages/local_auth) for fingerprint / biometric app protection alongside local PIN/Passcode.
*   **Image Compression**: [flutter_image_compress](https://pub.dev/packages/flutter_image_compress) to compress and scale user photos/images before sending to minimize network overhead.
*   **Unique Identifiers**: [uuid](https://pub.dev/packages/uuid) for unique message and transaction IDs.

---

## 🏗 2. Architecture & Directory Structure

The project implements **Clean Architecture** with a directory structure organized by **Features** (`auth`, `chats`, `messages`). Each feature is divided into three layers:

```
lib/
├── core/                         # Shared services and core configurations
│   ├── cache/                    # Local storage (Hive service)
│   ├── design_system/            # Design tokens: AppColors, Spacing, TextStyles, Shadows
│   ├── localization/             # LocalizationService (EN, RU, UZ)
│   ├── notifications/            # Local Notification management
│   └── platform/                 # Platform checks
├── features/                     # App Features
│   ├── auth/                     # Authentication Module
│   │   ├── data/                 # Models & Repository implementations
│   │   ├── domain/               # Domain entities & Repository abstractions
│   │   └── presentation/         # BLoC, Pages (Login, Profile, Passcode, Register)
│   ├── chats/                    # Chats Module (Active Chats, Settings)
│   │   ├── data/                 # ChatModel & ChatRepositoryImpl
│   │   ├── domain/               # Repository interfaces
│   │   └── presentation/         # Blocs, Pages (ChatList, Settings, Search, Sheets)
│   └── messages/                 # Real-time Messaging & Calls Module
│       ├── data/                 # MessageModel & MessageRepositoryImpl
│       ├── domain/               # Entities, Message types
│       └── presentation/         # Pages (MessagePage, CallPage), Message widgets
├── shared/                       # App-wide reusable UI components
│   └── widgets/                  # Custom Adaptive buttons, TextFields
└── main.dart                     # Entry point & Initializations
```

### Layer Definitions:
1.  **Domain Layer (Entities & Repositories interfaces)**: Contains core business objects (`AppUser`, `Message`) and abstract repository protocols. Completely independent of external plugins.
2.  **Data Layer (Models & Repositories implementations)**: Contains data serialization models (`UserModel`, `MessageModel`, `ChatModel`) and handles real-time API bindings (Firebase Firestore, Storage, Local cache).
3.  **Presentation Layer (BLoCs & Views)**: Composed of UI widgets, flutter page views, and BLoC controllers reacting to UI events to emit states.

---

## 💬 3. Core Features & Capabilities

### 🔒 Authentication & Security
*   **Email & Password Authentication**: Classic login/sign-up module.
*   **Password Recovery**: Secure password reset flow using Firebase password reset emails. Fully adapted to Light/Dark modes and localized in English, Uzbek, and Russian.
*   **Profile Configuration**: Users can update their display name, status, and upload profile pictures.
*   **App Lock Protection**: Option to enforce a local Passcode (PIN) or biometric (fingerprint/face recognition) check upon opening the app.

### 👥 Chats & Collaborations
*   **1-to-1 Personal Chats**: Private real-time messages between two users.
*   **Group Chats**: Multiple participants collaborating in a group with user avatars and admin control.
*   **Broadcast Channels**: Admin-only publishing platforms where users subscribe and view announcements.
*   **User Search**: Real-time Firestore query to find users by email and start chats instantly.

### ✉️ Real-time Messaging (Supported Message Types)
The messaging module (`message_page.dart`) supports rich interaction payloads:
1.  **Text Messages**: Rich text rendering supporting clickable hyper-links.
2.  **Image Messages**: Compressed images transmitted securely with interactive fullscreen viewing and zoom features.
3.  **GIFs & Stickers**: Integration with Giphy APIs for animated gifs and pre-defined stickers.
4.  **Voice Messages**: Real-time voice recording, waveform visualization, and dynamic audio playback.
5.  **Location Sharing**: Leaflet-powered OpenStreetMap implementation allowing users to search, pick, and share precise coordinates and addresses.
6.  **Contact Cards**: Sharing name and phone number of contacts directly inside the chat.

### ⚙️ Interactive Message Actions
*   **Replies & Threads**: Users can reply to specific messages. Clicking the reply snippet smoothly scrolls (`Scrollable.ensureVisible`) to the parent message.
*   **Reactions**: Emoticon reactions (👍, ❤️, 😂, 😮, 😢) update real-time via Firestore transactions.
*   **Message Editing**: Senders can edit sent messages, updating both the database and the last message snippet.
*   **Message Deletion**: Users can delete messages globally.
*   **Pinned Messages**: Admins/users can pin important messages to the top of the chat view for easy access.
*   **Self-Destruct (Secret Messages)**: Configurable timers (e.g., 5s, 10s, 1m). Once a self-destruct message is read by the recipient, it is automatically purged from the Firestore database permanently.

### 📞 VoIP Calls
*   **Audio Calls**: Dynamic Calling State Machine (`call_page.dart`) allowing real-time voice call invitations, call acceptances, call declines, and active call timers.

### 🎨 Customization & Localization
*   **Multilingual Support**: Real-time localization (`en`, `ru`, `uz`) covering the entire app layout. Saved and fetched via local Hive storage.
*   **Chat Wallpapers**: Custom visual chat backgrounds. Users can select solid colors, gradients, pre-defined templates, or upload custom gallery images.
*   **Presence (Online/Offline) Tracking**: Live user status tracking. Updates last seen timestamp when users disconnect.

---

## 🗄 4. Data Architecture & Firestore Schema

### 1. `users` Collection
Stores registered user credentials and privacy states.
```json
{
  "uid": "USER_ID",
  "email": "user@example.com",
  "displayName": "John Doe",
  "photoUrl": "data:image/jpeg;base64,...",
  "isOnline": true,
  "lastSeen": "Timestamp",
  "lastSeenPrivate": false
}
```

### 2. `chats` Collection
Contains metadata for direct, group, and channel chats.
```json
{
  "id": "CHAT_ID",
  "participants": ["USER_ID_1", "USER_ID_2"],
  "isGroup": false,
  "isChannel": false,
  "groupName": "Development Team",
  "createdBy": "USER_ID_1",
  "lastMessage": "Hello there!",
  "lastMessageTime": "Timestamp",
  "lastMessageSenderId": "USER_ID_1",
  "pinnedMessageId": "MSG_ID_123",
  "unreadCount": {
    "USER_ID_1": 0,
    "USER_ID_2": 2
  },
  "userNames": {
    "USER_ID_1": "John Doe",
    "USER_ID_2": "Ali"
  },
  "userPhotos": {
    "USER_ID_1": "photo_base64_string"
  }
}
```

#### `chats/{chatId}/messages` Sub-Collection
Stores individual message logs.
```json
{
  "id": "MSG_ID_123",
  "senderId": "USER_ID_1",
  "text": "Hello there!",
  "imageUrl": "data:image/jpeg;base64,...",
  "type": "text", // text, image, voice, location, contact, gif
  "isRead": true,
  "isDeleted": false,
  "isForwarded": false,
  "timestamp": "Timestamp",
  "replyToMessageId": null,
  "reactions": {
    "USER_ID_2": "❤️"
  },
  "selfDestructDuration": null,
  "expiresAt": "Timestamp", // calculated once read if self-destruct is active
  "latitude": 41.31108,
  "longitude": 69.27972,
  "address": "Amir Temur Square, Tashkent",
  "contactName": "Sherzod",
  "contactPhone": "+998901234567"
}
```

---

## 🚀 5. Performance Optimizations implemented

1.  **Idempotent Unread Count Clears**: `markMessagesAsRead` only commits database batch updates when actual foreign unread messages exist, reducing heavy write loops.
2.  **Interactive Viewport Rendering**: Heavy image assets are compressed on-device using byte manipulation before transport, saving user bandwidth.
3.  **Local Memory Cache**: Recipient profile photos and wallpaper preferences are kept locally via Hive & volatile memory cache maps to skip repetitive database calls during list rendering.
4.  **Debounced Nominatim API Requests**: Map dragging coordinates are debounced with a 700ms threshold to prevent API rate-limits during reverse geocoding lookup.
