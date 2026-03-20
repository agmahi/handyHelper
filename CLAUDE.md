# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

HandyHelper is an iOS app that creates an "expert over your shoulder" experience using Meta Ray-Ban Smart Glasses. The MVP focuses on furniture assembly guidance (IKEA products) but is architected to support multiple use-cases (cooking, workouts, etc.).

**Core Value Proposition:** Hands-free, audio-first AR guidance using POV vision from Meta glasses to provide real-time contextual feedback during physical tasks.

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

The project currently uses mock data for testing the core assembly loop without requiring actual IKEA furniture or custom ML models. Look for `MockData` and test assembly sessions in `InstructionExtractionService.swift:26-62`.

## Architecture: "Dual Pipeline" System

The codebase follows a strict separation between two processing streams:

### Pipeline A: "The Brain" (Static Manual Processing)
**Location:** `handyHelper/Services/Manuals/`

- **Purpose:** Convert 2D PDF manuals into structured JSON steps
- **Strategy:** Offline GPT-4o Vision API → Firebase/Local JSON (not cloud-processed on-device)
- **Status:** Currently using mock data (`InstructionExtractionService.extractSteps()`)
- **Next Step:** See `conductor/tracks/manual_ingestion_20260316/` for implementation plan

**Key Files:**
- `InstructionExtractionService.swift` - Parses JSON or generates mock steps
- `ManualManager.swift` - Handles library, search, and persistence (UserDefaults)
- `ManualModels.swift` - Core data structures (`AssemblyStep`, `FurnitureManual`)

### Pipeline B: "The Eyes" (Real-Time Vision)
**Location:** `handyHelper/Services/Vision/PartDetectionService.swift`

- **Purpose:** Process 24fps POV stream from Meta glasses to detect parts
- **Technology:** YOLOv8 via CoreML (currently using pre-trained COCO model)
- **Fallback:** Apple Vision OCR + rectangle detection if YOLO model missing
- **Performance:** Runs on Apple Neural Engine (ANE), must dispatch to `@MainActor`

**How it Works:**
1. `PartDetectionService` receives `VideoFrame` from `AssemblyViewModel`
2. Runs Vision framework requests (YOLO or OCR+rectangles)
3. Returns `Detection` array via delegate pattern to avoid blocking UI
4. Detections trigger audio feedback ("I see you found it")

## Meta Wearables SDK Integration

### Critical SDK Lifecycle Pattern

The Meta DAT SDK is **highly sensitive to initialization order**. Follow this exact pattern:

```swift
// 1. Configure SDK before ANY other usage (in App.init)
try Wearables.configure()

// 2. Use AutoDeviceSelector (not manual device selection)
let deviceSelector = AutoDeviceSelector(wearables: wearables)

// 3. Create StreamSession ONCE in ViewModel.init (not in onAppear)
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
- ❌ Calling `streamSession.start()` in `onAppear` → black screen hang
- ❌ Creating multiple `StreamSession` instances → crashes
- ❌ Not gating stream behind permission check → silent failures
- ✅ Use listener tokens for frame/state updates: `streamSession.videoFramePublisher.listen { }`

**Reference Implementation:** `AssemblyViewModel.swift:32-104`

### Registration Flow

Users must authorize the app via Meta AI before accessing camera:

1. App calls `wearables.startRegistration()`
2. Meta AI app opens via Universal Link
3. User approves in Meta AI
4. Meta AI redirects back via `handyhelper://` URL scheme
5. App handles via `.onOpenURL` in `CameraAccessApp.swift`

## Audio & Voice Control

### Text-to-Speech (TTS)
- **Framework:** `AVSpeechSynthesizer` (routes through Bluetooth HFP to glasses speakers)
- **Pattern:** Always delay TTS by 2-3 seconds after stream starts to avoid overlapping with Meta's "Experience Started" hardware prompt
- **Location:** `AssemblyViewModel.speakCurrentStep()`

