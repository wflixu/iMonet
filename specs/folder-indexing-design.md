# Design: Smart Folder Indexing (Revised)

## 变更概述

当用户打开一张图片时，Monet 提供索引当前文件夹下所有图片的功能，在侧边栏显示缩略图以便快速导航。

---

## 1. 权限策略（重要修改）

### 审核反馈
> Full Disk Access 不应作为首选方案。App Store 审核风险高，且无法程序化检测。应优先使用 security-scoped bookmarks + on-the-fly NSOpenPanel。

### 最终方案：三层权限

| 优先级 | 方案 | 用户体验 | App Store 风险 |
|--------|------|----------|----------------|
| **⭐ 1** | On-the-fly `fileImporter` 授权文件夹 | 在索引提示中用 fileImporter 获取权限，一键授权 | 无 |
| **2** | Security-scoped bookmarks（已有） | 设置中手动添加常用文件夹，重启后仍有效 | 无 |
| **3** | Full Disk Access（可选） | 在设置中作为高级选项说明，不主动推出 | 仅作说明无风险 |

### Tier 1 流程（核心新功能）
```
用户打开图片 → 提示栏显示"此文件夹有 12 张图片 [浏览全部]"
→ 用户点击 → 弹出 fileImporter 预定位到该文件夹
→ 用户点击"允许" → 获得安全范围访问 → 扫描目录 → 显示侧边栏
→ 保存 bookmark 以便下次无需重复授权
```

### Tier 3：仅在设置中提及
- 设置页面底部增加一个小节："高级：全磁盘访问"
- 说明：如果希望打开任意文件夹都无需授权，可前往系统设置开启
- 按钮："打开系统设置" → `x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles`

---

## 2. 用户流程（修改后）

```
用户打开图片 (Finder双击 / 拖拽 / File > Open)
  │
  ├─ showCurDirImg == true AND 该文件夹已有 bookmark
  │   │
  │   ├─ startAccessingSecurityScopedResource() 成功 → 扫描目录 → 显示侧边栏
  │   └─ 失败（bookmark 过期等）→ 降级为显示单张图片 + 提示栏
  │
  └─ showCurDirImg == false OR 该文件夹无 bookmark
      │
      └─ 显示非模态提示栏（在图片上方）：
          "此文件夹包含 12 张图片 [浏览全部] [✕]"
          │
          ├─ "浏览全部" → 弹出 fileImporter 定位到父目录
          │   ├─ 用户授权 → 扫描目录 → 保存 bookmark → 显示侧边栏
          │   └─ 用户取消 → 仅显示当前图片，提示栏消失
          └─ "✕" → 关闭提示栏，仅显示当前图片
```

**关键改进**：只有 1 个非模态提示 + 最多 1 个 fileImporter，比原来的 3 层对话框大幅简化。

---

## 3. 文件变更清单

| 文件 | 变更类型 | 说明 |
|------|----------|------|
| `Sources/iMonet/AppState.swift` | 修改 | 新增状态变量 |
| `Sources/iMonet/iiMonetApp.swift` | 修改 | `loadImages()` 增加权限检测、后台扫描、bookmark 管理 |
| `Sources/iMonet/ContentView.swift` | 修改 | 增加非模态索引提示栏 |
| `Sources/iMonet/Settings/GeneralSettingsPane.swift` | 修改 | 文案优化、增加全磁盘访问说明 |
| `Sources/iMonet/Shared/Constants.swift` | 修改 | 新增 UserDefaults key |

**不新增文件**。提示栏用简单的 overlay 实现，不单独建文件。

---

## 4. 详细设计

### 4.1 AppState 新增属性

```swift
// 是否显示索引提示栏
@Published var showIndexBanner: Bool = false

// 当前待索引的文件夹 URL
@Published var pendingDirectoryURL: URL?

// 当前文件夹的图片数量（预扫描结果）
@Published var pendingDirectoryImageCount: Int = 0

// 索引提示栏是否已被用户关闭（本次会话内不再提示同一文件夹）
@Published var dismissedBannerFolder: URL?
```

### 4.2 AppDelegate.loadImages() 改造

```swift
func loadImages(from url: URL) {
    guard let appState else { return }
    let directory = url.deletingLastPathComponent()

    // 先显示当前图片
    appState.imageFiles = [url]
    appState.selectedImageIndex = 0
    appState.currentImageURL = url

    if !appState.showCurDirImg {
        // 未开启索引 → 预扫描目录获取图片数量 → 显示提示栏
        DispatchQueue.global(qos: .userInitiated).async {
            let count = self.countImages(in: directory)
            DispatchQueue.main.async {
                if count > 0 {
                    appState.pendingDirectoryURL = directory
                    appState.pendingDirectoryImageCount = count
                    appState.showIndexBanner = true
                }
            }
        }
        return
    }

    // 已开启索引 → 尝试使用已有 bookmark 或触发 fileImporter
    indexFolder(directory, currentURL: url)
}

private func countImages(in directory: URL) -> Int {
    // 先检查是否有安全范围访问
    let accessing = directory.startAccessingSecurityScopedResource()
    defer { if accessing { directory.stopAccessingSecurityScopedResource() } }

    guard let files = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) else {
        return 0
    }
    return files.filter { ["png", "jpg", "jpeg", "gif", "webp"].contains($0.pathExtension.lowercased()) }.count
}

func indexFolder(_ directory: URL, currentURL: URL) {
    guard let appState else { return }

    let accessing = directory.startAccessingSecurityScopedResource()
    defer { if accessing { directory.stopAccessingSecurityScopedResource() } }

    guard let files = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) else {
        // 无权限 → 提示用户通过 fileImporter 授权
        appState.pendingDirectoryURL = directory
        appState.showIndexBanner = true
        return
    }

    let imageFiles = files
        .filter { ["png", "jpg", "jpeg", "gif", "webp"].contains($0.pathExtension.lowercased()) }
        .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }

    appState.imageFiles = imageFiles
    appState.selectedImageIndex = imageFiles.firstIndex(of: currentURL) ?? 0
    appState.currentImageURL = currentURL
}

/// 通过 fileImporter 获取文件夹访问权限，成功后保存 bookmark
func authorizeAndIndexFolder(_ directory: URL) {
    // 触发 fileImporter，由 ContentView 处理回调
    // 回调后调用 indexFolder() 并保存 bookmark
}
```

