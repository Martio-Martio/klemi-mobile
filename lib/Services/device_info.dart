import 'dart:io' show Platform;

import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// Identité stable de l'appareil pour les headers mobiles (`x-device-id`,
/// `x-device-name`, `x-platform`). Le `deviceId` est généré une seule fois
/// au premier lancement et persisté — il ne change jamais sur un même device.
class DeviceInfo {
  static const _cleDeviceId = 'deviceId';

  static String? _cache;

  /// UUID v4 persistant. Généré à la volée au premier appel si absent.
  static Future<String> deviceId() async {
    if (_cache != null) return _cache!;
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString(_cleDeviceId);
    if (id == null) {
      id = const Uuid().v4();
      await prefs.setString(_cleDeviceId, id);
    }
    _cache = id;
    return id;
  }

  /// `ios` | `android` | `web` | `other`.
  static String platform() {
    if (Platform.isIOS) return 'ios';
    if (Platform.isAndroid) return 'android';
    return 'other';
  }

  /// Nom lisible envoyé en `x-device-name`. Le backend sait l'enrichir
  /// via User-Agent — ici on reste simple pour éviter une dep native.
  static String deviceName() => '${platform()}-klemi-mobile';
}
