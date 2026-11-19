# AGENTS.md — portrait-webgpu-base

> **打开本仓库时的第一入口。**  
> 合并自 **niantu**（适配/TS/预览）+ **three-webgpu-cap-shell**（打包/文档/bootstrap/可验证 demo）。

## 当前状态（2026-11-19）

**网页版（`src/`、`ios/`、`plugins/`）暂停开发，只做原生版（`native/`）。** 网页版代码保留不删，但不再跟进功能和阈值；除非明确要求，不要改动它。

## 一句话

**TypeScript + Three.js WebGPU + Vite + Capacitor iOS** 竖屏手游稳健底座。  
设计空间固定 **390×844**，contain letterbox；桌面可切手机/Pad 预览；`base: './'` 保证真机资源路径。

## 入口地图

| 职责 | 文件 |
|------|------|
| Web 启动 | `index.html` → `src/main.ts` |
| 设计舞台 | `src/adapt/design.ts` |
| 设备预览 | `src/adapt/devicePreview.ts` |
| Safe Area | `src/adapt/safeArea.ts` + `src/style.css` |
| WebGPU | `src/create-renderer.ts` |
| 震动 JS | `src/utils/haptics.ts` |
| 震动 Swift 真源 | `plugins/native-haptics/*` |
| 震动怎么接 | `docs/HAPTICS.md` **§0 正确接入** |
| Capacitor | `capacitor.config.ts`（`contentInset: never`） |
| 构建 | `vite.config.ts`（**`base: './'`**） |
| iOS 注入 | `scripts/bootstrap-ios.mjs` |
| 音效方案（未实现） | `docs/AUDIO.md` |
| 页面与路由 | `src/ui/app.ts`（路由、转场）· `src/ui/ride.ts`（骑行页）· `src/ui/pages.ts`（首页/总结/记录/设置） |
| 骑行计算（纯函数，可单测） | `src/ride/tracker.ts`：距离、移动时间、自动暂停回溯、爬升、坡度 |
| 定位来源 | `src/ride/source.ts`：iOS 走 `RideTracker` 原生插件，浏览器走 `navigator.geolocation` |
| 引擎选择 | `src/ride/engine.ts`：iOS 真实定位；浏览器默认模拟骑行，`?gps=1` 用浏览器定位 |
| 定位 Swift 真源 | `plugins/native-ride/RideTrackerPlugin.swift`（后台定位、气压计、加速度计、分享） |
| 存储 | `src/data/store.ts`：设置在 localStorage，骑行记录（含轨迹）在 IndexedDB |
| GPX 导出 | `src/ride/gpx.ts` |
| 模拟骑行（仅浏览器看界面） | `src/data/sim.ts` |

## DOM（勿拆）

```
#shell > #viewport > #app > #stage
  canvas          ← WebGPU
  #ui-root        ← 所有游戏 UI（safe padding）
#device-switcher  ← 仅桌面预览例外
```

## 骑行 App 现状（覆盖下方底座约定中冲突的部分）

- 界面是 `#ui-root` 里的纯 DOM，**不创建 WebGPU 渲染器**（`create-renderer.ts` 保留未用）。
- 改了 `plugins/native-ride/` 或 `plugins/native-haptics/` 后必须 `npm run ios:bootstrap`；它同时写入 Info.plist 的定位 / 运动权限说明和 `UIBackgroundModes: location`。
- 自动暂停等阈值集中在 `src/ride/tracker.ts` 顶部的 `TUNE`，需要真机路测调整。
- 原生层只负责采集和缓冲，JS 每秒 `drain` 一次；锁屏期间 WebView 可能挂起，回到前台时一次性补算。

## 原生版（`native/`，SwiftUI）— 当前主线

**设计以 `docs/DESIGN.md` 为准：先改文档，再改代码。**

与网页版并存的原生重写，包名 `com.wangzhixuan.pedalfun`（网页壳是 `…pwgbase.hapticstest`，两者可同时安装，数据不互通）。

