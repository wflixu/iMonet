# StoreKit 内购测试指南

## 前提

StoreKit 测试**必须在 Xcode 中运行**（`swift run` 不行），因为需要将 `.storekit` 配置文件关联到 Scheme。

## 第一步：配置 StoreKit Configuration

1. Xcode 打开 `iMonet.xcodeproj`
2. 菜单 **Product → Scheme → Edit Scheme...** (或 `Cmd+<`)
3. 左侧选择 **Run** → 右侧选择 **Options** 标签
4. **StoreKit Configuration** 下拉 → 选择 `iMonet.storekit`
5. 关闭窗口

这一步告诉 Xcode 使用本地 `.storekit` 文件替代真实的 App Store 沙盒环境。

## 第二步：基础购买流程测试

| # | 操作 | 预期 |
|---|------|------|
| 1 | Xcode `Cmd+R` 运行 App | 正常启动，无报错 |
| 2 | 菜单 **Debug → Force Show Purchase Prompt** (`Cmd+Shift+P`) | 弹出购买弹窗，显示两个产品及价格 |
| 3 | 切换选中包年 / 买断 | "立即购买" 按钮文字随价格变化 |
| 4 | 点击 **"下次再说"** | 弹窗关闭 |
| 5 | 再按 `Cmd+Shift+P` | 弹窗重新出现（Debug 强制触发） |
| 6 | 选择任一产品，点 **"立即购买"** | 弹出系统 StoreKit 测试面板 |
| 7 | 在测试面板选 **"Purchase"**（默认） | 弹窗消失，购买成功 |

## 第三步：验证购买生效

购买成功后，验证以下两处：

| 检查点 | 位置 | 预期 |
|--------|------|------|
| 弹窗 | 按 `Cmd+Shift+P` → 弹窗不会再出现 | 不弹窗（已购买） |
| 设置页 | **Preferences... → 通用 → "支持 iMonet"** | 显示红心 + "Purchase Successful" + "Thank you" |

## 第四步：验证权益持久化

1. `Cmd+Q` 完全退出 App
2. `Cmd+R` 重新运行
3. 验证：设置页仍显示已购买状态
4. 验证：`Cmd+Shift+P` 仍不会弹窗

## 第五步：StoreKit 测试面板场景

Xcode 的 StoreKit 测试面板在购买时还可以选以下几种结果：

| 选择 | 预期 |
|------|------|
| **Purchase** | 购买成功 |
| **Cancel** | 用户取消，弹窗还在，`purchaseError` 为 nil |
| **Pending** | 购买挂起，显示 "Purchase Pending" |
| **Fail** | 购买失败，`purchaseError` 显示错误信息 |

## 第六步：退款测试

1. Xcode 菜单 **Debug → StoreKit → Manage Transactions...**
2. 找到刚才的交易 → 右键 **Refund**
3. 重启 App — 设置页应显示未购买状态，弹窗可再次触发

## 第七步：重置（反复测试用）

菜单 **Debug → Reset Purchase State** (`Cmd+Shift+R`)：

- 清空所有 UsageTracker 数据
- 重置 `storeManager.isPurchased = false`
- 后可重新用 `Cmd+Shift+P` 触发弹窗
