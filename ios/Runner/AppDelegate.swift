import AVFAudio
import CallKit
import Flutter
import PushKit
import GoogleMaps
import UIKit
import firebase_messaging
import flutter_callkit_incoming

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate,
  PKPushRegistryDelegate, CallkitIncomingAppDelegate {
  private var voipRegistry: PKPushRegistry?
  private var nativeCallsChannel: FlutterMethodChannel?
  private let pendingActionKey = "fixleo_pending_call_action"

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // UIScene registers plugins after this method. Firebase requires its
    // notification-center delegate before launch completes.
    FLTFirebaseMessagingPlugin.configureNotificationCenterDelegate()
    if let apiKey = Bundle.main.object(forInfoDictionaryKey: "GoogleMapsAPIKey") as? String,
       !apiKey.isEmpty,
       !apiKey.contains("$(") {
      GMSServices.provideAPIKey(apiKey)
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    nativeCallsChannel = FlutterMethodChannel(
      name: "com.fixleo.app/native_calls",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    nativeCallsChannel?.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(nil)
        return
      }
      switch call.method {
      case "consumePendingAction":
        result(self.consumePendingAction())
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    // Register PushKit only after GeneratedPluginRegistrant, so the CallKit
    // plugin singleton is available before the first VoIP payload arrives.
    let registry = PKPushRegistry(queue: .main)
    registry.delegate = self
    registry.desiredPushTypes = [.voIP]
    voipRegistry = registry
  }

  func pushRegistry(
    _ registry: PKPushRegistry,
    didUpdate pushCredentials: PKPushCredentials,
    for type: PKPushType
  ) {
    let token = pushCredentials.token.map { String(format: "%02x", $0) }.joined()
    SwiftFlutterCallkitIncomingPlugin.sharedInstance?.setDevicePushTokenVoIP(token)
  }

  func pushRegistry(_ registry: PKPushRegistry, didInvalidatePushTokenFor type: PKPushType) {
    SwiftFlutterCallkitIncomingPlugin.sharedInstance?.setDevicePushTokenVoIP("")
  }

  func pushRegistry(
    _ registry: PKPushRegistry,
    didReceiveIncomingPushWith payload: PKPushPayload,
    for type: PKPushType,
    completion: @escaping () -> Void
  ) {
    // A stale APNs token may still receive after logout. Never expose another
    // account's call on a logged-out device.
    guard UserDefaults.standard.string(forKey: "flutter.auth_access_token")?.isEmpty == false else {
      completion()
      return
    }

    var info: [String: Any] = [:]
    payload.dictionaryPayload.forEach { key, value in
      if let key = key as? String { info[key] = value }
    }
    guard let id = info["id"] as? String, UUID(uuidString: id) != nil else {
      completion()
      return
    }
    info["appName"] = "Fixleo"
    info["type"] = 0
    info["duration"] = 60_000
    info["handle"] = info["handle"] ?? "Fixleo"
    info["nameCaller"] = info["nameCaller"] ?? "Fixleo"
    info["ios"] = [
      "handleType": "generic",
      "supportsVideo": false,
      "maximumCallGroups": 1,
      "maximumCallsPerCallGroup": 1,
      "supportsDTMF": false,
      "supportsHolding": false,
      "supportsGrouping": false,
      "supportsUngrouping": false,
      "includesCallsInRecents": true,
      "configureAudioSession": true,
      "audioSessionMode": "voiceChat",
      "audioSessionActive": true,
      "audioSessionPreferredSampleRate": 48_000.0,
      "audioSessionPreferredIOBufferDuration": 0.005,
    ]

    guard let plugin = SwiftFlutterCallkitIncomingPlugin.sharedInstance else {
      completion()
      return
    }
    plugin.showCallkitIncoming(
      flutter_callkit_incoming.Data(args: info),
      fromPushKit: true,
      completion: completion
    )
  }

  func onAccept(_ call: Call, _ action: CXAnswerCallAction) {
    publishNativeAction("accept", call: call)
    action.fulfill()
  }

  func onDecline(_ call: Call, _ action: CXEndCallAction) {
    publishNativeAction("decline", call: call)
    action.fulfill()
  }

  func onEnd(_ call: Call, _ action: CXEndCallAction) {
    publishNativeAction("end", call: call)
    action.fulfill()
  }

  func onTimeOut(_ call: Call) {
    publishNativeAction("timeout", call: call)
  }

  func didActivateAudioSession(_ audioSession: AVAudioSession) {}

  func didDeactivateAudioSession(_ audioSession: AVAudioSession) {}

  func providerDidReset() {}

  private func publishNativeAction(_ action: String, call: Call) {
    var payload = call.data.toJSON().compactMapValues { $0 }
    payload["nativeAction"] = action
    if let data = try? JSONSerialization.data(withJSONObject: payload) {
      UserDefaults.standard.set(data, forKey: pendingActionKey)
    }
    nativeCallsChannel?.invokeMethod("nativeCallAction", arguments: payload)
  }

  private func consumePendingAction() -> [String: Any]? {
    guard let data = UserDefaults.standard.data(forKey: pendingActionKey) else {
      return nil
    }
    UserDefaults.standard.removeObject(forKey: pendingActionKey)
    return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
  }
}
