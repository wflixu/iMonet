import AppKit
import SwiftUI

// MARK: - NSView: Image display with zoom & pan

final class MonetImageView: NSView {
    var image: NSImage? {
        didSet { needsDisplay = true }
    }

    var onStateChanged: ((CGFloat) -> Void)?
    var onClick: (() -> Void)?
    var isDarkMode = false

    private(set) var magnification: CGFloat = 1.0
    private var offset: CGPoint = .zero
    private var hasPerformedInitialFit = false

    private let minMag: CGFloat = 0.1
    private let maxMag: CGFloat = 16.0

    // Pan state
    private var dragStartPoint: CGPoint = .zero
    private var dragStartOffset: CGPoint = .zero
    private var isPotentialClick = false

    // MARK: - Lifecycle

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window != nil, !hasPerformedInitialFit {
            DispatchQueue.main.async { [weak self] in
                self?.fitToWindow()
            }
        }
    }

    override func layout() {
        super.layout()
        if !hasPerformedInitialFit, bounds.width > 0, bounds.height > 0 {
            fitToWindow()
        }
    }

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        let fillColor: NSColor = isDarkMode
            ? NSColor(white: 0.15, alpha: 1.0)
            : NSColor(white: 0.9, alpha: 1.0)
        fillColor.setFill()
        bounds.fill()

        guard let image, let context = NSGraphicsContext.current?.cgContext else { return }

        context.saveGState()

        // Transform: center in view → apply pan offset → scale
        let cx = bounds.width / 2 + offset.x
        let cy = bounds.height / 2 + offset.y
        context.translateBy(x: cx, y: cy)
        context.scaleBy(x: magnification, y: magnification)

        // Draw image centered at origin
        let imageRect = NSRect(
            x: -image.size.width / 2,
            y: -image.size.height / 2,
            width: image.size.width,
            height: image.size.height
        )
        image.draw(in: imageRect, from: .zero, operation: .sourceOver, fraction: 1.0)

        context.restoreGState()
    }

    // MARK: - Scroll Wheel (Command + scroll = zoom)

    override func scrollWheel(with event: NSEvent) {
        guard event.modifierFlags.contains(.command) else {
            super.scrollWheel(with: event)
            return
        }

        let factor: CGFloat = event.scrollingDeltaY > 0 ? 1.1 : 0.9
        let newMag = (magnification * factor).clamped(to: minMag...maxMag)
        guard newMag != magnification else { return }

        let scaleRatio = newMag / magnification

        // Mouse position in this view's coordinate system (bottom-left origin)
        let mouseInView = convert(event.locationInWindow, from: nil)

        // Convert to center-relative coordinates
        let mouseCenteredX = mouseInView.x - bounds.width / 2
        let mouseCenteredY = mouseInView.y - bounds.height / 2

        // Compute new offset such that the pixel under the mouse stays fixed
        let newOffsetX = (offset.x - mouseCenteredX) * scaleRatio + mouseCenteredX
        let newOffsetY = (offset.y - mouseCenteredY) * scaleRatio + mouseCenteredY

        magnification = newMag
        offset = CGPoint(x: newOffsetX, y: newOffsetY)

        needsDisplay = true
        onStateChanged?(magnification)
    }

    // MARK: - Mouse Drag (pan)

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        dragStartPoint = point
        dragStartOffset = offset
        isPotentialClick = true
    }

    override func mouseDragged(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        let dx = point.x - dragStartPoint.x
        let dy = point.y - dragStartPoint.y

        if abs(dx) > 3 || abs(dy) > 3 {
            isPotentialClick = false
        }

        let newOffsetX = dragStartOffset.x + dx
        let newOffsetY = dragStartOffset.y + dy

        guard newOffsetX.isFinite, newOffsetY.isFinite else { return }

        offset = CGPoint(x: newOffsetX, y: newOffsetY)
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        if isPotentialClick {
            onClick?()
        }
        isPotentialClick = false
    }

    // MARK: - Fit to Window

    func fitToWindow() {
        guard let image else { return }
        guard bounds.width > 0, bounds.height > 0 else { return }

        let fitMag = min(
            bounds.width / image.size.width,
            bounds.height / image.size.height
        )
        magnification = fitMag
        offset = .zero
        hasPerformedInitialFit = true
        needsDisplay = true

        onStateChanged?(magnification)
    }

    // MARK: - Toolbar Zoom Actions

    func zoomIn() {
        zoomAtCenter(factor: 1.25)
    }

    func zoomOut() {
        zoomAtCenter(factor: 0.8)
    }

    private func zoomAtCenter(factor: CGFloat) {
        let newMag = (magnification * factor).clamped(to: minMag...maxMag)
        guard newMag != magnification else { return }

        let scaleRatio = newMag / magnification
        magnification = newMag
        offset.x = offset.x * scaleRatio
        offset.y = offset.y * scaleRatio
        needsDisplay = true
        onStateChanged?(magnification)
    }
}

extension CGFloat {
    func clamped(to range: ClosedRange<CGFloat>) -> CGFloat {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}

// MARK: - NSViewRepresentable bridge

struct MonetImageRepresentable: NSViewRepresentable {
    let image: NSImage?
    let isDarkMode: Bool
    var onStateChanged: ((CGFloat) -> Void)?
    var onViewCreated: ((MonetImageView) -> Void)?
    var onClick: (() -> Void)?

    func makeNSView(context: Context) -> MonetImageView {
        let view = MonetImageView()
        view.image = image
        view.isDarkMode = isDarkMode
        view.onStateChanged = onStateChanged
        view.onClick = onClick
        DispatchQueue.main.async {
            onViewCreated?(view)
        }
        return view
    }

    func updateNSView(_ nsView: MonetImageView, context: Context) {
        nsView.image = image
        nsView.isDarkMode = isDarkMode
        nsView.onStateChanged = onStateChanged
        nsView.onClick = onClick
    }
}

// MARK: - SwiftUI Wrapper

struct ZoomableImageView: View {
    @Environment(\.colorScheme) private var colorScheme

    let image: NSImage?
    var onScaleChanged: ((CGFloat) -> Void)?
    var onViewCreated: ((MonetImageView) -> Void)?
    var onClick: (() -> Void)?

    var body: some View {
        MonetImageRepresentable(
            image: image,
            isDarkMode: colorScheme == .dark,
            onStateChanged: onScaleChanged,
            onViewCreated: onViewCreated,
            onClick: onClick
        )
    }
}

#Preview {
    ZoomableImageView(image: NSImage(systemSymbolName: "photo", accessibilityDescription: nil))
        .background(Color.gray)
}
