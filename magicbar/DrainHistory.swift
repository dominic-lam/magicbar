import Foundation

/// Remembers how a device's level has fallen, and turns that into "about three days left".
///
/// **Only changes are recorded.** The poll runs every five seconds, but these peripherals
/// report whole percents and a Magic Mouse takes hours to cross one, so sampling the timer
/// would store seventeen thousand copies of the same number a day. A sample is written when
/// the reading actually moves.
///
/// **A charge ends a segment, not the history.** A person's daily use barely changes, so the
/// rate measured before a charge still describes the battery after it. Each run between charges
/// is kept as its own segment, and one rate is fitted across all of them, so the estimate
/// survives a top-up instead of going blank for a day. A rise of `rechargeDelta` or more counts
/// as a charge even without the charging flag; a one-point Bluetooth wobble does not.
///
/// **Time counts, not just changes.** The current reading is added as a point at "now", so a
/// quiet weekend with no change counts as a weekend that used nothing. Without it the fit
/// behaves as if the clock stopped at the last change, and overstates the drain.
///
/// **Absence is not a reading.** A vanished or stale device records nothing. A sleeping mouse is
/// not a mouse draining to zero, and a gap between samples is still time on the clock.
struct DrainHistory: Codable {

    struct Sample: Codable, Equatable {
        let at: Date
        let percent: Int
    }

    /// Discharge segments per device, oldest first, keyed by `DeviceAddress` like everything
    /// else that must survive a device moving between Bluetooth and USB. A trailing empty
    /// segment means the device is on a cable and the next reading opens a new run.
    private(set) var segments: [String: [[Sample]]] = [:]

    /// Samples kept per device across all segments. At about one crossing every three hours
    /// for a mouse, 200 is several weeks of use — long enough to span weekdays and weekends.
    static let capacity = 200

    /// A rise this large means a cable, not noise. Matches the alert rule's recharge threshold
    /// deliberately: two answers to "was that a charge?" in one app is a bug waiting to happen.
    static let rechargeDelta = 5

    /// The fit needs a whole day, so every window holds a full cycle of working and idle hours.
    /// Anything shorter measures a time of day, not a habit.
    static let minimumSamples = 3
    static let minimumSpan: TimeInterval = 24 * 3600

    /// A device not heard from in this long is forgotten — no longer paired, or in a drawer.
    static let forgetAfter: TimeInterval = 30 * 24 * 3600

    /// Records a reading, if it is worth recording. Returns true when the history changed.
    @discardableResult
    mutating func record(id: String, percent: Int, isCharging: Bool, at now: Date = .now) -> Bool {
        var list = segments[id] ?? []

        // A device on a cable is not draining. Close the open segment once, on the way in.
        if isCharging {
            guard let open = list.last, !open.isEmpty else { return false }
            list.append([])
            store(list, for: id)
            return true
        }

        if let last = list.last?.last {
            if percent == last.percent { return false }
            if percent >= last.percent + Self.rechargeDelta {
                // A charge the flag never showed. The old run still describes the habit.
                list.append([Sample(at: now, percent: percent)])
                store(list, for: id)
                return true
            }
        }

        if list.isEmpty { list = [[]] }
        list[list.count - 1].append(Sample(at: now, percent: percent))
        store(list, for: id)
        return true
    }

    /// Drops the oldest samples beyond `capacity`, and any segment left empty by that.
    private mutating func store(_ list: [[Sample]], for id: String) {
        var list = list
        var excess = list.reduce(0) { $0 + $1.count } - Self.capacity
        while excess > 0, !list.isEmpty {
            let drop = min(excess, list[0].count)
            list[0].removeFirst(drop)
            excess -= drop
            if list[0].isEmpty, list.count > 1 { list.removeFirst() }
        }
        segments[id] = list
    }

    /// Forgets devices with no sample newer than `forgetAfter`. Returns true when any went.
    ///
    /// Not tied to a device leaving the registry: a keyboard switched off overnight or a
    /// sleeping mouse vanishes too, and forgetting those threw away the whole history.
    mutating func forgetUnseen(now: Date = .now) -> Bool {
        let unseen = segments.compactMap { id, list -> String? in
            guard let newest = list.last(where: { !$0.isEmpty })?.last?.at else { return id }
            return now.timeIntervalSince(newest) > Self.forgetAfter ? id : nil
        }
        unseen.forEach { segments[$0] = nil }
        return !unseen.isEmpty
    }

    var sampleCounts: [String: Int] { segments.mapValues { $0.reduce(0) { $0 + $1.count } } }

    struct Fit {
        let points: Int
        let segments: Int
        let span: TimeInterval
        /// Percent lost per hour, or nil when the history cannot support a number yet.
        let rate: Double?
    }

    /// One slope fitted across every segment, each with its own starting level.
    ///
    /// Pooled least squares: each segment is centred on its own mean, so the jump at a charge
    /// never reads as drain, and the segments share one slope because they share one habit.
    /// `percent` is the current reading, added at `now` to the open segment; pass nil for a
    /// device that is not currently being read.
    func fit(id: String, percent: Int?, now: Date = .now) -> Fit {
        guard var list = segments[id] else { return Fit(points: 0, segments: 0, span: 0, rate: nil) }
        if let percent, let last = list.last?.last, now > last.at {
            list[list.count - 1].append(Sample(at: now, percent: percent))
        }

        var covariance = 0.0, variance = 0.0, span = 0.0
        var points = 0, used = 0
        for segment in list where segment.count >= 2 {
            let origin = segment[0].at
            let hours = segment.map { $0.at.timeIntervalSince(origin) / 3600 }
            let levels = segment.map { Double($0.percent) }
            let count = Double(segment.count)
            let meanHours = hours.reduce(0, +) / count
            let meanLevel = levels.reduce(0, +) / count
            for (hour, level) in zip(hours, levels) {
                covariance += (hour - meanHours) * (level - meanLevel)
                variance += (hour - meanHours) * (hour - meanHours)
            }
            span += segment[segment.count - 1].at.timeIntervalSince(origin)
            points += segment.count
            used += 1
        }

        var rate: Double?
        if points >= Self.minimumSamples, span >= Self.minimumSpan, variance > 0 {
            let slope = covariance / variance
            // A flat or rising fit is not a drain. Saying nothing is the correct output.
            if slope < 0 { rate = -slope }
        }
        return Fit(points: points, segments: used, span: span, rate: rate)
    }

