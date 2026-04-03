# CardMax: Development Milestones & Execution Plan
**Version:** 2.0.0
**Start Date:** March 2026
**Last Updated:** April 2026
**Target MVP:** 7 Days
**Target Launch:** 14 Days

---

## 📋 Milestone Overview

| Milestone | Duration | Status | Success Criteria |
|-----------|----------|--------|------------------|
| **M1: Voice Activation** | Day 1 | ✅ Complete (Siri) | Siri command activates recommendation |
| **M2: Visual Detection** | Day 2-3 | ⏳ Pending | Detect top 20 merchants via glasses POV |
| **M3: Recommendation** | Day 4 | ✅ Complete | Accurate card selection with rotating categories |
| **M4: Audio Response** | Day 5 | ✅ Complete | Premium TTS via glasses speakers |
| **M5: Card Management** | Day 6 | ✅ Complete | Full card wallet UI with household support |
| **M6: Real-World Testing** | Day 7 | ⏳ Pending | 90% accuracy in field |
| **M7: Beta Launch** | Day 8-14 | ⏳ Pending | 50 active beta users |

---

## 🎯 Milestone 1: Voice Activation (Day 1) — ✅ COMPLETE

### Objective
Implement voice activation that triggers the recommendation flow

### What Was Built
- **Siri App Intents** via `AppShortcutsProvider` — "Which card at [merchant]?", "Which card for [category]?"
- App Intents call `CardMaxViewModel.recommendForMerchantName(_:)` and `recommendForCategory(_:)`
- Audio feedback delivered through Meta glasses via `AudioResponseService`

### Note on Previous Approach
The original `VoiceTriggerService` used continuous `SFSpeechRecognizer` listening but was removed due to:
- OOM crashes from persistent audio engine taps
- Recursive `restartListening()` loops spawning unbounded Tasks
- Duplicate `AVAudioEngine` instances in feedback service
- `removeTap(onBus:)` crashes when no tap installed

The file still exists but is not used by CardMax. Siri handles all voice activation with zero battery impact.

### Deliverable
✅ User invokes Siri → "Which card at Starbucks?" → Audio: "Use your Amex Gold, 4% back on dining."

---

## 🎯 Milestone 2: Visual Detection (Day 2-3)

### Objective
Detect merchant from POV camera (logos, text, URLs)

### Day 2: Foundation
- [x] Implement frame capture from glasses
- [x] Set up Vision framework for OCR
- [x] Create merchant database (top 20)
- [x] Build text-to-merchant matching

### Day 3: Logo Recognition
- [ ] Train/import logo detection model
- [ ] Add logo-to-merchant mapping
- [ ] Implement confidence scoring
- [ ] Handle multiple detection results

### Known Issues (from 2026-03-30 testing)
- OCR works for large clear text but fails on browser URL bars at current camera resolution
- Logo-only merchants (Starbucks siren, etc.) require a trained ML model -- OCR cannot detect logos
- Current config: .high resolution with frameRate 10; may need multi-frame best-quality selection

### Success Criteria
✅ Detect Amazon.com from webpage (95% accuracy)
✅ Detect Starbucks from logo (90% accuracy)
✅ Detect Walmart from store sign (85% accuracy)
✅ Response time <1 second

### Test Merchants (Priority Order)
1. Amazon
2. Walmart
3. Target
4. Starbucks
5. McDonald's
6. Whole Foods
7. Shell
8. Costco
9. Home Depot
10. Best Buy

### Deliverable
Demo showing detection of 5 online and 5 physical merchants

---

## 🎯 Milestone 3: Recommendation Engine (Day 4) — ✅ COMPLETE

### Objective
Calculate optimal card based on merchant and user's portfolio

### What Was Built
- [x] Card model with reward structures, merchant bonuses, and rotating categories
- [x] `RecommendationEngine` with merchant-specific, category, and default rate fallback
- [x] `effectiveCategoryRewards` merges static + active rotating schedules at query time
- [x] Owner-aware recommendations across household cards
- [x] Natural language audio response generation
- [x] 15+ card catalog: Chase (Sapphire Preferred/Reserve, Freedom Flex/Unlimited), Amex (Gold, Platinum, Blue Cash Preferred), Citi (Double Cash, Custom Cash), Capital One (Venture X, SavorOne), Discover it, BofA Customized Cash, Wells Fargo Active Cash

### Rotating Categories
```swift
// Hardcoded quarterly schedules (update annually):
RotatingSchedule.discover2026    // Q1: grocery+drugstore, Q2: gas+transit, Q3: dining+streaming, Q4: online+entertainment
RotatingSchedule.freedomFlex2026 // Q1: grocery+entertainment, Q2: gas+online, Q3: dining+streaming, Q4: grocery+gas
```

### Deliverable
✅ Siri-triggered recommendations with owner prefix and rotating category awareness

---

## 🎯 Milestone 4: Audio Response (Day 5) — ✅ COMPLETE

### Objective
Deliver natural language recommendations through Meta glasses

### What Was Built
- [x] `AudioResponseService` with `AVSpeechSynthesizer`
- [x] Premium voice selection — sorts available en-US voices by `quality.rawValue`, picks highest
- [x] Audio session configured for `.playAndRecord` with `.allowBluetooth` + `.defaultToSpeaker`
- [x] Response templates with owner-aware prefixes
- [x] Rate formatting: whole numbers ≤3 use "X% back", >3 use "Xx points", decimals use "X.X% back"
- [x] Speech delegate callbacks for completion tracking (`isSpeaking` published state)

### Response Format
```
"Use your Amex Gold, 4% back on dining."
"Use Sarah's Blue Cash Preferred, 6% back on groceries."
"Use your Amazon, 5x points at Amazon."
```

