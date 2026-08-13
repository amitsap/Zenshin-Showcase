import Foundation
import XCTest
@testable import ZenshinShowcase

final class ReadinessEngineTests: XCTestCase {
    private let engine = ReadinessEngine()
    private let reference = Date(timeIntervalSince1970: 1_700_000_000)

    private func day(_ offset: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: offset, to: reference)!
    }

    private func steadyBaseline(days: Int = 30) -> RecoveryBaseline {
        engine.updateBaseline(history: (0..<days).map { index in
            let jitter = index.isMultiple(of: 2) ? 1.0 : -1.0
            return DailyMetrics(date: day(-index), hrv: 60 + jitter, restingHR: 55 + jitter * 0.5, sleepHours: 7.5)
        })
    }

    func testCalibrationAndWindowCap() {
        let ten = (0..<10).map { DailyMetrics(date: day(-$0), hrv: 60, restingHR: 55, sleepHours: 7.5) }
        XCTAssertFalse(engine.updateBaseline(history: ten).isCalibrated)
        let fourteen = (0..<14).map { DailyMetrics(date: day(-$0), hrv: 60, restingHR: 55, sleepHours: 7.5) }
        XCTAssertTrue(engine.updateBaseline(history: fourteen).isCalibrated)
        let long = (0..<120).map { DailyMetrics(date: day(-$0), hrv: 60, restingHR: 55, sleepHours: 7.5) }
        XCTAssertEqual(engine.updateBaseline(history: long).dayCount, 60)
    }

    func testBaselineGoodPoorMissingAndNoSignalScores() {
        let baseline = steadyBaseline()
        XCTAssertTrue((60...70).contains(engine.computeReadiness(
            today: DailyMetrics(date: day(1), hrv: 60, restingHR: 55, sleepHours: 7.5), baseline: baseline
        ).readinessScore))
        XCTAssertGreaterThanOrEqual(engine.computeReadiness(
            today: DailyMetrics(date: day(1), hrv: 90, restingHR: 48, sleepHours: 8.5), baseline: baseline
        ).readinessScore, 70)
        XCTAssertLessThan(engine.computeReadiness(
            today: DailyMetrics(date: day(1), hrv: 35, restingHR: 66, sleepHours: 5), baseline: baseline
        ).readinessScore, 40)
        XCTAssertGreaterThanOrEqual(engine.computeReadiness(
            today: DailyMetrics(date: day(1), hrv: 95), baseline: baseline
        ).readinessScore, 60)
        XCTAssertEqual(engine.computeReadiness(today: DailyMetrics(date: day(1)), baseline: baseline).readinessScore, 50)
    }

    func testHistoricalScoresHaveNoLookAhead() {
        let history = (0..<20).map { index in
            DailyMetrics(date: day(index), hrv: 60 + Double(index % 3), restingHR: 55 + Double(index % 2), sleepHours: 7.5)
        }
        let original = engine.historicalSnapshots(history: history)
        let extended = engine.historicalSnapshots(history: history + [DailyMetrics(date: day(20), hrv: 150, restingHR: 80, sleepHours: 3)])
        XCTAssertFalse(original.isEmpty)
        XCTAssertEqual(Array(extended.prefix(original.count)).map(\.readinessScore), original.map(\.readinessScore))
    }

    func testReadinessZoneBoundaries() {
        XCTAssertEqual(ReadinessZone.from(score: 80), .primed)
        XCTAssertEqual(ReadinessZone.from(score: 79), .ready)
        XCTAssertEqual(ReadinessZone.from(score: 40), .moderate)
        XCTAssertEqual(ReadinessZone.from(score: 39), .low)
    }
}

final class LoadEngineTests: XCTestCase {
    private let engine = LoadEngine()
    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    private func entry(daysAgo: Int, load: Double, source: LoadSource = .strength) -> TrainingLoadEntry {
        TrainingLoadEntry(
            date: Calendar.current.date(byAdding: .day, value: -daysAgo, to: now)!,
            source: source,
            activityType: "test",
            loadScore: load
        )
    }

    func testWeeklyLoadAndBreakdown() {
        let entries = [entry(daysAgo: 0, load: 100), entry(daysAgo: 3, load: 50, source: .cardio), entry(daysAgo: 10, load: 999)]
        XCTAssertEqual(engine.weeklyLoad(entries: entries, asOf: now), 150, accuracy: 0.001)
        let breakdown = engine.weeklyBreakdown(entries: entries, asOf: now)
        XCTAssertEqual(breakdown.strength, 100)
        XCTAssertEqual(breakdown.cardio, 50)
    }

    func testRatioTypicalSpikeAndInsufficient() {
        let steady = (0..<28).map { entry(daysAgo: $0, load: 100) }
        XCTAssertEqual(engine.loadRatio(entries: steady, asOf: now) ?? 0, 1, accuracy: 0.001)
        var spike: [TrainingLoadEntry] = []
        for day in 7..<28 { spike.append(entry(daysAgo: day, load: 50)) }
        for day in 0..<7 { spike.append(entry(daysAgo: day, load: 250)) }
        let ratio = engine.loadRatio(entries: spike, asOf: now)
        XCTAssertEqual(LoadTrendZone.from(ratio: ratio), .sharpIncrease)
        XCTAssertTrue(LoadTrendZone.from(ratio: ratio).suggestsCaution)
        XCTAssertNil(engine.loadRatio(entries: [entry(daysAgo: 1, load: 100)], asOf: now))
    }
}
