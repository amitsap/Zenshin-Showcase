import Foundation

/// Deterministic, on-device readiness over personal HRV, resting-heart-rate, and sleep baselines.
public struct ReadinessEngine: Sendable {
    public static let preferredWindowDays = 60
    public static let minimumCalibrationDays = RecoveryBaseline.minimumCalibrationDays

    private let hrvWeight = 0.50
    private let rhrWeight = 0.25
    private let sleepWeight = 0.25
    private let sleepReferenceHours = 7.5
    private let sleepReferenceSpread = 1.5

    public init() {}

    public func updateBaseline(history: [DailyMetrics], before cutoff: Date? = nil) -> RecoveryBaseline {
        let eligible = cutoff.map { cutoff in history.filter { $0.date < cutoff } } ?? history
        let window = Array(eligible.sorted { $0.date < $1.date }.suffix(Self.preferredWindowDays))
        let hrvs = window.compactMap(\.hrv)
        let rhrs = window.compactMap(\.restingHR)
        let sleeps = window.compactMap(\.sleepHours)
        return RecoveryBaseline(
            hrvMean: mean(hrvs), hrvStdDev: stdDev(hrvs), hrvCount: hrvs.count,
            rhrMean: mean(rhrs), rhrStdDev: stdDev(rhrs), rhrCount: rhrs.count,
            sleepMean: mean(sleeps), sleepStdDev: stdDev(sleeps), sleepCount: sleeps.count,
            dayCount: window.filter(\.hasAnySignal).count
        )
    }

    public func historicalSnapshots(history: [DailyMetrics], limit: Int = 30) -> [ReadinessSnapshot] {
        let sorted = history.sorted { $0.date < $1.date }
        let snapshots = sorted.compactMap { metrics -> ReadinessSnapshot? in
            let baseline = updateBaseline(history: sorted, before: metrics.date)
            guard baseline.isCalibrated else { return nil }
            return computeReadiness(today: metrics, baseline: baseline)
        }
        return Array(snapshots.suffix(limit))
    }

    public func computeReadiness(today: DailyMetrics, baseline: RecoveryBaseline) -> ReadinessSnapshot {
        var components: [(subscore: Double, weight: Double)] = []
        var contributors: [String] = []

        if let hrv = today.hrv, baseline.hrvMean > 0, baseline.supportsHRV() {
            let z = (hrv - baseline.hrvMean) / baseline.hrvStdDev
            components.append((clampedSubscore(z), hrvWeight))
            let percent = abs((hrv - baseline.hrvMean) / baseline.hrvMean) * 100
            if z <= -0.5 { contributors.append("HRV \(Int(percent.rounded()))% below your norm") }
            if z >= 0.5 { contributors.append("HRV \(Int(percent.rounded()))% above your norm") }
        }

        if let restingHR = today.restingHR, baseline.rhrMean > 0, baseline.supportsRHR() {
            let z = (baseline.rhrMean - restingHR) / baseline.rhrStdDev
            components.append((clampedSubscore(z), rhrWeight))
            let difference = restingHR - baseline.rhrMean
            if difference >= 2 { contributors.append("Resting HR elevated \(Int(difference.rounded())) bpm") }
            if difference <= -2 { contributors.append("Resting HR \(Int(abs(difference).rounded())) bpm below your norm") }
        }

        if let sleep = today.sleepHours, baseline.supportsSleep() {
            let referenceZ = (sleep - sleepReferenceHours) / sleepReferenceSpread
            let z: Double
            if baseline.sleepMean > 0 {
                let personalSpread = min(2.0, max(0.5, baseline.sleepStdDev))
                z = 0.7 * ((sleep - baseline.sleepMean) / personalSpread) + 0.3 * referenceZ
            } else {
                z = referenceZ
            }
            components.append((clampedSubscore(z), sleepWeight))
            if baseline.sleepMean > 0, abs(sleep - baseline.sleepMean) >= 0.75 {
                contributors.append("Slept \(oneDecimal(sleep))h vs your usual \(oneDecimal(baseline.sleepMean))h")
            } else if sleep < 6.5 {
                contributors.append("Slept \(oneDecimal(sleep))h — a little short")
            }
        }

        let totalWeight = components.reduce(0) { $0 + $1.weight }
        let score = totalWeight > 0
            ? Int((components.reduce(0) { $0 + $1.subscore * $1.weight } / totalWeight).rounded())
            : 50
        if contributors.isEmpty {
            contributors.append(score >= 60 ? "Your recovery markers look steady" : "Recovery markers are a touch off your norm")
        }
        return ReadinessSnapshot(date: today.date, readinessScore: score, zone: .from(score: score), contributors: contributors)
    }

    private func clampedSubscore(_ z: Double) -> Double { min(100, max(0, 65 + z * 15)) }
    private func mean(_ values: [Double]) -> Double { values.isEmpty ? 0 : values.reduce(0, +) / Double(values.count) }
    private func stdDev(_ values: [Double]) -> Double {
        guard values.count >= 2 else { return 0 }
        let average = mean(values)
        return (values.reduce(0) { $0 + ($1 - average) * ($1 - average) } / Double(values.count - 1)).squareRoot()
    }
    private func oneDecimal(_ value: Double) -> String { String(format: "%.1f", value) }
}
