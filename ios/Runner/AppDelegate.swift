import Flutter
import UIKit

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
    let canal = FlutterMethodChannel(
      name: "klemi/config_google",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    canal.setMethodCallHandler { call, result in
      guard call.method == "lire" else {
        result(FlutterMethodNotImplemented)
        return
      }
      result(lireConfigGoogle())
    }
  }
}

/// Lit GIDClientID et les schémas d'URL sans appeler Google Sign-In.
/// Une NSException du SDK (config absente) n'est pas rattrapable côté Dart.
private func lireConfigGoogle() -> [String: Any] {
  let brut = Bundle.main.object(forInfoDictionaryKey: "GIDClientID") as? String ?? ""
  let clientId = brut.trimmingCharacters(in: .whitespacesAndNewlines)
  var schemes: [String] = []
  if let types = Bundle.main.object(forInfoDictionaryKey: "CFBundleURLTypes") as? [Any] {
    for type in types {
      guard let dict = type as? [String: Any] else { continue }
      let liste = dict["CFBundleURLSchemes"] as? [Any] ?? []
      for scheme in liste {
        guard let valeur = scheme as? String else { continue }
        let propre = valeur.trimmingCharacters(in: .whitespacesAndNewlines)
        if !propre.isEmpty {
          schemes.append(propre)
        }
      }
    }
  }
  return [
    "gidClientId": clientId,
    "schemesUrl": schemes,
    "clientWebPresent": false,
  ]
}
