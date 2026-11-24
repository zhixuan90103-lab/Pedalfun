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

                    note("个人资料", color: pal.ink2)
                        .padding(.top, 26)
                        .padding(.bottom, 4)
                    row("性别", nil) {
                        PillPicker(selection: $settings.sex, options: [(.male, "男"), (.female, "女")])
                    }
                    row("身高", nil) {
                        NumberField(value: $settings.height, unit: "cm", range: Profile.heightRange, label: "身高")
                    }
                    row("体重", "填了才显示消耗") {
                        NumberField(value: $settings.weight, unit: "kg", range: Profile.weightRange, decimal: true, label: "体重")
                    }

                    note("消耗按均速、时间和个人资料估算，没有心率和功率数据，只是一个粗略的数。", color: pal.ink3)
                        .padding(.top, 10)
                    note("只用手机 GPS 记录，不连接心率带、功率计等外设。", color: pal.ink3)
                        .padding(.vertical, 22)
                }
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollDismissesKeyboard(.immediately)
        }
    }

    /// A line of small print across the page: a section title or a footnote.
    private func note(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.text(TextScale.label))
            .foregroundStyle(color)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Metrics.side)
    }

    private func row<Control: View>(_ label: String, _ hint: String?, @ViewBuilder control: () -> Control) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(.text(TextScale.title)).foregroundStyle(pal.ink)
                if let hint {
                    Text(hint).font(.text(TextScale.label)).foregroundStyle(pal.ink2)
                }
            }
            Spacer(minLength: 8)
            control()
        }
        .padding(.horizontal, Metrics.side)
        .frame(minHeight: Metrics.settingRow)
    }
}
