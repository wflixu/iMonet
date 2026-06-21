# Monet 自动更新实施计划 (Sparkle)

> **技术选型**: Sparkle 2.x + GitHub Releases
> **预计时间**: 4-6 小时
> **文档版本**: 1.0

---

## 概述

本文档描述 Monet macOS 应用使用 Sparkle 框架实现自动更新功能的具体实施步骤。

---

## 前置准备

### 1. 生成 EdDSA 密钥对

```bash
# 安装 Sparkle
brew install sparkle

# 生成密钥对
cd /opt/homebrew/opt/sparkle/bin
./generate_ed_key
```

**输出示例**:
```
Public key: 8a5b7c9d2e3f4a1b6c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0b
Private key: 1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0b1c2d3e4f5a6b7c8d9e0f1a2b
```

**保存密钥**:
- 公钥 → 暂时保存，用于填入 Info.plist
- 私钥 → 存入 GitHub Secrets

### 2. 配置 GitHub Secrets

在 GitHub 仓库 `Settings → Secrets and variables → Actions` 中添加：

| Secret Name | Value |
|-------------|-------|
| `SPARKLE_PRIVATE_ED_KEY` | 上一步生成的私钥 |

---

## 实施步骤

### 步骤 1: 添加 Sparkle 依赖

**文件**: `Package.swift`

在 `dependencies` 数组中添加：

```swift
.package(url: "https://github.com/sparkle-project/Sparkle.git", from: "2.6.0"),
```

在 Monet target 的 `dependencies` 中添加：

```swift
.product(name: "Sparkle", package: "Sparkle"),
```

**完整示例**:

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
        // Sparkle
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
                .product(name: "LaunchAtLogin", package: "LaunchAtLogin-Modern"),
                .product(name: "SDWebImageSwiftUI", package: "SDWebImageSwiftUI"),
            ],
            path: "Sources/Monet"
        )
    ]
)
```

---

### 步骤 2: 配置 Info.plist

**文件**: `Sources/iMonet/Info.plist`

在 `</dict>` 之前添加：

```xml
<!-- Sparkle Configuration -->
<key>SUFeedURL</key>
<string>https://github.com/wflixu/Monet/releases/latest/download/appcast.xml</string>

<key>SUPublicEDKey</key>
<string>[填入生成的公钥]</string>

<key>SUEnableAutomaticChecks</key>
<false/>

<key>SUEnableSkipVersionUpdates</key>
<true/>
```

---

### 步骤 3: 初始化 Sparkle

**文件**: `Sources/iMonet/iiMonetApp.swift`

**修改 1**: 在文件顶部添加导入

```swift
import Sparkle
```

**修改 2**: 在 struct 中添加 updaterController

```swift
@main
struct iMonetApp: App {
    @AppLog(category: "iMonetApp")
    private var logger

    @Environment(\.openWindow) private var openWindow

    @AppStorage("showMenuBarExtra") private var showMenuBarExtra = true

    // Sparkle 更新器控制器
    private let updaterController: SPUStandardUpdaterController

    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @ObservedObject var appState = AppState()

    init() {
        logger.info("app init.....")

        // 初始化 Sparkle
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )

        appDelegate.assignAppState(appState)
    }

    // ... rest of the code
}
```

---

### 步骤 4: 创建 UpdatesSettingsPane

**文件**: `Sources/iMonet/Settings/UpdatesSettingsPane.swift` (新建)

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

    private var updater: SPUUpdater {
        SPUStandardUpdaterController.sharedInstance().updater
    }

    private var automaticallyCheckForUpdates: Bool {
        get { updater.automaticallyChecksForUpdates }
        nonmutating set {
            updater.automaticallyChecksForUpdates = newValue
        }
    }

    var body: some View {
        Form {
            Section {
                HStack {
                    Text("Current Version")
                    Spacer()
                    Text(Constants.appVersion)
                        .foregroundColor(.secondary)
                }
            }

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

### 步骤 5: 启用 Updates 设置页

**文件**: `Sources/iMonet/SettingsView.swift`

找到 `detailView` 的 switch 语句，取消注释 `.updates` 分支：

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
        UpdatesSettingsPane()  // 取消这行的注释
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

### 步骤 6: 在 About 页面添加检查更新按钮

**文件**: `Sources/iMonet/Settings/AboutSettingsPane.swift`

在版本号下方添加按钮：

```swift
HStack(spacing: 4) {
    Text("Version")
    Text(Constants.appVersion)
}
.font(.system(size: minFrameDimension / 30))
.foregroundStyle(.secondary)

