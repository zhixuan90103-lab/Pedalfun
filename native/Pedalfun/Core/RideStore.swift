import Foundation
import Observation

struct Ride: Codable, Identifiable, Equatable {
    var id: String
    var date: Date
    var name: String
    /// metres
    var dist: Double
    /// seconds
    var moving: Double
    var total: Double
    /// km/h
    var max: Double
    /// metres
    var climb: Double
    var altMax: Double
    var samples: [Sample]
    /// the full path is stored in a separate file and loaded only for export
    var hasTrack: Bool

    var avg: Double { moving > 0 ? dist / moving * 3.6 : 0 }

    static func == (a: Ride, b: Ride) -> Bool { a.id == b.id }

    static func name(for date: Date) -> String {
        let h = Calendar.current.component(.hour, from: date)
        if h < 5 { return "夜骑" }
        if h < 11 { return "晨间骑行" }
        if h < 14 { return "午间骑行" }
        if h < 18 { return "午后骑行" }
        return "夜骑"
    }
}

/// Ride history on disk: one small JSON per ride plus one for its track, in
/// Application Support/rides. Summaries are all loaded at launch; tracks only
/// when exporting.
@Observable
final class RideStore {
    private(set) var rides: [Ride] = []

    private let dir: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("rides", isDirectory: true)
    }()

    private func url(_ id: String, track: Bool = false) -> URL {
        dir.appendingPathComponent(track ? "\(id).track.json" : "\(id).json")
    }

    func load(mock: Bool) {
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let files = (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? []
        var out: [Ride] = []
        for f in files where f.pathExtension == "json" && !f.lastPathComponent.hasSuffix(".track.json") {
            if let data = try? Data(contentsOf: f), let ride = try? JSONDecoder().decode(Ride.self, from: data) {
                out.append(ride)
            }
        }
        out.sort { $0.date > $1.date }
        rides = out + (mock ? Demo.rides() : [])
    }

    /// Returns false when the ride could not be written to disk (it stays in memory for this session).
    @discardableResult
    func add(_ ride: Ride, track: [[TrackPoint]]) -> Bool {
        rides.insert(ride, at: 0)
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            try JSONEncoder().encode(ride).write(to: url(ride.id), options: .atomic)
            if ride.hasTrack {
                try JSONEncoder().encode(track).write(to: url(ride.id, track: true), options: .atomic)
            }
            return true
        } catch {
            return false
        }
    }

    func delete(_ id: String) {
        rides.removeAll { $0.id == id }
        try? FileManager.default.removeItem(at: url(id))
        try? FileManager.default.removeItem(at: url(id, track: true))
    }

    func track(for ride: Ride) -> [[TrackPoint]]? {
        guard ride.hasTrack, let data = try? Data(contentsOf: url(ride.id, track: true)) else { return nil }
        return try? JSONDecoder().decode([[TrackPoint]].self, from: data)
    }
}
