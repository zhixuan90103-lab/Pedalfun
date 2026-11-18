import SwiftUI

/// Flat stepped elevation profile; each segment is filled by its grade band
/// (red uphill, green downhill, grey flat).
struct ElevationProfile: View {
    var samples: [Sample]
    var maxSeg = 56

    @Environment(\.palette) private var pal

    var body: some View {
        Canvas { ctx, size in
            guard samples.count > 1, let first = samples.first, let last = samples.last, last.d - first.d >= 1 else {
                ctx.fill(Path(CGRect(x: 0, y: size.height - 3, width: size.width, height: 3)), with: .color(pal.flat))
                return
            }
            let n = min(maxSeg, samples.count - 1)
            let pts = (0...n).map { samples[Int((Double($0) / Double(n) * Double(samples.count - 1)).rounded())] }
            let span = pts[n].d - pts[0].d
            let lo = pts.map(\.a).min() ?? 0
            let hi = pts.map(\.a).max() ?? 0
            let range = max(hi - lo, 24)
            let floor: CGFloat = 6
            func x(_ p: Sample) -> CGFloat { CGFloat((p.d - pts[0].d) / span) * size.width }
            func y(_ p: Sample) -> CGFloat { size.height - floor - CGFloat((p.a - lo) / range) * (size.height - floor - 2) }
            for i in 0..<n {
                let a = pts[i], b = pts[i + 1]
                let run = b.d - a.d
                if run <= 0 { continue }
                var path = Path()
                // Half-point overlap hides hairline seams between segments.
                path.move(to: CGPoint(x: x(a), y: size.height))
                path.addLine(to: CGPoint(x: x(a), y: y(a)))
                path.addLine(to: CGPoint(x: x(b) + 0.5, y: y(b)))
                path.addLine(to: CGPoint(x: x(b) + 0.5, y: size.height))
                path.closeSubpath()
                ctx.fill(path, with: .color(pal.band(GradeBand((b.a - a.a) / run * 100))))
            }
        }
        .accessibilityHidden(true)
    }
}
