import Foundation

/// Aggregates already-estimated strength and cardio loads into recent training trends.
public struct LoadEngine: Sendable {
    public init() {}

    public func weeklyLoad(entries: [TrainingLoadEntry], asOf: Date = .now) -> Double {
        totalLoad(entries, days: 7, asOf: asOf)
    }

    public func loadRatio(entries: [TrainingLoadEntry], asOf: Date = .now) -> Double? {
        let calendar = Calendar.current
        let acute = totalLoad(entries, days: 7, asOf: asOf)
        var priorWeeks: [Double] = []
        for week in 1...3 {
            guard let end = calendar.date(byAdding: .day, value: -7 * week, to: asOf),
                  let start = calendar.date(byAdding: .day, value: -7, to: end) else { return nil }
            let load = entries.filter { $0.date > start && $0.date <= end }.reduce(0) { $0 + $1.loadScore }
            guard load > 0.0001 else { return nil }
            priorWeeks.append(load)
        }
        let typical = priorWeeks.reduce(0, +) / Double(priorWeeks.count)
        return typical > 0.0001 ? acute / typical : nil
    }

    public func weeklyBreakdown(entries: [TrainingLoadEntry], asOf: Date = .now) -> (strength: Double, cardio: Double) {
        let cutoff = Calendar.current.date(byAdding: .day, value: -7, to: asOf) ?? asOf
        let recent = entries.filter { $0.date > cutoff && $0.date <= asOf }
        return (
            recent.filter { $0.source == .strength }.reduce(0) { $0 + $1.loadScore },
            recent.filter { $0.source == .cardio }.reduce(0) { $0 + $1.loadScore }
        )
    }

    public func weeklyHistory(entries: [TrainingLoadEntry], weeks: Int = 8, asOf: Date = .now)
        -> [(weekStart: Date, strength: Double, cardio: Double)] {
        guard weeks > 0 else { return [] }
        let calendar = Calendar.current
        return stride(from: weeks - 1, through: 0, by: -1).compactMap { week in
            guard let end = calendar.date(byAdding: .day, value: -7 * week, to: asOf),
                  let start = calendar.date(byAdding: .day, value: -7, to: end) else { return nil }
            let bucket = entries.filter { $0.date > start && $0.date <= end }
            return (
                calendar.startOfDay(for: start),
                bucket.filter { $0.source == .strength }.reduce(0) { $0 + $1.loadScore },
                bucket.filter { $0.source == .cardio }.reduce(0) { $0 + $1.loadScore }
            )
        }
    }

    private func totalLoad(_ entries: [TrainingLoadEntry], days: Int, asOf: Date) -> Double {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: asOf) ?? asOf
        return entries.filter { $0.date > cutoff && $0.date <= asOf }.reduce(0) { $0 + $1.loadScore }
    }
}
