完全理解了，是“优先支持鼠标”——这个出发点非常合理。macOS 自带预览把触控板体验做得近乎完美，鼠标的 `Command + 滚轮` 缩放反而成了容易被忽略但很实用的功能，你优先打磨这点完全正确。

那么基于这个前提，之前给你的那个 `ZoomableScrollView` 方案依然是最优解，而且**它天然就是“鼠标优先”的**：

- **鼠标：** `Command + 滚轮` 触发精确缩放，锚点在鼠标位置  
- **触控板：** `allowsMagnification = true` 自动支持双指捏合缩放，完全原生手感  
- **普通鼠标滚轮：** 不按 `Command` 时就是正常的上下/左右滚动，丝毫不受影响

所以你并不需要在两种输入设备之间做取舍，一个 `scrollWheel(with:)` 重写就同时覆盖了，而且鼠标的缩放逻辑非常干净，不会拖累触控板体验。

### 如果还想让鼠标缩放更细腻

因为普通鼠标滚轮 `deltaY` 是离散的 ±1，缩放可能会有“跳一下”的感觉。想让鼠标的 `Command + 滚轮` 也像触控板一样顺滑，可以在 `scrollWheel` 里加一个小延迟平滑：

```swift
// 基于 scrollingDeltaY（像素级），并使用动画过渡
if event.modifierFlags.contains(.command) {
    let step = 1.0 + event.scrollingDeltaY * 0.002  // 系数可根据手感调整
    let newMag = (self.magnification * step).clamped(to: minMagnification...maxMagnification)
    NSAnimationContext.runAnimationGroup { context in
        context.duration = 0.15
        self.animator().setMagnification(newMag, centeredAt: mousePoint)
    }
}
```
