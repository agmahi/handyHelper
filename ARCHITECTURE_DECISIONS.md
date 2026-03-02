# HandyHelper: Master Architectural Decisions Record (ADR)

**Version:** 1.0.0
**Date:** March 1, 2026

This document tracks all core architectural, technical, and UX decisions made during the development of the HandyHelper iOS application. It serves as the source of truth for the project's SOTA (State of the Art) implementation strategy.

---

## 1. System Architecture: The "Dual Pipeline"

We adopted a "Dual Pipeline" architecture to balance heavy document understanding with real-time, low-latency AR execution.

### Pipeline A: The "Brain" (Map Generation)
*   **Purpose:** To convert static, visual 2D PDF manuals into structured, actionable JSON steps.
*   **Technology:** Local Document Understanding Transformer (Donut).
*   **Execution Context:** Runs asynchronously via Apple Neural Engine (ANE) using CoreML (`.mlpackage`).
*   **Rationale:** Standard OCR fails on IKEA manuals because the instructions rely on visual cues (arrows, zoomed diagrams) rather than text. By using a Vision Language Model (VLM) locally, we eliminate marginal cloud API costs while maintaining SOTA extraction capabilities.
*   **Status:** Stub integrated (`LocalDocumentTransformer.swift`). Awaiting `.mlpackage` export via Python script.

### Pipeline B: The "Eyes" (Real-time Execution)
*   **Purpose:** To ingest the 24fps live POV stream from the Meta Ray-Ban glasses and track required parts in real-world space.
*   **Technology:** Apple Vision Framework (Text/Rectangle Recognition) -> Future: YOLOv8 via CoreML.
*   **Execution Context:** Runs synchronously on the iOS device, heavily isolated to the `MainActor` to prevent UI blocking.
*   **Rationale:** We need to keep latency under 50ms to ensure the AR audio feedback ("I see you found it") feels magical and immediate.
*   **Status:** Implemented (`PartDetectionService.swift`). Currently using a permissive Vision OCR proxy for MVP testing.

---

## 2. Meta Wearables DAT SDK Lifecycle

The Meta SDK is highly sensitive to state conflicts. We established a strict, robust lifecycle for managing the `StreamSession`.

*   **Decision:** Single Source of Truth for Session Initialization.
*   **Implementation:** The `AssemblyViewModel` mirrors the Meta `CameraAccess` sample precisely. It initializes the `StreamSession` exactly *once* during `init`.
*   **Auto-Discovery Pattern:** Instead of manually calling `streamSession.start()` on view appearance (which causes black screen hangs), we use `deviceSelector.activeDeviceStream()`. The stream only starts *after* the SDK guarantees the glasses are active and worn.
*   **Permissions Gate:** Hardware stream initiation is strictly gated behind an explicit `await wearables.checkPermissionStatus(.camera)` check.

---

## 3. UI/UX: The "Copilot" Interface

*   **Unified Tab Architecture:** Removed the segmented "Glasses" vs "Manuals" tabs. The app uses a unified hub (`ManualHubView`) where the glasses connection state acts as a global feature toggle rather than a standalone destination.
*   **Deep Linking:** Meta AI OAuth authentication requires the `handyhelper://` URL scheme. The app intercepts this via `.onOpenURL` in the root `App` struct to complete the handshake.
*   **Dynamic View Modes:** The Assembly Session features a segmented picker (Split, POV, Manual) to allow users to dedicate screen real estate to the live camera feed for debugging or the PDF manual for granular study.
*   **Sheet Dismissal Logic:** All `fullScreenCover` dismissals are handled via closures passed down to ViewModels (e.g., `viewModel.exit()`), bypassing brittle SwiftUI environment variables.

---

## 4. Concurrency & State Management

*   **The MainActor Mandate:** All UI state and delegate callbacks from background processing (like Vision bounding box updates or stream frame ingestion) must be routed through `Task { @MainActor in }` to prevent race conditions and black screens.
*   **Combine Dependency:** The `Combine` framework is globally utilized to resolve `ObservableObject` and `@Published` conformance across ViewModels mapping to SDK properties.

---

## Version History
*   **v1.0.0 (March 1, 2026):** Initial document creation. Captured SDK lifecycle stabilization, Local Transformer (Donut) integration plan, and Dynamic View Modes.
