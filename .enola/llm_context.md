# Architecture Snapshot

## Repository Map

| Module | Language | Symbols | Exported |
|--------|----------|---------|----------|
| `firmware/canekit_grip` | cpp | 7 | 7 |
| `hardware/mount` | python | 9 | 9 |
| `ios/CaneKit/Alerts` | swift | 68 | 48 |
| `ios/CaneKit/App` | swift | 407 | 262 |
| `ios/CaneKit/Audio` | swift | 142 | 66 |
| `ios/CaneKit/Cloud` | swift | 90 | 59 |
| `ios/CaneKit/Conversation` | swift | 107 | 34 |
| `ios/CaneKit/Depth` | swift | 274 | 154 |
| `ios/CaneKit/Haptics` | swift | 39 | 16 |
| `ios/CaneKit/Navigation` | swift | 210 | 122 |
| `ios/CaneKit/Scene` | swift | 198 | 156 |
| `ios/CaneKit/Speech` | swift | 174 | 86 |
| `ios/CaneKit/Store` | swift | 33 | 24 |
| `ios/CaneKit/Trip` | swift | 141 | 92 |
| `ios/CaneKit/UI` | swift | 480 | 238 |
| `ios/CaneKit/Watch` | swift | 30 | 23 |
| `ios/CaneKitUITests` | swift | 55 | 22 |
| `ios/CaneKitWatch` | swift | 87 | 57 |
| `ios/CaneKitWidget` | swift | 113 | 87 |
| `ios/Logic/.build/out/Intermediates.noindex/CaneKitLogic.build/Debug/CaneKitLogic-t.build/Objects-normal/arm64` | c | 12 | 12 |
| `ios/Logic/.build/out/Intermediates.noindex/CaneKitLogic.build/Debug/CaneKitLogicTests-p.build/DerivedSources` | swift | 95 | 87 |
| `ios/Logic/.build/out/Intermediates.noindex/GeneratedModuleMaps` | c | 12 | 12 |
| `ios/Logic/Sources/CaneKitLogic` | swift | 2004 | 1836 |
| `ios/Logic/Sources/CaneKitLogicTests` | swift | 0 | 0 |
| `ios/Logic/Tests/CaneKitLogicTests` | swift | 1136 | 1043 |
| `ios/Shared/Brand` | swift | 13 | 12 |
| `ios/Shared/Intents` | swift | 6 | 6 |
| `ios/Shared/LiveActivity` | swift | 24 | 23 |
| `ios/drafts` | swift | 180 | 144 |
| `ios/scripts` | python | 92 | 92 |
| `ios/scripts/stress` | python | 17 | 17 |
| `ios/stretch` | swift | 43 | 29 |

## Extraction Quality

- Files parsed: **280** / 2858 seen (0 file(s) + 2 directory tree(s) skipped by ignore globs)
- Parse errors: 0

## Architecture Pattern

_No specific architecture pattern detected._

## Entry Points

- **app**: `ios/CaneKit/App.CaneKitApp` (ios/CaneKit/App/CaneKitApp.swift)
- **app**: `ios/CaneKitWatch.WatchApp` (ios/CaneKitWatch/WatchApp.swift)
- **app**: `ios/drafts.CaneKitApp` (ios/drafts/CaneKitApp.swift)
- **handler**: `ios/Logic/Tests/CaneKitLogicTests.blankWallsTeensAndMisreadsAreHandled` (ios/Logic/Tests/CaneKitLogicTests/SceneVocabularyTests.swift)
- **handler**: `ios/scripts/e2e.reserved_collisions` (ios/scripts/e2e.py)
- **main**: `ios/scripts/cue_audit.main` (ios/scripts/cue_audit.py)
- **main**: `ios/scripts/e2e.main` (ios/scripts/e2e.py)
- **main**: `ios/scripts/streetview_stim.main` (ios/scripts/streetview_stim.py)
- **main**: `ios/scripts/stress/build_routes.main` (ios/scripts/stress/build_routes.py)
- **main**: `ios/scripts/stress/campaign.main` (ios/scripts/stress/campaign.py)

## Dependency Rules

70 internal module dependencies. The modules that reach furthest; traverse() or query_facts(kind="dependency") for the edges themselves.

| Module | Depends on |
|--------|------------|
| `ios/CaneKit` | 15 modules |
| `ios` | 9 modules |
| `ios/CaneKit/App` | 8 modules |
| `ios/CaneKit/UI` | 6 modules |
| `ios/CaneKit/Conversation` | 3 modules |
| `ios/CaneKit/Scene` | 3 modules |
| `ios/CaneKit/Trip` | 3 modules |
| `ios/Logic/Sources` | 3 modules |
| `ios/CaneKit/Audio` | 2 modules |
| `ios/CaneKit/Cloud` | 2 modules |
| `ios/CaneKit/Speech` | 2 modules |
| `ios/CaneKitWidget` | 2 modules |
| `ios/Shared` | 2 modules |
| `firmware/canekit_grip` | 1 modules |
| `ios/CaneKit/Alerts` | 1 modules |
| `ios/CaneKit/Depth` | 1 modules |
| `ios/CaneKit/Haptics` | 1 modules |
| `ios/CaneKit/Navigation` | 1 modules |
| `ios/CaneKit/Store` | 1 modules |
| `ios/CaneKit/Watch` | 1 modules |
| `ios/CaneKitWatch` | 1 modules |
| `ios/Logic/Sources/CaneKitLogicTests` | 1 modules |
| `ios/Logic/Tests/CaneKitLogicTests` | 1 modules |

## Critical Modules

| Module | Fan-In | Fan-Out | Criticality |
|--------|--------|---------|-------------|
| `ios/Logic/Sources/CaneKitLogic` | 88 | 0 | high |
| `ios/CaneKit/UI` | 3 | 20 | high |
| `ios/CaneKit/App` | 5 | 13 | high |
| `ios/CaneKit/Depth` | 6 | 9 | high |
| `ios/CaneKit/Trip` | 7 | 8 | high |
| `ios/CaneKit/Scene` | 7 | 7 | high |
| `ios/CaneKit/Navigation` | 5 | 6 | high |
| `ios/CaneKit/Speech` | 5 | 6 | high |
| `ios/Logic/Tests/CaneKitLogicTests` | 0 | 9 | medium |
| `ios/CaneKit/Alerts` | 3 | 5 | medium |

## Risk Zones

- **Cyclic dependency detected (2 modules)** (confidence: 100%): The following modules form a dependency cycle: ios/CaneKit/Scene -> ios/CaneKit/Speech -> ios/CaneKit/Scene. This can cause initialization issues, make refactoring harder, and indicates tight coupling.

---

*Generated at 2026-10-01T04:04:07Z in 1.560094875s. 7773 facts, 181 insights.*
