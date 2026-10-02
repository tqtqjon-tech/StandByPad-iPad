# StandByPad for iPad

Swift + UIKit + WKWebView 原生 iPad App，iPadOS 15+，横屏、隐藏状态栏，前台保持屏幕常亮。网页 UI、动画、背景和字体来自只读的 [standbypad](https://github.com/tqtqjon-tech/standbypad)，构建时复制到 App Bundle；启动加载本地 `WebAssets/index.html`，无需网页服务器。设置使用 WKWebView 持久化存储，原网页照片选择交互保留。

## 下载 IPA

1. 打开本仓库 **Actions → Build unsigned IPA**。
2. 点击 **Run workflow**，选择 `main` 后运行。
3. 等待构建成功，在该次运行页面的 **Artifacts** 下载 **StandByPad-unsigned-IPA**。
4. 解压下载的 artifact ZIP，得到 **StandByPad.ipa**。

**GitHub Actions 产生的是 unsigned IPA，必须自行用支持免费 Apple ID 的签名/侧载工具重新签名后安装。** CI 不保存 Apple ID、密码、证书、Provisioning Profile 或 App Store Connect Key，不需要付费开发者账户。

## 原生 Bridge

在文档开始时注入 `App/Resources/native-bridge.js`，以 `WKScriptMessageHandler` 请求数据、`evaluateJavaScript` 主动推送变化：

- `navigator.getBattery()` 返回 Promise，支持 `level`、`charging`、`levelchange`、`chargingchange` 及相应 `on…` 回调。数据来自 UIDevice battery monitoring。未知电量/充电状态不会伪造；获取有效数据前 Promise 等待。
- `navigator.connection.type`、`change` 和 `navigator.onLine` / `online` / `offline` 来自 NWPathMonitor，区分 wifi、cellular、ethernet、other、none、unknown。这里表示系统网络路径可用性，不保证互联网服务器可达；不猜测 4G/5G、网速或 SSID。
- `window.StandByPadNative.state` 包含 `battery`（level、percent、charging、state）、`network`（online、type、interfaces、expensive、constrained）、`device`（systemName、systemVersion、model、name）、`screen`（width、height、scale、orientation）。尚未获得的数据为 null 或 unknown。
- 调用 `.refresh()` 请求新快照；监听 `.addEventListener('statechange', e => …)` 或 window 的 `standbypad-native-state` 事件获取 `e.detail`。电池、网络、屏幕布局和返回前台会主动更新。

设备 model 使用公开 UIDevice.model（通常为 iPad，不承诺具体机型）；iPadOS 16+ 的 device name 通常为系统提供的通用名称，不申请受限 entitlement。屏幕宽高为 App 视图的逻辑点，scale 可用于换算像素。

只使用公开 SDK。不提供 CPU 温度、真实电池健康度、循环次数、其他 App 信息、当前系统墙纸、剩余充电时间等无可靠公开 API 的数据。Battery shim 的充放电时间为 Infinity，表示无法估计。

## 本地生成和构建（macOS + Xcode）

```sh
bash scripts/sync-web-assets.sh
brew install xcodegen
xcodegen generate
xcodebuild -project StandByPad.xcodeproj -scheme StandByPad \
  -configuration Release -sdk iphoneos -destination 'generic/platform=iOS' \
  -derivedDataPath build ARCHS=arm64 \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" build
```

`project.yml` 是完整工程来源。`web-source-ref.txt` 固定网页 commit，以保持可重复构建；若需升级 UI，改为已审核的原仓库 commit。工作流逐一验证网页文件及字体的内容哈希、App 可执行文件、Bundle ID、arm64 和 IPA 的 `Payload/StandByPad.app` 结构。网页资源在编译时下载，运行时离线使用；file URL 不需要 service worker。
