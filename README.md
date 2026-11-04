# Firebase Chat Application

A cross-platform real-time messaging application built with Flutter, Clean Architecture, and Firebase backend services.

## Overview

This project provides a full-featured chat application supporting direct conversations, group chats, broadcast channels, end-to-end self-destructing secret messaging, and multimedia sharing across Android, iOS, Web, and Desktop platforms.

### Architecture

The application is structured following Clean Architecture principles:

* **Presentation Layer**: Flutter widgets and BLoCs (`flutter_bloc`) managing responsive UI state.
* **Domain Layer**: Pure business logic models and abstract repository contracts.
* **Data Layer**: Concrete repository implementations interfacing with Cloud Firestore, Firebase Storage, and Hive local persistence.

Detailed architecture and Firestore database schemas are documented in [DOCUMENTATION.md](DOCUMENTATION.md).

## Key Features

* **Authentication & Profile**: Email/password authentication, password recovery, profile editing, and biometric / passcode app lock.
* **Real-time Messaging**: Direct 1-on-1 chats, group chats with admin roles, and broadcast channels.
* **Rich Payloads**: Text, compressed images, audio voice notes with waveform visualization, OpenStreetMap location sharing, contact cards, and stickers.
* **Interactive Message Actions**: Message replies, real-time emoji reactions, editing, deletion, pinned messages, and self-destructing timers.
* **Offline Resilience**: Offline outbox queue caching outgoing messages locally until network connectivity is restored.
* **VoIP Calling State Machine**: Audio call signaling and in-call controls.
* **Internationalization**: Complete localization support for English (`en`), Russian (`ru`), and Uzbek (`uz`).

## Getting Started

### Prerequisites

* [Flutter SDK](https://docs.flutter.dev/get-started/install) (Dart 3.0.0+)
* [Firebase CLI](https://firebase.google.com/docs/cli) & [FlutterFire CLI](https://firebase.flutter.dev/docs/cli/)

### Configuration

1. Copy the example environment configuration:
   ```bash
   cp .env.example .env
   ```
2. Configure your Firebase project using the FlutterFire CLI:
   ```bash
   flutterfire configure
   ```
   This generates the platform configurations in `lib/firebase_options.dart` and `android/app/google-services.json` using your Firebase project credentials.

### Running the Application

Fetch dependencies and start the app:

```bash
flutter pub get
flutter run
```

### Running Analysis & Tests

```bash
flutter analyze
flutter test
```
