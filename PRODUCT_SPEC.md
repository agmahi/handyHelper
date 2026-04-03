# CardMax: Product Specification & MVP Plan
**Project:** Credit Card Rewards Maximizer with Meta Ray-Ban Integration
**Version:** 2.0.0
**Date:** April 2026
**Status:** MVP Development — Core Loop Complete

---

## 1. Executive Summary

### Product Vision
CardMax is an iOS application that leverages Meta Ray-Ban Smart Glasses to provide **on-demand**, hands-free credit card recommendations through voice commands, helping users maximize rewards for both in-store and online purchases.

### The Problem
- Users leave **$300-600 annually** in unclaimed rewards by using suboptimal cards
- Average American carries **4+ credit cards** with different reward structures
- Impossible to remember which card offers best rewards at each merchant
- Decision paralysis at checkout leads to using default card
- **Online shopping** represents 20% of purchases but lacks location-based solutions

### The Solution
An intelligent, Siri-activated assistant that:
1. **Activates** via Siri — "Which card at [merchant]?" (zero battery drain, no in-app listening)
2. **Recommends** optimal card from the household portfolio via audio through Meta glasses
3. **Supports** rotating quarterly categories (Discover it, Freedom Flex, etc.)
4. **Captures** receipts via glasses camera, phone camera, or photo library
5. **Detects** context through visual recognition (planned) OR location (planned)

---

## 2. Core Innovation: Siri-Activated Rewards with Household Support

### The Trigger Mechanism
Instead of continuous monitoring (battery drain + privacy concerns), CardMax uses **Siri App Intents** for activation:

```
User (via Siri): "Which card at Starbucks?"
CardMax: "Use your Amex Gold, 4% back on dining."

User (via Siri): "Which card for groceries?"
CardMax: "Use Sarah's Blue Cash Preferred, 6% back on groceries."
```

The previous in-app `SFSpeechRecognizer` approach was abandoned due to OOM crashes from continuous audio monitoring. Siri handles all voice recognition with zero battery impact.

### Dual Detection Approach

#### Visual Detection (Primary)
- **Works for:** Online shopping, physical stores, menus
- **Method:** POV image capture → Logo/text recognition
- **Accuracy:** 95% for major merchants
- **Response time:** <1 second

#### Location Detection (Fallback)
- **Works for:** Physical stores without clear signage
- **Method:** GPS + WiFi → Google Places API
- **Accuracy:** 90% for mapped merchants
- **Response time:** 1-2 seconds

```mermaid
flowchart TD
    A[User: "Which card?"] --> B[Capture POV Frame]
    B --> C{Visual Detection}
    C -->|Logo Found| D[Identify Merchant]
    C -->|Text Found| E[OCR Processing]
    C -->|Nothing Found| F[Check GPS Location]

    E --> D
    F --> G[Places API]
    G --> D

    D --> H[Match to Card Rewards]
    H --> I[Audio: "Use X card for Y% back"]

    F -->|No Location| J[Audio: "What type of purchase?"]
    J --> K[User: "Dining/Gas/Grocery"]
    K --> H
```

---

## 3. User Scenarios (Updated)

### Scenario 1: Amazon Online Shopping
```
1. User browsing Amazon on laptop
2. Sees total: $150
3. Says: "Which card?"
4. Glasses capture screen → detect "amazon.com"
5. Audio: "Amazon Prime card, 5% back, saving $7.50"
```

### Scenario 2: Starbucks Mobile Order
```
1. User in Starbucks app on phone
2. Says: "Which card?"
3. Glasses see Starbucks logo on phone screen
4. Audio: "Chase Sapphire for 3x points on dining"
```

### Scenario 3: Gas Station
```
1. User at pump, no clear branding visible
2. Says: "Which card?"
3. App uses GPS → detects "Shell Station"
4. Audio: "Costco Visa, 4% on gas"
```

### Scenario 4: Local Restaurant
```
1. User looking at menu
2. Says: "Which card?"
3. Glasses OCR menu header → "Tony's Italian"
4. Audio: "Amex Gold, 4x points on dining"
```

### Scenario 5: Unknown Merchant
```
1. User at farmer's market
2. Says: "Which card?"
3. No detection possible
4. Audio: "What category? Say dining, grocery, or other"
5. User: "Grocery"
6. Audio: "Amex Gold, 4% on groceries"
```

---

## 4. Technical Architecture (Revised)

### System Flow

