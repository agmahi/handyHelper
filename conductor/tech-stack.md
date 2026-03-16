# Tech Stack: HandyHelper

## Core Components
*   **Language**: Swift 5.x+
*   **Platform**: iOS (iOS 17.0+)
*   **UI Framework**: SwiftUI
*   **ML Engine**: CoreML (Apple Neural Engine optimization for YOLOv8)
*   **Hardware Interface**: Meta MWDAT SDK (Official SDK for Meta Ray-Ban Smart Glasses)

## Services & APIs
*   **Object Detection**: Custom-trained YOLOv8 for furniture parts.
*   **Speech-to-Text**: Apple `SFSpeechRecognizer` (local processing).
*   **Text-to-Speech**: Apple `AVSpeechSynthesizer`.
*   **Data Hosting**: Firebase (Remote hosting for Instruction JSON).
*   **Document Processing**: PDFKit for manual rendering and GPT-4o Vision (Offline extraction).

## Development Workflow
*   **Architecture**: MVVM (Model-View-ViewModel).
*   **Concurrency**: Swift Structured Concurrency (Async/Await).
*   **Local Storage**: SwiftData or local JSON cache for manual persistence.
