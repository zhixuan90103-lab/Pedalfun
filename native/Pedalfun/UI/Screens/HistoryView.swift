import SwiftUI

/// Rides grouped by month. Swipe a row left to delete it.
struct HistoryView: View {
    @Environment(AppModel.self) private var model
    @Environment(SettingsStore.self) private var settings
    @Environment(RideStore.self) private var store
    @Environment(\.palette) private var pal

    private struct Month: Identifiable {
        var id: String
        var rides: [Ride]
    }

    private var months: [Month] {
        var out: [Month] = []
        let cal = Calendar.current
        for r in store.rides {
            let c = cal.dateComponents([.year, .month], from: r.date)
            let key = "\(c.year ?? 0)年\(c.month ?? 0)月"
            if out.last?.id == key {
                out[out.count - 1].rides.append(r)
            } else {
                out.append(Month(id: key, rides: [r]))
            }
        }
        return out
    }

    var body: some View {
        let f = settings.fmt

        ScreenScaffold {
            TopBar(title: "骑行记录") {
                IconButton(icon: "chevron.left", label: "返回") { model.go(.home) }
            } trailing: {
                EmptyView()
            }
        } content: {
            if store.rides.isEmpty {
                Text("还没有骑行记录。回到首页，点开始按钮记下第一条。")
                    .font(.system(size: 15))
                    .foregroundStyle(pal.ink2)
                    .padding(.horizontal, Metrics.side)
                    .padding(.top, 40)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else {
                List {
                    ForEach(months) { month in
                        Section {
                            ForEach(month.rides) { ride in
                                row(ride, f)
                                    .listRowInsets(EdgeInsets())
                                    .listRowSeparator(.hidden)
                                    .listRowBackground(pal.bg)
                                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                        Button(role: .destructive) {
                                            Haptics.tap(.medium, settings)
                                            store.delete(ride.id)
                                            model.showToast("已删除")
                                        } label: {
                                            Image(systemName: "trash")
                                        }
                                        .tint(pal.stop)
                                    }
                            }
                        } header: {
                            header(month, f)
                                .listRowInsets(EdgeInsets())
                        }
                        .listSectionSeparator(.hidden)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .environment(\.defaultMinListRowHeight, 0)
                .contentMargins(.top, 0, for: .scrollContent)
            }
        }
    }

    private func header(_ month: Month, _ f: Fmt) -> some View {
        HStack(alignment: .lastTextBaseline) {
            Text(month.id)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(pal.ink)
            Spacer()
            HStack(alignment: .lastTextBaseline, spacing: 3) {
                Text("\(month.rides.count) 次，")
                Text(f.dist(month.rides.reduce(0) { $0 + $1.dist }, digits: 1))
                    .font(.num(TypeScale.inline))
                    .foregroundStyle(pal.ink)
                Text(f.distUnit)
            }
            .font(.system(size: 13))
            .foregroundStyle(pal.ink2)
        }
        .padding(.horizontal, Metrics.side)
        .padding(.top, 10)
        .padding(.bottom, 6)
        .frame(maxWidth: .infinity)
        .background(pal.bg)
    }

    private func row(_ ride: Ride, _ f: Fmt) -> some View {
        Button {
            model.go(.summary(ride, live: false, fromHistory: true))
        } label: {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 2) {
                    CellLabel("\(Fmt.date(ride.date))，\(ride.name)")
                    HStack(alignment: .lastTextBaseline, spacing: 4) {
                        Num(f.dist(ride.dist, digits: 1), TypeScale.emphasis)
                        small(f.distUnit)
                        Num(Fmt.dur(ride.moving), TypeScale.inline).padding(.leading, 8)
                        small("↑").padding(.leading, 8)
                        Num(f.alt(ride.climb), TypeScale.inline)
                        small(f.altUnit)
                    }
                }
                Spacer(minLength: 8)
                ElevationProfile(samples: ride.samples, maxSeg: 24)
                    .frame(width: 68, height: 32)
            }
            .padding(.horizontal, Metrics.side)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func small(_ text: String) -> some View {
        Text(text).font(.system(size: 13)).foregroundStyle(pal.ink2)
    }
}
