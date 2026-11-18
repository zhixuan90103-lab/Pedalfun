import SwiftUI

/// A number in the numeral face with a tight line box, so big digits sit
/// close to their labels the way they do in the design.
struct Num: View {
    var text: String
    var size: CGFloat
    var bold = true
    var color: Color?

    @Environment(\.palette) private var pal

    init(_ text: String, _ size: CGFloat, bold: Bool = true, color: Color? = nil) {
        self.text = text
        self.size = size
        self.bold = bold
        self.color = color
    }

    var body: some View {
        Text(text)
            .font(.num(size, bold: bold))
            .foregroundStyle(color ?? pal.ink)
            .lineLimit(1)
            .fixedSize()
            .frame(height: size * 0.86)
    }
}

/// Small label above or beside a number: "爬升 m".
struct CellLabel: View {
    var text: String
    var unit: String?
    var color: Color?

    @Environment(\.palette) private var pal

    init(_ text: String, unit: String? = nil, color: Color? = nil) {
        self.text = text
        self.unit = unit
        self.color = color
    }

    var body: some View {
        (Text(text).foregroundColor(color ?? pal.ink2)
            + Text(unit.map { " \($0)" } ?? "").foregroundColor(color ?? pal.ink3))
            .font(.system(size: 13))
            .lineLimit(1)
    }
}

/// Three signal bars.
struct GPSBars: View {
    enum Level { case good, weak, off }
    var level: Level
    var color: Color?

    @Environment(\.palette) private var pal

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<3, id: \.self) { i in
                RoundedRectangle(cornerRadius: 2)
                    .fill(barColor(i))
                    .frame(width: 4, height: 12)
            }
        }
        .animation(.easeOut(duration: 0.25), value: level)
        .accessibilityHidden(true)
    }

    private func barColor(_ i: Int) -> Color {
        switch level {
        case .good: return color ?? pal.go
        case .weak: return i == 0 ? (color ?? pal.warn) : (color ?? pal.ink3).opacity(color == nil ? 1 : 0.35)
        case .off: return pal.ink3
        }
    }
}

struct GPSChip: View {
    var permission: LocationPermission

    @Environment(\.palette) private var pal

    var body: some View {
        HStack(spacing: 7) {
            Text(permission == .denied ? "定位未授权" : "GPS")
                .font(.system(size: 13))
                .foregroundStyle(permission == .denied ? pal.warn : pal.ink)
            GPSBars(level: permission == .granted ? .good : .off)
        }
        .padding(.horizontal, 12)
        .frame(height: 30)
        .background(pal.surface, in: Capsule())
    }
}
