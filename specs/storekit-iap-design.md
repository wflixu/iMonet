# StoreKit 内购集成设计

## 背景

iMonet 是免费图片查看器。如果设置付费，下载量很低；如果免费，有用户但没有收入。所以集成 StoreKit 内购，以"不限制功能 + 偶尔提示购买"的方式实现收入。

用户购买后弹窗永远不再出现。

---

## 1. 触发时机

跟踪的是 **App 启动次数**（`applicationDidFinishLaunching` 时 +1）。

| | 首次提示 | 关闭后再次提示 |
|---|---|---|
| 打开次数 | >= 15 次 | 距上次提示再多 >= 10 次 |
| 时间间隔 | 距首次使用 >= 7 天 | 距上次提示 >= 5 天 |
| 条件关系 | 两个条件都满足 | 两个条件都满足 |

**示例时间线：**
- Day 1: 首次启动，count=1
- Day 3: count=10（不满 15 次，不弹）
- Day 8: count=16，距首次 8 天 → 首次弹窗
- Day 13: count=26，距上次 5 天 + 多用了 10 次 → 再次弹窗
- Day 18: count=36，距上次 5 天 + 又多用了 10 次 → 再次弹窗

---

## 2. 内购产品

| 产品 | 价格 | StoreKit 类型 | Product ID |
||---|---|---|---|
| 包年支持 | $0.99/年 | Auto-Renewable Subscription | `cn.wflixu.Monet.yearly` |
| 终生买断 | $2.99 | Non-Consumable | `cn.wflixu.Monet.lifetime` |

> **注意：** Product ID 需要在 App Store Connect 中配置，与代码中保持一致。

---

## 3. 弹窗设计

### 视觉结构

```
┌──────────────────────────────────────────┐
│                                          │
│            🎨 支持 iMonet                 │
│                                          │
│    感谢你使用 iMonet 浏览图片！            │
│    如果觉得好用，请考虑支持我们：           │
│                                          │
│    ┌────────────────────────────────┐    │
│    │ ○ 包年支持                     │    │
│    │ ● 终生买断                     │    │
│    └────────────────────────────────┘    │
│                                          │
│      [ 下次再说 ]    [ 立即购买 ]         │
│                                          │
└──────────────────────────────────────────┘
```

### 行为
- 弹窗以 `.sheet` 或 overlay 形式出现在窗口中央
- 半透明背景遮罩，点击遮罩不做任何操作（强制用户做出选择）
- 两个产品选项用 radio-button 风格，默认选中"终生买断"
- **"立即购买"** → 走 StoreKit 支付流程 → 成功后弹窗消失，记录已购买，永不再弹
- **"下次再说"** → 关闭弹窗，记录本次提示时间 + 当前启动次数
- 如果 StoreKit 拉取产品失败，降级显示通用文案（不显示具体价格）

### 窗口层级
- 弹窗作为 ContentView 的最顶层 overlay
- zIndex 高于工具栏和其他浮动 UI
- `allowsHitTesting(true)` 确保拦截所有交互

---

## 4. 文件结构

### 新增文件（`Sources/iMonet/Store/` 目录）

```
Sources/iMonet/Store/
├── UsageTracker.swift        # 启动次数和提示时间的跟踪
├── StoreManager.swift        # StoreKit 2 集成
└── PurchasePromptView.swift  # 购买弹窗 UI
```

#### UsageTracker.swift

```swift
// 纯静态方法，不需要实例化
enum UsageTracker {
    static var openCount: Int
    static var firstLaunchDate: Date?
    static var lastPromptDate: Date?
    static var lastPromptOpenCount: Int
    static var hasPurchased: Bool
    
    static func recordLaunch()     // 启动计数 +1
    static func recordPrompt()     // 记录本次提示时间和计数
    static func recordPurchase()   // 标记已购买
    static func shouldShowPrompt() -> Bool
}
```

所有数据通过 `UserDefaults` 持久化：

| Key | 类型 | 说明 |
|---|---|---|
| `usage_firstLaunchDate` | Double | 首次启动时间戳 |
| `usage_openCount` | Int | 累计启动次数 |
| `usage_lastPromptDate` | Double | 上次弹窗时间戳 |
| `usage_lastPromptOpenCount` | Int | 上次弹窗时的启动次数 |
| `usage_hasPurchased` | Bool | 本地购买标记 |

#### StoreManager.swift

```swift
@MainActor
class StoreManager: ObservableObject {
    @Published var products: [Product] = []          // 从 App Store 拉取的产品
    @Published var isPurchased = false               // StoreKit 验证的购买状态
    @Published var isPurchasing = false              // 是否正在购买中
    @Published var purchaseError: String?            // 购买错误信息
    
    func loadProducts() async                        // 拉取产品列表
    func purchase(_ product: Product) async          // 购买
    func verifyEntitlement() async                   // 启动时验证权益
    func listenForTransactions()                     // 监听交易更新
}
```

关键设计：
- 通过 `Transaction.currentEntitlements` 验证用户是否已购买
- 通过 `Transaction.updates` 监听外部交易（如家庭共享、退款）
- 购买成功后同时更新 `StoreManager.isPurchased` 和 `UsageTracker.hasPurchased`
- 价格显示直接从 `Product.displayPrice` 获取（自动本地化）

