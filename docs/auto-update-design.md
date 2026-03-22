# Monet 自动更新机制设计方案 (Sparkle)

> **技术选型**: Sparkle 2.x + GitHub Releases
> **文档版本**: 1.0
> **最后更新**: 2026-03-19

---

## 背景

Monet 是一款 macOS 图片查看器应用，当前通过 GitHub Actions 自动构建和发布到 GitHub Releases。用户需要手动访问 GitHub 下载并安装更新。本设计旨在实现应用内自动更新检测、下载和安装功能。

---

## 需求分析

### 用户流程

```
┌─────────────────┐
│   用户启动 App   │
└────────┬────────┘
         │
         ▼
┌─────────────────────────────────┐
│  App 后台检查 GitHub Releases    │
│  (Sparkle 自动完成)              │
└────────┬────────────────────────┘
         │
         ▼
┌─────────────────────────────────┐
│  对比当前版本，是否有更新？      │
└────────┬────────────────────────┘
         │
    ┌────┴────┐
    │         │
    ▼         ▼
  有更新     无更新 → 结束
    │
    ▼
┌─────────────────────────────────┐
│  显示更新提示对话框              │
│  ┌───────────────────────────┐  │
│  │  发现新版本 v1.2.0         │  │
│  │  当前版本 v1.1.0           │  │
│  │                           │  │
│  │  [ 稍后提醒 ] [ 跳过此版本 ] │  │
│  │  [    立即下载    ]        │  │
│  └───────────────────────────┘  │
└─────────────────────────────────┘
         │
    ┌────┼────┐
    │    │    │
    ▼    ▼    ▼
  下载  跳过  稍后
   │           │
   ▼           └────→ 记录，下次启动再提示
下载完成
   │
   ▼
┌─────────────────────────────────┐
│  显示安装按钮                    │
│  [ 安装并重启 ] [ 取消 ]         │
└────────┬────────────────────────┘
         │
         ▼
┌─────────────────────────────────┐
│  Sparkle 自动完成：              │
│  1. 替换当前 App                 │
│  2. 重启应用                    │
└─────────────────────────────────┘
```

### 功能需求

| 功能 | 说明 | Sparkle 支持 |
|------|------|-------------|
| 版本检测 | 启动时检查 GitHub Releases | ✓ 内置 |
| 版本比较 | 对比语义化版本号 | ✓ 内置 |
| 跳过版本 | 用户跳过某版本后不再提示 | ✓ `SUEnableSkipVersionUpdates` |
| 稍后提醒 | 本次不处理，下次启动再提示 | ✓ 内置 |
| 下载更新 | 下载 DMG/ZIP | ✓ 内置下载器 |
| 安装更新 | 自动替换当前 App | ✓ 内置 |
| 重启 App | 安装后自动重启 | ✓ 内置 |
| 手动检查 | 设置页检查更新按钮 | ✓ `checkForUpdates()` |

---

## 技术架构

### 组件图

