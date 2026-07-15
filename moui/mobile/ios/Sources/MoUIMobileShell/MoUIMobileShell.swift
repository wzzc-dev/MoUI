import Metal
import MoUIMobileRuntimeBridge
import QuartzCore
import SwiftUI
import UIKit

public enum MOUIMobileStatusBarMode: String {
  case auto
  case visible
  case hidden
}

public enum MOUIMobileOrientation: String {
  case any
  case portrait
  case landscape

  fileprivate var mask: UIInterfaceOrientationMask {
    switch self {
    case .any: return .all
    case .portrait: return .portrait
    case .landscape: return .landscape
    }
  }
}

public struct MOUIMobileConfiguration {
  public let appArgument: String
  public let renderer: String
  public let fullscreen: Bool
  public let statusBar: MOUIMobileStatusBarMode
  public let orientation: MOUIMobileOrientation
  public let plugins: [MOUIMobilePlugin.Type]

  public init(
    appArgument: String,
    renderer: String = "auto",
    fullscreen: Bool = false,
    statusBar: MOUIMobileStatusBarMode = .auto,
    orientation: MOUIMobileOrientation = .any,
    plugins: [MOUIMobilePlugin.Type] = []
  ) {
    self.appArgument = appArgument
    self.renderer = renderer
    self.fullscreen = fullscreen
    self.statusBar = statusBar
    self.orientation = orientation
    self.plugins = plugins
  }
}

private final class MOUIMobileSystemPolicy {
  static let shared = MOUIMobileSystemPolicy()
  var orientation: MOUIMobileOrientation = .any

  private init() {}
}

public final class MOUIMobileApplicationDelegate: NSObject, UIApplicationDelegate {
  public func application(
    _ application: UIApplication,
    supportedInterfaceOrientationsFor window: UIWindow?
  ) -> UIInterfaceOrientationMask {
    MOUIMobileSystemPolicy.shared.orientation.mask
  }

  public func applicationWillTerminate(_ application: UIApplication) {
    _ = MOUIMobileRuntimeBridge.shared.destroyApplication()
  }
}

private final class MOUIMobileSceneLease {
  static let shared = MOUIMobileSceneLease()
  static let unsupported: Int32 = -1001

  private var activeIdentifier: String?

  private init() {}

  func acquire(identifier: String) -> Int32 {
    dispatchPrecondition(condition: .onQueue(.main))
    if activeIdentifier == nil || activeIdentifier == identifier {
      activeIdentifier = identifier
      return 1
    }
    return Self.unsupported
  }

  func release(identifier: String) {
    dispatchPrecondition(condition: .onQueue(.main))
    if activeIdentifier == identifier {
      activeIdentifier = nil
    }
  }
}

private final class MOUIPassthroughOverlayView: UIView {
  override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
    let hit = super.hitTest(point, with: event)
    return hit === self ? nil : hit
  }
}

public final class MOUIMetalSurfaceView: UIView {
  public override class var layerClass: AnyClass { CAMetalLayer.self }

  var layoutHandler: (() -> Void)?
  var pointerHandler: ((Int32, CGPoint, TimeInterval) -> Void)?

  public override init(frame: CGRect) {
    super.init(frame: frame)
    isMultipleTouchEnabled = false
    isOpaque = true
    backgroundColor = .black
    (layer as? CAMetalLayer)?.framebufferOnly = true
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) is unavailable")
  }

  public override func layoutSubviews() {
    super.layoutSubviews()
    layoutHandler?()
  }

  public override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
    forward(touches, phase: 0)
  }

  public override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
    forward(touches, phase: 1)
  }

  public override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
    forward(touches, phase: 2)
  }

  public override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
    forward(touches, phase: 3)
  }

  private func forward(_ touches: Set<UITouch>, phase: Int32) {
    guard let touch = touches.first else { return }
    pointerHandler?(phase, touch.location(in: self), touch.timestamp)
  }
}

final class MOUIMobileSceneIdentity: ObservableObject {
  let value = UUID().uuidString
}

public struct MOUIMobileRootView: View {
  private let configuration: MOUIMobileConfiguration
  @Environment(\.scenePhase) private var scenePhase
  @StateObject private var sceneIdentity = MOUIMobileSceneIdentity()

  public init(configuration: MOUIMobileConfiguration) {
    self.configuration = configuration
  }

  @ViewBuilder
  public var body: some View {
    let surface = MOUIMobileSurfaceRepresentable(
      configuration: configuration,
      sceneIdentifier: sceneIdentity.value,
      scenePhase: scenePhase
    )
    if configuration.fullscreen {
      surface
        .ignoresSafeArea()
        .statusBarHidden(true)
    } else {
      surface.statusBarHidden(configuration.statusBar == .hidden)
    }
  }
}

public struct MOUIMobileSurfaceRepresentable: UIViewRepresentable {
  let configuration: MOUIMobileConfiguration
  let sceneIdentifier: String
  let scenePhase: ScenePhase

  public func makeCoordinator() -> Coordinator {
    Coordinator(configuration: configuration, sceneIdentifier: sceneIdentifier)
  }

  public func makeUIView(context: Context) -> UIView {
    context.coordinator.makeView()
  }

  public func updateUIView(_ uiView: UIView, context: Context) {
    context.coordinator.transition(to: scenePhase)
  }

  public static func dismantleUIView(_ uiView: UIView, coordinator: Coordinator) {
    coordinator.dismantle()
  }

