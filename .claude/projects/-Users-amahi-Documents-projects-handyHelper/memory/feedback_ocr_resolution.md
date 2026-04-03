---
name: OCR Resolution Limitation
description: Meta glasses camera at .high resolution still too low for browser URL bar text; plain large text works fine
type: feedback
---

OCR detection works for large clear text (e.g., text editor) but fails on browser URL bars and small web page text even at `.high` resolution from Meta glasses.

**Why:** The glasses camera resolution combined with viewing angle/distance makes small text like browser address bars unreadable by Apple Vision OCR.

**How to apply:** For M2 visual detection, prioritize: (1) a trained logo detection ML model for merchant logos, (2) consider using `.high` resolution + multiple frame capture with best-quality selection, (3) browser URL detection may need a different approach (e.g., screen share API or companion browser extension rather than camera OCR).
