import 'dart:convert';

import 'package:http/http.dart' as http;

import '../Services/api_exception.dart';
import '../Services/auth_storage.dart';
import '../Services/device_info.dart';
import 'api_url.dart';

/// Résout la langue courante au moment de la requête (lue depuis AppState
/// par le binding dans main.dart). Séparé pour éviter la dépendance cyclique
/// `ApiClient ↔ AppState` et faciliter les tests unitaires.
typedef ResolveurLangue = String Function();

/// Résout le token d'accès courant. Nullable si l'utilisateur n'est pas
/// connecté (endpoints publics, ping health, platform/features…).
typedef ResolveurToken = Future<String?> Function();

/// Client HTTP unique de l'app. Injecte systématiquement :
///   - `Authorization: Bearer <token>` quand un token existe.
///   - `x-device-id`, `x-device-name`, `x-platform`, `x-language`.
///   - `Content-Type: application/json` (sauf multipart).
/// Décode la réponse, lève [ApiException] sur statut >= 400.
class ApiClient {
  final String baseUrl;
  final ResolveurLangue resoudreLangue;
  final ResolveurToken resoudreToken;
  final http.Client _client;

  ApiClient({
    String? baseUrl,
    required this.resoudreLangue,
    ResolveurToken? resoudreToken,
    http.Client? client,
  })  : baseUrl = baseUrl ?? ApiUrl.baseUrl,
        resoudreToken = resoudreToken ?? AuthStorage.accessToken,
        _client = client ?? http.Client();

  static ApiClient? _instance;

  /// Singleton utilisé par les services applicatifs. [brancher] doit être
  /// appelé au démarrage (dans main.dart) avec les résolveurs branchés sur
  /// AppState + AuthStorage.
  static ApiClient get instance {
    final i = _instance;
    if (i == null) {
      throw StateError('ApiClient non branché — appeler ApiClient.brancher() au démarrage.');
    }
    return i;
  }

  static void brancher(ApiClient client) {
    _instance = client;
  }

  Future<Map<String, String>> _entetes({Map<String, String>? extra, bool jsonBody = true}) async {
    final token = await resoudreToken();
    return {
      if (jsonBody) 'Content-Type': 'application/json',
      'Accept': 'application/json',
      'x-device-id': await DeviceInfo.deviceId(),
      'x-device-name': DeviceInfo.deviceName(),
      'x-platform': DeviceInfo.platform(),
      'x-language': resoudreLangue(),
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      ...?extra,
    };
  }

  Uri _uri(String path, [Map<String, dynamic>? query]) {
    final chemin = path.startsWith('/') ? path : '/$path';
    final url = Uri.parse('$baseUrl$chemin');
    if (query == null || query.isEmpty) return url;
    return url.replace(queryParameters: {
      ...url.queryParameters,
      for (final e in query.entries)
        if (e.value != null) e.key: e.value.toString(),
    });
  }

  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async {
    return _executer(() async => _client.get(_uri(path, query), headers: await _entetes()));
  }

  Future<dynamic> post(String path, {Object? body, Map<String, dynamic>? query}) async {
    return _executer(() async => _client.post(
          _uri(path, query),
          headers: await _entetes(),
          body: body == null ? null : jsonEncode(body),
        ));
  }

  Future<dynamic> patch(String path, {Object? body}) async {
    return _executer(() async => _client.patch(
          _uri(path),
          headers: await _entetes(),
          body: body == null ? null : jsonEncode(body),
        ));
  }

  Future<dynamic> put(String path, {Object? body}) async {
    return _executer(() async => _client.put(
          _uri(path),
          headers: await _entetes(),
          body: body == null ? null : jsonEncode(body),
        ));
  }

  Future<dynamic> delete(String path, {Object? body}) async {
    return _executer(() async => _client.delete(
          _uri(path),
          headers: await _entetes(),
          body: body == null ? null : jsonEncode(body),
        ));
  }

  /// Envoie un multipart (upload de fichiers — pattern utilisé en Phase 3).
  /// [champs] = champs texte, [fichiers] = multipart files prêts à envoyer.
  Future<dynamic> multipart(
    String path, {
    required Map<String, String> champs,
    required List<http.MultipartFile> fichiers,
  }) async {
    final requete = http.MultipartRequest('POST', _uri(path));
    requete.headers.addAll(await _entetes(jsonBody: false));
    requete.fields.addAll(champs);
    requete.files.addAll(fichiers);
    final reponseStream = await _client.send(requete);
    final reponse = await http.Response.fromStream(reponseStream);
    return _decoder(reponse);
  }

  Future<dynamic> _executer(Future<http.Response> Function() action) async {
    try {
      final reponse = await action();
      return _decoder(reponse);
    } on http.ClientException catch (e) {
      throw ApiException(statusCode: 0, message: 'Problème réseau : ${e.message}');
    }
  }

  dynamic _decoder(http.Response reponse) {
    final code = reponse.statusCode;
    final corpsBrut = reponse.body;
    final corps = corpsBrut.isEmpty ? null : _parserJson(corpsBrut);
    if (code >= 200 && code < 300) {
      return corps;
    }
    throw ApiException.depuisJson(code, corps ?? corpsBrut);
  }

  dynamic _parserJson(String raw) {
    try {
      return jsonDecode(raw);
    } catch (_) {
      return raw;
    }
  }
}
