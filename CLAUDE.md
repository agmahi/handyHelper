# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

CardMax is an iOS app that leverages Meta Ray-Ban Smart Glasses to help users maximize credit card rewards. It provides on-demand, hands-free recommendations for the best card to use at checkout, whether shopping in-person or online.

**Core Value Proposition:** Siri-activated rewards optimization with audio feedback through Meta glasses. Users say "Which card?" via Siri, and the app identifies the merchant and recommends the optimal card from the household's portfolio.

## Development Environment

### Building and Running

```bash
# Open the project in Xcode
open handyHelper.xcodeproj

# Build from command line
xcodebuild -project handyHelper.xcodeproj -scheme handyHelper -configuration Debug

# The app requires:
# - iOS 15.0+
# - Physical iPhone (Meta SDK doesn't support Simulator fully)
# - Meta Ray-Ban glasses paired via Meta View app (or MockDevice in DEBUG mode)
```

### Testing

The project uses mock card data and merchant templates for testing the recommendation loop. Assembly-related code has been moved to `archive/assembly_helper/`.

## Architecture

### Activation via Siri App Intents

CardMax uses **Siri App Intents** (not in-app voice recognition) for activation. The user triggers recommendations by asking Siri "Which card at [merchant/category]?" This avoids battery drain from continuous audio monitoring and prevents OOM crashes that occurred with the previous `SFSpeechRecognizer`-based `VoiceTriggerService`.

**Key Pattern:**
- `AppShortcutsProvider` registers intents with Siri
- App Intents call into `CardMaxViewModel.recommendForMerchantName(_:)` or `recommendForCategory(_:)`
- Audio response is delivered through Meta glasses via `AudioResponseService`

### Detection & Recommendation Pipeline
**Location:** `handyHelper/CardMax/Services/`

- **Recommendation Engine:** `RecommendationEngine.swift` matches merchants/categories against the user's card portfolio to find the highest reward rate. Supports merchant-specific bonuses, category rewards, and rotating quarterly categories. Owner-aware — recommends across household cards.
- **Visual Detection (planned):** POV frame capture from Meta glasses for merchant logo/text recognition.
- **Location Detection (planned):** GPS + Google Places API as fallback for physical stores.

**Key Files:**
- `handyHelper/CardMax/Models/CreditCard.swift` - Card model with reward structures, rotating categories, and multi-owner support.
- `handyHelper/CardMax/Models/Merchant.swift` - Merchant definitions with category mapping and keyword matching.
- `handyHelper/CardMax/Models/Receipt.swift` - Receipt capture model with image persistence.
- `handyHelper/CardMax/Services/RecommendationEngine.swift` - Core reward calculation and card selection logic.
- `handyHelper/CardMax/Services/CardMaxService.swift` - Orchestrates detection pipeline and glasses camera.
- `handyHelper/CardMax/Services/AudioResponseService.swift` - TTS with premium voice selection.
- `handyHelper/CardMax/Services/CardStorageService.swift` - JSON persistence for user's card portfolio.
- `handyHelper/CardMax/Services/ReceiptStorageService.swift` - JSON persistence for receipt metadata and images.

## Meta Wearables SDK Integration

### Critical SDK Lifecycle Pattern

The Meta DAT SDK is highly sensitive to initialization order. Follow this exact pattern:

```swift
// 1. Configure SDK before ANY other usage (in App.init)
try Wearables.configure()

// 2. Use AutoDeviceSelector (not manual device selection)
let deviceSelector = AutoDeviceSelector(wearables: wearables)

// 3. Create StreamSession ONCE in ViewModel.init
let streamSession = StreamSession(streamSessionConfig: config, deviceSelector: deviceSelector)

// 4. Use activeDeviceStream() - stream auto-starts when glasses detected
for await device in deviceSelector.activeDeviceStream() {
    if device != nil {
        await streamSession.start()
    }
}

// 5. ALWAYS check permissions before starting stream
let status = try await wearables.checkPermissionStatus(.camera)
if status == .granted {
    await streamSession.start()
}
```

**Common Pitfalls:**
- Calling `streamSession.start()` in `onAppear` leads to black screen hang.
- Creating multiple `StreamSession` instances causes crashes.
- Use listener tokens for frame updates: `streamSession.videoFramePublisher.listen { }`.

