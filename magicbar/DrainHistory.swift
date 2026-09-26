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
/// **Two estimates, deliberately.** The clock estimate above depends on when the owner next sits
/// down, which varied sixfold day to day in the first real run (2026-09-13 to 09-18). The
/// use estimate — "about 5 hours of use left" — depends only on how fast the device drains
/// while it is being used, which is a property of the hardware. It is a car's range in
/// kilometres rather than a guess at when the tank runs dry: it does not tick down while parked.
/// Both are shown so they can be judged against each other over several charge cycles.
///
/// **Charging is recorded too, separately.** Each charge is kept as its own run of rising
/// readings, and "about 40 minutes to full" is the sum of how long each remaining percent took
/// on earlier charges. Per level, unlike the drain, because a charge is repeatable — same
/// cable, same cell, nobody's week in the way — and it is not a straight line: lithium-ion
/// charges at a steady rate and then tapers near the top. Levels never yet seen charging fall
/// back to the median step, so the first charge reads as a straight line and runs optimistic.
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

    /// Charge runs per device, oldest first: the rising readings of each time on the cable.
    private(set) var charges: [String: [[Sample]]] = [:]

    /// Samples kept per device across all segments.
    ///
    /// Effectively "keep everything": at about one crossing every three hours for a mouse this
    /// is several years, and a sample costs roughly 40 bytes. It was 200 until 2026-09-16, which
    /// held only a few weeks and would have discarded the start of the record while several
    /// charge cycles were being collected to judge the model against. The valve stays because
    /// `UserDefaults` is a preferences file, not a database, and unbounded growth there is how
    /// one quietly becomes a problem.
    static let capacity = 20_000

    /// A rise this large means a cable, not noise. Matches the alert rule's recharge threshold
    /// deliberately: two answers to "was that a charge?" in one app is a bug waiting to happen.
    static let rechargeDelta = 5

    /// The fit needs a whole day, so every window holds a full cycle of working and idle hours.
    /// Anything shorter measures a time of day, not a habit.
    static let minimumSamples = 3
    static let minimumSpan: TimeInterval = 24 * 3600

    /// A one-percent drop this quick means the device was in use the whole time. In the first
    /// real run the gaps split cleanly: 22 of 38 under 1.5 hours, the rest from 2.6 to 16.
    static let useGap: TimeInterval = 1.5 * 3600
    static let minimumUseSteps = 5

    /// A charge is about a hundred samples, and the curve only changes as the cell ages.
    static let chargeRunsKept = 10
    static let minimumChargeSteps = 5
    /// A percent that took longer than this was not gained by charging — a loose cable, or a
    /// full cell sitting on the charger.
    static let chargeStepLimit: TimeInterval = 20 * 60

    /// A device not heard from in this long is forgotten — no longer paired, or in a drawer.
    static let forgetAfter: TimeInterval = 30 * 24 * 3600

    /// Records a reading, if it is worth recording. Returns true when the history changed.
    @discardableResult
    mutating func record(id: String, percent: Int, isCharging: Bool, at now: Date = .now) -> Bool {
        var list = segments[id] ?? []

        // A device on a cable is not draining. Close the open segment once, on the way in,
        // and open a charge run with it. A launch mid-charge finds the segment already closed
        // and carries on the run it was in.
        if isCharging {
            var runs = charges[id] ?? []
            var changed = false
            if let open = list.last, !open.isEmpty {
                list.append([])
                store(list, for: id)
                runs.append([])
                changed = true
            }
            if runs.isEmpty { runs = [[]] }
            if runs[runs.count - 1].last?.percent != percent {
                runs[runs.count - 1].append(Sample(at: now, percent: percent))
                changed = true
            }
            charges[id] = Array(runs.suffix(Self.chargeRunsKept))
            return changed
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
        unseen.forEach { segments[$0] = nil; charges[$0] = nil }
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

    /// Minutes until full, or nil without enough charging on record.
    ///
    /// Each remaining percent costs what it cost on earlier charges — the median for that level —
    /// or the median of every step where that level has never been seen. Time already spent in
    /// the current percent is taken off, so the number counts down between readings.
    func chargeMinutesRemaining(id: String, percent: Int, now: Date = .now) -> Double? {
        guard percent < 100 else { return nil }
        var byLevel: [Int: [Double]] = [:]
        var all: [Double] = []
        for run in charges[id] ?? [] {
            for (earlier, later) in zip(run, run.dropFirst()) {
                let rise = later.percent - earlier.percent
                guard rise >= 1 else { continue }
                let each = later.at.timeIntervalSince(earlier.at) / Double(rise)
                guard each <= Self.chargeStepLimit else { continue }
                for level in earlier.percent..<later.percent { byLevel[level, default: []].append(each / 60) }
                all.append(contentsOf: Array(repeating: each / 60, count: rise))
            }
        }
        guard all.count >= Self.minimumChargeSteps else { return nil }
        let typical = Self.median(all)
        var minutes = (percent..<100).reduce(0.0) { $0 + (byLevel[$1].map(Self.median) ?? typical) }
        if let last = charges[id]?.last?.last, last.percent == percent, now > last.at {
            let thisLevel = byLevel[percent].map(Self.median) ?? typical
            minutes -= min(now.timeIntervalSince(last.at) / 60, thisLevel)
        }
        return minutes
    }

    /// The charge estimate as a phrase, or nil.
    func chargePhrase(id: String, percent: Int, now: Date = .now) -> String? {
        guard let minutes = chargeMinutesRemaining(id: id, percent: percent, now: now) else { return nil }
        // To the minute, unlike the drain phrases: a charge is an hour or two and repeatable, and
        // the number is being watched against the clock to judge the model.
        let whole = max(1, Int(minutes.rounded()))
        if whole < 60 { return "about \(whole) min to full" }
        return whole % 60 == 0 ? "about \(whole / 60) hr to full" : "about \(whole / 60) hr \(whole % 60) min to full"
    }

    private static func median(_ values: [Double]) -> Double {
        let sorted = values.sorted()
        let middle = sorted.count / 2
        return sorted.count % 2 == 1 ? sorted[middle] : (sorted[middle - 1] + sorted[middle]) / 2
    }

    /// Hours of continuous use that one percent lasts, or nil without enough in-use steps.
    ///
    /// The median time per one-percent drop, over drops quick enough to have been continuous
    /// use. Android estimates the same way — the average time per battery level step — but
    /// averages every step; keeping only the in-use ones is what makes this a measure of the
    /// hardware instead of the owner's week. The median, because one step that straddles a
    /// coffee break should not move it. A keyboard never qualifies: its drops are a day apart.
    func useHoursPerPercent(id: String) -> Double? {
        var steps: [Double] = []
        for segment in segments[id] ?? [] {
            for (earlier, later) in zip(segment, segment.dropFirst()) {
                let drop = earlier.percent - later.percent
                guard drop >= 1 else { continue }
                let each = later.at.timeIntervalSince(earlier.at) / Double(drop)
                if each <= Self.useGap { steps.append(contentsOf: Array(repeating: each / 3600, count: drop)) }
            }
        }
        guard steps.count >= Self.minimumUseSteps else { return nil }
        return Self.median(steps)
    }

    /// The use estimate as a phrase, or nil.
    func usePhrase(id: String, percent: Int) -> String? {
        guard let perPercent = useHoursPerPercent(id: id) else { return nil }
        let hours = Double(percent) * perPercent
        return hours < 1 ? "under an hour of use left" : "about \(Int(hours.rounded())) hours of use left"
    }
}

extension DrainHistory {

    private enum CodingKeys: String, CodingKey { case segments, series, charges }

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
        self.charges = try container.decodeIfPresent([String: [[Sample]]].self, forKey: .charges) ?? [:]
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(segments, forKey: .segments)
        try container.encode(charges, forKey: .charges)
    }

    private static let defaultsKey = "drainHistory"

    static func load(from defaults: UserDefaults) -> DrainHistory {
        guard let data = defaults.data(forKey: defaultsKey),
              let decoded = try? JSONDecoder().decode(DrainHistory.self, from: data) else {
            return DrainHistory()
        }
        return decoded
    }

    func save(to defaults: UserDefaults) {
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
            let use = history.usePhrase(id: "d", percent: percent) ?? "nothing"
            lines.append("\(label.padding(toLength: 44, withPad: " ", startingAt: 0))\(rate.padding(toLength: 12, withPad: " ", startingAt: 0))\(says.padding(toLength: 22, withPad: " ", startingAt: 0))\(use)")
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

        // Three sittings a day of 48 minutes per percent, idle between them. The clock estimate
        // averages the idle time in; the use estimate must see only the 0.8 hours.
        var sittings = DrainHistory()
        var level = 60
        for day in 0..<3 {
            for sitting in [9.0, 14.0, 20.0] {
                for step in 0..<3 {
                    sittings.record(id: "d", percent: level, isCharging: false,
                                    at: at(Double(day) * 24 + sitting + Double(step) * 0.8))
                    level -= 1
                }
            }
        }
        report("3 sittings a day at 0.8h per 1%, at 33%", sittings, percent: 33, now: 72)
        lines.append("  hours of use per 1%:                     \(sittings.useHoursPerPercent(id: "d").map { String(format: "%.2f", $0) } ?? "nil")")

        // A charge that tapers: 1.5 minutes a percent to 80%, then 4. The first time through, the
        // top has never been seen and reads as a straight line; the second time it is known.
        var charging = DrainHistory()
        func charge(from start: Int, startingAtHour hour: Double) {
            var minutes = 0.0
            for p in start...100 {
                charging.record(id: "d", percent: p, isCharging: true, at: at(hour + minutes / 60))
                minutes += p < 80 ? 1.5 : 4
            }
        }
        charging.record(id: "d", percent: 10, isCharging: false, at: at(0))
        charging.record(id: "d", percent: 10, isCharging: true, at: at(1))
        for p in 11...40 { charging.record(id: "d", percent: p, isCharging: true, at: at(1 + Double(p - 10) * 1.5 / 60)) }
        lines.append("first charge, at 40% (truth 140 min):      \(charging.chargePhrase(id: "d", percent: 40, now: at(1.75)) ?? "nothing")")
        charging = DrainHistory()
        charging.record(id: "d", percent: 10, isCharging: false, at: at(0))
        charge(from: 10, startingAtHour: 1)
        charging.record(id: "d", percent: 30, isCharging: false, at: at(50))
        charge(from: 30, startingAtHour: 51)
        let replug = charging.charges["d"]?.last?.first(where: { $0.percent == 40 })?.at ?? at(51)
        lines.append("second charge, at 40% (truth 140 min):     \(charging.chargePhrase(id: "d", percent: 40, now: replug) ?? "nothing")")
        lines.append("  charge runs kept:                        \(charging.charges["d"]?.count ?? 0)")

        var capped = DrainHistory()
        for i in 0..<250 { capped.record(id: "d", percent: 250 - i, isCharging: false, at: at(Double(i))) }
        lines.append("250 readings stored as:                    \(capped.sampleCounts["d"] ?? 0)")

        let old = #"{"series":{"d":[{"at":0,"percent":50},{"at":90000,"percent":48}]}}"#
        let migrated = (try? JSONDecoder().decode(DrainHistory.self, from: Data(old.utf8)))
        lines.append("old saved format reads as:                 \(migrated.map { "\($0.segments["d"]?.count ?? 0) segment, \($0.sampleCounts["d"] ?? 0) samples" } ?? "FAILED")")

        return lines.joined(separator: "\n")
    }
}
