# Implementation Plan: Implement and Test Manual Ingestion Flow

## Phase 1: Core Implementation
- [x] Task: Implement Instruction Extraction Logic
    - [x] Define `AssemblyStep` model in `ManualModels.swift`.
    - [x] Implement `InstructionExtractionService` to parse instruction JSON.
- [~] Task: Integrate with ManualManager
    - [ ] Update `ManualManager` to persist and retrieve manuals.
- [ ] Task: Conductor - User Manual Verification 'Phase 1: Core Implementation' (Protocol in workflow.md)

## Phase 2: Testing & Validation
- [ ] Task: Write Unit Tests for Manual Ingestion
    - [ ] Create `ManualIngestionTests.swift`.
    - [ ] Test parsing of sample IKEA manual JSON.
- [ ] Task: Conductor - User Manual Verification 'Phase 2: Testing & Validation' (Protocol in workflow.md)
