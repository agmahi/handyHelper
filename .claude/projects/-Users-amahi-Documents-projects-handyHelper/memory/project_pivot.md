---
name: Project Pivot to CardMax
description: Project pivoted from IKEA assembly helper (HandyHelper) to CardMax credit card optimizer on 2026-03-29
type: project
---

On 2026-03-29, the project was reorganized from an IKEA furniture assembly helper to CardMax (credit card rewards maximizer).

**Why:** User decided to pivot the product direction while reusing the same Meta Ray-Ban Smart Glasses infrastructure.

**How to apply:**
- All assembly/IKEA code is archived in `archive/assembly_helper/`
- Root docs (PRODUCT_SPEC.md, ARCHITECTURE.md, MILESTONES.md) now refer to CardMax
- CLAUDE.md was rewritten for CardMax context
- Shared infrastructure (Meta SDK, speech recognition, debug tools) remains in the main source tree
- CardMax-specific code lives in `handyHelper/CardMax/`