```
┌─────────────────────────────────────────────────────────────┐
│                         Monet App                           │
│                                                             │
│  ┌───────────────────────────────────────────────────────┐ │
│  │                    MonetApp.swift                     │ │
│  │                                                       │ │
│  │  import Sparkle                                       │ │
│  │  private let updaterController: SPUStandardUpdaterController │
│  │                                                       │ │
│  │  init() {                                             │ │
│  │    updaterController = SPUStandardUpdaterController(  │ │
│  │      startingUpdater: true,                           │ │
│  │      updaterDelegate: nil,                            │ │
│  │      userDriverDelegate: nil                          │ │
│  │    )                                                  │ │
│  │  }                                                    │ │
│  └───────────────────────────────────────────────────────┘ │
│                           │                                 │
│                           ▼                                 │
│  ┌───────────────────────────────────────────────────────┐ │
│  │           SPUStandardUpdaterController (Sparkle)      │ │
│  │                                                       │ │
│  │  ┌─────────────────┐    ┌─────────────────────────┐  │ │
│  │  │  SPUUpdater     │    │  SPUStandardUserDriver  │  │ │
│  │  │  - 检查更新      │    │  - 显示更新提示 UI       │  │ │
│  │  │  - 解析 appcast │    │  - 下载进度显示         │  │ │
│  │  │  - 版本比较     │    │  - 安装确认对话框       │  │ │
│  │  └─────────────────┘    └─────────────────────────┘  │ │
│  └───────────────────────────────────────────────────────┘ │
│                           │                                 │
│              ┌────────────┼────────────┐                   │
│              ▼            ▼            ▼                   │
│  ┌──────────────┐ ┌───────────┐ ┌──────────────┐         │
│  │ Updates      │ │ About     │ │ AppDelegate │         │
│  │ SettingsPane │ │ Settings  │ │ (可选代理)  │         │
│  │              │ │ Pane      │ │             │         │
│  │ • 检查更新   │ │ • 版本号  │ │ • 更新前    │         │
│  │ • 自动检查   │ │ • 检查按钮│ │   回调      │         │
│  │ • 更新状态   │ │           │ │             │         │
│  └──────────────┘ └───────────┘ └──────────────┘         │
│                                                             │
│  ┌───────────────────────────────────────────────────────┐ │
│  │                    Info.plist                         │ │
│  │                                                       │ │
│  │  SUFeedURL              → GitHub appcast.xml         │ │
│  │  SUPublicEDKey          → EdDSA 公钥                 │ │
│  │  SUEnableAutomaticChecks → false (用户控制)          │ │
│  │  SUEnableSkipVersionUpdates → true                   │ │
│  └───────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
                 ┌───────────────────────┐
                 │   GitHub Releases     │
                 │                       │
                 │  /latest/download/    │
                 │    appcast.xml        │
                 │                       │
                 │  Monet-v1.2.0.dmg     │
                 │  (带 EdDSA 签名)       │
                 └───────────────────────┘
```

### 数据流

```
1. App 启动
       │
       ▼
2. Sparkle 读取 Info.plist 中的 SUFeedURL
       │
       ▼
3. HTTP GET 请求 appcast.xml
       │
       ▼
4. 解析 XML，获取最新版本信息
       │
       ├── 网络失败 → 使用缓存/结束
       │
       ▼
5. 比较版本 (SUAppcastItem.version vs Bundle.version)
       │
       ├── 无更新 → 显示"已是最新版本" → 结束
       │
       ▼
6. 读取用户跳过记录 (UserDefaults: "SUSkippedVersion")
       │
       ├── 版本已跳过 → 不提示 → 结束
       │
       ▼
7. 显示更新提示窗口 (SPUStandardUserDriver)
       │
       ├── 点击"跳过此版本" → 写入 SUSkippedVersion → 结束
       │
       ├── 点击"稍后提醒" → 不操作 → 结束
       │
       ▼
8. 用户点击"立即下载"
       │
       ▼
9. Sparkle 下载 DMG/ZIP
       │
       ▼
10. 验证 EdDSA 签名
       │
       ├── 签名失败 → 拒绝安装 → 报错
       │
       ▼
11. 显示"安装并重启"按钮
       │
       ▼
12. 用户确认 → 替换 App → 重启
```

---

## 实现方案

### 阶段 1：生成 EdDSA 密钥对

**命令行操作**:

```bash
# 方法 1: Homebrew 安装 Sparkle
brew install sparkle
cd /opt/homebrew/opt/sparkle/bin
./generate_ed_key

# 方法 2: 从 SPM 包中获取
# 构建项目后在 DerivedData 中查找 Sparkle binaries
```

**输出示例**:

