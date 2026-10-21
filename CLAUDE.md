# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

@AGENTS.md

## Claude Code specifics

- Sandman is a macOS app, so the iOS Simulator tools don't apply. `/run-sandman` builds and launches it, creates test assertions and screenshots its window. `/install` (user-only) replaces `/Applications/Sandman.app` with a Release build.
- The swift-lsp plugin is enabled in `.claude/settings.json`. It needs a `buildServer.json` (gitignored, machine-specific): `brew install xcode-build-server`, then `xcode-build-server config -project Sandman.xcodeproj -scheme Sandman`. It reads Xcode's own DerivedData, not `build/DerivedData`, so if diagnostics look stale, build once in Xcode (⌘B).
- Keep project guidance in `AGENTS.md` so other agents get it too. Only Claude Code–specific notes (hooks, skills, tools) belong here.