## Audio Response

### Text-to-Speech (TTS)
- **Framework:** `AVSpeechSynthesizer` with premium voice selection (sorted by `quality.rawValue`).
- **Routing:** Audio plays through Bluetooth to glasses speakers when connected, falls back to phone speaker.
- **Function:** Delivers natural language recommendations like "Use your Amex Gold, 4% back on groceries."
- **Implementation:** `handyHelper/CardMax/Services/AudioResponseService.swift`

### Voice Activation (Siri)
- **Framework:** Apple App Intents / `AppShortcutsProvider`.
- **Triggers:** "Which card at [merchant]?", "Which card for [category]?"
- **Note:** The previous in-app `VoiceTriggerService` (SFSpeechRecognizer) was removed due to OOM crashes from continuous audio monitoring. The file still exists but is not used by CardMax.

## State Management & Concurrency

### MainActor Requirements

**CRITICAL:** All UI updates and SDK delegate callbacks MUST be dispatched to `@MainActor`:

```swift
// Results from background detection services
Task { @MainActor in
    self.currentRecommendation = bestCard
}
```

### ViewModel Pattern

- All ViewModels are `@MainActor` classes conforming to `ObservableObject`.
- Use `@Published` properties for SwiftUI reactivity.
- Complex async operations (Visual/Location detection) use `Task { }` blocks.

## Project Structure

```
handyHelper/
├── CameraAccessApp.swift              # App entry point, SDK configuration
├── CardMax/
│   ├── Models/
│   │   ├── CreditCard.swift           # Card model, rotating schedules, presets, catalog
│   │   ├── Merchant.swift             # Merchant definitions and keyword matching
│   │   └── Receipt.swift              # Receipt capture model with image persistence
│   ├── Services/
│   │   ├── CardMaxService.swift       # Detection pipeline orchestrator, glasses camera
│   │   ├── RecommendationEngine.swift # Reward calculation, owner-aware card selection
│   │   ├── AudioResponseService.swift # TTS with premium voice selection
│   │   ├── CardStorageService.swift   # JSON persistence for card portfolio
│   │   ├── ReceiptStorageService.swift# JSON persistence for receipts
│   │   └── VoiceTriggerService.swift  # (Legacy — not used, kept for reference)
│   ├── ViewModels/
│   │   └── CardMaxViewModel.swift     # State machine, card/receipt management
│   └── Views/
│       ├── CardMaxView.swift          # Main UI — wallet, quick glance, receipts
│       ├── AddCardView.swift          # Searchable card catalog grouped by issuer
│       └── ImagePicker.swift          # UIImagePickerController wrapper
├── Services/
│   └── SpeechRecognizerService.swift  # Shared speech infrastructure
├── ViewModels/
│   ├── WearablesViewModel.swift       # SDK/Device management
│   └── StreamSessionViewModel.swift
├── Views/
│   ├── MainAppView.swift              # Root navigation
│   └── HomeScreenView.swift
└── archive/
    └── assembly_helper/               # Former IKEA assembly code
```

## Meta SDK Dependencies

The project uses Meta's Wearables DAT SDK via Swift Package Manager:

```
MetaWearablesDAT: https://github.com/facebook/meta-wearables-dat-ios @ 0.4.0
```

**Frameworks:**
- `MWDATCore` - Device identity, registration, permissions
- `MWDATCamera` - Video streaming, photo capture
- `MWDATMockDevice` - DEBUG-only simulated glasses

## Adding ML Models

### Merchant Logo Recognition (YOLOv8)

1. Train YOLOv8 model on top 50 merchant logos.
2. Export as CoreML `.mlpackage`.
3. Add to `handyHelper/CardMax/Resources/`.
4. The visual detection service uses these models to identify merchants from POV frames.
5. If models are missing, the system gracefully falls back to OCR and Google Places API.

## Key Design Decisions

### Siri-Only Activation (No In-App Voice Trigger)
The original `VoiceTriggerService` used continuous `SFSpeechRecognizer` listening, which caused OOM crashes from persistent audio engine taps and recursive restart loops. CardMax now uses Siri App Intents exclusively — zero battery impact when idle, and the OS handles all voice recognition.

