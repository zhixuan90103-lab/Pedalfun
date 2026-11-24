import SwiftUI

/// Seven day bars. Each carries its distance and unit in the middle of the
/// capsule and its weekday and date below. Tapping a bar picks that day; the
/// picked bar is green.
struct WeekBars: View {
    var bars: [HomePresentation.Bar]
    /// false until the screen has appeared, so the bars grow in once
    var grown: Bool
    var onPick: (Int) -> Void

    @Environment(\.palette) private var pal

    var body: some View {
        HStack(spacing: Metrics.barGap) {
            ForEach(bars) { bar in
                VStack(spacing: 8) {
                    capsule(bar)
                        .opacity(bar.isFuture ? 0.5 : 1)
                    VStack(spacing: 1) {
                        Text(bar.weekday)
                            .font(.text(TextScale.caption, bar.isToday || bar.isPicked ? .semibold : .regular))
                            .foregroundStyle(bar.isToday ? pal.goText : bar.isPicked ? pal.ink : pal.ink3)
                        Text("\(bar.dayNumber)")
                            .font(.num(TypeScale.date, bold: false))
                            .foregroundStyle(bar.isToday ? pal.goText : bar.isPicked ? pal.ink : pal.ink2)
                    }
                }
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
                .onTapGesture {
                    guard !bar.isFuture, !bar.isPicked else { return }
                    onPick(bar.id)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(bar.accessibilityLabel)
                .accessibilityIdentifier("day-\(bar.id)")
                .accessibilityAddTraits(bar.isPicked ? [.isButton, .isSelected] : .isButton)
            }
        }
    }

    private func capsule(_ bar: HomePresentation.Bar) -> some View {
        GeometryReader { geo in
            let h = geo.size.height
            // A day with a ride is never shorter than a full circle.
            let fill: CGFloat = bar.ratio > 0 ? max(geo.size.width, h * bar.ratio) : 0
            let place = HomePresentation.labelPlace(height: h, fill: fill, half: Metrics.barLabelHalf)
            let step = Double(bar.id) * Motion.barStep + Motion.barDelay
            ZStack(alignment: .bottom) {
                Capsule().fill(pal.surface)
                Capsule()
                    .fill(bar.isPicked ? pal.go : pal.ink2)
                    .frame(height: fill)
                    .opacity(bar.ratio > 0 ? 1 : 0)
                    .scaleEffect(y: grown ? 1 : 0, anchor: .bottom)
                    .animation(Motion.barGrow.delay(step), value: grown)
                if let text = bar.text {
                    VStack(spacing: 0) {
                        Text(text).font(.num(TypeScale.label))
                        Text(bar.unit).font(.text(TextScale.micro, .medium))
                    }
                    // On the fill the label must contrast with it; on the track it is plain text.
                    .foregroundStyle(place.onFill ? (bar.isPicked ? Color.white : pal.bg) : pal.ink)
                    .lineLimit(1)
                    .fixedSize()
                    .position(x: geo.size.width / 2, y: h - place.centre)
                    .opacity(grown ? 1 : 0)
                    .animation(Motion.barLabel.delay(step), value: grown)
                }
            }
        }
    }
}
