import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @Environment(SettingsStore.self) private var settings
    @Environment(\.palette) private var pal

    var body: some View {
        @Bindable var settings = settings

        ScreenScaffold {
            TopBar(title: "设置") {
                IconButton(icon: "chevron.left", label: "返回") { model.go(.home) }
            } trailing: {
                EmptyView()
            }
        } content: {
            ScrollView {
                VStack(spacing: 0) {
                    row("单位", nil) {
                        PillPicker(selection: $settings.units, options: [(.km, "公里"), (.mi, "英里")])
                    }
                    row("外观", "强光下浅色更清楚") {
                        PillPicker(selection: $settings.theme, options: [(.dark, "深色"), (.light, "浅色"), (.system, "自动")])
                    }
                    row("自动暂停", "停车时停表，起步后继续") { PillSwitch(isOn: $settings.autoPause) }
                    row("骑行时屏幕常亮", nil) { PillSwitch(isOn: $settings.keepAwake) }
                    row("震动反馈", "暂停、继续、结束时震一下") { PillSwitch(isOn: $settings.haptics) }

                    Text("个人资料")
                        .font(.system(size: 13))
                        .foregroundStyle(pal.ink2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, Metrics.side)
                        .padding(.top, 26)
                        .padding(.bottom, 4)
                    row("性别", nil) {
                        PillPicker(selection: $settings.sex, options: [(.male, "男"), (.female, "女")])
                    }
                    row("身高", nil) {
                        NumberField(value: $settings.height, unit: "cm", range: 100...230, label: "身高")
                    }
                    row("体重", "填了才显示消耗") {
                        NumberField(value: $settings.weight, unit: "kg", range: 30...200, decimal: true, label: "体重")
                    }

                    Text("消耗按均速、时间和个人资料估算，没有心率和功率数据，只是一个粗略的数。")
                        .font(.system(size: 13))
                        .foregroundStyle(pal.ink3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, Metrics.side)
                        .padding(.top, 10)

                    Text("只用手机 GPS 记录，不连接心率带、功率计等外设。")
                        .font(.system(size: 13))
                        .foregroundStyle(pal.ink3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, Metrics.side)
                        .padding(.vertical, 22)
                }
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollDismissesKeyboard(.immediately)
        }
    }

    private func row<Control: View>(_ label: String, _ hint: String?, @ViewBuilder control: () -> Control) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(.system(size: 16)).foregroundStyle(pal.ink)
                if let hint {
                    Text(hint).font(.system(size: 13)).foregroundStyle(pal.ink2)
                }
            }
            Spacer(minLength: 8)
            control()
        }
        .padding(.horizontal, Metrics.side)
        .frame(minHeight: 68)
    }
}

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
                    .font(.system(size: 14))
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
                .frame(width: 58)
                .accessibilityLabel(label)
                .accessibilityIdentifier(label)
            Text(unit).font(.system(size: 13)).foregroundStyle(pal.ink2)
        }
        .padding(.horizontal, 16)
        .frame(height: 42)
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
