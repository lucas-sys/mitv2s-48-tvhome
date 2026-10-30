# Xiaomi Mi TV 2S 48" (MiTV2S-48, Android 5.1.1)：改机记录

这台机器是 2015 年的中国版 PatchWall 电视，Android 5.1.1（API 22），1 GB 内存，1920×1080。
上游 CleanYourTV 的 launcher 需要 API 26，`pm disable-user` 又被小米固件拒绝，所以这里的做法是
**改用 `pm hide`**（可逆、不卸载）并给 launcher 打了 API 22 移植（见 [`api22-port.md`](api22-port.md)）。

实测型号信息：

| 项 | 值 |
|---|---|
| 型号 / 代号 | MiTV2S-48 / `gladiator` |
| Android | 5.1.1（SDK 22） |
| 固件 build | 7.6.20.2492 |
| 桌面（HOME） | `com.mitv.tvhome`（PatchWall） |
| 板卡 | MStar（`com.mstar.*`） |
| 分辨率 / 内存 | 1920×1080 / 1 GB |

## 0. 打开 ADB

电视：设置 →（小米设置）帐号与安全 → **ADB调试 → 允许**；同时确认开发者选项里 USB 调试打开。
电视和电脑在同一 Wi-Fi，电脑上：

```bash
adb connect <tv ip>:5555
adb devices
```

> 这台固件**每次重启/待机后都会关闭网络 ADB**，重新连不上时回到上面的开关再打开一次。
> 若刷机前 `pm disable-user` 被拒（`SecurityException: attempt to change component state`），不要重试，
> 本仓库的所有脚本都走 `pm hide`。

## 1. 去广告 / 精简（可选、可逆）

三个清单在 [`lists/`](../lists/)：

| 清单 | 内容 | 数量 |
|---|---|---|
| `01-ads-telemetry.txt` | 小米统计、酷云收视、广告 SDK、推送/推广、电视淘宝、商城、清理 SDK | 11 |
| `02-preloaded-apps.txt` | 音乐、天气、日历、相册、时尚画报、米家、游戏、支付、管家、下载、百度云、浏览器、录音、健身、手册、语音助手、锁屏、应用中心、视频播放器、屏保 | 26 |
| `03-account-cloud.txt` | 小米账号 / 账号授权 / 云推送 + 用不到的百度输入法 | 4 |

```bash
export TV_HOST=<tv ip>
scripts/hide.sh lists/01-ads-telemetry.txt      # 每个包单独一条 adb shell pm hide 并校验
scripts/hide.sh lists/02-preloaded-apps.txt
scripts/hide.sh lists/03-account-cloud.txt
```

还原：

```bash
scripts/unhide.sh lists/01-ads-telemetry.txt
scripts/unhide.sh lists/02-preloaded-apps.txt
scripts/unhide.sh lists/03-account-cloud.txt
# 或者一次全还原（含下面的系统开关）
scripts/restore-all.sh
```

### 必须保留的包（不要放进隐藏清单）

| 包 | 原因 |
|---|---|
| `com.mitv.tvhome` | 系统桌面。**隐藏它之前必须先装好并确认新桌面能用**，否则按 Home 没有东西可回。 |
| `mitv.service`、`com.mstar.*`、`com.xiaomi.mitv.tvplayer` | 有线/HDMI 输入、信号源、电视硬件服务 |
| `com.xiaomi.mitv.settings`、`com.android.settings`、`com.xiaomi.mitv.systemui`、`com.xiaomi.mitv.providers.settings` | 设置与系统 UI |
| `com.sohu.inputmethod.sogou.tv`、`com.android.inputmethod.*` | 唯一输入法（默认搜狗） |
| `com.xiaomi.mitv.appstore` | TV 自带「我的应用」页面的数据来源；隐藏后整页会报错 |
| `com.xiaomi.mitv.tvpush.tvpushservice` | 带安装白名单，隐藏后可能装不了 APK；只关通知即可 |
| `com.google.android.webview`、`com.android.packageinstaller`、`com.android.documentsui` | WebView / 装 APK / 选 U 盘文件 |
| `com.xiaomi.mitv.smartshare`、`com.xiaomi.dlnatvservice`、`com.duokan.airkan.tvbox` | 手机投屏 / DLNA |

