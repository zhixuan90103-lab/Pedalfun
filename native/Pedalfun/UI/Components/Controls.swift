import SwiftUI

/// Segmented control: the selected pill slides between options.
struct PillPicker<Value: Hashable>: View {
    @Binding var selection: Value
    var options: [(Value, String)]

    @Environment(SettingsStore.self) private var settings
    @Environment(\.palette) private var pal
    @Namespace private var ns

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options, id: \.0) { value, title in
                let on = value == selection
                Text(title)
                    .font(.text(TextScale.note))
                    .foregroundStyle(on ? pal.bg : pal.ink2)
                    .lineLimit(1)
                    .fixedSize()
                    .padding(.horizontal, 13)
                    .frame(minWidth: 46, minHeight: 36)
                    .background {
                        if on {
                            Capsule().fill(pal.ink).matchedGeometryEffect(id: "thumb", in: ns)
                        }
                    }
                    .contentShape(Capsule())
                    .onTapGesture {
                        guard !on else { return }
                        Haptics.tap(.light, settings)
                        withAnimation(Motion.select) { selection = value }
                    }
                    .accessibilityAddTraits(on ? [.isButton, .isSelected] : .isButton)
            }
        }
        .padding(3)
        .background(pal.surface, in: Capsule())
    }
}

/// A number typed on the keypad, in a pill with its unit. Values outside
/// `range` count as not filled in.
struct NumberField: View {
    @Binding var value: Double?
    var unit: String
    var range: ClosedRange<Double>
    var decimal = false
    var label: String

    @Environment(\.palette) private var pal
    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 6) {
            TextField("--", text: $text)
                .font(.num(TypeScale.unit))
                .foregroundStyle(pal.ink)
                .multilineTextAlignment(.trailing)
                .keyboardType(decimal ? .decimalPad : .numberPad)
                .focused($focused)
                .frame(width: Metrics.fieldDigits)
                .accessibilityLabel(label)
                .accessibilityIdentifier(label)
            Text(unit).font(.text(TextScale.label)).foregroundStyle(pal.ink2)
        }
        .padding(.horizontal, 16)
        .frame(height: Metrics.fieldHeight)
        .background(pal.surface, in: Capsule())
        .contentShape(Capsule())
        .onTapGesture { focused = true }
        .onAppear { text = Self.show(value) }
        .onChange(of: text) { _, new in
            let parsed = Double(new.replacingOccurrences(of: ",", with: "."))
            let next = parsed.flatMap { range.contains($0) ? $0 : nil }
            if next != value { value = next }
        }
        .onChange(of: focused) { _, on in
            // Leaving the field: drop anything that was not a usable value.
            if !on { text = Self.show(value) }
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                if focused {
                    Spacer()
                    Button("完成") { focused = false }
                }
            }
        }
    }

    private static func show(_ v: Double?) -> String {
        guard let v else { return "" }
        return v == v.rounded() ? String(Int(v)) : String(format: "%.1f", v)
    }
}

struct PillSwitch: View {
    @Binding var isOn: Bool

    @Environment(SettingsStore.self) private var settings
    @Environment(\.palette) private var pal

    var body: some View {
        Capsule()
            .fill(isOn ? pal.go : pal.surface)
            .frame(width: 52, height: 32)
            .overlay(alignment: isOn ? .trailing : .leading) {
                Circle().fill(.white).frame(width: 26, height: 26).padding(3)
            }
            .contentShape(Capsule())
            .onTapGesture {
                withAnimation(Motion.select) { isOn.toggle() }
                Haptics.tap(.light, settings)
            }
            .accessibilityAddTraits(.isButton)
            .accessibilityValue(isOn ? "开" : "关")
    }
}