// 添加这段代码
Button("Check for Updates...") {
    SPUStandardUpdaterController.sharedInstance().updater.checkForUpdates()
}
.padding(.top, 8)
```

---

### 步骤 7: 更新 GitHub Actions

**文件**: `.github/workflows/release.yml`

在 `Create Release` 步骤之前添加 Sparkle 签名步骤：

```yaml
# 在 "9. 创建 Release 并上传" 之前添加

- name: Install Sparkle
  run: |
    brew install sparkle

- name: Sign updates and create appcast
  env:
    SPARKLE_PRIVATE_ED_KEY: ${{ secrets.SPARKLE_PRIVATE_ED_KEY }}
    VERSION: ${{ steps.version.outputs.version }}
  run: |
    DMG_FILE="Monet-v${VERSION}.dmg"
    ZIP_FILE="Monet-v${VERSION}.app.zip"

    # 为 DMG 生成签名
    echo "Signing DMG..."
    DMG_SIG=$(echo "$SPARKLE_PRIVATE_ED_KEY" | sparkle --sign-update --file "$DMG_FILE" 2>&1 | grep -oP 'edSignature="\K[^"]+' || echo "")

    # 为 ZIP 生成签名
    echo "Signing ZIP..."
    ZIP_SIG=$(echo "$SPARKLE_PRIVATE_ED_KEY" | sparkle --sign-update --file "$ZIP_FILE" 2>&1 | grep -oP 'edSignature="\K[^"]+' || echo "")

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
          <pubDate>$(date -R)</pubDate>
          <enclosure url="https://github.com/wflixu/Monet/releases/download/v${VERSION}/${DMG_FILE}"
                     sparkle:version="${VERSION}"
                     sparkle:shortVersionString="${VERSION}"
                     sparkle:edSignature="${DMG_SIG}"
                     length="$(stat -f%z "$DMG_FILE")"
                     type="application/octet-stream"/>
        </item>
      </channel>
    </rss>
    EOF

    echo "Generated appcast.xml:"
    cat appcast.xml

- name: Upload appcast.xml
  uses: softprops/action-gh-release@v2
  with:
    files: appcast.xml
```

---

## 时间估算

| 步骤 | 预计时间 |
|------|----------|
| 生成密钥对 | 10 分钟 |
| 配置 GitHub Secrets | 5 分钟 |
| 添加 Sparkle 依赖 | 10 分钟 |
| 配置 Info.plist | 5 分钟 |
| 初始化 iiMonetApp.swift | 10 分钟 |
| 创建 UpdatesSettingsPane | 30 分钟 |
| 启用设置页 | 5 分钟 |
| About 页面添加按钮 | 5 分钟 |
| 更新 GitHub Actions | 30 分钟 |
| 本地编译测试 | 30 分钟 |
| **总计** | **约 2.5 小时** |

---

## 验收标准

- [ ] `swift build` 编译通过
- [ ] App 能正常启动运行
- [ ] 设置页显示 "Updates" 选项
- [ ] Updates 页面显示当前版本
- [ ] "检查更新"按钮可点击
- [ ] 无更新时显示相应提示
- [ ] GitHub Actions 成功生成 appcast.xml
- [ ] appcast.xml 包含正确的签名

---

## 测试流程

### 本地测试

1. 编译运行 App
2. 打开 Settings → Updates
3. 点击 "Check for Updates"
4. 验证无更新时的提示

### 端到端测试

1. 推送测试 tag: `git tag v0.1.5-test && git push origin v0.1.5-test`
2. 观察 GitHub Actions 执行
3. 检查 appcast.xml 是否正确生成
4. 修改 Info.plist 版本号为更低版本
5. 重启 App，检查是否能检测到更新

---

## 常见问题

### Q: 编译错误 "No such module 'Sparkle'"
A: 运行 `swift package resolve` 重新解析依赖

### Q: GitHub Actions 签名失败
A: 检查 `SPARKLE_PRIVATE_ED_KEY` secret 是否正确配置

### Q: 更新提示窗口不显示
A: 检查 Info.plist 中的 `SUPublicEDKey` 是否正确

---

## 参考资料

- [Sparkle 官方文档](https://sparkle-project.org/documentation/)
- [Sparkle 2.x 迁移指南](https://sparkle-project.org/documentation/sparkle-2-upgrade/)
- [EdDSA 签名](https://sparkle-project.org/documentation/eddsa/)
