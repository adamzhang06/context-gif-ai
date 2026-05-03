# ADR-0003: Gemini Flash as AI provider, BYOK model

## Status
Accepted

## Context
The product needs vision (screenshot analysis, pragmatic captioning) and text (embeddings, reranking) AI capabilities. The project is in validation phase — not committed to launch. Cost must stay near zero while the core loop is proven. If the product ships, a monetization model is needed.

## Decision
Use Google Gemini Flash for all AI calls (vision captioning, screenshot analysis, text embeddings via text-embedding-004, LLM reranking). Users provide their own Gemini API key (BYOK). No backend server — the Flutter app calls Gemini directly.

## Reasons
- Gemini Flash has a free tier sufficient for validation-phase testing
- Single provider = single API key, simpler BYOK onboarding
- No backend eliminates infrastructure cost and complexity during validation
- BYOK is standard for early AI tools; defers monetization decisions until product is proven

## Trade-offs
- BYOK adds onboarding friction (user must create a Google AI Studio account and paste a key)
- Gemini Flash may underperform frontier models on humor/cultural reasoning; acceptable trade-off during validation
- Calling AI APIs directly from the client exposes the user's API key in-app (acceptable for BYOK; not acceptable if Adam ever pays for a shared key)

## Revisit when
- The product proves out and targets non-technical users (BYOK friction becomes a blocker)
- Volume justifies negotiating API pricing or switching providers
- A backend becomes necessary for other reasons (sync, analytics, etc.)
