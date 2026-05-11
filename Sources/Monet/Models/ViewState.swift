//
//  ViewState.swift
//  Monet
//
//  Created by luke on 2025/11/8.
//

import Combine
import SwiftUI
import OSLog

class ViewState: ObservableObject {
    @AppLog(category: "ViewState")
    private var logger

    @Published var scale: Double = 1.0
    @Published var offset: CGSize = .zero
    @Published var anchor: UnitPoint = .center
    @Published var rotation: Double = 0.0
    @Published var fitToWindow: Bool = true

    // Click position tracking
    @Published var clickPosition: CGPoint?
    @Published var imageSize: CGSize = .zero

    // Constants
    private let minScale: Double = 0.1
    private let maxScale: Double = 10.0

    init() {}

    // MARK: - Click Position Tracking

    func recordClickPosition(_ position: CGPoint) {
        clickPosition = position
        updateAnchorBasedOnClick()
    }

    // MARK: 根据imageSize 和 clickPosition 计算 anchor

    func updateAnchorBasedOnClick() {
        guard let clickPos = clickPosition, imageSize.width > 0, imageSize.height > 0 else {
            return
        }

        // 考虑 offset 的影响，计算实际在图像上的位置
        let imageX = (clickPos.x - offset.width / scale) 
        let imageY = (clickPos.y - offset.height / scale)

        // 归一化到图像尺寸
        let normalizedX = clickPos.x / imageSize.width
        let normalizedY = clickPos.y / imageSize.height

        // 确保 anchor 值在 0-1 范围内
        let clampedX = max(0, min(1, normalizedX))
        let clampedY = max(0, min(1, normalizedY))

        let newOffset = CGSize(
            width: offset.width + (anchor.x - clampedX) * imageSize.width * scale,
            height: offset.height + (anchor.y - clampedY) * imageSize.height * scale
        )
        anchor = UnitPoint(x: clampedX, y: clampedY)
        offset = newOffset
    }

    func clearClickPosition() {
        clickPosition = nil
    }

    // MARK: - Zoom Operations

    func zoom(factor: Double) {
        let newScale = scale * factor

        if newScale != scale {
            scale = newScale
        }
    }

    /// 以鼠标位置为中心进行缩放（Google Picasa 风格）
    /// - Parameters:
    ///   - factor: 缩放因子（>1 放大，<1 缩小）
    ///   - mouseLocation: 鼠标在视图中的位置（坐标系：原点在左上角）
    ///   - viewSize: 视图尺寸
    ///   - logger: 日志记录器
    func zoomAtMousePosition(factor: Double, mouseLocation: CGPoint, viewSize: CGSize, logger: Logger) {
        let newScale = min(max(scale * factor, minScale), maxScale)
        guard newScale != scale else {
            logger.log("scale unchanged: \(self.scale)")
            return
        }

        let scaleRatio = newScale / scale

        logger.log("===== [zoomAtMousePosition] =====")
        logger.log("  mouseLocation: (\(mouseLocation.x), \(mouseLocation.y))")
        logger.log("  viewSize: \(viewSize.width) x \(viewSize.height)")
        logger.log("  viewCenter: (\(viewSize.width / 2), \(viewSize.height / 2))")

        // 将鼠标位置转换到以视图中心为原点的坐标系
        // mouseLocation 原点在左上角，需要转换
        let cursorX = mouseLocation.x - viewSize.width / 2
        let cursorY = mouseLocation.y - viewSize.height / 2

        // 计算新的 offset，使鼠标下的图像点保持不变
        let newOffsetX = (offset.width - cursorX) * scaleRatio + cursorX
        let newOffsetY = (offset.height - cursorY) * scaleRatio + cursorY

        logger.log("  cursor (centered): (\(cursorX), \(cursorY))")
        logger.log("  scale: \(self.scale) -> \(newScale) (ratio: \(scaleRatio))")
        logger.log("  offset: (\(self.offset.width), \(self.offset.height)) -> (\(newOffsetX), \(newOffsetY))")
        logger.log("======================================")

        scale = newScale
        offset = CGSize(width: newOffsetX, height: newOffsetY)
    }

    func pan(delta: CGSize) {
        // 确保增量是有效值
        guard delta.width.isFinite && delta.height.isFinite else {
            return
        }

        let newOffset = CGSize(
            width: offset.width + delta.width,
            height: offset.height + delta.height
        )

        // 确保新的偏移量也是有效值
        guard newOffset.width.isFinite && newOffset.height.isFinite else {
            return
        }

        offset = newOffset
    }

    func setPan(offset: CGSize) {
        // 确保偏移量是有效值
        guard offset.width.isFinite && offset.height.isFinite else {
            return
        }
        self.offset = offset
    }

    func reset() {
        scale = 1.0
        offset = .zero
        anchor = .center
        rotation = 0.0
        fitToWindow = true
        clearClickPosition()
    }

    // MARK: - Bounds Checking

    func isScaleValid(_ newScale: Double) -> Bool {
        return (minScale ... maxScale).contains(newScale)
    }

    // MARK: - Convenience

    var isAtDefaultScale: Bool {
        return abs(scale - 1.0) < 0.001
    }

    var isZoomed: Bool {
        return !isAtDefaultScale
    }

    var isPanned: Bool {
        return abs(offset.width) > 0.1 || abs(offset.height) > 0.1
    }
}