`tools/disable.sh`（上游）在这台机器上不能用的原因：它只调用 `pm disable-user`，会被拒绝。

## 2. 安装新桌面

先构建 APK（见仓库 README 的 Build），然后：

```bash
export TV_HOST=<tv ip>
scripts/install-launcher.sh launcher/app/build/outputs/apk/release/app-release.apk
```

脚本会 `adb push` + `pm install -r`。此时新桌面只是一个普通应用，小米桌面仍是 Home：
可以在「我的应用」里找到「主屏幕」打开试用。

## 3. 接管 Home

这台小米固件会在框架层忽略第三方桌面的 Home 偏好：在系统设置「主屏幕」里选中新桌面不生效，
唯一可靠的办法是**隐藏小米桌面**，让 HOME 只剩新桌面：

```bash
adb -s <tv ip>:5555 shell pm hide --user 0 com.mitv.tvhome
adb -s <tv ip>:5555 shell input keyevent 3      # 按 Home，应进入新桌面
```

验证（应输出 `com.gathin.tvhome`）：

```bash
adb -s <tv ip>:5555 shell dumpsys activity | grep mHomeProcess
```

还原小米桌面：

```bash
adb -s <tv ip>:5555 shell pm unhide --user 0 com.mitv.tvhome
adb -s <tv ip>:5555 shell input keyevent 3
```

`com.mitv.tvhome` 只是隐藏，没有卸载，随时可以恢复。

## 4. 小米电视设置的入口

launcher 右上角「设置」胶囊直接打开小米电视设置（配置项 `settings_pill_native`），
网络调试路径：**帐号与安全 → ADB调试 → 允许**。AOSP 设置仍在（USB 调试等），
但小米的网络 ADB 开关只在小米设置里。

## 5. 壁纸

launcher 从 `/sdcard/Android/data/com.gathin.tvhome/files/` 读壁纸：

```bash
D=/sdcard/Android/data/com.gathin.tvhome/files
adb -s <tv ip>:5555 shell mkdir -p $D/wallpapers
adb -s <tv ip>:5555 push wallpaper.jpg $D/wallpaper.jpg        # 单张
adb -s <tv ip>:5555 push wallpapers/*.jpg $D/wallpapers/       # 轮换合集
adb -s <tv ip>:5555 push config.json $D/config.json
```

`config.json` 例（每天换一张、按文件名顺序循环、压暗 14%）：

```json
{
  "wallpaper": true,
  "wallpaper_rotation_minutes": 1440,
  "wallpaper_order": "sequential",
  "wallpaper_dim": 14,
  "dock_opacity": 80,
  "ambient_glow": false
}
```

桌面 Dock 的「壁纸」按钮会打开缩略图选择页：可选「主题默认（轮换）」/「无」/任意一张图，
选择保存在 launcher 的设置里，Home 会自动刷新。壁纸图可以从上游
[`themes/`](https://github.com/Gathin23/cleanyourtv/tree/main/themes) 拿（注意其中部分照片是 CC BY，
使用前看上游的 `CREDITS.md`）。

## 6. 已知限制

- **网络 ADB 每次重启/待机后关闭**：固件行为，重新在小米设置里打开。
- **没有 TvInputManager 输入**：这台机器的 `dumpsys tv_input` 是空的，launcher 的 Inputs 菜单无从列出。
  信号源可以这样打开：
  `adb shell am start -n com.xiaomi.mitv.tvplayer/.ExternalSourceActivity`
- **字体**：launcher 的 Outfit 字体是 `@font` XML family，Android 5.1 只能回退系统字体；要真字体需引入
  AppCompat，本仓库没有加。
- **R8 混淆关闭**：API 22 上 R8 的 lambda 合成类会 `NoClassDefFoundError`，因此 APK 约 1.9 MB。
- 画面里的 GITV 角标属于小米桌面；隐藏小米桌面后就没有了。
