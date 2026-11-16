import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Stockage sécurisé des tokens JWT (Keychain iOS / EncryptedSharedPreferences
/// Android). Ne jamais utiliser `SharedPreferences` pour les tokens — c'est en
/// clair sur disque.
class AuthStorage {
  static const _cleAccess = 'accessToken';
  static const _cleRefresh = 'refreshToken';

  static const _options = IOSOptions(accessibility: KeychainAccessibility.first_unlock);
  static const _androidOptions = AndroidOptions(encryptedSharedPreferences: true);

  static const _stockage = FlutterSecureStorage(
    iOptions: _options,
    aOptions: _androidOptions,
  );

  static Future<void> enregistrer({required String accessToken, String? refreshToken}) async {
    await _stockage.write(key: _cleAccess, value: accessToken);
    if (refreshToken != null) {
      await _stockage.write(key: _cleRefresh, value: refreshToken);
    }
  }

  static Future<String?> accessToken() => _stockage.read(key: _cleAccess);

  static Future<String?> refreshToken() => _stockage.read(key: _cleRefresh);

  static Future<void> vider() async {
    await _stockage.delete(key: _cleAccess);
    await _stockage.delete(key: _cleRefresh);
  }
}