```
Public key: xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
Private key: xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

**密钥用途**:
- **公钥** → 放入 `Info.plist` 的 `SUPublicEDKey`
- **私钥** → 存入 GitHub Secrets 的 `SPARKLE_PRIVATE_ED_KEY`

---

### 阶段 2：添加 Sparkle 依赖

**文件**: `Package.swift`

```swift
// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Monet",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "Monet", targets: ["Monet"])
    ],
    dependencies: [
        // 添加 Sparkle
        .package(url: "https://github.com/sparkle-project/Sparkle.git", from: "2.6.0"),

        // 现有依赖
        .package(url: "https://github.com/wflixu/LaunchAtLogin-Modern.git", from: "1.1.0"),
        .package(url: "https://github.com/SDWebImage/SDWebImageSwiftUI.git", from: "3.0.0"),
    ],
    targets: [
        .executableTarget(
            name: "Monet",
            dependencies: [
                .product(name: "Sparkle", package: "Sparkle"),
                // ... 现有依赖
            ],
            path: "Sources/Monet"
        )
    ]
)
```

---

### 阶段 3：配置 Info.plist

**文件**: `Sources/Monet/Info.plist`

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- 现有配置保持不变 -->

    <!-- Sparkle 配置 -->
    <key>SUFeedURL</key>
    <string>https://github.com/wflixu/Monet/releases/latest/download/appcast.xml</string>

    <key>SUPublicEDKey</key>
    <string>[填入生成的公钥]</string>

    <key>SUEnableAutomaticChecks</key>
    <false/>  <!-- 不自动检查，由用户在设置页控制 -->

    <key>SUEnableSkipVersionUpdates</key>
    <true/>   <!-- 支持跳过版本 -->

    <key>SUSystemProfilerUpdateType</key>
    <false/>  <!-- 不发送系统信息 -->
</dict>
</plist>
```

---

### 阶段 4：初始化 Sparkle

**文件**: `Sources/Monet/MonetApp.swift`

```swift
//
//  MonetApp.swift
//  Monet
//

import AppKit
import SwiftUI
import Sparkle  // 添加导入

@main
struct MonetApp: App {
    @AppLog(category: "MonetApp")
    private var logger

    @Environment(\.openWindow) private var openWindow

    @AppStorage("showMenuBarExtra") private var showMenuBarExtra = true

    // 添加 Sparkle 更新器控制器
    private let updaterController: SPUStandardUpdaterController

    // 设置 App Delegate 以响应 open file 请求
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @ObservedObject var appState = AppState()

    init() {
        logger.info("app init.....")

        // 初始化 Sparkle 更新器
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )

        appDelegate.assignAppState(appState)
    }

    var body: some Scene {
        // ... 现有代码保持不变
    }
}
```

---

### 阶段 5：创建 UpdatesSettingsPane

**文件**: `Sources/Monet/Settings/UpdatesSettingsPane.swift` (新建)

```swift
//
//  UpdatesSettingsPane.swift
//  Monet
//

import SwiftUI
import Sparkle

struct UpdatesSettingsPane: View {
    @EnvironmentObject var appState: AppState
    @State private var isCheckingForUpdates = false
    @State private var lastCheckDate: Date?

    // 获取 Sparkle 更新器实例
    private var updater: SPUUpdater {
        SPUStandardUpdaterController.sharedInstance().updater
    }

    // 自动检查更新的绑定
    private var automaticallyCheckForUpdates: Bool {
        get { updater.automaticallyChecksForUpdates }
        nonmutating set {
            updater.automaticallyChecksForUpdates = newValue
        }
    }

    var body: some View {
        Form {
            // 版本信息
            Section {
                HStack {
                    Text("Current Version")
                    Spacer()
                    Text(Constants.appVersion)
                        .foregroundColor(.secondary)
                }
            }

            // 检查更新按钮
            Section {
                Button(action: checkForUpdates) {
                    HStack {
                        if isCheckingForUpdates {
                            ProgressView()
                                .scaleEffect(0.5)
                                .frame(width: 10, height: 10)
                            Text("Checking for Updates...")
                        } else {
                            Image(systemName: "arrow.triangle.2.circlepath")
                            Text("Check for Updates")
                        }
                    }
                }
                .disabled(isCheckingForUpdates)

                if let lastCheck = lastCheckDate {
                    HStack {
                        Text("Last checked")
                        Spacer()
                        Text(lastCheck, style: .relative)
                            .foregroundColor(.secondary)
                    }
                    .font(.caption)
                }
            }

            // 自动检查开关
            Section {
                Toggle("Automatically check for updates", isOn: $automaticallyCheckForUpdates)

                HStack {
                    Image(systemName: "info.circle")
                        .foregroundColor(.secondary)
                    Text("When enabled, Monet will periodically check for updates")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .onAppear {
            lastCheckDate = updater.lastUpdateCheckDate
        }
    }

    private func checkForUpdates() {
        isCheckingForUpdates = true
        updater.checkForUpdates()

        // 监听更新检查完成
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            isCheckingForUpdates = false
            lastCheckDate = Date()
        }
    }
}

#Preview {
    UpdatesSettingsPane()
        .environmentObject(AppState())
}
```

