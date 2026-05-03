# ADR-0001: Screenshot as initial Chat Context ingestion mechanism

## Status
Accepted

## Context
The product needs to read the user's live chat conversation to recommend Reaction Media. Multiple ingestion mechanisms are possible: screenshot (vision AI reads an image), manual paste, clipboard polling, or live screen/accessibility API capture.

## Decision
Start with screenshot. The user takes a screenshot of their chat; the app passes it to a vision model to extract conversational context.

## Reasons
- Lowest implementation complexity across all target platforms
- Works with every chat app without per-app integration
- Vision models handle emoji, reactions, and usernames naturally
- No special OS permissions required beyond photo library access

## Trade-offs
- Requires a manual user action (friction at the critical comedic window)
- Screenshot quality and cropping affect accuracy

## Future direction
The Chat Context ingestion layer must remain swappable. Planned upgrade path: live screen capture or accessibility API polling for zero-friction, always-on context — but only after the core recommendation loop is validated.
