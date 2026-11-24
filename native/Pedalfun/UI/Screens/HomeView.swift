import SwiftUI

struct HomeView: View {
    @Environment(AppModel.self) private var model
    @Environment(SettingsStore.self) private var settings
    @Environment(RideStore.self) private var store
    @Environment(\.palette) private var pal

    @State private var permission: LocationPermission = .prompt
    @State private var grown = false
    /// The day whose numbers show under the bars; nil = today.
    @State private var picked: Int?
    @State private var startFrame: CGRect = .zero
    private static var autoStarted = false

    var body: some View {
        let f = settings.fmt
        let p = HomePresentation(
            WeekStats(rides: store.rides, profile: settings.profile),
            picked: picked, hasWeight: settings.weight != nil, f
        )

        ScreenScaffold {
            TopBar {
                Text("Pedalfun")
                    .font(.num(TypeScale.card, bold: false))
                    .foregroundStyle(pal.ink)
                    .padding(.leading, 10)
            } trailing: {
                IconButton(icon: "text.alignleft", label: "骑行记录") { model.go(.history) }
                IconButton(icon: "slider.horizontal.3", label: "设置") { model.go(.settings) }
            }
        } content: {
            VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    CellLabel("本周里程")
                    Spacer()
                    GPSChip(permission: permission)
                }
                HStack(alignment: .lastTextBaseline, spacing: 8) {
                    Num(p.weekDist, TypeScale.display)
                    Text(p.distUnit).font(.text(TextScale.title)).foregroundStyle(pal.ink2)
                }
                .padding(.top, 4)
                Text(p.weekSummary)
                    .font(.text(TextScale.note))
                    .foregroundStyle(pal.ink2)
                    .padding(.top, 12)

                WeekBars(bars: p.bars, grown: grown) { day in
                    Haptics.tap(.light, settings)
                    withAnimation(Motion.stateChange) { picked = day }
                }
                .frame(maxHeight: Metrics.barMaxHeight)
                .padding(.top, 22)
                dayDetail(p)
                    .padding(.top, 18)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, Metrics.side)
            .padding(.top, 22)

            if let last = store.rides.first {
                lastRide(last, f)
            }
            }
        } actions: {
                RoundButton(icon: "play.fill", label: "开始骑行", fill: pal.go) {
                    Task {
                        await model.startRide(
                            origin: CGPoint(x: startFrame.midX, y: startFrame.midY),
                            radius: startFrame.width / 2
                        )
                        permission = LocationRecorder().permission
                    }
                }
                .background {
                    GeometryReader { geo in
                        Color.clear
                            .onAppear { startFrame = geo.frame(in: .global) }
                            .onChange(of: geo.frame(in: .global)) { _, r in startFrame = r }
                    }
                }
        }
        .onAppear {
            permission = LocationRecorder().permission
            grown = true
            // Review hook: `-autostart 1` presses start once, to exercise the real flow unattended.
            if ProcessInfo.processInfo.arguments.contains("-autostart"), !HomeView.autoStarted {
                HomeView.autoStarted = true
                Task {
                    try? await Task.sleep(for: .seconds(1.2))
                    await model.startRide(
                        origin: CGPoint(x: startFrame.midX, y: startFrame.midY),
                        radius: startFrame.width / 2
                    )
                }
            }
        }
    }

    /// The picked day's totals. The four cells never move; a day without a
    /// ride shows "--".
    private func dayDetail(_ p: HomePresentation) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                CellLabel(p.dayTitle)
                Spacer()
                if p.showsWeightHint {
                    Button("填写体重以显示消耗") { model.go(.settings) }
                        .font(.text(TextScale.label))
                        .foregroundStyle(pal.goText)
                }
            }
            HStack(spacing: Metrics.gridGap) {
                ForEach(p.dayCells, id: \.label) { Stat($0, TypeScale.card) }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("day-detail")
    }

    private func lastRide(_ ride: Ride, _ f: Fmt) -> some View {
        Button {
            model.go(.summary(ride, live: false, fromHistory: false))
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    CellLabel("上次骑行，\(Fmt.date(ride.date))")
                    HStack(alignment: .lastTextBaseline, spacing: 4) {
                        Num(f.dist(ride.dist, digits: 1), TypeScale.card)
                        Text(f.distUnit).font(.text(TextScale.label)).foregroundStyle(pal.ink2)
                        Num(Fmt.dur(ride.moving), TypeScale.card).padding(.leading, 8)
                    }
                }
                Spacer(minLength: 8)
                ElevationProfile(samples: ride.samples, maxSeg: 30)
                    .frame(width: 110, height: 36)
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 12)
            .background(pal.surface, in: RoundedRectangle(cornerRadius: Metrics.cardRadius))
        }
        .buttonStyle(PressStyle(scale: 0.97))
        .padding(.horizontal, 16)
    }
}