### Deliverable
✅ Audio plays through glasses when connected, falls back to phone speaker

---

## 🎯 Milestone 5: Card Management UI (Day 6) — ✅ COMPLETE

### Objective
Allow users to manage their household credit card portfolio

### What Was Built
- [x] **Card Wallet** — vertical card spines that fill available width, expand horizontally on tap to reveal rewards
- [x] **Add Card** — `AddCardView` with searchable 15+ card catalog grouped by issuer, owner name prompt
- [x] **Remove Card** — button on expanded card face, or swipe
- [x] **Multi-Owner** — owner field on cards, owner-aware duplicate prevention
- [x] **Persistence** — `CardStorageService` saves/loads portfolio as JSON, survives app restarts
- [x] **Receipt Capture** — via Meta glasses camera, phone camera, or photo library (`ImagePicker` wrapper)
- [x] **Receipt Management** — thumbnail grid, context menu delete, `ReceiptStorageService` persistence
- [x] **Quick Glance** — top 5 spending categories with best card for each, auto-updates with portfolio changes
- [x] **Physical Card Feel** — `CardMaterialModifier` with layered gradients, edge highlights, dynamic shadows, haptic feedback
- [x] **Design System** — Rams-inspired palette (warm off-whites, muted signals), PO-inspired card colors

### UI Design Details
- Cards use Pocket Operator-inspired muted colors: teal, amber, warm gray, charcoal, brick red, olive, burgundy
- Collapsed spines distribute evenly across available width (dynamic calculation via GeometryReader)
- Expanded cards push neighbors aside with spring animation (response: 0.4, damping: 0.78)
- Horizontal ScrollView allows scrolling when expanded card exceeds screen bounds
- `CardMaterialModifier`: base fill + top-edge highlight gradient + subtle inner border stroke

### Deliverable
✅ Full card management with household support, receipt capture, and physical-feel wallet UI

---

## 🎯 Milestone 6: Real-World Testing (Day 7)

### Objective
Validate MVP in actual shopping scenarios

### Test Locations
**Online (10 tests)**
- Amazon checkout
- Walmart.com
- Target app
- DoorDash order
- Uber ride request

**Physical (10 tests)**
- Grocery store (Whole Foods)
- Gas station (Shell)
- Restaurant (Starbucks)
- Department store (Target)
- Home improvement (Home Depot)

### Metrics to Track
- Detection accuracy (target: 90%)
- Response time (target: <2 seconds)
- Recommendation accuracy (target: 95%)
- Audio clarity (subjective 1-5)
- Battery impact (target: <5% per hour)

### Success Criteria
✅ 18/20 successful detections
✅ All responses under 3 seconds
✅ No crashes or hangs
✅ Battery drain acceptable

### Deliverable
Test report with video evidence and metrics

---

## 🎯 Milestone 7: Beta Launch (Days 8-14)

### Week 2 Plan

#### Day 8-9: Polish & Bug Fixes
- Fix issues from field testing
- Improve detection accuracy
- Optimize performance
- Add error handling

#### Day 10-11: TestFlight Preparation
- Create app store assets
- Write app description
- Set up TestFlight build
- Create beta tester guide

#### Day 12-13: Beta User Recruitment
- Post in r/CreditCards
- Reach out to friends/family
- Create demo video
- Set up feedback form

#### Day 14: Launch & Monitor
- Send TestFlight invites
- Monitor crash reports
- Gather initial feedback
- Plan iteration cycle

### Success Metrics
- 50+ beta testers recruited
- 30+ active users (60% activation)
- 10+ feedback responses
- <5% crash rate
- 4.0+ average rating

---

## 📊 Risk Management

### Critical Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Voice recognition fails | High | Test multiple accents, add button trigger |
| Logo detection inaccurate | High | Focus on text/OCR as primary |
| Meta SDK issues | High | Build iPhone-only fallback mode |
| API rate limits | Medium | Implement aggressive caching |
| User forgets glasses | Medium | iPhone notification option |

---

## 🚀 Post-MVP Roadmap

### Next Up
- Visual detection — YOLOv8 logo recognition + OCR from glasses POV (M2)
- Location detection — GPS + Google Places API fallback
- Savings tracking / analytics dashboard
- Real-world field testing with physical glasses (M6)

### Future
- Purchase amount detection from receipts
- Multi-card comparison view
- CloudKit sync across devices
- Referral system and social sharing

---

## 📈 Success Tracking

### Daily Standup Questions
1. What was completed yesterday?
2. What's the goal for today?
3. Any blockers?
4. User feedback received?

### Key Performance Indicators
- **Technical:** Detection accuracy, response time
- **User:** Daily active users, queries per user
- **Business:** Cards added, recommendations followed
- **Quality:** Crash rate, app store rating

---

## 🎬 Demo Script (End of Day 7)

```
1. "Hi, I'm shopping at Whole Foods" [Shows store]
2. "Which card?" [Activates app]
3. "Use Amex Gold, 4% on groceries" [Audio response]
4. "Now I'm buying something on Amazon" [Shows laptop]
5. "Which card?" [Activates again]
6. "Amazon Prime card, 5% back" [Audio response]
7. "The app saved me $50 this month!" [Shows savings screen]
```

---

## ✅ Definition of Done

Each milestone is complete when:
1. All tasks checked off
2. Success criteria met
3. Code committed to Git
4. Demo video recorded
5. Next milestone plan reviewed

---

*Last Updated: April 2026*
*M1, M3, M4, M5 complete. M2 (visual detection) and M6 (field testing) are next.*