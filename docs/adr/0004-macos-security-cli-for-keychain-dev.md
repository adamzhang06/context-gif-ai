# ADR-0004: macOS security CLI for Keychain access in dev builds

## Status
Accepted

## Context
`ApiKeyStore` needs to write the Gemini API key to the device's secure keystore. The natural Flutter package for this is `flutter_secure_storage`, but its macOS backend (`flutter_secure_storage_macos` 3.x) uses the Data Protection Keychain (`kSecUseDataProtectionKeychain = true`), which requires the `keychain-access-groups` entitlement regardless of sandbox status. That entitlement requires the app to be signed with a real Apple Developer team identity — a setup step that blocks local dev with no paid account.

Two alternatives were evaluated:

1. **Configure Xcode code signing** — set a development team, add `keychain-access-groups`, use `flutter_secure_storage` as intended. Correct long-term path; requires every contributor to configure Xcode signing before running the app.

2. **Use the macOS `security` CLI** — shell out to `/usr/bin/security add-generic-password` etc. Writes to the real login Keychain. Works without any entitlements in an unsandboxed debug build.

## Decision
Use the `security` CLI for macOS dev builds. Debug builds disable the App Sandbox (`com.apple.security.app-sandbox = false` in `DebugProfile.entitlements`) so that `Process.run` is not blocked. Release entitlements retain sandboxing.

`ApiKeyStore` is a single concrete class; no platform abstraction layer yet.

## Reasons
- Unblocks development immediately with zero Xcode signing setup
- Writes to the real macOS Keychain — the privacy guarantee holds for dev builds
- `ApiKeyStore` is small; the refactor to a platform-abstracted interface is cheap when needed

## Trade-offs
- **Release builds are broken for Keychain storage.** `Release.entitlements` has `app-sandbox = true` but no code signing; `Process.run` will be blocked by the sandbox. App Store submission requires this to be resolved.
- **macOS-only.** The `security` CLI does not exist on Android, iOS, or Windows. `ApiKeyStore` must be refactored into a platform-abstracted interface before any non-macOS platform is added.
- Shelling out is surprising — a reader will not expect Keychain access via a subprocess.

## Future direction
**Before the first Android build ships to external users**, resolve macOS release storage — even if Android is the user-facing track, a broken macOS release build is a debt that compounds:
1. Configure Xcode automatic signing with a development team.
2. Re-enable sandboxing in `DebugProfile.entitlements` and add `keychain-access-groups`.
3. Replace `ApiKeyStore` with an abstract interface and per-platform implementations (`MacOsApiKeyStore` via `flutter_secure_storage`, `AndroidApiKeyStore` via the same, etc.).