#### PurchasePromptView.swift

```swift
struct PurchasePromptView: View {
    @EnvironmentObject var storeManager: StoreManager
    @Binding var isPresented: Bool
    
    @State private var selectedProductType: ProductType = .lifetime
    
    enum ProductType { case yearly, lifetime }
}
```

关键设计：
- 选择的产品通过 `ProductType` 枚举映射到 StoreKit `Product`
- 购买按钮文案动态显示价格：`"立即购买 (\(product.displayPrice))"`
- 加载产品中显示 loading 状态
- 购买中禁用按钮，防止重复点击
- 购买失败显示错误信息
- 购买成功自动关闭弹窗

### 修改文件

#### AppState.swift
```diff
+ @Published var storeManager = StoreManager()
```

#### iiMonetApp.swift
```diff
  func applicationDidFinishLaunching(_ notification: Notification) {
      logger.info("applicationDidFinishLaunching  .......")
+     UsageTracker.recordLaunch()
+     Task {
+         await appState.storeManager.loadProducts()
+         await appState.storeManager.verifyEntitlement()
+     }
+     Task.detached {
+         await appState.storeManager.listenForTransactions()
+     }
  }
```
- `appState` 需要注入 `storeManager`，或通过 `.environmentObject(appState.storeManager)` 传递

#### ContentView.swift
```diff
+ @State private var showPurchasePrompt = false
+ @EnvironmentObject var storeManager: StoreManager

  .onAppear {
+     checkPurchasePrompt()
  }

+ func checkPurchasePrompt() {
+     if UsageTracker.shouldShowPrompt() && !storeManager.isPurchased {
+         showPurchasePrompt = true
+     }
+ }
```

弹窗展示位置（放在 ZStack 最顶层）：
```swift
// 在 ZStack 最末尾（最高层级）
if showPurchasePrompt {
    PurchasePromptView(isPresented: $showPurchasePrompt)
        .zIndex(100)
        .transition(.opacity)
}
```

#### Localizable.xcstrings
新增字符串：

| Key | en | zh-Hans |
|---|---|---|
| `Support iMonet` | Support iMonet | 支持 iMonet |
| `Thank you for using iMonet to browse images! If you find it useful, please consider supporting us:` | (同上英文) | 感谢你使用 iMonet 浏览图片！如果觉得好用，请考虑支持我们：|
| `Yearly Support` | Yearly Support | 包年支持 |
| `Lifetime Purchase` | Lifetime Purchase | 终生买断 |
| `Buy Now` | Buy Now | 立即购买 |
| `Maybe Later` | Maybe Later | 下次再说 |
| `Purchasing...` | Purchasing... | 购买中... |
| `Purchase Successful` | Purchase Successful | 购买成功 |
| `Purchase Failed` | Purchase Failed | 购买失败 |

---

## 5. 购买验证流程

```
App 启动
    │
    ├─ UsageTracker.recordLaunch()      // 计数 +1
    ├─ StoreManager.loadProducts()      // 拉取产品信息
    └─ StoreManager.verifyEntitlement() // 验证是否已购买
            │
            ├─ 已购买 → UsageTracker.hasPurchased = true
            │          弹窗永不出现
            │
            └─ 未购买 → UsageTracker.shouldShowPrompt()
                          │
                          ├─ true  → 显示弹窗
                          └─ false → 继续正常使用
```

**双重验证：**
- `UsageTracker.hasPurchased`（UserDefaults，快速判断）
- `StoreManager.isPurchased`（StoreKit 验证，权威来源）
- 以 StoreKit 为准：即使 UserDefaults 被篡改，StoreKit 验证不过就不会隐藏弹窗

---

## 6. 测试方案

### 6.1 测试分层

这个功能分为两层，需要不同的测试方式：

| 层级 | 测试内容 | 测试方式 |
|---|---|---|
| UI 层 | 弹窗显示/关闭、产品选项切换、文案正确性 | `swift run` + Debug 辅助 |
| StoreKit 层 | 产品拉取、购买流程、权益验证 | Xcode + .storekit 配置 |

### 6.2 StoreKit Configuration 本地测试

在 Xcode 项目中创建 `iMonet.storekit` 配置文件，模拟 App Store 环境：

**文件内容（`iMonet.storekit`）：**
```
- 添加两个产品：
  - cn.wflixu.Monet.yearly (Auto-Renewable Subscription, $0.99/年)
  - cn.wflixu.Monet.lifetime (Non-Consumable, $2.99)
- 启用 "Use StoreKit Configuration" 后，所有购买走本地模拟
- 无需联网，无需 App Store Connect 配置
```

**在 Xcode 中启用：**
1. 用 Xcode 打开 `iMonet.xcodeproj`
2. Product → Scheme → Edit Scheme → Run → Options
3. StoreKit Configuration → 选择 `iMonet.storekit`
4. 通过 Xcode Run 来测试完整购买流程

