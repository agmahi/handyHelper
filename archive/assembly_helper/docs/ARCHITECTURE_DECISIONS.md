# HandyHelper: Master Architectural Decisions Record (ADR)

**Version:** 1.2.0
**Date:** March 5, 2026

This document tracks all core architectural, technical, and UX decisions made during the development of the HandyHelper iOS application. It serves as the source of truth for the project's SOTA (State of the Art) implementation strategy.

---

## 1. System Architecture: The "Dual Pipeline"

We adopted a "Dual Pipeline" architecture to balance heavy document understanding with real-time, low-latency AR execution.

### Pipeline A: The "Brain" (Map Generation)
*   **Purpose:** To convert static, visual 2D PDF manuals into structured, actionable JSON steps.
*   **Technology:** Offline GPT-4o Vision API -> Firebase / Embedded JSON.
*   **Execution Context:** Offline preparation.
*   **Rationale:** Standard OCR fails on IKEA manuals because the instructions rely on visual cues. Instead of running a heavy on-device VLM (like Donut), we constrain the MVP scope to 10 specific popular IKEA products. We process their manuals offline using GPT-4o Vision to generate 100% accurate JSON arrays. These will be stored in a Firebase backend, decoupling "The Brain" from the iOS binary, enabling instant OTA updates for manual corrections, and ensuring zero battery drain or processing latency on the iPhone.
*   **Status:** Mock JSON bridge currently integrated (`InstructionExtractionService.swift`). Awaiting Firebase setup.

### Pipeline B: The "Eyes" (Real-time Execution)
*   **Purpose:** To ingest the 24fps live POV stream from the Meta Ray-Ban glasses and track required parts in real-world space.
*   **Technology:** YOLOv8 via CoreML and Apple Vision Framework.
*   **Execution Context:** Runs synchronously on the iOS device, utilizing the Apple Neural Engine (ANE) for blazing-fast inference, heavily isolated to the `MainActor` to prevent UI blocking.
*   **Dataset Strategy:** To train a custom YOLOv8 model for the 10 target IKEA products efficiently, we will bypass manual data collection and YouTube scraping. Instead, we will leverage **Roboflow Universe**, utilizing existing, open-source datasets containing thousands of pre-labeled images of IKEA hardware (screws, dowels, panels, tools). These datasets will be used to train YOLOv8 on a cloud GPU (e.g., Google Colab Pro) before exporting the final `.mlpackage` for iOS.
*   **Rationale:** We need to keep latency under 50ms to ensure the AR audio feedback ("I see you found it") feels magical and immediate.
*   **Status:** Fully Implemented. Currently using a pre-trained `yolov8n` COCO model as a SOTA proof-of-concept. Awaiting custom dataset generation.

---

## 2. Audio & Voice Control (The "Ears")
*   **Decision:** Continuous, non-overlapping voice command recognition.
*   **Implementation:** Using Apple's `SFSpeechRecognizer` to allow the user to say "Next Step", "Go Back", or "Repeat".
*   **Audio Duel Prevention:** The microphone buffer specifically waits for the `AVSpeechSynthesizer` (the app's TTS) and the hardware's internal prompts ("Experience started") to finish speaking before activating. This prevents the app from transcribing its own voice and causing infinite loops.

---

## 3. Meta Wearables DAT SDK Lifecycle

The Meta SDK is highly sensitive to state conflicts. We established a strict, robust lifecycle for managing the `StreamSession`.

*   **Decision:** Single Source of Truth for Session Initialization.
*   **Implementation:** The `AssemblyViewModel` mirrors the Meta `CameraAccess` sample precisely. It initializes the `StreamSession` exactly *once* during `init`.
*   **Auto-Discovery Pattern:** Instead of manually calling `streamSession.start()` on view appearance (which causes black screen hangs), we use `deviceSelector.activeDeviceStream()`. The stream only starts *after* the SDK guarantees the glasses are active and worn.
*   **Permissions Gate:** Hardware stream initiation is strictly gated behind an explicit `await wearables.checkPermissionStatus(.camera)` check.

---

## 4. UI/UX: The "Copilot" Interface

*   **Unified Tab Architecture:** Removed the segmented "Glasses" vs "Manuals" tabs. The app uses a unified hub (`ManualHubView`) where the glasses connection state acts as a global feature toggle rather than a standalone destination.
*   **Deep Linking:** Meta AI OAuth authentication requires the `handyhelper://` URL scheme. The app intercepts this via `.onOpenURL` in the root `App` struct to complete the handshake.
*   **Dynamic View Modes:** The Assembly Session features a perfectly responsive segmented picker (Split, POV, Manual) to allow users to dedicate screen real estate to the live camera feed for debugging or the PDF manual for granular study. Built utilizing strict SwiftUI `.tag` matching on `CaseIterable` enums for state stability.
*   **Sheet Dismissal Logic:** All `fullScreenCover` dismissals are handled via closures passed down to ViewModels (e.g., `viewModel.exit()`), bypassing brittle SwiftUI environment variables.

---

## 5. Concurrency & State Management

*   **The MainActor Mandate:** All UI state and delegate callbacks from background processing (like Vision bounding box updates or stream frame ingestion) must be routed through `Task { @MainActor in }` to prevent race conditions and black screens.
*   **Combine Dependency:** The `Combine` framework is globally utilized to resolve `ObservableObject` and `@Published` conformance across ViewModels mapping to SDK properties.

---

## Version History
*   **v1.2.0 (March 5, 2026):** Updated AI Strategy. Abandoned on-device Donut for offline GPT-4o Vision + Firebase JSON embedding. Logged YouTube dataset scraping strategy for custom YOLOv8 training. Added Audio/Voice Control architecture.
*   **v1.1.0 (March 1, 2026):** Confirmed successful SOTA Pipeline B (YOLOv8 CoreML) integration and fixed Segmented UI View Modes.
*   **v1.0.0 (March 1, 2026):** Initial document creation. Captured SDK lifecycle stabilization, Local Transformer (Donut) integration plan.
