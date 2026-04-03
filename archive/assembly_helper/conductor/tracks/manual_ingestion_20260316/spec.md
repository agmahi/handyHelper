# Specification: Implement and Test Manual Ingestion Flow

## Overview
This track focuses on implementing and verifying the manual ingestion flow, which is the "Brain" of the HandyHelper system. This involves extracting assembly steps from PDF manuals (via GPT-4o Vision offline) and loading them into the app via Firebase or local JSON.

## Key Objectives
-   Implement the `InstructionExtractionService` to handle step-by-step assembly instructions.
-   Integrate with the `ManualManager` for document persistence and state management.
-   Provide unit tests for instruction parsing and validation.

## Technical Details
-   **Service**: `InstructionExtractionService.swift`
-   **Models**: `ManualModels.swift`
-   **Validation**: Ensure 100% accuracy of extracted JSON steps.
