# Our Receipt

A SwiftUI iOS app to capture, generate, and organize receipts with a privacy‑first design. Built for Tech Series 2025 (“Overclocked”).

> **Core:** SwiftUI + Firebase (Auth, Firestore, Storage). Optional Node backend later.

---

## Screenshots (placeholders)
Add images into `docs/screenshots/` and update the paths:
```
![Home](docs/screenshots/home.png)
![History](docs/screenshots/history.png)
![Add](docs/screenshots/add.png)
```

---

## Features
- Email/password **login & sign‑up** (Firebase Auth).
- **Add receipts** manually or through the **QR/Generator** flow.
- **View / search / detail** receipts (merchant, date, amount, category, tags).
- Optional **location**, **notes**, and **images**.
- **History** and **discovery/challenges** screens for future growth.
- Swift Package Manager setup. Unit + UI test targets included.

---

## Project Structure (high level)
```
Final/
├─ aaa/                         # App source
│  ├─ aaaApp.swift              # App entry; FirebaseApp.configure()
│  ├─ Models.swift              # Data models (User/Receipt/...)
│  ├─ AuthView.swift, LoginView.swift, SignUpView.swift
│  ├─ HomeView.swift, NewReceiptView.swift, ReceiptDetailView.swift, ReceiptPreviewView.swift
│  ├─ BillGeneratorView.swift, ProductFormView.swift, ProductSelectionView.swift
│  ├─ MyQRCodeView.swift, QRCodeGenerator.swift, MapView.swift
│  ├─ Assets.xcassets/          # Colors, app icon
│  ├─ GoogleService-Info.plist  # Firebase config (add your own)
│  └─ ... other views & helpers
├─ aaa.xcodeproj/               # Xcode project
├─ aaaTests/                    # Unit tests
└─ aaaUITests/                  # UI tests
```

Third‑party frameworks seen in code:
- `FirebaseCore`, `FirebaseAuth`, `FirebaseFirestore`

---

## Requirements
- **Xcode**: 15+ (latest recommended)
- **iOS Deployment Target**: 18.5 (adjust if needed)
- **Swift**: 5.x
- **Apple ID** for code signing

---

## Getting Started (iOS)

1. **Clone & open**
   ```bash
   git clone <YOUR_REPO_URL>
   open Final/aaa.xcodeproj
   ```

2. **Firebase config**
   - Create a Firebase iOS app with your bundle id (e.g., `com.ourreceipt.app`).  
   - Download **`GoogleService-Info.plist`** and place it in `Final/aaa/` (ensure it’s in the app target).

3. **Signing**
   - Xcode → **Targets → aaa → Signing & Capabilities**
     - **Automatically manage signing**: On
     - **Team**: your Apple ID
     - **Bundle Identifier**: unique (e.g., `com.ourreceipt.app`)

4. **Run**
   - Pick a simulator or your iPhone and press **Run**.  
   - First device install requires enabling **Developer Mode** and trusting your developer app.

---

## Configuration Points
- Secrets belong in Keychain or server; never commit to git.
- If you add a Node backend later, define a `BASE_URL` constant and set via build settings or plist.
- Firestore rule example (owner‑only access):
  ```
  rules_version = '2';
  service cloud.firestore {
    match /databases/{db}/documents {
      match /users/{uid}/receipts/{doc} {
        allow read, write: if request.auth != null && request.auth.uid == uid;
      }
    }
  }
  ```

---

## Privacy & Security
- `PRIVACY-POLICY-Our Receipt.md`
---

## Roadmap
- OCR import & automatic line‑item parsing.
- CSV export and sharing.
- Category rules and insights.
- Optional Supabase/Node API for advanced features.

---

## Contributors
Thanks to the collaborators on this repo:
- **@hackathontechseries2025** 
- **@ImNuza** (Dewa Bratanusa)
- **@ownerofanime** (Matthew Tjandera)
- **@sehyuno** (Sehyun Oh)
- **@Seunghak0401** (Kim Seunghak)
- **@Xxdsanctuary** (Nathanael Steven Chiang)
- **@Naitik-J309** (Naitik Jain)

---

## License
None

---

## Judge Notes
For a quick demo: open `aaa.xcodeproj`, select a simulator, run. Sign up, then add a receipt via **+** or the generator flow.