---

### 阶段 6：启用 Updates 设置页

**文件**: `Sources/Monet/SettingsView.swift`

```swift
@ViewBuilder
private var detailView: some View {
    switch appState.settingsNavigationIdentifier {
    case .general:
        GeneralSettingsPane()
    case .hotkeys:
        HotkeysSettingsPane()
    case .advanced:
        AdvancedSettingsPane()
    case .updates:
        UpdatesSettingsPane()  // 取消注释，启用更新页面
    case .about:
        AboutSettingsPane()
    default:
        HStack {
            Text("detailView")
        }
    }
}
```

---

### 阶段 7：在 About 页面添加检查更新按钮

**文件**: `Sources/Monet/Settings/AboutSettingsPane.swift`

```swift
var body: some View {
    HStack {
        Spacer()
        Image("Monet")
            .resizable()
            .frame(width: 200, height: 200)

        VStack(alignment: .leading) {
            Text("Monet")
                .font(.largeTitle)
                .foregroundStyle(.primary)

            HStack(spacing: 4) {
                Text("Version")
                Text(Constants.appVersion)
            }
            .font(.system(size: minFrameDimension / 30))
            .foregroundStyle(.secondary)

            // 添加检查更新按钮
            Button("Check for Updates...") {
                SPUStandardUpdaterController.sharedInstance().updater.checkForUpdates()
            }
            .padding(.top, 8)
        }
        .fontWeight(.medium)
        .padding([.vertical, .trailing])
        Spacer()
    }
    .frame(
        maxWidth: .infinity,
        maxHeight: .infinity
    )
    .bottomBar {
        // ... 现有代码
    }
}
```

---

### 阶段 8：GitHub Actions 集成

**文件**: `.github/workflows/release.yml`

在现有 workflow 中添加 Sparkle 签名步骤：

```yaml
# 在创建 Release 之前添加以下步骤

- name: Install Sparkle
  run: |
    brew install sparkle

- name: Sign update and create appcast
  env:
    SPARKLE_PRIVATE_ED_KEY: ${{ secrets.SPARKLE_PRIVATE_ED_KEY }}
  run: |
    VERSION=${{ steps.version.outputs.version }}
    DMG_FILE="Monet-v${VERSION}.dmg"
    ZIP_FILE="Monet-v${VERSION}.app.zip"

    # 为 DMG 生成签名
    DMG_SIGNATURE=$(echo "$SPARKLE_PRIVATE_ED_KEY" | sparkle --sign-update --file "$DMG_FILE")

    # 为 ZIP 生成签名
    ZIP_SIGNATURE=$(echo "$SPARKLE_PRIVATE_ED_KEY" | sparkle --sign-update --file "$ZIP_FILE")

    # 生成 appcast.xml
    cat > appcast.xml << EOF
    <?xml version="1.0" encoding="utf-8"?>
    <rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
      <channel>
        <title>Monet</title>
        <description>Most recent changes with links to updates.</description>
        <language>en</language>
        <item>
          <title>Version ${VERSION}</title>
          <description>Release notes here</description>
          <pubDate>$(date -R)</pubDate>
          <enclosure url="https://github.com/wflixu/Monet/releases/download/v${VERSION}/${DMG_FILE}" sparkle:version="${VERSION}" sparkle:shortVersionString="${VERSION}" sparkle:edSignature="${DMG_SIGNATURE}" length="0" type="application/octet-stream"/>
        </item>
      </channel>
    </rss>
    EOF

- name: Upload appcast.xml
  uses: softprops/action-gh-release@v2
  with:
    files: appcast.xml
    allow_empty_files: true
```

