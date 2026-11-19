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
        let week = WeekStats(rides: store.rides, profile: settings.profile)
        let sel = min(picked ?? week.todayIndex, week.todayIndex)

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
                    Num(f.dist(week.dist, digits: 1), TypeScale.display)
                    Text(f.distUnit).font(.system(size: 16)).foregroundStyle(pal.ink2)
                }
                .padding(.top, 4)
                Text(week.count == 0
                    ? "这周还没骑。"
                    : "\(week.count) 次骑行，\(Fmt.dur(week.moving))，爬升 \(f.alt(week.climb)) \(f.altUnit)")
                    .font(.system(size: 14))
                    .foregroundStyle(pal.ink2)
                    .padding(.top, 12)

                bars(week, sel, f)
                    .frame(maxHeight: 150)
                    .padding(.top, 22)
                dayDetail(week, sel, f)
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

    private static let weekdays = ["一", "二", "三", "四", "五", "六", "日"]

    /// Seven day bars, each with its distance and unit in the middle of the
    /// capsule, and weekday and date below. Tapping one picks that day; the picked bar is green.
    private func bars(_ week: WeekStats, _ sel: Int, _ f: Fmt) -> some View {
        let peak = max(week.perDay.max() ?? 0, 1)
        return HStack(spacing: 14) {
            ForEach(0..<7, id: \.self) { i in
                let day = week.days[i]
                let today = i == week.todayIndex
                let on = i == sel
                let future = i > week.todayIndex
                let ratio = day.dist > 0 ? max(0.06, day.dist / peak) : 0
                VStack(spacing: 8) {
                    GeometryReader { geo in
                        let h = geo.size.height
                        let fill: CGFloat = ratio > 0 ? max(geo.size.width, h * ratio) : 0
                        // The label sits mid-capsule when the fill reaches past it,
                        // otherwise in the empty track above the fill: never across the edge.
                        let half: CGFloat = 15
                        let covered = fill >= h / 2 + half
                        let above: CGFloat = min(max(h / 2, fill + half + 2), h - half - 4)
                        let centre: CGFloat = covered ? h / 2 : above
                        ZStack(alignment: .bottom) {
                            Capsule().fill(pal.surface)
                            Capsule()
                                .fill(on ? pal.go : pal.ink2)
                                .frame(height: fill)
                                .opacity(ratio > 0 ? 1 : 0)
                                .scaleEffect(y: grown ? 1 : 0, anchor: .bottom)
                                .animation(
                                    Motion.barGrow.delay(Double(i) * 0.045 + 0.08),
                                    value: grown
                                )
                            if day.dist > 0 {
                                VStack(spacing: 0) {
                                    Text(f.dist(day.dist, digits: 1)).font(.num(TypeScale.label))
                                    Text(f.distUnit).font(.system(size: 10, weight: .medium))
                                }
                                .foregroundStyle(covered ? (on ? Color.white : pal.bg) : pal.ink)
                                .lineLimit(1)
                                .fixedSize()
                                .position(x: geo.size.width / 2, y: h - centre)
                                .opacity(grown ? 1 : 0)
                                .animation(.easeOut(duration: 0.25).delay(Double(i) * 0.045 + 0.35), value: grown)
                            }
                        }
                    }
                    .opacity(future ? 0.5 : 1)
                    VStack(spacing: 1) {
                        Text(Self.weekdays[i])
                            .font(.system(size: 12, weight: today || on ? .semibold : .regular))
                            .foregroundStyle(today ? pal.goText : on ? pal.ink : pal.ink3)
                        Text("\(week.dayNumbers[i])")
                            .font(.num(15, bold: false))
                            .foregroundStyle(today ? pal.goText : on ? pal.ink : pal.ink2)
                    }
                }
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
                .onTapGesture {
                    guard !future, !on else { return }
                    Haptics.tap(.light, settings)
                    withAnimation(Motion.stateChange) { picked = i }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("周\(Self.weekdays[i])，\(f.dist(day.dist, digits: 1)) \(f.distUnit)")
                .accessibilityIdentifier("day-\(i)")
                .accessibilityAddTraits(on ? [.isButton, .isSelected] : .isButton)
            }
        }
    }

    /// The picked day's totals. The four cells never move; a day without a
    /// ride shows "--".
    private func dayDetail(_ week: WeekStats, _ sel: Int, _ f: Fmt) -> some View {
        let day = week.days[sel]
        let has = day.count > 0
        let title = sel == week.todayIndex ? "今天" : "周\(Self.weekdays[sel])"
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                CellLabel(has ? "\(title)，\(day.count) 次骑行" : "\(title)，没有骑行")
                Spacer()
                if settings.weight == nil {
                    Button("填写体重以显示消耗") { model.go(.settings) }
                        .font(.system(size: 13))
                        .foregroundStyle(pal.goText)
                }
            }
            HStack(spacing: Metrics.gridGap) {
                dayCell("里程", f.distUnit, has ? f.dist(day.dist, digits: 1) : "--")
                dayCell("均速", nil, has ? f.speed(day.avg) : "--")
                dayCell("时间", nil, has ? Fmt.dur(day.moving) : "--")
                dayCell("消耗", "kcal", has ? day.kcal.map(Fmt.kcal) ?? "--" : "--")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("day-detail")
    }

    private func dayCell(_ label: String, _ unit: String?, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            CellLabel(label, unit: unit)
            Num(value, TypeScale.card)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
                        Text(f.distUnit).font(.system(size: 13)).foregroundStyle(pal.ink2)
                        Num(Fmt.dur(ride.moving), TypeScale.card).padding(.leading, 8)
                    }
                }
                Spacer(minLength: 8)
                ElevationProfile(samples: ride.samples, maxSeg: 30)
                    .frame(width: 110, height: 36)
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 12)
            .background(pal.surface, in: RoundedRectangle(cornerRadius: 22))
        }
        .buttonStyle(PressStyle(scale: 0.97))
        .padding(.horizontal, 16)
    }
}
