import Foundation

/// What the summary / ride detail screen shows for one ride: the headline and
/// the numbers sorted into categories. Laid out by `SummaryView`.
struct SummaryPresentation: Equatable {
    struct Group: Equatable, Identifiable {
        var title: String
        var cells: [StatCell]
        var id: String { title }
    }

    var topTitle: String
    var name: String
    var distText: String
    var distUnit: String
    /// right end of the elevation profile's scale
    var endLabel: String
    /// time, speed, altitude, energy: always these four, in this order
    var groups: [Group]

    /// `live`: the ride has just ended (and is already saved).
    init(_ ride: Ride, live: Bool, profile: Profile, _ f: Fmt) {
        topTitle = "\(Fmt.date(ride.date)) \(Fmt.clock(ride.date))"
        name = live ? "\(ride.name)，已保存" : ride.name
        distText = f.dist(ride.dist)
        distUnit = f.distUnit
        endLabel = "\(f.dist(ride.dist, digits: 1)) \(f.distUnit)"
        groups = [
            Group(title: "时间", cells: [
                StatCell("移动时间", nil, Fmt.dur(ride.moving)),
                StatCell("总耗时", nil, Fmt.dur(ride.total)),
            ]),
            Group(title: "速度", cells: [
                StatCell("均速", f.speedUnit, f.speed(ride.avg)),
                StatCell("最高", f.speedUnit, f.speed(ride.max)),
            ]),
            Group(title: "海拔", cells: [
                StatCell("爬升", f.altUnit, f.alt(ride.climb)),
                StatCell("最高", f.altUnit, f.alt(ride.altMax)),
            ]),
            Group(title: "消耗", cells: [
                StatCell("估算", "kcal", ride.kcal(profile).map(Fmt.kcal) ?? StatCell.none),
            ]),
        ]
    }
}
