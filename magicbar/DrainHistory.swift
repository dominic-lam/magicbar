import Foundation

/// Remembers how a device's level has fallen, and turns that into "about three days left".
///
/// **Only changes are recorded.** The poll runs every five seconds, but these peripherals
/// report whole percents and a Magic Mouse takes weeks to cross them, so sampling the timer
/// would store seventeen thousand copies of the same number a day. A sample is written when
/// the reading actually moves, which makes the stored series the same shape as the real drain
/// curve at a fraction of the size.
///
/// **A rise ends the curve.** Everything before a charge describes a battery that no longer
/// exists, so a rise of `rechargeDelta` or more clears the series and starts again. The
/// threshold is not one percent for the same reason the alert rule does not use one: a
/// Bluetooth reading wobbles by a point, and treating that as a charge would throw away the
/// history every time it happened.
///
/// **Absence is not a reading.** A vanished or stale device records nothing at all. A sleeping
/// mouse is not a mouse draining to zero, and a gap in the series is silence, not data.
///
/// The estimate itself is a least-squares slope rather than first-to-last, because two
/// endpoints give a wobble the same weight as the trend, and this app has already been bitten
/// by exactly that.
struct DrainHistory: Codable {

    struct Sample: Codable, Equatable {
        let at: Date
        let percent: Int
    }

    /// Samples per device, keyed by `DeviceAddress` like everything else that must survive a
    /// device moving between Bluetooth and USB.
    private(set) var series: [String: [Sample]] = [:]

    /// How many samples to keep per device. Thirty crossings of a percent is more than a full
    /// drain for these peripherals, and the fit does not get better with more.
    static let capacity = 30

    /// A rise this large or larger means a cable, not noise. Matches the alert rule's own
    /// recharge threshold deliberately: two different answers to "was that a charge?" in one
    /// app is a bug waiting to be argued about.
    static let rechargeDelta = 5

    /// The fit needs both enough points and enough time. Three points inside an hour describe
    /// a wobble; three points across a day describe a battery.
    static let minimumSamples = 3
    static let minimumSpan: TimeInterval = 6 * 3600

    /// Records a reading, if it is worth recording. Returns true when the series changed.
    @discardableResult
    mutating func record(id: String, percent: Int, isCharging: Bool, at now: Date = .now) -> Bool {
        // A device on a cable is not draining, and its rise would otherwise read as a recharge
        // event over and over. Drop the curve once, on the way in.
        if isCharging {
            guard series[id] != nil else { return false }
            series[id] = nil
            return true
        }

        var samples = series[id] ?? []

        if let last = samples.last {
            if percent == last.percent { return false }
            if percent >= last.percent + Self.rechargeDelta {
                series[id] = [Sample(at: now, percent: percent)]
                return true
            }
        }

        samples.append(Sample(at: now, percent: percent))
        if samples.count > Self.capacity { samples.removeFirst(samples.count - Self.capacity) }
        series[id] = samples
        return true
    }

    /// Forgets a device entirely — used when it is no longer paired.
    mutating func forget(id: String) { series[id] = nil }

    /// Percent lost per hour, or nil when the series cannot support a number yet.
    func ratePerHour(id: String) -> Double? {
        guard let samples = series[id], samples.count >= Self.minimumSamples,
              let first = samples.first, let last = samples.last else { return nil }
        guard last.at.timeIntervalSince(first.at) >= Self.minimumSpan else { return nil }

        let hours = samples.map { $0.at.timeIntervalSince(first.at) / 3600 }
        let levels = samples.map { Double($0.percent) }
        let count = Double(samples.count)
        let meanHours = hours.reduce(0, +) / count
        let meanLevel = levels.reduce(0, +) / count

        var covariance = 0.0
        var variance = 0.0
        for (hour, level) in zip(hours, levels) {
            covariance += (hour - meanHours) * (level - meanLevel)
            variance += (hour - meanHours) * (hour - meanHours)
        }
        guard variance > 0 else { return nil }

        let slope = covariance / variance
        // A flat or rising fit is not a drain. Saying nothing is the correct output.
        guard slope < 0 else { return nil }
        return -slope
    }

    /// Hours until empty at the observed rate, or nil when there is no rate.
    func hoursRemaining(id: String, percent: Int) -> Double? {
        guard let rate = ratePerHour(id: id), rate > 0 else { return nil }
        return Double(percent) / rate
    }

    /// The estimate as a phrase, or nil. Deliberately vague: the input is a straight line
    /// through a handful of integer readings, and "2.7 days" would claim a precision the data
    /// does not have.
    func phrase(id: String, percent: Int) -> String? {
        guard let hours = hoursRemaining(id: id, percent: percent) else { return nil }
        switch hours {
        case ..<1: return "under an hour left"
        case ..<48: return "about \(Int(hours.rounded())) hours left"
        case ..<(30 * 24): return "about \(Int((hours / 24).rounded())) days left"
        default: return "over a month left"
        }
    }
}

extension DrainHistory {

    private static let defaultsKey = "drainHistory"

    static func load(from defaults: UserDefaults = .standard) -> DrainHistory {
        guard let data = defaults.data(forKey: defaultsKey),
              let decoded = try? JSONDecoder().decode(DrainHistory.self, from: data) else {
            return DrainHistory()
        }
        return decoded
    }

    func save(to defaults: UserDefaults = .standard) {
        guard let data = try? JSONEncoder().encode(self) else { return }
        defaults.set(data, forKey: Self.defaultsKey)
    }
}
