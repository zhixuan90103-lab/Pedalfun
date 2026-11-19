import CoreLocation
import CoreMotion
import Foundation

enum RideError: LocalizedError {
    case denied
    case unavailable

    var errorDescription: String? {
        switch self {
        case .denied: return "没有定位权限。请到 设置 > 隐私与安全性 > 定位服务 里允许 Pedalfun 使用定位。"
        case .unavailable: return "无法开始定位。"
        }
    }
}

enum LocationPermission {
    case granted, prompt, denied
}

/// Location + barometer + accelerometer for one ride. Keeps running with the
/// screen locked (background location mode) and delivers each fix on the main
/// thread, already tagged with barometric altitude and vibration level.
final class LocationRecorder: NSObject, CLLocationManagerDelegate {
    var onFix: ((Fix) -> Void)?

    private let manager = CLLocationManager()
    private let altimeter = CMAltimeter()
    private let motion = CMMotionManager()
    private let sensorQueue: OperationQueue = {
        let q = OperationQueue()
        q.maxConcurrentOperationCount = 1
        return q
    }()

    /// Guards the sensor values, written on the sensor queue and read on main.
    private let lock = NSLock()
    private var baro: Double?
    private var motionLevel: Double?
    private var motionEma = 0.0

    private var pending: CheckedContinuation<Void, Error>?
    private var running = false

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        manager.distanceFilter = kCLDistanceFilterNone
        manager.activityType = .fitness
        manager.pausesLocationUpdatesAutomatically = false
    }

    var permission: LocationPermission {
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse: return .granted
        case .denied, .restricted: return .denied
        default: return .prompt
        }
    }

    /// Asks for location access on first use. Throws `RideError.denied` when refused.
    func requestPermission() async throws {
        switch permission {
        case .granted: return
        case .denied: throw RideError.denied
        case .prompt:
            try await withCheckedThrowingContinuation { (c: CheckedContinuation<Void, Error>) in
                pending = c
                manager.requestWhenInUseAuthorization()
            }
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard let c = pending else { return }
        switch permission {
        case .granted:
            pending = nil
            c.resume()
        case .denied:
            pending = nil
            c.resume(throwing: RideError.denied)
        case .prompt:
            break
        }
    }

    func start() {
        guard !running else { return }
        running = true
        lock.lock()
        baro = nil
        motionLevel = nil
        motionEma = 0
        lock.unlock()

        // Setting this without the background mode declared crashes the app.
        let modes = Bundle.main.object(forInfoDictionaryKey: "UIBackgroundModes") as? [String] ?? []
        if modes.contains("location") {
            manager.allowsBackgroundLocationUpdates = true
            manager.showsBackgroundLocationIndicator = true
        }
        manager.startUpdatingLocation()

        if CMAltimeter.isRelativeAltitudeAvailable() {
            altimeter.startRelativeAltitudeUpdates(to: sensorQueue) { [weak self] data, _ in
                guard let self, let data else { return }
                self.lock.lock()
                self.baro = data.relativeAltitude.doubleValue
                self.lock.unlock()
            }
        }

        if motion.isAccelerometerAvailable {
            motion.accelerometerUpdateInterval = 1.0 / 25.0
            motion.startAccelerometerUpdates(to: sensorQueue) { [weak self] data, _ in
                guard let self, let a = data?.acceleration else { return }
                // Deviation of |a| from 1 g: road buzz and pedalling raise it, a parked bike is ~0.
                let dev = (a.x * a.x + a.y * a.y + a.z * a.z).squareRoot() - 1.0
                self.lock.lock()
                // ~1 s time constant at 25 Hz.
                self.motionEma += (dev * dev - self.motionEma) * 0.04
                self.motionLevel = self.motionEma.squareRoot()
                self.lock.unlock()
            }
        }
    }

    func stop() {
        guard running else { return }
        running = false
        manager.stopUpdatingLocation()
        manager.allowsBackgroundLocationUpdates = false
        altimeter.stopRelativeAltitudeUpdates()
        motion.stopAccelerometerUpdates()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        lock.lock()
        let baro = self.baro
        let motionLevel = self.motionLevel
        lock.unlock()
        for loc in locations {
            onFix?(Fix(
                t: loc.timestamp.timeIntervalSince1970,
                lat: loc.coordinate.latitude,
                lon: loc.coordinate.longitude,
                speed: loc.speed,
                speedAcc: loc.speedAccuracy,
                hAcc: loc.horizontalAccuracy,
                alt: loc.verticalAccuracy >= 0 ? loc.altitude : nil,
                baro: baro,
                motion: motionLevel
            ))
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {}
}
