import SwiftUI

/// The panel shown when the menu bar item is clicked.
///
/// Lists every discovered device regardless of level, which is the point of the idle state:
/// the menu bar says only "monitoring", and this is where the actual numbers live.
///
/// **One text size throughout, except the footer.** Every row uses `rowFont`; hierarchy comes
/// from weight and colour rather than from size. Mixed sizes made the panel read as several
/// unrelated widgets stacked together.
struct PopoverView: View {
    @ObservedObject var store: BatteryStore

    /// The single size every row shares. Changing it here changes the whole panel.
    static let rowFont: Font = .callout

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Battery")
                .font(Self.rowFont)
                .fontWeight(.semibold)

            if store.isSimulated {
                // Simulated readings look exactly like real ones, which has already produced
                // one false bug report against a forgotten test instance.
                Text("Showing simulated readings, not your hardware.")
                    .font(Self.rowFont)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.purple.opacity(0.18))
                    .cornerRadius(6)
            }

            if store.devices.isEmpty {
                // Distinct from "everything is fine". A peripheral that is asleep or
                // disconnected vanishes from the registry entirely, and saying so is better
                // than showing a confident 0%.
                Text("No devices reporting a battery.")
                    .font(Self.rowFont)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(store.devices) { device in
                        DeviceRow(device: device, color: store.color(for: device.percent))
                    }
                }
            }

            Divider()

            ThresholdControls(store: store)

            Divider()

            NotificationSection(store: store)

            Divider()

            Toggle("Open at login", isOn: Binding(
                get: { store.launchAtLogin },
                set: { store.launchAtLogin = $0 }
            ))
            .font(Self.rowFont)
            .toggleStyle(.checkbox)

            // The one row deliberately smaller: it is status and an escape hatch, not
            // something to read.
            HStack {
                Text("Updates live")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Quit") { NSApplication.shared.terminate(nil) }
                    .buttonStyle(.plain)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        // A `.window`-style MenuBarExtra does not size itself to anything sensible, so the
        // width is fixed here and the height left free.
        .frame(width: 340)
        // Permission is re-read here rather than on the poll timer: it can only change while
        // the user is away in System Settings, and checking it is an XPC round trip.
        .onAppear { store.refreshAuthorizationNow() }
    }
}

/// One device: name, level bar, percentage.
private struct DeviceRow: View {
    let device: Device
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: device.symbolCandidates.first ?? "battery.50percent")
                    .foregroundStyle(.secondary)
                Text(device.shortName)
                    .font(PopoverView.rowFont)
                if device.isCharging {
                    Image(systemName: "bolt.fill")
                        .font(PopoverView.rowFont)
                        .foregroundStyle(.green)
                }
                if device.isStale {
                    Text("last seen \(device.seenAgo)")
                        .font(PopoverView.rowFont)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 8) {
                // GeometryReader is greedy vertically, so it needs its own height as well as
                // the shapes inside it, or it swallows the whole stack.
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.primary.opacity(0.12))
                            .frame(height: 10)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(color)
                            .frame(width: geometry.size.width * CGFloat(min(max(device.percent, 0), 100)) / 100,
                                   height: 10)
                    }
                }
                .frame(height: 10)

                // Monospaced and fixed width, so the bar does not shift sideways as the
                // number's width changes.
                Text("\(device.percent)%")
                    .font(PopoverView.rowFont)
                    .fontWeight(.semibold)
                    .foregroundStyle(color)
                    .monospacedDigit()
                    .frame(width: 44, alignment: .trailing)
            }
        }
        // A remembered reading is dimmed, so it never reads as live data.
        .opacity(device.isStale ? 0.55 : 1)
    }
}

/// The two thresholds, adjustable without a rebuild.
///
/// The bash version kept these in `config.sh` where a text editor could reach them. Requiring
/// a recompile to change a number would have been a regression.
private struct ThresholdControls: View {
    @ObservedObject var store: BatteryStore

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Stepper(value: $store.alertThreshold, in: (store.nagThreshold + 1)...100, step: 5) {
                LabelledValue(title: "Show battery level in menu bar when below", value: "\(store.alertThreshold)%")
            }

            // Capped below the alert threshold so the two cannot cross. A nag threshold above
            // the alert threshold would notify about a device the menu bar was not showing.
            Stepper(value: $store.nagThreshold, in: 1...max(1, store.alertThreshold - 1), step: 1) {
                LabelledValue(title: "Notify on every % drop below", value: "\(store.nagThreshold)%")
            }
        }
    }
}

/// Everything about alerts: whether they can be delivered, what they sound like, and the
/// developer controls for provoking one.
private struct NotificationSection: View {
    @ObservedObject var store: BatteryStore

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Notifications")
                .font(PopoverView.rowFont)
                .fontWeight(.semibold)

            if !store.notificationsAllowed {
                // The one failure the app cannot fix for itself. Saying so here, with the way
                // out attached, beats a user wondering why alerts never arrive.
                VStack(alignment: .leading, spacing: 6) {
                    Text("Notifications are turned off")
                        .font(PopoverView.rowFont)
                        .fontWeight(.medium)
                    Text("magicbar can watch the battery but cannot warn you.")
                        .font(PopoverView.rowFont)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Button("Open Notification Settings") { store.openNotificationSettings() }
                        .font(PopoverView.rowFont)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.orange.opacity(0.14))
                .cornerRadius(8)
            }

            Picker(selection: $store.alertSound) {
                ForEach(BatteryStore.availableSounds, id: \.self) { name in
                    Text(name).tag(name)
                }
            } label: {
                Text("Alert sound")
                    .font(PopoverView.rowFont)
            }
            .pickerStyle(.menu)
            .font(PopoverView.rowFont)

            Toggle("Developer mode", isOn: $store.developerMode)
                .font(PopoverView.rowFont)
                .toggleStyle(.checkbox)

            if store.developerMode {
                DeveloperControls(store: store)
            }
        }
    }
}

/// Fires an alert for any device at any level.
///
/// Battery levels cannot be dialled to order, so without this the only way to see what a
/// warning looks like at 3% is to run a device down to 3%.
private struct DeveloperControls: View {
    @ObservedObject var store: BatteryStore

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker(selection: $store.testDeviceID) {
                ForEach(store.devices) { device in
                    Text(device.shortName).tag(device.id)
                }
            } label: {
                Text("Device")
                    .font(PopoverView.rowFont)
            }
            .pickerStyle(.menu)
            .font(PopoverView.rowFont)
            .disabled(store.devices.isEmpty)

            VStack(alignment: .leading, spacing: 4) {
                LabelledValue(title: "Battery level", value: "\(store.testPercent)%")
                // A slider rather than a stepper: the point is to sweep across the thresholds
                // and watch the colour and wording change, not to nudge one percent at a time.
                Slider(value: Binding(
                    get: { Double(store.testPercent) },
                    set: { store.testPercent = Int($0) }
                ), in: 0...100, step: 1)
            }

            Button("Fire notification") { store.fireDeveloperNotification() }
                .font(PopoverView.rowFont)
                .frame(maxWidth: .infinity)
                .disabled(!store.notificationsAllowed)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.06))
        .cornerRadius(8)
    }
}

/// A label on the left and its value on the right, at the shared row size. Used wherever a
/// setting shows its current number, so they all line up.
private struct LabelledValue: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
                .font(PopoverView.rowFont)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 8)
            Text(value)
                .font(PopoverView.rowFont)
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
    }
}