### 4.3 ContentView 新增索引提示栏

在图片上方叠加一个非模态提示栏（不阻塞操作）：

```swift
// 在 ContentView 的 ZStack 中添加
if appState.showIndexBanner, let dirURL = appState.pendingDirectoryURL {
    VStack {
        HStack {
            Image(systemName: "photo.stack")
            Text("此文件夹包含 \(appState.pendingDirectoryImageCount) 张图片")
            Button("浏览全部") {
                showFolderImporter = true
            }
            Button(action: {
                appState.showIndexBanner = false
            }) {
                Image(systemName: "xmark")
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(8)
        .padding(.top, 8)

        Spacer()
    }
    .transition(.move(edge: .top))
}
.fileImporter(
    isPresented: $showFolderImporter,
    allowedContentTypes: [.directory],
    allowsMultipleSelection: false
) { result in
    if case .success(let urls) = result, let dir = urls.first {
        let gotAccess = dir.startAccessingSecurityScopedResource()
        if gotAccess {
            appState.indexFolder(dir, currentURL: appState.currentImageURL!)
            // 保存 bookmark
            appState.dirs.append(dir)
            appState.storeBookmarkData()
        }
        appState.showIndexBanner = false
    }
}
```

### 4.4 GeneralSettingsPane 修改

- 现有 "Explore dir" 开关 → 改为 "自动索引文件夹中的图片"
- 增加说明文字
- 现有文件夹列表保留
- 底部增加全磁盘访问说明区（可选，不显眼）：

```swift
// 在 Form 末尾新增 Section
Section {
    VStack(alignment: .leading, spacing: 4) {
        Text("高级：全磁盘访问").font(.caption).foregroundColor(.secondary)
        Text("如果希望打开任意文件夹都无需单独授权，可在系统设置中为 Monet 开启全磁盘访问权限。")
            .font(.caption2).foregroundColor(.secondary)
        Button("打开系统设置...") {
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
                NSWorkspace.shared.open(url)
            }
        }
    }
}
```

---

## 5. 侧边栏交互（已有，确认正常）

- 缩略图列表：`ImageThumbnailView`，左侧面板
- 点击切换：`.onTapGesture` → `loadImage(at:)`
- 高亮：`isSelected` → 白色边框
- 键盘左右键：`NSEvent.addLocalMonitorForEvents`
- 工具栏前后切换：`showPreviousImage()` / `showNextImage()`
- 滚动到当前图片：`scrollViewProxy?.scrollTo(index)`

**注意**：现有缩略图使用 `NSImage(contentsOf:)` 加载，对于大量图片可能有性能问题。当前图片加载逻辑不变，后续需要时可增加缩略图缓存。

---

## 6. 关键修复

### 6.1 startAccessingSecurityScopedResource
在读取目录前必须调用 `startAccessingSecurityScopedResource()`，读取后调用 `stopAccessingSecurityScopedResource()`。现有代码（`iiMonetApp.swift:161`）缺少此调用。

### 6.2 后台线程扫描
对于大文件夹，在后台队列扫描目录，避免阻塞主线程：
```swift
DispatchQueue.global(qos: .userInitiated).async {
    // scan directory
    DispatchQueue.main.async {
        // update UI
    }
}
```

### 6.3 临时目录过滤
跳过临时目录（如 `/private/var/folders/...`）和系统目录的索引提示：
```swift
private func shouldSkipIndexing(_ directory: URL) -> Bool {
    let path = directory.path
    if path.hasPrefix(NSTemporaryDirectory()) { return true }
    if path.hasPrefix("/System/") { return true }
    return false
}
```

### 6.4 文件排序
扫描结果按文件名自然排序（localizedStandardCompare）。

---

## 7. 边界情况

| 场景 | 处理 |
|------|------|
| 文件夹只有 1 张图片 | 不显示提示栏（count > 1 才显示） |
| 文件夹无图片 | 不显示提示栏 |
| 用户取消 fileImporter | 仅显示当前图片 |
| 临时目录打开图片 | 跳过索引提示 |
| 系统目录 | 跳过索引提示 |
| 大文件夹（10000+ 图片） | 后台扫描，不阻塞 UI |
| 外部驱动器 / 网络卷 | `contentsOfDirectory` 可能慢，后台处理 |
| bookmark 过期 | 降级为单图片 + 提示栏 |

---

## 8. 不做的

- 递归索引子文件夹
- 监控文件夹变化
- 缩略图磁盘缓存
- 程序化检测 Full Disk Access 状态
