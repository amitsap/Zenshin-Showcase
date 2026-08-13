# Source provenance

This snapshot was adapted from the private Zenshin repository at commit `4f782ed9ef1519acba74d9fe2c855807f48e2d61`.

Original production paths:

- `Zenshin/Services/ReadinessEngine.swift`
- `Zenshin/Services/LoadEngine.swift`
- `Zenshin/Models/RecoveryModels.swift`
- `Zenshin/Models/LoadModels.swift`
- `ZenshinTests/RecoveryEngineTests.swift`

Adaptations for this public package:

- Replaced SwiftData `@Model` reference types with Foundation-only value types.
- Removed SwiftUI display properties and all HealthKit, persistence, and Apple Watch integration.
- Removed production strength/cardio adapter methods because their app models are intentionally private; aggregate load behavior is unchanged.
- Reduced `ReadinessSnapshot` to the fields exercised by the calculation boundary.
- Ported representative production tests from Swift Testing to XCTest for a dependency-free package.

The readiness math, calibration thresholds, trailing-window behavior, weight redistribution, no-look-ahead rule, load windows, ratio guard, and zone boundaries are unchanged.
