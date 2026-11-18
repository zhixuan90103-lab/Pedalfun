import Foundation

enum GPX {
    static func fileName(_ ride: Ride) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd-HHmm"
        return "pedalfun-\(f.string(from: ride.date)).gpx"
    }

    static func make(_ ride: Ride, track: [[TrackPoint]]) -> String {
        let iso = ISO8601DateFormatter()
        let name = ride.name
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
        var out = """
        <?xml version="1.0" encoding="UTF-8"?>
        <gpx version="1.1" creator="Pedalfun" xmlns="http://www.topografix.com/GPX/1/1">
          <metadata><time>\(iso.string(from: ride.date))</time></metadata>
          <trk>
            <name>\(name)</name>
            <type>cycling</type>

        """
        for seg in track where seg.count > 1 {
            out += "    <trkseg>\n"
            for p in seg {
                let time = iso.string(from: Date(timeIntervalSince1970: p.t))
                out += String(format: "      <trkpt lat=\"%.7f\" lon=\"%.7f\"><ele>%.1f</ele><time>%@</time></trkpt>\n", p.lat, p.lon, p.ele, time)
            }
            out += "    </trkseg>\n"
        }
        out += "  </trk>\n</gpx>\n"
        return out
    }
}