```mermaid
graph TD
    subgraph "Meta Ray-Ban Glasses"
        A[Voice Command: "Which card?"] --> B[POV Camera]
        C[Audio Response]
    end

    subgraph "CardMax iOS App"
        D[Voice Recognition] --> E[Context Analyzer]
        E --> F[Visual Processor]
        E --> G[Location Manager]

        F --> H[Logo Detection]
        F --> I[OCR Engine]
        G --> J[GPS/WiFi]

        H --> K[Merchant Identifier]
        I --> K
        J --> K

        K --> L[Recommendation Engine]
        M[(Card Database)] --> L
        N[(Merchant Database)] --> L

        L --> O[Natural Language Generator]
        O --> P[Audio Controller]
    end

    subgraph "External Services"
        Q[Google Places API] --> J
        R[Vision API] --> H
    end

    A --> D
    B --> F
    P --> C
```

### Key Components

#### Voice Trigger System
```swift
class VoiceTriggerManager {
    private let phrases = [
        "which card",
        "what card",
        "best card",
        "card recommendation"
    ]

    func startListening() {
        // Continuous listening for trigger phrase only
        // Low battery impact
    }

    func onTriggerDetected() {
        // Full system activation
        // Context detection
        // Recommendation generation
    }
}
```

#### Visual Merchant Detector
```swift
class VisualMerchantDetector {
    func detectMerchant(from frame: VideoFrame) async -> Merchant? {
        // Parallel detection strategies
        async let logoResult = detectLogo(frame)
        async let textResult = detectText(frame)
        async let domainResult = detectURL(frame)

        // Return first successful detection
        if let logo = await logoResult {
            return merchantFromLogo(logo)
        }
        if let text = await textResult {
            return merchantFromText(text)
        }
        if let url = await domainResult {
            return merchantFromDomain(url)
        }

        return nil
    }
}
```

---

## 5. MVP Feature Scope (Updated April 2026)

### Core Features — Implemented
✅ **Siri Activation**
- "Which card at [merchant]?" via App Intents
- "Which card for [category]?" via App Intents
- Zero battery impact — no in-app listening

✅ **Smart Recommendations**
- Merchant-specific bonuses (e.g., Amazon 5% on Amazon Prime card)
- Category-based rewards with owner-aware household optimization
- Rotating quarterly categories (Discover it, Freedom Flex schedules)
- Natural language audio response through glasses via premium TTS

✅ **Card Management**
- Add cards from a 15+ card catalog (grouped by issuer)
- Multi-owner support (track spouse/family cards with owner field)
- Persistent storage via JSON (survives app restarts)
- Remove cards with swipe or in-card button

✅ **Receipt Capture**
- Capture via Meta glasses camera
- Capture via phone camera
- Import from photo library
- Persistent storage with thumbnails

✅ **UI / Card Wallet**
- Vertical card spines that fill available width, expand horizontally on tap
- Pocket Operator-inspired muted color palette
- Physical card material treatment (gradient highlights, edge shadows)
- Quick Glance — top 5 spending categories with best card for each
- Rams-inspired minimal design system

### Planned (Not Yet Implemented)
- ⏳ Visual detection — logo recognition and OCR from glasses POV
- ⏳ Location detection — GPS + Google Places API fallback
- ⏳ Purchase amount detection
- ⏳ Savings tracking / analytics

### Explicitly Out of Scope
- ❌ Automatic/continuous monitoring
- ❌ Card application flow
- ❌ Cloud sync

---

## 6. Development Milestones (Revised)

### Phase 1: Voice Trigger & Core (Days 1-2)
**Goal:** Voice activation and basic detection

#### Day 1: Voice Command System
- [ ] Implement "Which card?" voice trigger
- [ ] Set up Meta SDK audio input
- [ ] Create activation feedback (beep/vibration)
- [ ] Build state machine (listening → processing → responding)
- **Deliverable:** App responds to voice command

#### Day 2: Dual Detection Foundation
- [ ] Implement POV frame capture
- [ ] Set up basic OCR for text extraction
- [ ] Configure CoreLocation for GPS
- [ ] Create merchant matching logic
- **Deliverable:** Can detect "Amazon" from screen or "Starbucks" from location

### Phase 2: Intelligence Layer (Days 3-4)
**Goal:** Accurate merchant detection and recommendations

#### Day 3: Visual Detection
- [ ] Add logo recognition for top 20 merchants
- [ ] Implement domain/URL detection
- [ ] Build confidence scoring
- [ ] Create merchant database
- **Deliverable:** 90% accuracy on major online merchants

