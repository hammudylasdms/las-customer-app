import Flutter
import UIKit
import LocalAuthentication
import Security

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
