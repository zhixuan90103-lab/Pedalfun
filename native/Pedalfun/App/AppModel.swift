import Observation
import SwiftUI
import UIKit

enum Route: Equatable {
    case home, ride, history, settings
    case summary(Ride, live: Bool, fromHistory: Bool)

    var depth: Int {
        switch self {
        case .home: return 0
        case .ride, .history, .settings: return 1
        case .summary: return 2
        }
    }

    var key: String {
        switch self {
        case .home: return "home"
        case .ride: return "ride"
        case .history: return "history"
        case .settings: return "settings"
        case .summary(let r, _, _): return "summary-\(r.id)"
        }
    }
}

/// Start transition: green floods out of the start button, then retracts
/// upward to become the speed field of the riding screen.
enum Reveal: Equatable {
    case none
    case flood(expanded: Bool)
    case settle(retracted: Bool)
}

@Observable
final class AppModel {
    let settings = SettingsStore()
    let store = RideStore()

    private(set) var route: Route = .home
    private(set) var forward = true
    private(set) var session: RideSession?
    private(set) var toast: String?
    /// `-theme` launch argument; overrides the saved appearance for this launch only.
    private(set) var reviewTheme: ThemePref?

    private(set) var reveal: Reveal = .none
    private(set) var revealOrigin: CGPoint = .zero
    private(set) var revealRadius: CGFloat = 40
    /// Bottom edge of the riding screen's speed field, in global coordinates.
    var heroBottom: CGFloat = 300

    @ObservationIgnored private var toastTask: Task<Void, Never>?
    @ObservationIgnored private var starting = false

    init() {
        let args = ProcessInfo.processInfo.arguments
        func arg(_ name: String) -> String? {
            guard let i = args.firstIndex(of: name), i + 1 < args.count else { return nil }
            return args[i + 1]
        }
        // Review hooks: -mock 1 · -demo <state|screen> · -theme light|dark
        // Held here, not written to settings: a review launch must not change the user's choice.
        if let t = arg("-theme") { reviewTheme = ThemePref(rawValue: t) }
        store.load(mock: arg("-mock") == "1")
        if let demo = arg("-demo") {
            if let state = Demo.state(demo) {
                session = RideSession(settings: settings, demo: state)
                route = .ride
            } else if demo == "history" {
                route = .history
            } else if demo == "settings" {
                route = .settings
            } else if demo == "summary" || demo == "detail", let ride = store.rides.dropFirst(2).first ?? store.rides.first {
                route = .summary(ride, live: demo == "summary", fromHistory: true)
            }
        }
    }

    func go(_ next: Route) {
        forward = next.depth > route.depth
        withAnimation(Motion.push) {
            route = next
        }
    }

    func showToast(_ text: String) {
        toastTask?.cancel()
        withAnimation(Motion.toast) { toast = text }
        toastTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(2.2))
            guard !Task.isCancelled else { return }
            withAnimation(Motion.toast) { self?.toast = nil }
        }
    }

    

    /// `origin` / `radius`: the start button in global coordinates.
    @MainActor
    func startRide(origin: CGPoint, radius: CGFloat) async {
        guard !starting else { return }
        starting = true
        defer { starting = false }
        Haptics.tap(.medium, settings)

        let next = RideSession(settings: settings)
        do {
            // First run: the system permission prompt appears here, before leaving home.
            try await next.prepare()
        } catch {
            showToast(error.localizedDescription)
            return
        }
        session = next
        next.start()

        if UIAccessibility.isReduceMotionEnabled {
            route = .ride
            return
        }
        revealOrigin = origin
        revealRadius = radius
        reveal = .flood(expanded: false)
        try? await Task.sleep(for: .milliseconds(20))
        withAnimation(Motion.flood) { reveal = .flood(expanded: true) }
        try? await Task.sleep(for: .seconds(Motion.floodDuration + 0.01))

        forward = true
        var plain = Transaction()
        plain.disablesAnimations = true
        withTransaction(plain) {
            route = .ride
            reveal = .settle(retracted: false)
        }
        // One layout pass so the riding screen reports where its speed field ends.
        try? await Task.sleep(for: .milliseconds(40))
        withAnimation(Motion.settle) { reveal = .settle(retracted: true) }
        try? await Task.sleep(for: .seconds(Motion.settleDuration + 0.01))
        withTransaction(plain) { reveal = .none }
    }

    /// Finished rides are saved straight away; unwanted ones are deleted from the history list.
    func endRide() {
        guard let session else { return }
        session.stop()
        let (ride, track) = session.finish()
        // The session stays until the next ride starts, so the riding screen
        // keeps its numbers while it fades out.
        if session.isDemo {
            go(.summary(ride, live: true, fromHistory: false))
            return
        }
        if !store.add(ride, track: track) {
            showToast("没能写入存储，这次骑行只保留到关闭应用为止")
        }
        go(.summary(ride, live: true, fromHistory: false))
    }

    func exportGPX(_ ride: Ride) {
        guard let track = store.track(for: ride) else {
            showToast("这条记录没有轨迹，无法导出")
            return
        }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(GPX.fileName(ride))
        do {
            try GPX.make(ride, track: track).write(to: url, atomically: true, encoding: .utf8)
        } catch {
            showToast("导出失败")
            return
        }
        ShareSheet.present(url)
    }
}

enum ShareSheet {
    static func present(_ url: URL) {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        guard var top = scenes.flatMap(\.windows).first(where: \.isKeyWindow)?.rootViewController else { return }
        while let next = top.presentedViewController { top = next }
        let sheet = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        sheet.popoverPresentationController?.sourceView = top.view
        top.present(sheet, animated: true)
    }
}