#### Day 4: Recommendation Engine
- [ ] Build card-reward matching algorithm
- [ ] Add category fallback system
- [ ] Implement natural language responses
- [ ] Create savings calculator
- **Deliverable:** Accurate recommendations with explanations

### Phase 3: Polish & Testing (Days 5-7)
**Goal:** Real-world ready MVP

#### Day 5: Edge Cases & Fallbacks
- [ ] Handle unknown merchants
- [ ] Add category override commands
- [ ] Implement timeout handling
- [ ] Build error recovery
- **Deliverable:** Graceful handling of all scenarios

#### Day 6: Card Management UI
- [ ] Create card input screen
- [ ] Add popular card presets
- [ ] Build reward editor
- [ ] Implement onboarding
- **Deliverable:** Users can configure their cards

#### Day 7: Real-World Testing
- [ ] Test 20 online merchants
- [ ] Test 20 physical locations
- [ ] Measure accuracy and speed
- [ ] Fix critical bugs
- **Deliverable:** 90% success rate in real usage

---

## 7. Success Metrics (Updated)

### Technical KPIs
- **Trigger Recognition:** 95% accuracy for "Which card?" phrase
- **Merchant Detection:** 90% for top 100 merchants (online + offline)
- **Response Time:** <2 seconds from trigger to recommendation
- **Battery Impact:** <5% daily with normal usage (10-15 queries)

### User KPIs
- **Activation Rate:** 10+ queries per user per week
- **Follow Rate:** 75% use recommended card
- **Coverage:** Successfully handles 85% of purchase scenarios
- **Savings:** $25+ per month per active user

---

## 8. Privacy & Security Considerations

### Data Handling
- **Visual frames:** Processed locally, immediately discarded
- **Location data:** Only accessed on-demand, not stored
- **Card details:** Stored locally in Keychain, never transmitted
- **Purchase history:** Optional, local-only analytics

### User Controls
- Voice activation requires explicit opt-in
- Visual processing disclosure on first use
- Option to disable location access
- Clear data deletion option

---

## 9. Competitive Advantages

| Feature | CardMax | MaxRewards App | Wallaby | CardPointers |
|---------|---------|---------------|---------|--------------|
| Hands-free | ✅ Voice | ❌ Manual | ❌ Manual | ❌ Manual |
| Online shopping | ✅ Visual | ❌ No | ⚠️ Limited | ✅ Browser |
| Real-time | ✅ Instant | ❌ Pre-plan | ❌ Pre-plan | ⚠️ Slow |
| Meta Glasses | ✅ Native | ❌ No | ❌ No | ❌ No |
| Battery efficient | ✅ On-demand | N/A | N/A | N/A |

---

## 10. Go-to-Market Strategy

### Week 1: Alpha Testing
- 10 users with diverse card portfolios
- Test both online and in-store scenarios
- Daily feedback sessions
- Iterate on voice recognition accuracy

### Week 2: Beta Launch
- 50 users via TestFlight
- Focus on r/CreditCards community
- Track real savings data
- A/B test recommendation algorithms

### Week 3: Content Creation
- Demo video showing online + in-store usage
- Blog post: "How I saved $100 in a month"
- Comparison chart vs manual tracking
- User testimonials

### Week 4: Public Launch
- Product Hunt launch
- Reddit posts (r/CreditCards, r/churning)
- Twitter thread with video demos
- Reach out to credit card influencers

---

## Appendix A: Top Merchants for Logo Detection

### Priority 1 (Day 1)
- Amazon, Walmart, Target, Starbucks, McDonald's

### Priority 2 (Week 1)
- Home Depot, Costco, CVS, Walgreens, Best Buy
- Uber, Lyft, DoorDash, Uber Eats, Instacart

### Priority 3 (Month 1)
- Major airlines (United, American, Delta)
- Hotel chains (Marriott, Hilton, Hyatt)
- Department stores (Macy's, Nordstrom)

---

## Appendix B: Voice Command Grammar

### Primary Commands
- "Which card?" → Full detection flow
- "Which card for [category]?" → Category override
- "Best card?" → Alternative trigger

### Category Overrides
- "Which card for dining?"
- "Which card for gas?"
- "Which card for groceries?"
- "Which card for travel?"

### Future Commands (Post-MVP)
- "How much will I save?"
- "Compare cards"
- "Add this card"
- "Settings"

---

*Last Updated: April 2026*
*Version: 2.0.0 — Siri activation, household cards, rotating categories, receipt capture, card wallet UI*