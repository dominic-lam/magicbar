import SwiftUI

/// A two-handle slider setting the urgent and warn levels on one track.
///
/// SwiftUI has no range slider, so this is built from a track and two drag gestures.
///
/// **Why one control instead of two steppers.** The two levels are not independent — the lower
/// must stay below the upper — and two steppers expressed that as moving bounds that silently
/// blocked a press with no explanation. Here the constraint is physical: the handles cannot
/// pass each other, and the coloured track shows what each band means without a sentence.
///
/// The track stops at 50 rather than 100. Nobody sets these above a third of a battery, and on
/// a full-width scale both handles crowd into the left fifth where they cannot be grabbed.
struct RangeSlider: View {
    @Binding var lower: Int   // urgent below this
    @Binding var upper: Int   // warn below this

    let bounds: ClosedRange<Int>
    let step: Int

    private let trackHeight: CGFloat = 10
    private let handleSize: CGFloat = 18

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            GeometryReader { geometry in
                let width = geometry.size.width - handleSize
                let lowerX = position(for: lower, width: width)
                let upperX = position(for: upper, width: width)

                ZStack(alignment: .leading) {
                    // Three bands, drawn as one continuous track so the boundaries read as
                    // divisions of a whole rather than three separate bars.
                    RoundedRectangle(cornerRadius: trackHeight / 2)
                        .fill(Urgency.ok.color.opacity(0.55))
                        .frame(height: trackHeight)

                    RoundedRectangle(cornerRadius: trackHeight / 2)
                        .fill(Urgency.low.color.opacity(0.85))
                        .frame(width: upperX + handleSize / 2, height: trackHeight)

                    RoundedRectangle(cornerRadius: trackHeight / 2)
                        .fill(Urgency.critical.color)
                        .frame(width: lowerX + handleSize / 2, height: trackHeight)

                    handle(at: lowerX, label: "urgent")
                        .gesture(drag(width: width, setting: .lower))
                    handle(at: upperX, label: "warn")
                        .gesture(drag(width: width, setting: .upper))
                }
                .frame(height: handleSize)
            }
            .frame(height: handleSize)

            // Endpoints, so the scale is legible without dragging anything to find out.
            HStack {
                Text("\(bounds.lowerBound)%")
                Spacer()
                Text("\(bounds.upperBound)%")
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
    }

    private func handle(at x: CGFloat, label: String) -> some View {
        Circle()
            .fill(Color.white)
            .overlay(Circle().strokeBorder(Color.black.opacity(0.25), lineWidth: 0.5))
            .shadow(radius: 1, y: 0.5)
            .frame(width: handleSize, height: handleSize)
            .offset(x: x)
            .accessibilityLabel(label)
    }

    private enum Handle { case lower, upper }

    private func position(for value: Int, width: CGFloat) -> CGFloat {
        let span = CGFloat(bounds.upperBound - bounds.lowerBound)
        return width * CGFloat(value - bounds.lowerBound) / span
    }

    private func drag(width: CGFloat, setting handle: Handle) -> some Gesture {
        DragGesture(minimumDistance: 0).onChanged { value in
            let span = CGFloat(bounds.upperBound - bounds.lowerBound)
            let raw = Double(bounds.lowerBound) + Double((value.location.x - handleSize / 2) / width) * Double(span)
            let snapped = Int((raw / Double(step)).rounded()) * step

            switch handle {
            case .lower:
                // Kept a step below the upper handle: equal values would mean the middle band
                // has no width, which is a configuration with no meaning rather than a choice.
                lower = min(max(snapped, bounds.lowerBound), upper - step)
            case .upper:
                upper = max(min(snapped, bounds.upperBound), lower + step)
            }
        }
    }
}
