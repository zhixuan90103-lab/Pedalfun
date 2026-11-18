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

                    Text("只用手机 GPS 记录，不连接心率带、功率计等外设。")
                        .font(.system(size: 13))
                        .foregroundStyle(pal.ink3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, Metrics.side)
                        .padding(.vertical, 22)
                }
            }
            .scrollBounceBehavior(.basedOnSize)
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
