# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

Beads UI is a native macOS SwiftUI app — the GUI frontend for the [Beads](https://github.com/baileywickham/beads) (`bd`) CLI issue tracker. It reads issues directly from SQLite via GRDB (read-only) and delegates all write operations to the `bd` CLI binary at `~/.local/bin/bd`.

## Build & Run

All commands run from the `Beads/` subdirectory (where `Package.swift` lives):

```bash
cd Beads
swift build              # debug build
swift build -c release   # release build
swift run                # build and launch the app
swift test               # run tests
```

Release packaging: `./scripts/build.sh <version>` (creates .app, .dmg, .zip)

## Architecture

**State management:** `@MainActor @Observable` classes (`AppState`, `ProjectState`) drive the UI. SwiftUI views observe these directly via the Observation framework.

**Read path:** `DatabaseReader` uses GRDB to query the SQLite database at `.beads/beads.db` directly. Models (`Issue`, `Comment`, `Dependency`) conform to `FetchableRecord`. `DatabaseWatcher` uses `DispatchSource` file system monitoring with 150ms debounce to auto-reload on external changes.

**Write path:** All mutations go through `CLIExecutor`, a Swift `actor` that shells out to the `bd` CLI. Write operations in `ProjectState` use **optimistic updates** — they mutate in-memory state immediately, fire an async CLI call, and roll back on failure.

**View structure:** Three-panel `NavigationSplitView` (sidebar → issue list → detail). Menu commands and keyboard shortcuts use `NotificationCenter` to decouple from views.

## Key Directories

```
Beads/Beads/
├── State/          # AppState, ProjectState (central state containers)
├── Data/           # CLIExecutor (actor), DatabaseReader (GRDB), DatabaseWatcher, GhosttyLauncher
├── Models/         # Issue, IssueStatus, IssuePriority, IssueType, Comment, Dependency, Project
├── Views/          # SwiftUI views organized by panel (Sidebar/, IssueList/, Detail/, CommandPalette/)
└── Commands/       # macOS menu bar commands and Notification.Name constants
```

## Dependencies

- **GRDB.swift** — SQLite read access; models use `FetchableRecord`
- **Sparkle** — macOS auto-update framework; configured in Info.plist

## Runtime Requirements

- `bd` CLI at `~/.local/bin/bd` (required for all write operations)
- Ghostty.app (optional, for launching Claude Code sessions)

## Conventions

- Swift 6.2, swift-tools-version 6.2, macOS 26+ target
- State classes are `@MainActor @Observable final class`
- CLI actor methods all take `dbPath` as a parameter and append `--db <path>`
- Issue IDs are string-based (e.g., `PROJ-123`)
- `ProjectDiscovery` auto-finds projects with `.beads/beads.db` in `~/workspace`
