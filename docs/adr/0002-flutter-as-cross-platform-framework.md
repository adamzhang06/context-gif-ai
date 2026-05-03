# ADR-0002: Flutter as the cross-platform framework

## Status
Accepted

## Context
The app must ship on macOS (dev/testing), Android (first external user), Windows, and iOS — from a single codebase. It needs native access to the photo library (for screenshot ingestion) and the local filesystem (for the Reaction Library).

## Decision
Use Flutter (Dart) as the sole application framework.

## Reasons
- Single codebase ships to Android, iOS, macOS, and Windows with first-class support
- Flutter's platform channels give native photo library and filesystem access on all four targets
- No secondary runtime needed (vs. React Native + Electron or Tauri + React Native combos)
- Strong ecosystem for camera, image picker, and file system plugins

## Trade-offs
- Dart is a less common language; smaller hiring pool and fewer AI-generated examples than JS/Python
- Flutter desktop (macOS, Windows) is mature but has a smaller plugin ecosystem than mobile
- Larger binary size than a native app

## Alternatives considered
- React Native + Electron — two runtimes, heavier glue code
- Tauri + React Native — smaller binaries but same two-runtime problem
- PWA — filesystem and photo library access too sandboxed on mobile
