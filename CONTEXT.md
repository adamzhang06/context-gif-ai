# Context

## Glossary

### Reaction Media
A locally-saved image or animation (`.gif`, `.jpg`, `.png`) used as a humorous or expressive response in a chat conversation. The core asset this product recommends. Do not call these "GIFs" (too narrow) or "memes" (implies specific format/origin).

### Reaction Library
The user's local collection of Reaction Media. Stored on-device; the product does not host or fetch media remotely.

### Tech Stack
Flutter (Dart). Single codebase targeting Android, iOS, macOS, and Windows. Chosen for its first-class cross-platform support and native photo library / filesystem access on all target platforms. No backend server — the app calls AI APIs directly from the client using the user's own API key (BYOK).

### AI Provider
Google Gemini Flash. Used for: pragmatic caption generation (vision, index time), screenshot analysis (vision, query time), and LLM reranking (text, query time). Gemini's embedding model (text-embedding-004) handles vector search. Single provider = single API key for BYOK. Chosen for free tier availability during validation; reassess if/when the product scales.

### Platform Rollout
The planned platform sequence: macOS (internal dev/testing) → Android (first external user) → Windows → iOS → full cross-platform. Architecture must be cross-platform from day one even though the first build targets macOS.

### Chat Context
The conversational input used to drive Reaction Media recommendations. Currently captured via screenshot. The ingestion mechanism is intentionally abstracted to allow future modes (e.g. live screen capture, accessibility APIs) without restructuring the recommendation pipeline.

### Recommendation Engine
Two-stage pipeline for matching Chat Context to Reaction Media:

**Stage 1 — Pragmatic captioning (index time):** A vision model generates a "pragmatic caption" for each item in the Reaction Library describing not just visual content but the conversational situations it fits, the tone it signals, and when it lands. This caption is embedded and stored. Known/common reaction media are seeded from licensed sources (Tenor/GIPHY APIs, Reddit, academic datasets like MemeCap) rather than scraped from ToS-restricted platforms.

**Stage 2 — Retrieval + reranking (query time):** The Chat Context screenshot is described and embedded. Top-N candidates are retrieved via vector similarity. An LLM then reranks those N candidates by comedic fit given the specific context.

### Onboarding Flow
Three-step sequence on first run:

1. **API key setup** — step-by-step instructions for creating a Google AI Studio account, generating a Gemini API key, and pasting it into the app. Includes: current free tier limits, estimated cost per indexing run (calculated from folder size before the user commits), and a plain-language explanation of what the key is used for (captioning their media, analyzing screenshots — never stored externally).

2. **Folder selection** — user picks one or more Reaction Library folders via the native folder picker. Before indexing begins, the app shows: total item count across all folders, estimated indexing time, and estimated API cost (or "free" if within free tier limits). Additional folders can be added later in settings.

3. **Background indexing** — indexing runs in the background with a visible progress indicator (e.g. "47 of 200 indexed"). The user can start receiving recommendations as soon as the first batch completes; they do not have to wait for full indexing.

**Design principle:** Maximum transparency at every step — cost, time, and data usage are surfaced proactively, not buried in settings.

### Reaction Library Management
The user designates one or more folders as their Reaction Library during onboarding (and can add/remove folders later in settings). The app indexes all selected folders and watches them for new additions. Implemented via Flutter's `file_picker` package (folder selection) across all platforms — macOS/Windows use the native folder picker, Android uses the Storage Access Framework picker, iOS uses the Files app picker. No native Photos library integration.

**No files are moved or copied.** The app's local index database tracks items across all source folders. AI-generated categories (e.g. "sarcasm", "celebration", "cringe") are stored in the index, not the filesystem — the user's existing folder organization is never modified.

### App Entry Point
- **Mobile (Android/iOS):** Share sheet — user screenshots their chat, taps share, selects the app. Two taps from screenshot to results.
- **Desktop (macOS/Windows):** Global keyboard shortcut opens the app; user provides a screenshot.
Share sheet chosen over auto-detection to avoid broad photo library permissions and invasive background monitoring. Entry point is intentionally kept simple for validation; faster zero-tap UX is a future optimization.

### Recommendation UI
Three results displayed in a grid of thumbnails. Tap to copy the selected Reaction Media to clipboard; user pastes manually into their chat app. Works universally across all chat apps and platforms without special integrations. Number of results and delivery mechanism are intentionally kept as swappable parameters.

### Personalization
The Recommendation Engine adapts to the user via implicit feedback only — no explicit rating UI. When the user taps a result (copying it to clipboard), that (context → choice) pair is recorded as a training signal and used to re-weight that item's ranking for similar future contexts. "Copied" is used as the signal — an approximation of "sent," accepted as good enough for validation phase. Zero additional friction from the user.

### Offline Behavior
When Gemini is unreachable, the app degrades gracefully: LLM reranking is skipped and results are returned from pure embedding similarity search on the local index. A clear, persistent "Offline mode — results may be less accurate" indicator is shown. Never shows a hard error screen for connectivity loss alone.

### Privacy
- **Chat screenshots** — sent to Gemini API for analysis, then immediately discarded. Never persisted anywhere.
- **Reaction Media captions and embeddings** — stored in a local on-device database only. Never uploaded.
- **Gemini API key** — stored in the device's secure keystore (not plain-text app storage). On macOS dev builds, this is implemented via the `security` CLI writing to the login Keychain. Production macOS (sandboxed/App Store) requires Xcode code signing to be configured before this guarantee holds — that is a known deferred item.
- **User disclosure** — a plain-language notice on the API key setup screen informs users that chat screenshots are processed by Google's servers during analysis. Not buried in a privacy policy.
