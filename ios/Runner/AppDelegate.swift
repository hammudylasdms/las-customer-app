import Flutter
import UIKit
import LocalAuthentication
import Security
import AVFoundation

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "LasDeviceLogin")!
    let introChannel = FlutterMethodChannel(name: "com.lastoptechnik/brand_intro", binaryMessenger: registrar.messenger())
    introChannel.setMethodCallHandler { call, result in
      guard call.method == "play" else { result(FlutterMethodNotImplemented); return }
      DispatchQueue.main.async {
        guard !UIAccessibility.isReduceMotionEnabled,
              let path = Bundle.main.path(forResource: registrar.lookupKey(forAsset: "assets/branding/intro.mp4"), ofType: nil),
              let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
              let root = scene.windows.first(where: { $0.isKeyWindow })?.rootViewController,
              root.presentedViewController == nil else { result(nil); return }
        let intro = LasIntroController(url: URL(fileURLWithPath: path)) { result(nil) }
        intro.modalPresentationStyle = .fullScreen
        root.present(intro, animated: false)
      }
    }
    let channel = FlutterMethodChannel(name: "com.lastoptechnik/device_login", binaryMessenger: registrar.messenger())
    channel.setMethodCallHandler { call, result in
      DispatchQueue.global(qos: .userInitiated).async {
        let service = "com.lastoptechnik.device-login.v1"
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
          kSecAttrService as String: service, kSecAttrAccount as String: "portal"]
        func finish(_ value: Any?) { DispatchQueue.main.async { result(value) } }
        func failure(_ code: String) { finish(FlutterError(code: code, message: "Device authentication could not be completed.", details: nil)) }
        switch call.method {
        case "available":
          let context = LAContext()
          finish(context.canEvaluatePolicy(.deviceOwnerAuthentication, error: nil))
        case "read":
          var read = query
          let context = LAContext()
          context.localizedReason = "Sign in to My LAS"
          read[kSecUseAuthenticationContext as String] = context
          read[kSecReturnData as String] = true
          read[kSecMatchLimit as String] = kSecMatchLimitOne
          var item: CFTypeRef?
          let status = SecItemCopyMatching(read as CFDictionary, &item)
          if status == errSecItemNotFound { finish(nil) }
          else if status == errSecSuccess, let data = item as? Data,
                  let value = String(data: data, encoding: .utf8) { finish(value) }
          else { failure("authentication_cancelled") }
        case "save":
          guard let value = call.arguments as? String,
                let access = SecAccessControlCreateWithFlags(nil,
                  kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly, .userPresence, nil) else {
            failure("storage_unavailable"); return
          }
          let context = LAContext()
          context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Enable Face ID or device passcode for My LAS") { success, _ in
            guard success else { failure("authentication_cancelled"); return }
            var save = query
            save[kSecAttrAccessControl as String] = access
            save[kSecValueData as String] = value.data(using: .utf8)!
            SecItemDelete(query as CFDictionary)
            let status = SecItemAdd(save as CFDictionary, nil)
            if status == errSecSuccess { finish(true) } else { failure("storage_unavailable") }
          }
        case "delete":
          let status = SecItemDelete(query as CFDictionary)
          if status == errSecSuccess || status == errSecItemNotFound { finish(true) }
          else { failure("storage_unavailable") }
        default: finish(FlutterMethodNotImplemented)
        }
      }
    }
  }
}

private final class LasIntroController: UIViewController {
  private let player: AVPlayer
  private let videoLayer: AVPlayerLayer
  private var completion: (() -> Void)?
  private var observations: [NSObjectProtocol] = []
  private var statusObservation: NSKeyValueObservation?
  private var timeout: Timer?
  init(url: URL, completion: @escaping () -> Void) {
    let source = AVPlayer(url: url)
    player = source
    videoLayer = AVPlayerLayer(player: source)
    self.completion = completion
    super.init(nibName: nil, bundle: nil)
  }
  required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }
  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .white
    player.isMuted = true
    videoLayer.videoGravity = .resizeAspectFill
    view.layer.addSublayer(videoLayer)
    let skip = UIButton(type: .system)
    skip.setTitle("Skip intro", for: .normal)
    skip.setTitleColor(.white, for: .normal)
    skip.backgroundColor = UIColor.black.withAlphaComponent(0.7)
    skip.layer.cornerRadius = 12
    skip.translatesAutoresizingMaskIntoConstraints = false
    skip.addTarget(self, action: #selector(finish), for: .touchUpInside)
    view.addSubview(skip)
    NSLayoutConstraint.activate([
      skip.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
      skip.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -20),
      skip.widthAnchor.constraint(greaterThanOrEqualToConstant: 110),
      skip.heightAnchor.constraint(equalToConstant: 48)
    ])
    for name in [AVPlayerItem.didPlayToEndTimeNotification, AVPlayerItem.failedToPlayToEndTimeNotification] {
      observations.append(NotificationCenter.default.addObserver(forName: name, object: player.currentItem, queue: .main) { [weak self] _ in self?.finish() })
    }
    observations.append(NotificationCenter.default.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main) { [weak self] _ in self?.finish() })
    statusObservation = player.currentItem?.observe(\.status, options: [.new]) { [weak self] item, _ in
      if item.status == .failed { DispatchQueue.main.async { self?.finish() } }
    }
  }
  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    timeout = Timer.scheduledTimer(withTimeInterval: 8, repeats: false) { [weak self] _ in self?.finish() }
    player.play()
  }
  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    videoLayer.frame = view.bounds
  }
  @objc private func finish() {
    guard let callback = completion else { return }
    completion = nil
    player.pause()
    timeout?.invalidate()
    statusObservation = nil
    observations.forEach { NotificationCenter.default.removeObserver($0) }
    observations.removeAll()
    dismiss(animated: false, completion: callback)
  }
  deinit {
    timeout?.invalidate()
    observations.forEach { NotificationCenter.default.removeObserver($0) }
  }
}
