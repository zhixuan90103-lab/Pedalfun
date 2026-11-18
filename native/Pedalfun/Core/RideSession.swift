import Foundation
import Observation
import UIKit

/// One ride in progress: location recorder → tracker → `state` for the UI.
/// Everything runs natively, so recording continues with the screen locked.
@Observable
final class RideSession {
    private(set) var state: RideState

    @ObservationIgnored private var tracker: RideTracker
    @ObservationIgnored private let recorder: LocationRecorder?
    @ObservationIgnored private let settings: SettingsStore
    @ObservationIgnored private var timer: Timer?

    init(settings: SettingsStore) {
        self.settings = settings
        recorder = LocationRecorder()
        tracker = RideTracker(autoPause: { settings.autoPause })
        state = tracker.state
    }

    /// A frozen state with no sensors, for screenshots (`-demo` launch argument).
    init(settings: SettingsStore, demo: RideState) {
        self.settings = settings
        recorder = nil
        tracker = RideTracker(autoPause: { false })
        state = demo
    }

    var isDemo: Bool { recorder == nil }

    /// Asks for location access on first use. Throws a `RideError` with a user-facing message.
    func prepare() async throws {
        try await recorder?.requestPermission()
    }

    func start() {
        guard let recorder else { return }
        let settings = self.settings
        tracker = RideTracker(autoPause: { settings.autoPause })
        state = tracker.state
        recorder.onFix = { [weak self] fix in self?.ingest(fix) }
        recorder.start()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in self?.tick() }
        UIApplication.shared.isIdleTimerDisabled = settings.keepAwake
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        recorder?.stop()
        UIApplication.shared.isIdleTimerDisabled = false
    }

    func pause() {
        if isDemo {
            state.status = .paused
            state.speed = 0
            state.grade = 0
            return
        }
        tracker.pause()
        publish()
    }

    func resume() {
        if isDemo {
            state.status = .moving
            return
        }
        tracker.resume()
        publish()
    }

    private func ingest(_ fix: Fix) {
        let before = tracker.state.status
        tracker.push(fix)
        let after = tracker.state.status
        if before != after {
            if after == .autoPaused { Haptics.tap(.light, settings) }
            if after == .moving && before == .autoPaused { Haptics.tap(.medium, settings) }
        }
        publish()
    }

    private func tick() {
        publish()
    }

    private func publish() {
        tracker.setTotal(Date().timeIntervalSince(tracker.state.startedAt))
        state = tracker.state
    }

    /// The finished ride and its track, ready to store.
    func finish() -> (ride: Ride, track: [[TrackPoint]]) {
        let s = state
        let track = s.track.filter { $0.count > 1 }
        let ride = Ride(
            id: "ride-\(Int(s.startedAt.timeIntervalSince1970 * 1000))",
            date: s.startedAt,
            name: Ride.name(for: s.startedAt),
            dist: s.dist,
            moving: s.moving,
            total: s.total,
            max: s.max,
            climb: s.climb,
            altMax: s.altMax,
            samples: s.samples,
            hasTrack: !track.isEmpty
        )
        return (ride, track)
    }
}
