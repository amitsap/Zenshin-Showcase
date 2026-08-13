# Architecture

This package isolates two pure calculation boundaries from Zenshin's production app.

- `Models.swift` defines immutable or value-semantic inputs and outputs.
- `ReadinessEngine` converts trailing personal recovery metrics into a 0–100 score. It requires physiological calibration before the production app adjusts training, redistributes weights when a daily metric is missing, and reconstructs history using only prior observations.
- `LoadEngine` consumes pre-estimated strength/cardio entries. It reports a trailing seven-day total and compares that total only when each of the three preceding weeks has signal.

Production adapters—HealthKit reads, strength/cardio session estimation, SwiftData models, UI interpretation, and watch synchronization—remain private. The extraction boundary makes the algorithms runnable on macOS without HealthKit entitlements or personal data.
