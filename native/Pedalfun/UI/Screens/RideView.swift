import SwiftUI

/// Riding screen. Positions never move; state only changes emphasis:
/// the speed field colour (moving / auto-paused / paused), the grade capsule
/// (red uphill, green downhill), and the bottom buttons.
///
/// What to show is decided by `RidePresentation`; this file only lays it out.
struct RideView: View {
    @Environment(AppModel.self) private var model
    @Environment(SettingsStore.self) private var settings
    @Environment(\.palette) private var pal

    /// Drives the entrance: data tiers rise in, then the pause button fades and scales in.
    @State private var appeared = false
    @State private var gradePop: CGFloat = 1
    @State private var maxFlash = false

    private var state: RideState { model.session?.state ?? RideState() }

    var body: some View {
        let s = state
        let p = RidePresentation(s, settings.fmt)

        ScreenScaffold {
            hero(p, gpsWeak: s.gpsWeak)
        } content: {
            tiers(p, samples: s.samples)
        } actions: {
            actions(p)
        }
        .onAppear { appeared = true }
        .onChange(of: p.band) { old, new in
            // Pop only when the capsule appears, not when it changes colour.
            guard old == .flat, new != .flat else { return }
            gradePop = 0.86
            withAnimation(Motion.gradePop) { gradePop = 1 }
        }
        .onChange(of: s.max) { old, new in
            // New top speed: one short highlight, only once the ride is under way.
            guard new > old + 0.05, s.moving > 45 else { return }
            maxFlash = true
            withAnimation(.easeOut(duration: 1.0).delay(0.6)) { maxFlash = false }
        }
    }

    // MARK: speed field

    private func hero(_ p: RidePresentation, gpsWeak: Bool) -> some View {
        let field: Color = p.field == .paused ? pal.fieldPaused : p.field == .autoPaused ? pal.fieldAuto : pal.field
        let ink: Color = p.field == .paused ? pal.dim : .white

        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                GPSBars(level: gpsWeak ? .weak : .good, color: ink)
                Text(p.statusText)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(p.weak ? Palette.warnOnField : ink)
                    .padding(.horizontal, p.weak ? 10 : 0)
                    .padding(.vertical, 3)
                    .background(p.weak ? Palette.warnChip : .clear, in: Capsule())
            }
            .frame(height: 24)

