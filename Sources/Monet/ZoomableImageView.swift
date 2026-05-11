import SwiftData
import SwiftUI
import AppKit
import OSLog

struct ZoomableImageView: View {
    @AppLog(category: "ZoomableImageView")
    private var logger

    @EnvironmentObject var viewState: ViewState
    @State private var dragStartOffset: CGSize = .zero

    var body: some View {
        GeometryReader { geometry in
            Image("sample")
                .resizable()
                .aspectRatio(nil, contentMode: .fit)
                .scaleEffect(viewState.scale)
                .offset(viewState.offset)
                
                .contentShape(Rectangle()) // Make entire image clickable
                .background(
                    GeometryReader { imageGeometry in
                        Color.clear
                            .onAppear {
                                viewState.imageSize = imageGeometry.size
                            }
                            .onChange(of: imageGeometry.size) { _, newSize in
                                viewState.imageSize = newSize
                            }
                    }
                )
                .onTapGesture { location in
                    // Store the click position relative to the image
                    viewState.recordClickPosition(location)
                }
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            // 计算新的偏移量：起始偏移量 + 当前拖动偏移量
                            let newOffset = CGSize(
                                width: dragStartOffset.width + value.translation.width,
                                height: dragStartOffset.height + value.translation.height
                            )

                            // 确保偏移量是有效值
                            guard newOffset.width.isFinite && newOffset.height.isFinite else {
                                return
                            }

                            viewState.setPan(offset: newOffset)
                        }
                        .onEnded { _ in
                            // 更新起始偏移量为当前偏移量，以便下次拖动从此位置开始
                            // 确保保存的偏移量是有效的
                            if viewState.offset.width.isFinite && viewState.offset.height.isFinite {
                                dragStartOffset = viewState.offset
                            }
                        }
                )
                .background(
                    ScrollWheelMonitor(viewState: viewState, viewBounds: geometry.size)
                )
                .onAppear {
                    // 打印几何尺寸用于调试
                    print("ZoomableImageView appeared with size: \(geometry.size)")
                }
               
        }
    }
    
}

struct ScrollWheelMonitor: NSViewRepresentable {
    @ObservedObject var viewState: ViewState
    let viewBounds: CGSize
    let logger = Logger(subsystem: "Monet", category: "ScrollWheelMonitor")

    func makeNSView(context: Context) -> NSView {
        let view = CustomScrollView()
        view.viewState = viewState
        view.logger = logger
        view.viewBounds = viewBounds
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        if let view = nsView as? CustomScrollView {
            view.viewState = viewState
            view.viewBounds = viewBounds
        }
    }
}

class CustomScrollView: NSView {
    var viewState: ViewState?
    var logger: Logger?
    var viewBounds: CGSize = .zero

    override var acceptsFirstResponder: Bool {
        return true
    }

    init() {
        super.init(frame: .zero)
        setupGlobalMonitor()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupGlobalMonitor()
    }

    nonisolated(unsafe) private var eventMonitor: Any?

    private func setupGlobalMonitor() {
        logger?.log("CustomScrollView setupGlobalMonitor")

        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            guard let self = self else { return event }

            // 检查是否按下了 Command 键
            guard event.modifierFlags.contains(.command) else {
                return event
            }

            self.logger?.log("===== [GlobalScrollWheel] =====")
            self.logger?.log("  scrollingDeltaY: \(event.scrollingDeltaY)")

            // 获取鼠标在窗口中的位置
            let windowLocation = event.locationInWindow
            self.logger?.log("  windowLocation: (\(windowLocation.x), \(windowLocation.y))")
            self.logger?.log("  viewBounds: \(self.viewBounds.width) x \(self.viewBounds.height)")

            // 计算缩放因子
            let zoomFactor: Double
            if event.scrollingDeltaY > 0 {
                zoomFactor = 1.1
                self.logger?.log("  action: ZOOM IN")
            } else {
                zoomFactor = 0.9
                self.logger?.log("  action: ZOOM OUT")
            }

            // 转换坐标：NSView (左下原点) -> SwiftUI (左上原点)
            // 由于是全局监听，我们假设 mouseLocation 已经是相对于视图的
            // 这里需要知道视图在窗口中的位置才能准确计算
            // 简单处理：直接使用窗口坐标，假设视图占满窗口
            let mouseLocation = CGPoint(x: windowLocation.x, y: windowLocation.y)

            self.logger?.log("  mouseLocation (for zoom): (\(mouseLocation.x), \(mouseLocation.y))")

            // 使用当前视图尺寸作为视图尺寸
            let viewSize = self.viewBounds.width > 0 ? self.viewBounds : CGSize(width: 1920, height: 1080)

            self.viewState?.zoomAtMousePosition(
                factor: zoomFactor,
                mouseLocation: mouseLocation,
                viewSize: viewSize,
                logger: self.logger ?? Logger(subsystem: "Monet", category: "ViewState")
            )

            self.logger?.log("==============================")

            // 消耗掉事件，不让其他视图处理
            return nil
        }
    }

    deinit {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }

    override func scrollWheel(with event: NSEvent) {
        logger?.log("----- [CustomScrollView.scrollWheel] -----")
        logger?.log("  event.locationInWindow: (\(event.locationInWindow.x), \(event.locationInWindow.y))")
        logger?.log("  scrollingDeltaY: \(event.scrollingDeltaY)")

        // 检查是否按下了 Command 键
        guard event.modifierFlags.contains(.command) else {
            logger?.log("  -> IGNORED: Command key not pressed")
            return
        }

        logger?.log("  Command key detected, processing...")

        // 获取鼠标在视图中的位置
        // NSView 坐标系原点在左下角，需要转换为 SwiftUI 坐标系（原点在左上角）
        let locationInWindow = event.locationInWindow
        let location = convert(locationInWindow, from: nil)

        logger?.log("  bounds: \(self.bounds.width) x \(self.bounds.height)")
        logger?.log("  locationInWindow: (\(locationInWindow.x), \(locationInWindow.y))")
        logger?.log("  converted location: (\(location.x), \(location.y))")

        // 转换 Y 轴：从左下角原点转换为左上角原点
        let flippedLocation = CGPoint(
            x: location.x,
            y: self.bounds.height - location.y
        )

        logger?.log("  flippedLocation: (\(flippedLocation.x), \(flippedLocation.y))")
        logger?.log("------------------------------------------")
    }
}

#Preview {
    ZoomableImageView()
        .background(Color.gray)
}