    /// Hours until empty at the fitted rate, or nil when there is no rate.
    func hoursRemaining(id: String, percent: Int, now: Date = .now) -> Double? {
        guard let rate = fit(id: id, percent: percent, now: now).rate else { return nil }
        return Double(percent) / rate
    }

    /// The estimate as a phrase, or nil. Deliberately vague: the input is a straight line
    /// through integer readings, and "2.7 days" would claim a precision the data does not have.
    func phrase(id: String, percent: Int, now: Date = .now) -> String? {
        guard let hours = hoursRemaining(id: id, percent: percent, now: now) else { return nil }
        switch hours {
        case ..<1: return "under an hour left"
        case ..<48: return "about \(Int(hours.rounded())) hours left"
        case ..<(30 * 24): return "about \(Int((hours / 24).rounded())) days left"
        default: return "over a month left"
        }
    }
}

extension DrainHistory {

    private enum CodingKeys: String, CodingKey { case segments, series }

    /// Reads both formats. Before 2026-09-13 a charge deleted the curve, so the old `series`
    /// held exactly one run per device and becomes a single segment.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let segments = try container.decodeIfPresent([String: [[Sample]]].self, forKey: .segments) {
            self.segments = segments
        } else {
            let series = try container.decodeIfPresent([String: [Sample]].self, forKey: .series) ?? [:]
            self.segments = series.mapValues { [$0] }
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(segments, forKey: .segments)
    }

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

extension DrainHistory {

    /// Synthetic series run through the rule alone, for `--check-estimate`. Touches no saved
    /// data: the real history takes weeks and a charge to exercise, and the other diagnostics
    /// have already corrupted it once.
    static func selfCheck() -> String {
        let start = Date(timeIntervalSinceReferenceDate: 0)
        func at(_ hours: Double) -> Date { start.addingTimeInterval(hours * 3600) }
        func drain(from level: Int, everyHours step: Double, until hours: Double,
                   into history: inout DrainHistory, offset: Double = 0) {
            var h = 0.0, p = level
            while h <= hours {
                history.record(id: "d", percent: p, isCharging: false, at: at(offset + h))
                h += step; p -= 1
            }
        }
        var lines: [String] = []
        func report(_ label: String, _ history: DrainHistory, percent: Int, now hours: Double) {
            let fit = history.fit(id: "d", percent: percent, now: at(hours))
            let rate = fit.rate.map { String(format: "%.1f%%/day", $0 * 24) } ?? "no rate"
            let says = history.phrase(id: "d", percent: percent, now: at(hours)) ?? "nothing"
            lines.append("\(label.padding(toLength: 44, withPad: " ", startingAt: 0))\(rate.padding(toLength: 12, withPad: " ", startingAt: 0))\(says)")
        }

        // 4% a day: one percent every six hours, 60% down to 48% over three days.
        var steady = DrainHistory()
        drain(from: 60, everyHours: 6, until: 72, into: &steady)
        report("4%/day for 3 days, at 48%", steady, percent: 48, now: 72)

        var short = DrainHistory()
        drain(from: 60, everyHours: 6, until: 18, into: &short)
        report("4%/day for 18 hours only", short, percent: 57, now: 18)

        var charged = steady
        charged.record(id: "d", percent: 48, isCharging: true, at: at(73))
        report("same, now on the cable", charged, percent: 48, now: 74)
        charged.record(id: "d", percent: 90, isCharging: false, at: at(75))
        report("charged to 90%, one hour later", charged, percent: 90, now: 76)

        var weekend = DrainHistory()
        drain(from: 60, everyHours: 6, until: 24, into: &weekend)
        let quiet = weekend.fit(id: "d", percent: nil, now: at(96)).rate.map { String(format: "%.1f%%/day", $0 * 24) } ?? "no rate"
        report("1 busy day, then 3 quiet days", weekend, percent: 56, now: 96)
        lines.append("  same, ignoring the quiet time:           \(quiet)")

        var wobble = DrainHistory()
        for (h, p) in [(0.0, 50), (10, 49), (11, 50), (30, 48), (40, 47)] {
            wobble.record(id: "d", percent: p, isCharging: false, at: at(h))
        }
        report("one-point wobble mid-run", wobble, percent: 47, now: 40)
        lines.append("  segments after the wobble:               \(wobble.segments["d"]?.count ?? 0)")

        var capped = DrainHistory()
        for i in 0..<250 { capped.record(id: "d", percent: 250 - i, isCharging: false, at: at(Double(i))) }
        lines.append("250 readings stored as:                    \(capped.sampleCounts["d"] ?? 0)")

        let old = #"{"series":{"d":[{"at":0,"percent":50},{"at":90000,"percent":48}]}}"#
        let migrated = (try? JSONDecoder().decode(DrainHistory.self, from: Data(old.utf8)))
        lines.append("old saved format reads as:                 \(migrated.map { "\($0.segments["d"]?.count ?? 0) segment, \($0.sampleCounts["d"] ?? 0) samples" } ?? "FAILED")")

        return lines.joined(separator: "\n")
    }
}
