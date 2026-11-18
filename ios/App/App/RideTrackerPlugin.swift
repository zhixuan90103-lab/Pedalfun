import Capacitor
import CoreLocation
import CoreMotion
import UIKit

/// Records location for a ride and hands it to JS in batches.
///
/// Fixes go into a native buffer with a sequence number. JS calls `drain`
/// about once a second and acknowledges what it has processed. While the
/// screen is locked or the app is in the background the web view may be
/// suspended, but this keeps recording; the next `drain` returns everything.
///
/// Each fix also carries the barometric altitude relative to the start
/// (much steadier than GPS altitude) and a recent accelerometer vibration
/// level, which JS uses to tell "stopped" from GPS drift.
@objc(RideTrackerPlugin)
public class RideTrackerPlugin: CAPPlugin, CAPBridgedPlugin, CLLocationManagerDelegate {
    public let identifier = "RideTrackerPlugin"
    public let jsName = "RideTracker"
    public let pluginMethods: [CAPPluginMethod] = [
        CAPPluginMethod(name: "permission", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "start", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "stop", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "drain", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "shareFile", returnType: CAPPluginReturnPromise),
    ]

    private var manager: CLLocationManager?
    private let altimeter = CMAltimeter()
    private let motion = CMMotionManager()
    private let sensorQueue: OperationQueue = {
        let q = OperationQueue()
        q.maxConcurrentOperationCount = 1
        return q
    }()

    /// Guards everything below, which is touched from the main thread,
    /// the sensor queue and the bridge queue.
    private let lock = NSLock()
    private var buffer: [[String: Any]] = []
    private var seq = 0
    private var baro: Double?
    private var motionLevel: Double?
    private var motionEma = 0.0

    private var pendingStart: CAPPluginCall?
    private var running = false

    /// Hard cap so a ride that is never drained cannot grow without bound (~11 h at 1 Hz).
    private let maxBuffered = 40_000

    override public func load() {
        DispatchQueue.main.async {
            let m = CLLocationManager()
            m.delegate = self
            m.desiredAccuracy = kCLLocationAccuracyBestForNavigation
            m.distanceFilter = kCLDistanceFilterNone
            m.activityType = .fitness
            m.pausesLocationUpdatesAutomatically = false
            self.manager = m
        }
    }

    // MARK: - permission

    private func permissionState() -> String {
        switch manager?.authorizationStatus ?? .notDetermined {
        case .authorizedAlways, .authorizedWhenInUse: return "granted"
        case .denied, .restricted: return "denied"
        default: return "prompt"
        }
    }

    @objc func permission(_ call: CAPPluginCall) {
        DispatchQueue.main.async {
            call.resolve(["state": self.permissionState()])
        }
    }

    // MARK: - start / stop

    @objc func start(_ call: CAPPluginCall) {
        DispatchQueue.main.async {
            guard let manager = self.manager else {
                call.reject("location manager unavailable")
                return
            }
            switch self.permissionState() {
            case "granted":
                self.begin()
                call.resolve()
            case "denied":
                call.reject("denied")
            default:
                // Resolved in locationManagerDidChangeAuthorization.
                self.pendingStart?.reject("superseded")
                self.pendingStart = call
                manager.requestWhenInUseAuthorization()
            }
        }
    }