| 职责 | 位置 |
|------|------|
| 工程定义 | `native/project.yml` → `cd native && xcodegen` 生成 `Pedalfun.xcodeproj`（新增文件后要重新生成） |
| 入口 / 路由与开始过渡 / 根视图 | `native/Pedalfun/App/{PedalfunApp,AppModel,RootView}.swift` |
| 骑行计算（纯逻辑，阈值在 `Tune`） | `native/Pedalfun/Core/RideTracker.swift` |
| 骑行页显示规则（纯逻辑） | `native/Pedalfun/Core/RidePresentation.swift` |
| 定位 / 气压计 / 加速度计 | `native/Pedalfun/Core/LocationRecorder.swift` |
| 一次骑行的会话 | `native/Pedalfun/Core/RideSession.swift` |
| 存储、设置、导出、格式化、周统计、消耗估算 | `native/Pedalfun/Core/{RideStore,Settings,GPX,Format,WeekStats,Calories}.swift` |
| 配色、尺寸、字号、动效常量 | `native/Pedalfun/UI/Design.swift` |
| 共用组件 | `native/Pedalfun/UI/Components/{Buttons,Readouts,Chrome,ElevationProfile}.swift` |
| 页面 | `native/Pedalfun/UI/Screens/*View.swift` |
| 单元测试 / 界面测试 | `native/PedalfunTests/` · `native/PedalfunUITests/` |

- 每个页面建在 `ScreenScaffold` 里；主按钮高度由 `Metrics.actionBar` 统一。
- 跑测试：`cd native && xcodebuild -project Pedalfun.xcodeproj -scheme Pedalfun -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test`
- 启动参数（看界面用）：`-mock 1` · `-demo cruise|climb|descent|autopause|paused|gpsweak|summary|detail|history|settings` · `-theme light|dark` · `-autostart 1` · `-weight 70 -height 175 -sex male|female`（个人资料，只对这次启动生效）。
- 改骑行阈值只改 `RideTracker.swift`。网页版暂停期间 `src/ride/tracker.ts` 不再同步，恢复开发时要先对齐。

## 硬性约定

1. **`vite` `base: './'`** — Capacitor 禁止绝对 `/assets/`  
2. **`webDir: dist`** 与 Vite `outDir` 一致  
3. **`ios.contentInset: never`** — Safe Area 只走 CSS  
4. **布局坐标 390×844**；禁止 `renderer.setSize(window.innerWidth,…)`  
5. **UI 只挂 `#ui-root`**；禁止玩法 UI `position: fixed` 贴浏览器窗  
6. **Pad 只改外层视口**，不改 `DESIGN_*`  
7. **改 Swift 改 `plugins/native-haptics/`** 再 `ios:bootstrap`；震动接线见 `docs/HAPTICS.md`。Capacitor 8 的 `SceneDelegate` 必须 `rootViewController = BridgeViewController()`（默认 `CAPBridgeViewController` 不会注册插件）。不要用 JS `prepare()` 判断是否接上；真机 HUD 看 `plugin: true` + 点「点我震动」。  
8. **无 WebGPU 则明确失败**，不静默 WebGL  

## 命令

```bash
npm install
npm run dev           # http://127.0.0.1:5190/
npm run build
npm run cap:sync
npm run ios:bootstrap # 首次 / 修插件
npm run ios
```

查询参数：`?preview=0|1` · `?debugFit=1`  
调试安全区：`document.body.classList.add('debug-safe-area')`

## 业务怎么加

- 玩法：改 `src/main.ts` 或 `src/game/*`  
- 保留：adapt / create-renderer / haptics / plugins / `base`  
- 触控：`clientToDesign` + 忽略 letterbox 外  
- 音效：按 `docs/AUDIO.md` 接入；禁止热路径 `new Audio()` / 每发一次桥  

## 刻意不做

- 具体游戏玩法（demo 立方体可删）  
- Android（可后加）  
- WebGL 静默回退  
