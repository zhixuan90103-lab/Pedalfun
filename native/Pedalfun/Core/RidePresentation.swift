import Foundation

/// What the riding screen shows for a given ride state. All the "which text,
/// which colour, which emphasis" decisions live here, away from layout, so
/// they can be unit-tested and so the screen itself only places things.
struct RidePresentation: Equatable {
    enum Field: Equatable {
        /// green: recording
        case moving
        /// grey: stopped by auto-pause
        case autoPaused
        /// dark, dimmed numerals: paused by the rider
        case paused
    }

    var field: Field
    /// GPS is too poor to trust the speed. Only reported while moving.
    var weak: Bool
    var statusText: String
    /// "--" while the speed cannot be trusted
    var speedText: String
    var speedUnit: String

    var timeLabel: String
    var timeText: String
    var distText: String
    var distUnit: String

    var avgText: String
    var maxText: String
    var climbText: String
    var altText: String
    var altUnit: String

    /// Flat whenever the clock is stopped: a parked bike has no grade.
    var band: GradeBand
    var gradeLabel: String
    var gradeText: String

    var showsPausedActions: Bool

    init(_ s: RideState, _ f: Fmt) {
        switch s.status {
        case .moving: field = .moving
        case .autoPaused: field = .autoPaused
        case .paused: field = .paused
        }
        weak = s.gpsWeak && s.status == .moving

        switch s.status {
        case .paused: statusText = "已暂停"
        case .autoPaused: statusText = "自动暂停，起步后继续"
        case .moving: statusText = weak ? "GPS 信号弱，速度暂不可用" : "记录中"
        }
        speedText = weak ? "--" : f.speed(s.speed)
        speedUnit = f.speedUnit

        timeLabel = s.status == .moving ? "时间" : "时间（已停表）"
        timeText = Fmt.dur(s.moving)
        distText = f.dist(s.dist)
        distUnit = f.distUnit

        avgText = f.speed(s.avg)
        maxText = f.speed(s.max)
        climbText = f.alt(s.climb)
        altText = f.alt(s.alt)
        altUnit = f.altUnit

        band = s.status == .moving ? GradeBand(s.grade) : .flat
        switch band {
        case .flat: gradeLabel = "坡度 %"
        case .down: gradeLabel = "下坡 %"
        case .up: gradeLabel = "上坡 %"
        }
        gradeText = s.status == .moving ? Fmt.grade(s.grade) : "0.0"

        showsPausedActions = s.status == .paused
    }
}