            // Unit sits bottom-right, level with the foot of the digits.
            HStack(alignment: .bottom) {
                Num(p.speedText, TypeScale.hero, color: ink)
                    .minimumScaleFactor(0.6)
                    .opacity(p.weak ? 0.45 : 1)
                Spacer(minLength: 8)
                Text(p.speedUnit)
                    .font(.num(TypeScale.unit, bold: false))
                    .foregroundStyle(ink.opacity(0.85))
                    .padding(.bottom, 2)
            }
        }
        .padding(.horizontal, Metrics.side)
        .padding(.top, 12)
        .padding(.bottom, 22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(field.ignoresSafeArea(edges: .top))
        .background {
            // The start transition retracts to exactly this edge.
            GeometryReader { geo in
                Color.clear
                    .onAppear { model.heroBottom = geo.frame(in: .global).maxY }
                    .onChange(of: geo.frame(in: .global).maxY) { _, y in model.heroBottom = y }
            }
        }
        .animation(Motion.stateChange, value: p.field)
    }

    // MARK: data

    /// Three tiers on one four-column grid, so every left edge lines up:
    /// primary (time, distance) / secondary (four small stats) / terrain.
    private func tiers(_ p: RidePresentation, samples: [Sample]) -> some View {
        GeometryReader { geo in
            let gap = Metrics.gridGap
            let col = (geo.size.width - gap * 3) / 4

            VStack(spacing: 0) {
                Spacer(minLength: 0)
                HStack(spacing: gap) {
                    cell(p.timeLabel, nil, p.timeText, TypeScale.primary)
                    cell("里程", p.distUnit, p.distText, TypeScale.primary)
                }
                .modifier(RiseIn(shown: appeared, delay: 0))
                Spacer(minLength: 0)
                rule
                Spacer(minLength: 0)
                HStack(spacing: gap) {
                    cell("均速", nil, p.avgText, TypeScale.secondary)
                    cell("最高", nil, p.maxText, TypeScale.secondary, color: maxFlash ? pal.goText : nil)
                    cell("爬升", p.altUnit, p.climbText, TypeScale.secondary)
                    cell("海拔", p.altUnit, p.altText, TypeScale.secondary)
                }
                .modifier(RiseIn(shown: appeared, delay: Motion.riseStep))
                Spacer(minLength: 0)
                rule
                Spacer(minLength: 0)
                HStack(spacing: gap) {
                    gradeCell(p)
                        .frame(width: col, alignment: .leading)
                    ElevationProfile(samples: samples, maxSeg: 40)
                        .frame(height: 50)
                }
                .modifier(RiseIn(shown: appeared, delay: Motion.riseStep * 2))
                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, Metrics.side)
        .padding(.top, 4)
    }

    private var rule: some View {
        Rectangle().fill(pal.surface).frame(height: 1)
    }

    private func cell(_ label: String, _ unit: String?, _ value: String, _ size: CGFloat, color: Color? = nil) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            CellLabel(label, unit: unit)
            Num(value, size, color: color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// The capsule hugs the text with equal padding on both sides. The text
    /// keeps its place on the grid whether or not the capsule is showing.
    private func gradeCell(_ p: RidePresentation) -> some View {
        let on = p.band != .flat
        return VStack(alignment: .leading, spacing: 3) {
            CellLabel(p.gradeLabel, color: on ? .white : nil)
            Num(p.gradeText, TypeScale.emphasis, color: on ? .white : nil)
        }
        .background {
            Capsule()
                .fill(on ? pal.band(p.band) : .clear)
                .padding(.horizontal, -Metrics.capsulePad.width)
                .padding(.vertical, -Metrics.capsulePad.height)
        }
        .scaleEffect(gradePop)
        .animation(Motion.stateChange, value: p.band)
    }

    // MARK: buttons

    @ViewBuilder private func actions(_ p: RidePresentation) -> some View {
        if p.showsPausedActions {
            RoundButton(icon: "play.fill", label: "继续", fill: pal.go) {
                Haptics.tap(.medium, settings)
                withAnimation(Motion.split) { model.session?.resume() }
            }
            .transition(.asymmetric(
                insertion: .offset(x: 82).combined(with: .scale(scale: 0.8)).combined(with: .opacity),
                removal: .identity
            ))
            HoldButton(icon: "stop.fill", label: "结束骑行，长按", fill: pal.stop, ring: pal.stop) {
                model.showToast("长按结束骑行")
            } action: {
                model.endRide()
            }
            .transition(.asymmetric(
                insertion: .offset(x: -82).combined(with: .scale(scale: 0.8)).combined(with: .opacity),
                removal: .identity
            ))
        } else {
            RoundButton(icon: "pause.fill", label: "暂停", fill: pal.go) {
                Haptics.tap(.medium, settings)
                withAnimation(Motion.split) { model.session?.pause() }
            }
            // Entrance belongs to the button alone and starts from its hidden
            // state, so it is never drawn full-size first and then animated.
            .scaleEffect(appeared ? 1 : 0.4)
            .opacity(appeared ? 1 : 0)
            .animation(Motion.pauseEnter, value: appeared)
            .transition(.asymmetric(
                insertion: .scale(scale: 0.5).combined(with: .opacity),
                removal: .identity
            ))
        }
    }
}

/// Fades up into place once `shown` turns true.
private struct RiseIn: ViewModifier {
    var shown: Bool
    var delay: Double

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown ? 0 : 14)
            .animation(Motion.rise.delay(delay), value: shown)
    }
}
