# Command + 滚轮鼠标位置缩放设计方案

## 背景

用户希望实现类似 Google Picasa 的缩放体验：按住 Command + 滚动滚轮时，图片以鼠标指针位置为中心进行缩放。

当前代码已有基础框架，但存在以下问题：
1. 滚轮事件监听是全局的，无法获取鼠标在视图中的准确位置
2. 缩放逻辑没有基于鼠标位置计算 anchor 和 offset
3. 坐标转换逻辑不正确

## 问题分析

### 当前架构

```
LayoutView
└── ZoomableImageView
    ├── Image (使用 viewState.scale, viewState.anchor, viewState.offset)
    └── ScrollWheelMonitor (NSViewRepresentable 监听滚轮)
```

### 核心问题

1. **ScrollWheelMonitor 事件监听方式错误**
   - 当前使用 `NSEvent.addLocalMonitorForEvents` 全局监听
   - 无法获取事件发生时鼠标相对于图像的位置
   - 应该使用局部监听，在 `NSViewRepresentable` 内部处理事件

2. **ViewState.zoom() 缺少鼠标位置参数**
   - 当前方法签名：`zoom(factor: Double)`
   - 需要改为：`zoom(factor: Double, mouseLocation: CGPoint, viewSize: CGSize)`

3. **坐标转换逻辑缺失**
   - 需要将鼠标位置转换为以图像中心为原点的坐标
   - 缩放后需要调整 offset，使鼠标下的图像点保持不变

## 设计方案

### 核心算法

以鼠标为中心缩放的数学原理：

```
1. 获取鼠标在视图中的位置 (mouseX, mouseY)
2. 转换为以视图中心为原点的坐标：
   cursorX = mouseX - viewWidth / 2
   cursorY = (viewHeight - mouseY) - viewHeight / 2  // Y 轴翻转

3. 计算新缩放比例：newScale = scale * zoomFactor

4. 计算新的 offset，使鼠标下的点保持不变：
   newOffset.x = (offset.x - cursorX) * (newScale / scale) + cursorX
   newOffset.y = (offset.y - cursorY) * (newScale / scale) + cursorY
```

### 修改文件

#### 1. `Sources/Monet/Models/ViewState.swift`

新增方法：
```swift
func zoomAtMousePosition(factor: Double, mouseLocation: CGPoint, viewSize: CGSize, imageSize: CGSize)
```

实现逻辑：
- 计算鼠标位置相对于视图中心
- 应用缩放
- 调整 offset 使鼠标下的图像点保持固定

#### 2. `Sources/Monet/ZoomableImageView.swift`

修改 `ScrollWheelMonitor`：
- 移除全局事件监听
- 在 `NSViewRepresentable` 内部创建自定义 `NSView`
- 重写 `scrollWheel(with:)` 方法
- 从事件中提取鼠标位置并传递给 ViewState

### 边界处理

1. **最小/最大缩放限制**：0.1x - 10.0x（已有常量）
2. **图像超出视图时的边界限制**：防止拖出黑边
3. **图像小于视图时居中**：自动居中显示

### 参考代码要点 (来自 docs/temp.md)

```swift
// 坐标转换：将鼠标位置转换到以视图中心为原点
private func convertToCentered(_ point: CGPoint, size: CGSize) -> CGPoint {
    CGPoint(
        x: point.x - size.width / 2,
        y: (size.height - point.y) - size.height / 2  // Y 轴翻转
    )
}

// 缩放处理
private func handleZoom(delta: CGFloat, cursor: CGPoint, viewSize: CGSize) {
    let zoom = 1 + delta * 0.001
    let newScale = min(max(scale * zoom, 0.2), 20)
    let scaleRatio = newScale / scale

    var newOffset = CGPoint(
        x: (offset.x - cursor.x) * scaleRatio + cursor.x,
        y: (offset.y - cursor.y) * scaleRatio + cursor.y
    )

    newOffset = clampOffset(newOffset, scale: newScale, viewSize: viewSize)

    scale = newScale
    offset = newOffset
}
```

## 实施步骤

1. **修改 ViewState.swift**
   - 新增 `zoomAtMousePosition` 方法
   - 保留现有 `zoom` 方法用于兼容

2. **修改 ZoomableImageView.swift**
   - 重构 `ScrollWheelMonitor` 为局部事件处理
   - 创建 `CustomScrollView` 处理滚轮事件
   - 传递鼠标位置给 ViewState

3. **测试验证**
   - 运行 App，选择图片
   - 按住 Command + 滚动滚轮
   - 验证：鼠标指哪放哪缩，不会漂移

## 验证标准

- [ ] 按住 Command + 滚轮向上，图片放大，鼠标位置下的图像点保持固定
- [ ] 按住 Command + 滚轮向下，图片缩小，鼠标位置下的图像点保持固定
- [ ] 缩放流畅，没有跳跃或漂移
- [ ] 边界情况下（最小/最大缩放）行为正确
