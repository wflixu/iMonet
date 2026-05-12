import AppKit
import SwiftUI

// MARK: - NSView: Image display with zoom & pan

final class MonetImageView: NSView {
    var image: NSImage? {
        didSet { needsDisplay = true }
    }

    var onStateChanged: ((CGFloat) -> Void)?

    private(set) var magnification: CGFloat = 1.0
    private var offset: CGPoint = .zero
    private var hasPerformedInitialFit = false

    private let minMag: CGFloat = 0.1
    private let maxMag: CGFloat = 10.0

    // Pan state
    private var dragStartPoint: CGPoint = .zero
    private var dragStartOffset: CGPoint = .zero

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
        NSColor.black.setFill()
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
    }

    override func mouseDragged(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        let dx = point.x - dragStartPoint.x
        let dy = point.y - dragStartPoint.y

        let newOffsetX = dragStartOffset.x + dx
        let newOffsetY = dragStartOffset.y + dy

        guard newOffsetX.isFinite, newOffsetY.isFinite else { return }

        offset = CGPoint(x: newOffsetX, y: newOffsetY)
        needsDisplay = true
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
    var onStateChanged: ((CGFloat) -> Void)?
    var onViewCreated: ((MonetImageView) -> Void)?

    func makeNSView(context: Context) -> MonetImageView {
        let view = MonetImageView()
        view.image = image
        view.onStateChanged = onStateChanged
        DispatchQueue.main.async {
            onViewCreated?(view)
        }
        return view
    }

    func updateNSView(_ nsView: MonetImageView, context: Context) {
        nsView.image = image
        nsView.onStateChanged = onStateChanged
    }
}

// MARK: - SwiftUI Wrapper

struct ZoomableImageView: View {
    let image: NSImage?
    var onScaleChanged: ((CGFloat) -> Void)?
    var onViewCreated: ((MonetImageView) -> Void)?

    var body: some View {
        MonetImageRepresentable(
            image: image,
            onStateChanged: onScaleChanged,
            onViewCreated: onViewCreated
        )
    }
}

#Preview {
    ZoomableImageView(image: Bundle.module.image(forResource: "sample"))
        .background(Color.gray)
}
