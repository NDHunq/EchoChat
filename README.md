# 🔐 EchoChat

### A Production-Grade, End-to-End Encrypted Real-Time Messaging App for iOS

![Swift](https://img.shields.io/badge/Swift-5.9-F05138?style=for-the-badge&logo=swift&logoColor=white)
![SwiftUI](https://img.shields.io/badge/SwiftUI-Framework-007AFF?style=for-the-badge&logo=apple&logoColor=white)
![MVVM](https://img.shields.io/badge/Architecture-MVVM-6C3483?style=for-the-badge)
![CryptoKit](https://img.shields.io/badge/Apple-CryptoKit-34495E?style=for-the-badge&logo=apple&logoColor=white)
![WebSockets](https://img.shields.io/badge/Transport-WebSockets-239120?style=for-the-badge)
![CoreData](https://img.shields.io/badge/Persistence-Core%20Data-1A5276?style=for-the-badge&logo=apple&logoColor=white)
![CallKit](https://img.shields.io/badge/VoIP-CallKit-117A65?style=for-the-badge&logo=apple&logoColor=white)

---

## 📖 Overview

**EchoChat** is a proof-of-concept iOS messaging application engineered to demonstrate enterprise-level mobile development capabilities at telecom and fintech standards. It combines **real-time encrypted communication**, **VoIP call simulation**, and **secure offline persistence** into a cohesive, production-ready architecture — all built natively on Apple's first-party frameworks.

This project is not a tutorial clone. Every architectural decision — from the encryption layer to the WebSocket signaling protocol — is intentional, reflecting the security-first and performance-conscious mindset required in regulated industries.

> **Target Audience:** Recruiting teams, senior iOS engineers, and tech leads evaluating candidates for roles involving real-time systems, security engineering, or native iOS architecture.

https://github.com/user-attachments/assets/68b86d4f-3660-4b95-8ce6-ff832ade74a7

---

## ✨ Core Features

### 🔒 End-to-End Encryption (E2EE)

Messages and media are encrypted **on-device before transmission** — the server only ever relays opaque ciphertext and cannot read content.

- **Algorithm:** AES-GCM 256-bit via `CryptoKit` — provides **confidentiality** + **tamper detection** (GCM auth tag) in one operation. Same cipher as TLS 1.3, Signal, and iMessage.
- **Sealed Box:** Each payload = `[12-byte Nonce | Ciphertext | 16-byte Auth Tag]` → Base64-encoded → sent over WebSocket. Unique nonce per message prevents replay attacks.
- **Flow:** `Plaintext → CryptoManager.encrypt() → AES.GCM.seal() → Base64 → WebSocket → Base64 → AES.GCM.open() → Plaintext`
- **Key model (demo):** Pre-shared 256-bit symmetric key in `CryptoManager.sharedSymmetricKey` — sufficient for two-simulator testing without a key exchange round-trip.
- **Production path:** Swap to per-user **Curve25519 key pairs** + **HKDF** derivation following the [Signal Protocol / X3DH](https://signal.org/docs/specifications/x3dh/) spec — outlined in `CryptoManager.swift` comments.

### ⚡ Real-Time Communication
- Powered by **`URLSessionWebSocketTask`** — Apple's native WebSocket API — for persistent, low-latency bidirectional messaging
- Supports **live typing indicators**, message delivery events, and instant push of encrypted payloads
- Automatic reconnection logic handled inside `WebSocketManager` to maintain session resilience

### 📞 VoIP Call Simulation
- Native **CallKit** integration via `CallManager` provides full system-level call UI (lock screen answer, mute, speaker controls)
- Manages the complete **call lifecycle**: incoming/outgoing signaling, hold, end, and CXProvider delegate callbacks
- Mirrors the architecture used in production VoIP apps (WhatsApp, FaceTime, Signal)

### 🗄️ Secure Offline Storage
- Chat history is persisted locally using **Core Data** with a structured entity model (`ChatMessage`, `Conversation`)
- Encrypted message content is stored at rest, ensuring the device's data layer mirrors the security posture of the transport layer
- Credentials and session keys are stored in the **iOS Keychain** via `KeychainManager` — never in `UserDefaults`

### 🖼️ Media Sharing
- Supports in-chat **image sharing** with automatic compression before encryption
- Images are encoded as Base64 strings, encrypted via AES-GCM, and transmitted over WebSocket as part of the message payload
- Receiver-side decryption and rendering is handled transparently in `MessageBubbleView`

### 🧬 Biometric Authentication
- App access is gated behind **Face ID / Touch ID** using `LocalAuthentication` via `BiometricAuthManager`
- `LockScreenView` presents a native biometric prompt, protecting conversations at the OS level

---

## 🏛️ Architecture

EchoChat strictly adheres to the **MVVM (Model-View-ViewModel)** pattern, ensuring a clean separation of concerns and testability across all layers.

```
EchoChat/
├── Managers/               # Stateful service layer (business logic & I/O)
│   ├── WebSocketManager    # Real-time transport, reconnection, message routing
│   ├── CryptoManager       # AES-GCM encryption / decryption via CryptoKit
│   ├── CallManager         # CallKit lifecycle, CXProvider, CXCallController
│   ├── KeychainManager     # Secure credential & key storage
│   └── BiometricAuthManager# Face ID / Touch ID authentication
│
├── ViewModels/             # Observable state & business logic binding
│   ├── ChatViewModel       # Message send/receive, E2EE orchestration
│   ├── ChatListViewModel   # Conversation list & session management
│   ├── CallViewModel       # Call state machine
│   └── LoginViewModel      # Auth flow coordination
│
├── Views/                  # Pure SwiftUI declarative UI
│   ├── ChatView            # Live chat interface
│   ├── MessageBubbleView   # Encrypted message rendering with media support
│   ├── CallView            # In-call UI synchronized with CallKit state
│   ├── ChatListView        # Conversation list
│   ├── LoginView           # Entry / authentication screen
│   └── LockScreenView      # Biometric gate
│
└── Models/                 # Plain Swift data models
    ├── ChatMessage         # Core Data NSManagedObject + codable DTO
    ├── Conversation        # Thread metadata
    └── Message             # Transport-layer message envelope
```

**Design Principles:**
- `Managers` own all side effects (network I/O, crypto, persistence) — ViewModels never touch these layers directly without the Manager abstraction
- ViewModels expose state via `@Published` properties and are injected into Views via SwiftUI's environment
- Views contain **zero business logic** — layout and presentation only

---

## 🚀 Getting Started

### Prerequisites

| Tool | Version |
|---|---|
| Xcode | 15.0+ |
| iOS Simulator | iOS 17.0+ |
| Node.js | 18.x+ |
| npm | 9.x+ |

### 1. Clone the Repository

```bash
git clone https://github.com/NDHunq/EchoChat.git
cd EchoChat
```

### 2. Run the Mock Signaling Server

EchoChat requires a local WebSocket server to relay messages between clients. The server is a lightweight Node.js broadcast relay.

```bash
# Navigate to the server directory (if present) or project root
cd server   # or wherever server.js lives

# Install dependencies
npm install

# Start the WebSocket server on port 8080
node server.js
```

You should see:
```
✅ WebSocket server listening on ws://localhost:8080
```

> **Keep this terminal open** while running the app. The iOS app connects to `ws://localhost:8080` on launch.

### 3. Open the Xcode Project

```bash
open EchoChat.xcodeproj
```

### 4. Build & Run

1. Select the **EchoChat** scheme in Xcode
2. Choose an **iOS Simulator** (iPhone 15 Pro recommended)
3. Press **⌘R** to build and run

> **💡 Tip:** To test real-time messaging between two users, launch a **second simulator instance** and run the app again — both will connect to the same local WebSocket server.

### 5. Enable Face ID in the Simulator

The app enforces biometric authentication on launch. To enable it in the Simulator:

```
Simulator Menu → Features → Face ID → Enrolled ✅
```

Then use **Features → Face ID → Matching Face** to simulate a successful authentication.

---

## 📸 Screenshots & Demos

| Chat & E2EE | CallKit UI | Architecture Flow |
|:-----------:|:----------:|:-----------------:|
| *(drop screenshot or GIF here)* | *(drop screenshot or GIF here)* | *(drop diagram here)* |
| Live encrypted messaging, typing indicators, image sharing | Native system call UI via CallKit integration | MVVM layer diagram with Manager abstraction |

---

## 🛡️ Security Posture

| Surface | Implementation |
|---|---|
| Message Transport | AES-GCM 256-bit encryption (CryptoKit) |
| Media Transmission | Base64-encoded AES-GCM ciphertext over WebSocket |
| Credential Storage | iOS Keychain (via `KeychainManager`) |
| App Access | Face ID / Touch ID (LocalAuthentication) |
| Data at Rest | Encrypted payloads persisted in Core Data |

---

## 🧪 Testing

```bash
# Unit Tests
xcodebuild test -scheme EchoChat -destination 'platform=iOS Simulator,name=iPhone 15 Pro'
```

Test targets:
- `EchoChatTests` — Unit tests for ViewModels and Managers
- `EchoChatUITests` — UI automation tests for core user flows

---

## 🗺️ Roadmap

- [ ] Signal Protocol key exchange (X3DH + Double Ratchet)
- [ ] Push Notifications via APNs for background message delivery
- [ ] Group messaging with per-member key distribution
- [ ] Server-side message store with zero-knowledge architecture

---

## 👤 Author

**Nguyen Duy Hung**
iOS Developer

[![LinkedIn](https://img.shields.io/badge/LinkedIn-Connect-0077B5?style=flat&logo=linkedin)](https://linkedin.com/in/your-profile)
[![GitHub](https://img.shields.io/badge/GitHub-Follow-181717?style=flat&logo=github)](https://github.com/your-username)

---

> *EchoChat is a portfolio/proof-of-concept project. The WebSocket server is a local mock — not a production backend. It is intended solely to demonstrate iOS architecture and security engineering skills.*