  public final class Coordinator: NSObject {
    private let configuration: MOUIMobileConfiguration
    private let sceneIdentifier: String
    private let bridge = MOUIMobileRuntimeBridge.shared
    private weak var surface: MOUIMetalSurfaceView?
    private var hostAdapter: MOUIMobileHostAdapter?
    private var displayLink: CADisplayLink?
    private var attached = false
    private var active = false
    private var lastPixelSize: CGSize = .zero
    private var suppressPointerStream = false

    init(configuration: MOUIMobileConfiguration, sceneIdentifier: String) {
      self.configuration = configuration
      self.sceneIdentifier = sceneIdentifier
    }

    func makeView() -> UIView {
      let root = UIView(frame: .zero)
      root.backgroundColor = .black
      let surface = MOUIMetalSurfaceView(frame: root.bounds)
      surface.autoresizingMask = [.flexibleWidth, .flexibleHeight]
      let overlay = MOUIPassthroughOverlayView(frame: root.bounds)
      overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
      overlay.backgroundColor = .clear
      root.addSubview(surface)
      root.addSubview(overlay)
      self.surface = surface

      let sceneStatus = MOUIMobileSceneLease.shared.acquire(identifier: sceneIdentifier)
      guard sceneStatus > 0 else {
        NSLog("moui-mobile ios rejected additional scene status=%d", sceneStatus)
        return root
      }
      guard bridge.compatible else {
        NSLog("moui-mobile ios runtime ABI v1 is incompatible")
        return root
      }
      let started = bridge.start(
        withAppArgument: configuration.appArgument,
        renderer: configuration.renderer
      )
      guard started > 0 else {
        NSLog("moui-mobile ios runtime start failed status=%d", started)
        return root
      }
      MOUIMobileSystemPolicy.shared.orientation = configuration.orientation
      MOUIMobilePluginRegistry.shared.install(configuration.plugins)
      hostAdapter = MOUIMobileHostAdapter(surface: surface, overlay: overlay)
      surface.layoutHandler = { [weak self] in self?.attachOrResize() }
      surface.pointerHandler = { [weak self] phase, point, timestamp in
        self?.dispatchPointer(phase: phase, point: point, timestamp: timestamp)
      }
      let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
      pan.cancelsTouchesInView = false
      surface.addGestureRecognizer(pan)
      active = true
      startDisplayLink()
      DispatchQueue.main.async { [weak self] in self?.attachOrResize() }
      return root
    }

    func transition(to phase: ScenePhase) {
      guard active else { return }
      switch phase {
      case .active:
        startDisplayLink()
        attachOrResize()
      case .background:
        detach()
      case .inactive:
        stopDisplayLink()
      @unknown default:
        stopDisplayLink()
      }
    }

    func dismantle() {
      detach()
      MOUIMobileSceneLease.shared.release(identifier: sceneIdentifier)
      active = false
      surface = nil
      hostAdapter = nil
    }

    private func attachOrResize() {
      guard active, let surface, surface.window != nil else { return }
      let scale = surface.window?.screen.scale ?? UIScreen.main.scale
      let size = CGSize(
        width: max(1, (surface.bounds.width * scale).rounded()),
        height: max(1, (surface.bounds.height * scale).rounded())
      )
      guard size != lastPixelSize || !attached else { return }
      let status: Int32
      if attached {
        status = bridge.resizeWidth(
          Int32(size.width),
          height: Int32(size.height),
          scale: scale
        )
      } else {
        status = bridge.attachSurfaceView(
          surface,
          width: Int32(size.width),
          height: Int32(size.height),
          scale: scale
        )
      }
      if status > 0 {
        attached = true
        lastPixelSize = size
      }
    }

    private func detach() {
      stopDisplayLink()
      if attached {
        _ = bridge.detachSurface()
        attached = false
      }
      lastPixelSize = .zero
      hostAdapter?.reset()
    }

    private func dispatchPointer(phase: Int32, point: CGPoint, timestamp: TimeInterval) {
      guard attached, let surface else { return }
      if phase == 0 { suppressPointerStream = false }
      guard !suppressPointerStream else { return }
      let scale = surface.window?.screen.scale ?? UIScreen.main.scale
      _ = bridge.dispatchPointerPhase(
        phase,
        x: point.x * scale,
        y: point.y * scale,
        timeMs: timestamp * 1000
      )
    }

    @objc private func handlePan(_ recognizer: UIPanGestureRecognizer) {
      guard attached, let surface else { return }
      let point = recognizer.location(in: surface)
      let translation = recognizer.translation(in: surface)
      let scale = surface.window?.screen.scale ?? UIScreen.main.scale
      let phase: Int32
      switch recognizer.state {
      case .began:
        phase = 0
        if !suppressPointerStream {
          _ = bridge.dispatchPointerPhase(
            3,
            x: point.x * scale,
            y: point.y * scale,
            timeMs: ProcessInfo.processInfo.systemUptime * 1000
          )
          suppressPointerStream = true
        }
      case .changed: phase = 1
      case .ended: phase = 2
      default: phase = 3
      }
      _ = bridge.dispatchScrollX(
        point.x * scale,
        y: point.y * scale,
        deltaX: translation.x * scale,
        deltaY: translation.y * scale,
        phase: phase
      )
      recognizer.setTranslation(.zero, in: surface)
    }

    private func startDisplayLink() {
      guard displayLink == nil else { return }
      let link = CADisplayLink(target: self, selector: #selector(frame(_:)))
      link.add(to: .main, forMode: .common)
      displayLink = link
    }

    private func stopDisplayLink() {
      displayLink?.invalidate()
      displayLink = nil
    }

    @objc private func frame(_ link: CADisplayLink) {
      guard attached else { return }
      _ = bridge.frameTick(link.timestamp * 1000)
      hostAdapter?.drain()
    }
  }
}