---

## 跳过版本机制

### Sparkle 内置实现

Sparkle 使用 `UserDefaults` 存储跳过的版本：

```swift
// Sparkle 内部实现
UserDefaults.standard.set(version, forKey: "SUSkippedVersion")
```

### 用户流程

```
更新提示窗口
┌─────────────────────────────────────┐
│  Update Available                   │
│  Version 1.2.0 is now available     │
│                                     │
│  [ Skip Version ]  [ Remind Later ] │
│  [    Download    ]                 │
└─────────────────────────────────────┘
```

- **Skip Version**: 写入 `SUSkippedVersion`，该版本不再提示
- **Remind Later**: 不记录，下次启动继续提示
- **Download**: 开始下载更新

### 清除跳过版本

如果用户想重新接收跳过的版本通知，可以在设置页添加"清除跳过版本"按钮：

```swift
// 清除跳过的版本
UserDefaults.standard.removeObject(forKey: "SUSkippedVersion")
```

---

## 文件清单

### 需要新建的文件

| 文件路径 | 说明 |
|----------|------|
| `Sources/Monet/Settings/UpdatesSettingsPane.swift` | 更新设置页面 |

### 需要修改的文件

| 文件路径 | 修改内容 |
|----------|----------|
| `Package.swift` | 添加 Sparkle 依赖 |
| `Sources/Monet/Info.plist` | 添加 Sparkle 配置 (SUFeedURL, SUPublicEDKey 等) |
| `Sources/Monet/MonetApp.swift` | 导入 Sparkle，初始化 SPUStandardUpdaterController |
| `Sources/Monet/SettingsView.swift` | 启用 UpdatesSettingsPane |
| `Sources/Monet/Settings/AboutSettingsPane.swift` | 添加检查更新按钮 |
| `.github/workflows/release.yml` | 添加 Sparkle 签名和 appcast 生成步骤 |

---

## 验证步骤

### 1. 本地构建测试

- [ ] 运行 `swift package resolve` 成功
- [ ] 运行 `swift build` 编译通过
- [ ] App 正常启动
- [ ] 设置页 Updates 面板显示正常
- [ ] 点击"检查更新"有响应（无更新时提示已是最新版本）

### 2. 密钥配置测试

- [ ] 生成 EdDSA 密钥对
- [ ] 公钥正确填入 Info.plist
- [ ] 私钥正确存入 GitHub Secrets

### 3. GitHub Actions 测试

- [ ] 推送测试 tag (如 v0.1.5-test)
- [ ] Workflow 成功执行
- [ ] appcast.xml 正确生成并上传
- [ ] DMG/ZIP 文件带签名

### 4. 端到端测试

- [ ] 安装旧版本（模拟已发布版本）
- [ ] 启动 App 检测更新
- [ ] 显示更新提示
- [ ] 测试"跳过此版本"功能
- [ ] 测试"稍后提醒"功能
- [ ] 测试下载安装重启流程

---

## 参考资料

- [Sparkle 官方文档](https://sparkle-project.org/documentation/)
- [Sparkle GitHub](https://github.com/sparkle-project/Sparkle)
- [Sparkle 2.x 迁移指南](https://sparkle-project.org/documentation/sparkle-2-upgrade/)
- [EdDSA 密钥生成](https://sparkle-project.org/documentation/eddsa/)
