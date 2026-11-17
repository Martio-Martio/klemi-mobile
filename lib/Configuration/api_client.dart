import 'dart:convert';

import 'package:http/http.dart' as http;

import '../Services/api_exception.dart';
import '../Services/auth_storage.dart';
import '../Services/device_info.dart';
import 'api_url.dart';

/// Résout la langue courante (de lecture, fr/en) au moment de la requête
/// (lue depuis `AppState.langue`). Séparé pour éviter la dépendance cyclique
/// `ApiClient ↔ AppState` et faciliter les tests unitaires.
typedef ResolveurLangue = String Function();

/// Résout la langue d'écoute courante (fr/en/bm/sus/ful) depuis
/// `AppState.langueAudio`. Si null, le header `x-language-audio` n'est pas
/// injecté — le backend retombe sur la langue de lecture.
typedef ResolveurLangueAudio = String? Function();

/// Résout le token d'accès courant. Nullable si l'utilisateur n'est pas
/// connecté (endpoints publics, ping health, platform/features…).
typedef ResolveurToken = Future<String?> Function();

/// Rafraîchit le token quand une requête retourne 401. Doit renvoyer `true`
/// si un nouveau token est en place (la requête originale sera rejouée),
/// `false` si l'utilisateur doit se reconnecter. Injecté depuis main.dart
/// pour éviter la cyclique `ApiClient → MobileAuthApi → ApiClient`.
typedef RafraichirSession = Future<bool> Function();

/// Client HTTP unique de l'app. Injecte systématiquement :
///   - `Authorization: Bearer <token>` quand un token existe.
///   - `x-device-id`, `x-device-name`, `x-platform`, `x-language`.
///   - `Content-Type: application/json` (sauf multipart).
/// Décode la réponse, lève [ApiException] sur statut >= 400.
/// Si [rafraichirSession] est branché, un 401 déclenche un refresh + retry
/// unique avant de propager l'erreur.
class ApiClient {
  final String baseUrl;
  final ResolveurLangue resoudreLangue;
  final ResolveurLangueAudio? resoudreLangueAudio;
  final ResolveurToken resoudreToken;
  RafraichirSession? rafraichirSession;
  final http.Client _client;

  /// Chemins qui ne doivent jamais déclencher le refresh : les endpoints d'auth
  /// retournent 401 dans des conditions normales (code OTP erroné, token
  /// expiré, etc.) — refresh ici tournerait en boucle.
  static const _cheminsSansRefresh = {
    '/mobile-auth/login',
    '/mobile-auth/signup',
    '/mobile-auth/verify-otp',
    '/mobile-auth/resend-otp',
    '/mobile-auth/refresh',
  };

  ApiClient({
    String? baseUrl,
    required this.resoudreLangue,
    this.resoudreLangueAudio,
    ResolveurToken? resoudreToken,
    this.rafraichirSession,
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
    final langAudio = resoudreLangueAudio?.call();
    return {
      if (jsonBody) 'Content-Type': 'application/json',
      'Accept': 'application/json',
      'x-device-id': await DeviceInfo.deviceId(),
      'x-device-name': DeviceInfo.deviceName(),
      'x-platform': DeviceInfo.platform(),
      'x-language': resoudreLangue(),
      if (langAudio != null && langAudio.isNotEmpty) 'x-language-audio': langAudio,
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
    return _executer(path, () async => _client.get(_uri(path, query), headers: await _entetes()));
  }

  Future<dynamic> post(String path, {Object? body, Map<String, dynamic>? query}) async {
    return _executer(path, () async => _client.post(
          _uri(path, query),
          headers: await _entetes(),
          body: body == null ? null : jsonEncode(body),
        ));
  }

  Future<dynamic> patch(String path, {Object? body}) async {
    return _executer(path, () async => _client.patch(
          _uri(path),
          headers: await _entetes(),
          body: body == null ? null : jsonEncode(body),
        ));
  }

  Future<dynamic> put(String path, {Object? body}) async {
    return _executer(path, () async => _client.put(
          _uri(path),
          headers: await _entetes(),
          body: body == null ? null : jsonEncode(body),
        ));
  }

  Future<dynamic> delete(String path, {Object? body}) async {
    return _executer(path, () async => _client.delete(
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
    Future<http.Response> envoyer() async {
      final requete = http.MultipartRequest('POST', _uri(path));
      requete.headers.addAll(await _entetes(jsonBody: false));
      requete.fields.addAll(champs);
      requete.files.addAll(fichiers);
      final reponseStream = await _client.send(requete);
      return http.Response.fromStream(reponseStream);
    }

    return _executer(path, envoyer);
  }

  /// Exécute une requête HTTP avec gestion réseau et retry sur 401.
  /// Le retry n'est déclenché qu'une seule fois par appel pour éviter les
  /// boucles infinies, et jamais sur les chemins listés dans
  /// [_cheminsSansRefresh].
  Future<dynamic> _executer(String path, Future<http.Response> Function() action) async {
    try {
      var reponse = await action();
      if (reponse.statusCode == 401 &&
          rafraichirSession != null &&
          !_cheminsSansRefresh.contains(path)) {
        final ok = await rafraichirSession!();
        if (ok) reponse = await action();
      }
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
