# 骑行 App 功能对照（是否要蓝牙硬件）

检索日期：2026-11-18。只记骑行。范围是已打开的官方页，不包含其他运动。

判断标准：功能的数据或动作是否必须来自蓝牙（或同类无线）外设。手机 GPS、蜂窝网络、扬声器不算蓝牙硬件。

## 本应用基础骑行界面

骑行中的基础界面只显示手机 GPS 能算出的数，不放心率、功率、踏频。

**大块（主视觉）**

- 速度
- 时间（本次骑行时间）
- 里程

这三项占界面的主要面积。

**同时显示，面积小于大块**

- 最高速度
- 均速
- 海拔
- 爬升
- 坡度

| 字段 | 含义 |
|------|------|
| 速度 | 当前速度 |
| 时间 | 本次骑行已用时间 |
| 里程 | 本次已骑距离 |
| 最高速度 | 本次骑行中的最大速度 |
| 均速 | 本次里程 ÷ 骑行时间 |
| 海拔 | 当前海拔 |
| 爬升 | 本次累计上升 |
| 坡度 | 当前坡度 |

## 需要蓝牙连接硬件

| 功能 | 依赖什么 | 依据 |
|------|----------|------|
| 心率 | 心率带或手表，蓝牙配对后显示 | Ride with GPS：心率栏需要已配对的蓝牙传感器 |
| 功率 | 功率计或智能骑行台 | Ride with GPS：功率栏需要已配对传感器。TrainerRoad / Zwift 的训练课用功率控制强度 |
| 踏频、外置速度传感器 | 踏频计或速度传感器 | Ride with GPS：踏频栏需要已配对传感器 |
| 按传感器数值做的语音播报 | 同上，把心率、功率等放进间隔播报 | Ride with GPS：间隔播报可以包含已连接蓝牙传感器的均值 |
| 路线发到码表、码表记录收回来 | Garmin、Wahoo、Hammerhead、COROS、行者码表 | Ride with GPS：Pin 后无线同步到码表，骑完再同步回账号。行者：路书下载后导入码表，码表记录经蓝牙回 App |
| 雷达来车提示 | Garmin Varia | Ride with GPS 帮助页写明可在 App 里接 Varia，用声音和画面提示来车。该页自称是唯一支持此雷达的第三方 App，没有第二份材料核对「唯一」 |
| 室内虚拟骑行与训练台课 | 智能骑行台（常为蓝牙）或功率计 | Zwift：室内世界、集团骑、分级赛、训练课。TrainerRoad：Plan Builder 的室内课；课也可以改成 Zwift 比赛。没有骑行台或功率计，这些课没有阻力与功率 |

TrainerRoad 还能把单次课改成「户外 Solo Ride」或集团骑，那一档不依赖骑行台，但计划本身仍按功率目标来写。

## 不需要连接硬件

手机 GPS 即可。安全类功能另要蜂窝网络，离线导航另要事先下载地图。

**记录**

- 轨迹、距离、时间、速度、爬升、海拔
- 暂停与结束后回看
- 数据栏里的速度、距离、时间、爬升、导航（Ride with GPS 约 25 项里的非传感器项）

**路线**

- 画路线、选路书、按长度 / 爬升 / 路面 / 环线·折返·点到点筛选
- 海拔剖面
- 用本人历史骑行估计耗时（Ride with GPS；行者路书详情）
- 行者：下载路书、按目的地快捷规划、沿路书导航、开关语音；网页端下载 GPX

**导航**

- 转弯提示、语音、偏航提醒、锁屏上的下一次转弯
- 离线地图（事先下载；Ride with GPS 的语音导航与离线地图在 Premium 或旧 Basic）
- komoot：事先规划再转弯导航，或不规划、只记录。导航只在 App 内。新账号一个免费区域，超出要买地图或 Premium

**找路和比较**