    public func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard let call = pendingStart else { return }
        switch permissionState() {
        case "granted":
            pendingStart = nil
            begin()
            call.resolve()
        case "denied":
            pendingStart = nil
            call.reject("denied")
        default:
            break
        }
    }

    /// Main thread only.
    private func begin() {
        guard let manager = manager else { return }
        lock.lock()
        buffer.removeAll()
        seq = 0
        baro = nil
        motionLevel = nil
        motionEma = 0
        lock.unlock()

        // Setting this without the background mode declared crashes the app.
        let modes = Bundle.main.object(forInfoDictionaryKey: "UIBackgroundModes") as? [String] ?? []
        if modes.contains("location") {
            manager.allowsBackgroundLocationUpdates = true
            manager.showsBackgroundLocationIndicator = true
        } else {
            CAPLog.print("⚠️ RideTracker: UIBackgroundModes lacks 'location'; recording stops when the screen locks. Run npm run ios:bootstrap.")
        }
        manager.startUpdatingLocation()

        if CMAltimeter.isRelativeAltitudeAvailable() {
            altimeter.startRelativeAltitudeUpdates(to: sensorQueue) { [weak self] data, _ in
                guard let self = self, let data = data else { return }
                self.lock.lock()
                self.baro = data.relativeAltitude.doubleValue
                self.lock.unlock()
            }
        }

        if motion.isAccelerometerAvailable {
            motion.accelerometerUpdateInterval = 1.0 / 25.0
            motion.startAccelerometerUpdates(to: sensorQueue) { [weak self] data, _ in
                guard let self = self, let a = data?.acceleration else { return }
                // Deviation of |a| from 1 g: road buzz and pedalling raise it, a parked bike is ~0.
                let dev = (a.x * a.x + a.y * a.y + a.z * a.z).squareRoot() - 1.0
                self.lock.lock()
                // ~1 s time constant at 25 Hz.
                self.motionEma += (dev * dev - self.motionEma) * 0.04
                self.motionLevel = self.motionEma.squareRoot()
                self.lock.unlock()
            }
        }
        running = true
    }

    @objc func stop(_ call: CAPPluginCall) {
        DispatchQueue.main.async {
            self.pendingStart?.reject("stopped")
            self.pendingStart = nil
            if self.running {
                self.manager?.stopUpdatingLocation()
                self.manager?.allowsBackgroundLocationUpdates = false
                self.altimeter.stopRelativeAltitudeUpdates()
                self.motion.stopAccelerometerUpdates()
                self.running = false
            }
            self.lock.lock()
            self.buffer.removeAll()
            self.lock.unlock()
            call.resolve()
        }
    }

    // MARK: - fixes

    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        lock.lock()
        defer { lock.unlock() }
        for loc in locations {
            seq += 1
            buffer.append([
                "seq": seq,
                "t": (loc.timestamp.timeIntervalSince1970 * 1000).rounded(),
                "lat": loc.coordinate.latitude,
                "lon": loc.coordinate.longitude,
                "speed": loc.speed,
                "hAcc": loc.horizontalAccuracy,
                "alt": loc.verticalAccuracy >= 0 ? loc.altitude as Any : NSNull(),
                "vAcc": loc.verticalAccuracy >= 0 ? loc.verticalAccuracy as Any : NSNull(),
                "baro": baro.map { $0 as Any } ?? NSNull(),
                "motion": motionLevel.map { $0 as Any } ?? NSNull(),
            ])
        }
        if buffer.count > maxBuffered {
            buffer.removeFirst(buffer.count - maxBuffered)
        }
    }

    public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        CAPLog.print("RideTracker location error: \(error.localizedDescription)")
    }

    /// Returns fixes newer than `after` and forgets the ones JS has acknowledged.
    @objc func drain(_ call: CAPPluginCall) {
        let after = call.getInt("after") ?? 0
        lock.lock()
        buffer.removeAll { ($0["seq"] as? Int ?? 0) <= after }
        let out = buffer
        lock.unlock()
        call.resolve(["fixes": out])
    }

    // MARK: - share

    @objc func shareFile(_ call: CAPPluginCall) {
        guard let name = call.getString("name"), let text = call.getString("text") else {
            call.reject("name and text are required")
            return
        }
        let safeName = (name as NSString).lastPathComponent
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(safeName)
        do {
            try text.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            call.reject("could not write file: \(error.localizedDescription)")
            return
        }
        DispatchQueue.main.async {
            guard let host = self.bridge?.viewController else {
                call.reject("no view controller")
                return
            }
            let sheet = UIActivityViewController(activityItems: [url], applicationActivities: nil)
            if let pop = sheet.popoverPresentationController {
                pop.sourceView = host.view
                pop.sourceRect = CGRect(x: host.view.bounds.midX, y: host.view.bounds.maxY - 80, width: 1, height: 1)
            }
            host.present(sheet, animated: true) {
                call.resolve()
            }
        }
    }
}