### Hybrid Detection (Planned)
Visual detection will be the primary method (supports online shopping via URL/logo detection on laptop screens). Location-based detection via GPS + Google Places serves as fallback for physical stores. Currently, recommendations are triggered by merchant name or category via Siri.

### Audio-First Response
Users are often at a checkout counter with hands full. Natural language audio delivered through the glasses provides a seamless experience without requiring the user to look at their phone.

### Multi-Owner Household Support
Cards have an `owner` field (defaults to "Me") so users can track a spouse's or family member's cards. The recommendation engine considers all household cards and prefixes the owner name in audio responses when recommending someone else's card.

### Rotating Category Schedules
Cards like Discover it and Chase Freedom Flex have quarterly rotating 5% categories. These are modeled as `RotatingSchedule` structs with hardcoded quarterly data. The `effectiveCategoryRewards` computed property merges static and active rotating rates at query time.

### On-Demand Frame Listener
The Meta SDK frame listener (`videoFramePublisher`) is started only when needed (photo capture) and stopped immediately after. Persistent listeners at 10 FPS caused OOM crashes from continuous UIImage conversion.

## Important Documentation Files

- `PRODUCT_SPEC.md` - Product vision, feature scope, and hybrid detection logic.
- `ARCHITECTURE.md` - Detailed technical system design and data models.
- `MILESTONES.md` - Development roadmap and execution plan.

## Next Implementation Priorities

1. **Visual Detection (Milestone 2)**
   - Train YOLOv8 logo detection model for top merchants.
   - Implement frame capture and OCR pipeline from glasses POV.

2. **Real-World Testing (Milestone 6)**
   - Test Siri App Intents with physical glasses connected.
   - Validate audio routing through glasses speakers.
   - Test receipt capture from all three sources (glasses, phone camera, photo library).

## Debug Mode Features

When running DEBUG builds:

- Mock device simulator available (shake device to access debug menu)
- Test recommendation flow without physical glasses
- Mock merchants and card data for rapid iteration

## Common Gotchas

1. **Black Screen on Stream Start:** Ensure `streamSession.start()` is only called after the device is confirmed as ready via `activeDeviceStream()`.
2. **Audio Routing:** Recommendations should play through the glasses; ensure the audio session is configured for `.playAndRecord` with `.allowBluetooth` and `.defaultToSpeaker`.
3. **Detection Latency:** Parallelize visual and location detection to keep total response time under 2 seconds.
4. **Stream Session Crashes:** Never create multiple `StreamSession` instances. Create once in ViewModel.init, reuse throughout lifecycle.
5. **OOM from Frame Listeners:** Never leave `videoFramePublisher.listen` running persistently. Use `startFrameListener()`/`stopFrameListener()` around capture operations only.
6. **Connection Status:** Use `activeDeviceStream()` (not `devicesStream()`) to detect actually connected glasses. `devicesStream()` returns paired devices even when offline.
7. **Audio Tap Crashes:** When using `AVAudioEngine`, track whether a tap is installed with a boolean flag before calling `removeTap(onBus:)`. Removing a nonexistent tap crashes.
8. **Photo Capture Continuation:** Use a `didResume` flag with `withCheckedContinuation` in `capturePhoto()` to prevent double-resume from the `photoDataPublisher`.

## Using Gemini CLI for Large Codebase Analysis

Use the Gemini CLI with its massive context window for analyzing project-wide patterns or complex SDK integrations.

### Usage Examples

```bash
# Analyze the CardMax service layer
gemini -p "@handyHelper/CardMax/Services/ Analyze the merchant detection pipeline"

# Verify Meta SDK usage across the project
gemini -p "@handyHelper/ViewModels/ @handyHelper/Services/ Is the Meta SDK lifecycle correctly implemented?"

# Check reward calculation logic
gemini -p "@handyHelper/CardMax/Models/CreditCard.swift How are rotating categories handled?"

# Full project overview
gemini -p "@./ Give me an overview of this entire project"
```

**Important Notes:**
- Paths in `@` syntax are relative to the project root.
- The CLI includes file contents directly in the context for thorough analysis.
- Use `gemini -p` for read-only research and architectural validation.