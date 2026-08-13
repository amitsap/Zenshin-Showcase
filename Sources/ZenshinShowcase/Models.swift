import Foundation

public struct DailyMetrics: Equatable, Sendable {
    public let date: Date
    public var hrv: Double?
    public var restingHR: Double?
    public var sleepHours: Double?

    public init(date: Date, hrv: Double? = nil, restingHR: Double? = nil, sleepHours: Double? = nil) {
        self.date = date
        self.hrv = hrv
        self.restingHR = restingHR
        self.sleepHours = sleepHours
    }

    public var hasAnySignal: Bool { hrv != nil || restingHR != nil || sleepHours != nil }
}

public struct RecoveryBaseline: Equatable, Sendable {
    public static let minimumCalibrationDays = 14
    public static let minimumMetricDays = 7

    public var hrvMean: Double
    public var hrvStdDev: Double
    public var hrvCount: Int
    public var rhrMean: Double
    public var rhrStdDev: Double
    public var rhrCount: Int
    public var sleepMean: Double
    public var sleepStdDev: Double
    public var sleepCount: Int
    public var dayCount: Int

    public init(
        hrvMean: Double = 0,
        hrvStdDev: Double = 0,
        hrvCount: Int = 0,
        rhrMean: Double = 0,
        rhrStdDev: Double = 0,
        rhrCount: Int = 0,
        sleepMean: Double = 0,
        sleepStdDev: Double = 0,
        sleepCount: Int = 0,
        dayCount: Int = 0
    ) {
        self.hrvMean = hrvMean
        self.hrvStdDev = hrvStdDev
        self.hrvCount = hrvCount
        self.rhrMean = rhrMean
        self.rhrStdDev = rhrStdDev
        self.rhrCount = rhrCount
        self.sleepMean = sleepMean
        self.sleepStdDev = sleepStdDev
        self.sleepCount = sleepCount
        self.dayCount = dayCount
    }

    public var isCalibrated: Bool {
        dayCount >= Self.minimumCalibrationDays &&
            (hrvCount >= Self.minimumCalibrationDays || rhrCount >= Self.minimumCalibrationDays)
    }

    public func supportsHRV() -> Bool { hrvCount >= Self.minimumMetricDays && hrvStdDev > 0.0001 }
    public func supportsRHR() -> Bool { rhrCount >= Self.minimumMetricDays && rhrStdDev > 0.0001 }
    public func supportsSleep() -> Bool { sleepCount >= Self.minimumMetricDays }
}

public enum ReadinessZone: String, Codable, Sendable {
    case primed
    case ready
    case moderate
    case low

    public static func from(score: Int) -> Self {
        switch score {
        case 80...: .primed
        case 60..<80: .ready
        case 40..<60: .moderate
        default: .low
        }
    }
}

public struct ReadinessSnapshot: Equatable, Sendable {
    public let date: Date
    public let readinessScore: Int
    public let zone: ReadinessZone
    public let contributors: [String]

    public init(date: Date, readinessScore: Int, zone: ReadinessZone, contributors: [String] = []) {
        self.date = date
        self.readinessScore = readinessScore
        self.zone = zone
        self.contributors = contributors
    }
}

public enum LoadSource: String, Codable, Sendable {
    case strength
    case cardio
}

public struct TrainingLoadEntry: Equatable, Sendable {
    public let date: Date
    public let source: LoadSource
    public let activityType: String
    public let loadScore: Double

    public init(date: Date, source: LoadSource, activityType: String, loadScore: Double) {
        self.date = date
        self.source = source
        self.activityType = activityType
        self.loadScore = loadScore
    }
}

public enum LoadTrendZone: String, Sendable {
    case insufficient
    case belowUsual
    case typical
    case increasing
    case sharpIncrease

    public static func from(ratio: Double?) -> Self {
        guard let ratio else { return .insufficient }
        return switch ratio {
        case ..<0.8: .belowUsual
        case 0.8..<1.2: .typical
        case 1.2..<1.5: .increasing
        default: .sharpIncrease
        }
    }

    public var suggestsCaution: Bool { self == .sharpIncrease }
}