### Voice Commands
- **Framework:** `SFSpeechRecognizer` (Apple's on-device speech recognition)
- **Commands:** "Next", "Back", "Repeat"
- **Delegate Pattern:** `SpeechRecognizerDelegate` in `AssemblyViewModel`
- **Anti-Loop Logic:** Only start listening AFTER TTS finishes speaking to prevent the app from transcribing its own voice

**Implementation:** `handyHelper/Services/SpeechRecognizerService.swift`

## State Management & Concurrency

### MainActor Requirements

**CRITICAL:** All UI updates and SDK delegate callbacks MUST be dispatched to `@MainActor`:

```swift
// Vision results come from background threads
Task { @MainActor in
    self.delegate?.partDetectionService(self, didUpdateDetections: allDetections)
}
```

### ViewModel Pattern

- All ViewModels are `@MainActor` classes conforming to `ObservableObject`
- Use `@Published` properties for SwiftUI reactivity
- Complex async operations use `Task { }` blocks
- Store `Task` references to cancel on `deinit`

**Key ViewModels:**
- `WearablesViewModel` - Global glasses connection state, registration
- `AssemblyViewModel` - Session-specific assembly logic, stream management
- `ManualDetailViewModel` - Manual preview and step extraction

## Project Structure

```
handyHelper/
├── CameraAccessApp.swift          # App entry point, SDK configuration
├── ViewModels/                    # MVVM pattern - business logic
│   ├── WearablesViewModel.swift   # Global device management
│   ├── AssemblyViewModel.swift    # Assembly session orchestration
│   └── ManualDetailViewModel.swift
├── Views/                         # SwiftUI views
│   ├── MainAppView.swift          # Root navigation
│   ├── Manuals/
│   │   ├── ManualHubView.swift    # Manual library & search
│   │   └── AssemblySessionView.swift # Core AR guidance UI
│   └── Components/                # Reusable UI components
├── Services/
│   ├── Manuals/                   # Pipeline A (document processing)
│   │   ├── InstructionExtractionService.swift
│   │   ├── ManualManager.swift
│   │   └── LocalDocumentTransformer.swift (planned)
│   ├── Vision/
│   │   └── PartDetectionService.swift # Pipeline B (real-time ML)
│   └── SpeechRecognizerService.swift
└── Models/
    └── ManualModels.swift         # Core data structures

conductor/tracks/                  # Project planning & execution tracks
├── tracks.md                      # Active tracks index
└── manual_ingestion_20260316/     # Current work: GPT-4o manual processing
```

## Adding ML Models

### YOLOv8 CoreML Integration

1. Train YOLOv8 model (or use pre-trained)
2. Export as CoreML: `model.export(format="coreml")`
3. Add `.mlpackage` or compiled `.mlmodelc` to Xcode project
4. `PartDetectionService` auto-detects model named "yolov8n" in bundle
5. If missing, gracefully falls back to Vision OCR

**Current Status:** Using COCO-trained YOLOv8 as proof-of-concept. Custom IKEA parts model pending (see `PRODUCT_SPEC.md:42` for dataset strategy).

## Key Design Decisions

### Why Offline Manual Processing?
Standard OCR fails on IKEA's visual diagrams (arrows, spatial relationships). GPT-4o Vision understands visual context but is expensive/slow. Solution: Process manuals offline once, serve perfect JSON instantly.

### Why Audio-First?
Users' hands are busy during assembly. Voice commands + audio feedback enables true hands-free operation. Meta glasses provide open-ear audio without blocking ambient sound.

### Why Limit to 10 Products?
Vertical slice strategy guarantees 100% accuracy. Better to excel at 10 manuals than provide mediocre guidance for 1000+. Validates core loop before scaling.

## Important Documentation Files

- `PRODUCT_SPEC.md` - Business context, technical pipeline, MVP scope
- `ARCHITECTURE_DECISIONS.md` - ADR log, SDK patterns, historical decisions
- `DOCUMENTATION.md` - Detailed technical docs, sequence diagrams, security notes

## Meta SDK Dependencies

The project uses Meta's Wearables DAT SDK via Swift Package Manager:

```
MetaWearablesDAT: https://github.com/facebook/meta-wearables-dat-ios @ 0.4.0
```

**Frameworks:**
- `MWDATCore` - Device identity, registration, permissions
- `MWDATCamera` - Video streaming, photo capture
- `MWDATMockDevice` - DEBUG-only simulated glasses

## Debug Mode Features

When running DEBUG builds:

- Mock device simulator available (shake device to access debug menu)
- Extensive logging via `NSLog`
- Test assembly sessions without physical glasses
- Mock steps use common objects (cell phone, cup, keyboard) for easy testing

## Next Implementation Priorities

Based on current git status and conductor tracks:

1. **Manual Ingestion Pipeline** (`conductor/tracks/manual_ingestion_20260316/`)
   - Implement GPT-4o Vision prompt for manual extraction
   - Set up Firebase JSON hosting
   - Build human review workflow

2. **State Machine Robustness** (`AssemblyViewModel`)
   - Handle non-linear step navigation
   - Add session persistence (pause/resume)
   - Implement error recovery

3. **Custom YOLOv8 Training**
   - Download IKEA parts dataset from Roboflow
   - Train on cloud GPU (Colab Pro)
   - Export and integrate `.mlpackage`

## Common Gotchas

1. **Black Screen on Stream Start:** You likely called `streamSession.start()` before the device was ready. Use `activeDeviceStream()` instead.

2. **App Transcribing Its Own Voice:** Speech recognizer starts too early. Ensure TTS finishes before calling `speechService.startListening()`.

3. **Vision Detections Not Appearing:** Check that delegate is set AND you're dispatching to `@MainActor`.

4. **Build Fails with YOLO Model Missing:** Normal. `PartDetectionService` gracefully falls back to OCR if model not found.

5. **Stream Session Crashes:** Never create multiple `StreamSession` instances. Create once in ViewModel.init, reuse throughout lifecycle.

## Using Gemini CLI for Large Codebase Analysis

When analyzing large codebases or multiple files that might exceed context limits, use the Gemini CLI with its massive context window.

### File and Directory Inclusion Syntax

Use the `@` syntax to include files and directories in Gemini prompts. Paths are relative to where you run the command:

```bash
# Single file analysis
gemini -p "@handyHelper/ViewModels/AssemblyViewModel.swift Explain this file's purpose and structure"

# Multiple files
gemini -p "@PRODUCT_SPEC.md @ARCHITECTURE_DECISIONS.md Summarize the architectural decisions"

# Entire directory
gemini -p "@handyHelper/Services/ Analyze the service layer architecture"

# Multiple directories
gemini -p "@handyHelper/ViewModels/ @handyHelper/Services/ Analyze the MVVM implementation"

# Current directory and subdirectories
gemini -p "@./ Give me an overview of this entire project"

# Or use --all_files flag
gemini --all_files -p "Analyze the project structure and dependencies"
```

### Implementation Verification Examples

```bash
# Check if a feature is implemented
gemini -p "@handyHelper/ Has voice command handling been implemented? Show me the relevant files and functions"

# Verify SDK integration
gemini -p "@handyHelper/ViewModels/ @handyHelper/Services/ Is Meta Wearables SDK properly integrated? List all SDK-related patterns"

# Check for specific patterns
gemini -p "@handyHelper/ Are there any ViewModels that handle camera streaming? List them with file paths"

# Verify error handling
gemini -p "@handyHelper/Services/ Is proper error handling implemented for all services? Show examples of try-catch blocks"

# Check for state management patterns
gemini -p "@handyHelper/ViewModels/ How is MainActor used across ViewModels? Show the implementation details"

# Verify ML integration
gemini -p "@handyHelper/Services/Vision/ Is YOLOv8 CoreML integration complete? List all ML-related functions and their usage"

# Check for specific security measures
gemini -p "@handyHelper/ Are there proper permission checks before accessing camera? Show how permissions are handled"

# Verify audio pipeline
gemini -p "@handyHelper/Services/ @handyHelper/ViewModels/ How is TTS and speech recognition implemented? List all audio-related code"
```

### When to Use Gemini CLI

Use `gemini -p` when:
- Analyzing entire codebases or large directories
- Comparing multiple large files
- Need to understand project-wide patterns or architecture
- Current context window is insufficient for the task
- Working with files totaling more than 100KB
- Verifying if specific features, patterns, or security measures are implemented
- Checking for the presence of certain coding patterns across the entire codebase

**Important Notes:**
- Paths in `@` syntax are relative to your current working directory when invoking gemini
- The CLI will include file contents directly in the context
- No need for `--yolo` flag for read-only analysis
- Gemini's context window can handle entire codebases that would overflow Claude's context
- When checking implementations, be specific about what you're looking for to get accurate results
