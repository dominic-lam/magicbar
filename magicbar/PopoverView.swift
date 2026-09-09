import SwiftUI

/// The panel shown when the menu bar item is clicked.
///
/// Lists every discovered device regardless of level, which is the point of the idle
/// state: the menu bar says only "monitoring", and this is where the actual numbers live.
struct PopoverView: View {
    @ObservedObject var store: BatteryStore

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Battery")
                .font(.title3)
                .fontWeight(.semibold)

            if store.devices.isEmpty {
                // Distinct from "everything is fine". A peripheral that is asleep or
                // disconnected vanishes from the registry entirely, and saying so is
                // better than showing a confident 0%.
                Text("No devices reporting a battery.")
                    .font(.footnote)
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

            Toggle("Open at login", isOn: Binding(
                get: { store.launchAtLogin },
                set: { store.launchAtLogin = $0 }
            ))
            .font(.footnote)
            .toggleStyle(.checkbox)

            HStack {
                Text("Updates every minute")
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
        .frame(width: 300)
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
                    .font(.callout)
            }

            HStack(spacing: 8) {
                // GeometryReader is greedy vertically, so it needs its own height as well
                // as the shapes inside it, or it swallows the whole stack.
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
                    .font(.callout)
                    .fontWeight(.semibold)
                    .foregroundStyle(color)
                    .monospacedDigit()
                    .frame(width: 44, alignment: .trailing)
            }
        }
    }
}

/// The two thresholds, adjustable without a rebuild.
///
/// The bash version kept these in `config.sh` where a text editor could reach them.
/// Requiring a recompile to change a number would have been a regression, so they live in
/// `UserDefaults` and are edited here.
private struct ThresholdControls: View {
    @ObservedObject var store: BatteryStore

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Stepper(value: $store.alertThreshold, in: (store.nagThreshold + 1)...100, step: 5) {
                HStack {
                    Text("Show in menu bar below")
                        .font(.footnote)
                    Spacer()
                    Text("\(store.alertThreshold)%")
                        .font(.footnote)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }

            // Capped below the alert threshold so the two cannot cross. A nag threshold
            // above the alert threshold would notify about a device the menu bar was not
            // even showing.
            Stepper(value: $store.nagThreshold, in: 1...max(1, store.alertThreshold - 1), step: 1) {
                HStack {
                    Text("Notify every % below")
                        .font(.footnote)
                    Spacer()
                    Text("\(store.nagThreshold)%")
                        .font(.footnote)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
