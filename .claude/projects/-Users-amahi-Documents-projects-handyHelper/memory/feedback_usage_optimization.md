---
name: Usage Optimization Preferences
description: User is on Pro plan with weekly usage limits; wants to optimize development workflow to reduce token consumption
type: feedback
---

User is concerned about burning through weekly Claude Pro usage limits during iterative iOS development.

**Why:** Pro plan has weekly caps. Iterative build-fix-rebuild cycles with full file reads consume tokens fast.

**How to apply:**
- Prefer targeted edits over full file rewrites
- Delegate doc updates and simple tasks to Gemini CLI when available
- Use subagents sparingly — they consume tokens too
- Avoid re-reading files already in context
- Keep responses concise; skip verbose explanations
- Batch related changes into single edits
- Use xcodebuild error grep to only show relevant lines, not full output