**配置文件中可测试的场景：**
- 产品信息拉取成功
- 购买成功 → StoreManager.isPurchased = true
- 购买失败/取消 → purchaseError 有值
- 退款后重新验证 → isPurchased 变回 false
- 订阅续期 → currentEntitlements 更新

### 6.3 Debug 辅助功能

为了日常开发调试方便，在 Debug 构建中添加以下辅助功能。

#### 6.3.1 重置按钮（帮助菜单中）

在 `iiMonetApp.swift` 的 `commands` 中添加：

```swift
#if DEBUG
CommandMenu("Debug") {
    Button("Force Show Purchase Prompt") {
        // 直接弹窗，绕过触发条件
    }
    .keyboardShortcut("p", modifiers: [.command, .shift])
    
    Button("Reset Purchase State") {
        UsageTracker.resetAll()
        // 重置后会再次弹窗，方便重复测试
    }
    .keyboardShortcut("r", modifiers: [.command, .shift])
}
#endif
```

#### 6.3.2 UsageTracker 辅助属性

```swift
#if DEBUG
extension UsageTracker {
    // 在 Debug 构建下提供重置方法
    static func resetAll() {
        UserDefaults.standard.removeObject(forKey: "usage_firstLaunchDate")
        UserDefaults.standard.removeObject(forKey: "usage_openCount")
        UserDefaults.standard.removeObject(forKey: "usage_lastPromptDate")
        UserDefaults.standard.removeObject(forKey: "usage_lastPromptOpenCount")
        UserDefaults.standard.removeObject(forKey: "usage_hasPurchased")
    }
    
    // 强制满足触发条件（设置为即将触发）
    static func forceReadyForPrompt() {
        let now = Date()
        UserDefaults.standard.set(now.timeIntervalSince1970 - 7*24*3600, forKey: "usage_firstLaunchDate")
        UserDefaults.standard.set(15, forKey: "usage_openCount")
    }
}
#endif
```

#### 6.3.3 StoreManager 中支持模拟购买

```swift
#if DEBUG
extension StoreManager {
    // 跳过 StoreKit 直接标记已购买（仅测试用）
    func debugMarkAsPurchased() {
        isPurchased = true
        UsageTracker.hasPurchased = true
    }
}
#endif
```

### 6.4 日常测试流程

**测试 UI 和触发逻辑（用 `swift run`）：**

1. `swift run` 启动应用
2. 用 Debug 菜单 → "Force Show Purchase Prompt" 直接看弹窗
3. 测试产品选项切换、中英文文案、按钮交互
4. 测试"下次再说"关闭弹窗
5. 用 Debug 菜单 → "Reset Purchase State" 重置后用 "Force Show" 再次测试
6. 重复测试 2-5 验证 UI 稳定性

**测试完整购买流程（用 Xcode + .storekit）：**

1. 在 Xcode 中配置 StoreKit Configuration
2. Xcode Run → 用 Debug 菜单触发弹窗
3. 点击"立即购买" → 系统购买弹窗出现
4. 选择"购买成功" / "购买失败" / "取消" 分别测试
5. 购买成功后重启 App → 验证 StoreKit verifyEntitlement 正确
6. 在 .storekit 中模拟退款 → 重启 App → 验证弹窗恢复

### 6.5 各功能点验证清单

- [ ] 产品拉取成功 → 弹窗显示价格
- [ ] 产品拉取失败 → 弹窗降级显示（无价格）
- [ ] 选择包年 → 购买按钮显示包年价格
- [ ] 选择买断 → 购买按钮显示买断价格
- [ ] 点击"下次再说" → 弹窗关闭，记录时间戳和计数
- [ ] 点击"立即购买" → 走 StoreKit 支付流程
- [ ] 购买成功 → 弹窗关闭，isPurchased = true
- [ ] 购买失败 → 显示错误信息，弹窗不关闭
- [ ] 购买取消 → 弹窗保持显示
- [ ] 首次弹窗：count < 15 → 不弹
- [ ] 首次弹窗：day < 7 → 不弹
- [ ] 首次弹窗：count >= 15 AND day >= 7 → 弹出
- [ ] 再次弹窗：再开 < 10 次 → 不弹
- [ ] 再次弹窗：距上次 < 5 天 → 不弹
- [ ] 再次弹窗：count+ >= 10 AND day+ >= 5 → 弹出
- [ ] 已购买后满足触发条件 → 不弹
- [ ] 中英文切换 → 文案正确
- [ ] 暗色模式 → 弹窗样式正常

### 6.6 注意事项

- **StoreKit 测试需要在沙盒环境进行**，可在 Xcode 中创建 StoreKit Configuration 文件进行本地测试
- **首次启动时 StoreKit 产品可能尚未加载完成**，弹窗应在产品加载完成后再判断
- `listenForTransactions()` 需要在后台 Task 中运行，因为它是一个 `AsyncSequence`
- 包年订阅的续期状态由 StoreKit 自动管理，退款/取消后 `currentEntitlements` 会相应变化
- **Debug 辅助功能用 `#if DEBUG` 包裹**，不会出现在 Release 构建中
- 在 App Store Connect 上线前，需要切换到真实的 StoreKit 环境再做一次完整测试