- 热力图：全部时间、近 30 天、近 7 天；长按地图查经过某点的路线（Ride with GPS）
- 附近推荐路书（行者）
- 赛段与排行榜、月挑战（距离、爬升、时间）。Strava 赛段榜上的最快成绩竞争、自定义目标、发现附近道路在订阅里；免费账号可以记录、分享、加入俱乐部和挑战
- 行者路书详情上的赛段榜

**安全**

把实时位置用链接发给联系人。对方不必安装同一个 App。没信号就不更新。

| App | 要点 |
|-----|------|
| Strava Beacon | 免费记录能力里包含。最多三个联系人。有网时大约每 15 秒更新。可见当前位置、历史位置、起点、记录状态、运动时间、剩余电量。没有停留警报，链接本身不含预计到达 |
| komoot Live Tracking | Premium。自由记录时分享位置、状态、距离、海拔、电量、GPS。沿规划路线时另有预计到达、规划线和剩余距离。默认约 1 分钟，有人正在看则约 5 秒。链接保留 28 天后删除 |
| Ride with GPS Live Logging | 实时位置和完成时间 ETA。记录或导航时都能开 |

**社交和隐私**

- 关注、点赞（kudos）、俱乐部（Strava 写明有超过 30 万个骑行俱乐部）
- 月挑战
- 活动照片和文字（komoot）
- 隐藏速度、隐藏起终点，或整页不公开（Strava）

**骑后**

- 距离、爬升、轨迹回放
- 从这次骑行再生成路线（Strava 活动页具备从活动创建路线；本次检索以骑行营销页的「路线规划」为准，没有单独打开活动页正文）

## 有效来源

同时满足：页面实际打开过，并且支撑了上面至少一条功能。

| 标题 | 链接 | 类型 | 用在哪 | 首次采用 |
|------|------|------|--------|----------|
| Cycling & Biking App \| Strava | https://www.strava.com/sports/cycling | 官方 | 记录、挑战、俱乐部、路线、免费 Beacon、隐私；赛段榜与自定义目标为订阅项 | 第 1 轮 |
| Strava Beacon | https://support.strava.com/en-us/articles/15401829-strava-beacon | 官方 | 实时位置字段、约 15 秒更新、无停留警报、链接不含 ETA | 第 2 轮 |
| Get started with komoot | https://support.komoot.com/hc/en-us/articles/10194701438234-Get-started-with-komoot | 官方 | 规划、转弯导航、只记录、社区、一个免费区域 | 第 1 轮 |
| Live Tracking | https://support.komoot.com/hc/en-us/articles/10365451254298-Live-Tracking-Share-your-live-location | 官方 | Premium 实时位置；导航时的 ETA 与剩余距离；28 天保留 | 第 2 轮 |
| Quick Start Guide for Mobile | https://support.ridewithgps.com/hc/en-us/articles/13683364950939-Quick-Start-Guide-for-Mobile | 官方 | 数据栏与蓝牙传感器、热力、筛选、语音导航、离线、个人 ETA、Live Logging、码表同步、Varia | 第 1 轮 |
| 如何使用行者 app 的路书导航 | https://hc.imxingzhe.com/hc/xing/articles/1740388579- | 官方帮助 | 路书导航、目的地快捷规划、语音 | 第 2 轮 |
| 路书探索功能如何使用 | https://hc.imxingzhe.com/hc/xing/articles/1766473721- | 官方帮助 | 附近路书、按本人记录估时、赛段榜、导入码表、GPX | 第 3 轮 |
| Plan Builder Overview | https://support.trainerroad.com/hc/en-us/articles/360037923191-Plan-Builder-Overview | 官方 | 按赛事排课；室内课 / 户外课 / 集团骑 / Zwift 比赛 | 第 2 轮 |
| Why Choose Zwift | https://www.zwift.com/why-zwift | 官方 | 室内训练课、FTP、全天集团骑、分级赛、虚拟世界、赛段与 HoloReplay | 第 3 轮 |

未写入正文的材料：横向比较博客、应用商店简介。Strava 功率曲线和 Fitness 页面没有打开，所以没有记成功能。坠车自动报警、除行者以外的中文骑行 App，也没有打开到来源，没有记。
