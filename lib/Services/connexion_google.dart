import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'api_exception.dart';
import 'config_google.dart';
import 'mobile_auth_api.dart';

const _messageClientManquant =
    'Connexion Google indisponible : aucun client OAuth n\'est configuré '
    '(oauth_client vide, pas de client iOS). '
    'Ajoute les clients Android, iOS et Web dans la console Google.';

/// Garde l'init du singleton `GoogleSignIn` (une seule fois, sinon comportement indéfini).
Future<void>? _initialisationGoogle;

Future<void> _initialiserGoogle() async {
  final enCours = _initialisationGoogle;
  if (enCours != null) {
    await enCours;
    return;
  }
  final future = GoogleSignIn.instance.initialize();
  _initialisationGoogle = future;
  try {
    await future;
  } catch (e) {
    _initialisationGoogle = null;
    rethrow;
  }
}

/// Récupère l'ID token Google, ou `null` si l'utilisateur annule.
///
/// Aucun client ID n'est inventé. Sans `GIDClientID` (et son schéma d'URL)
/// ou sans client web Android, le SDK n'est pas appelé. Sur iOS, `GIDSignIn`
/// lève une NSException que le plugin Swift ne rattrape pas
/// (`No active configuration. Make sure GIDClientID is set in Info.plist.`,
/// puis une seconde si seul le schéma d'URL manque). Le process mourrait
/// avant tout `catch` Dart.
Future<String?> obtenirIdTokenGoogle() async {
  final verdict = evaluerConfigGoogle(await lecteurFaitsConfigGoogle());
  if (!verdict.appelSdkAutorise) {
    throw ApiException(
      statusCode: 0,
      code: 'GOOGLE_NON_CONFIGURE',
      message: verdict.message.isEmpty
          ? _messageClientManquant
          : verdict.message,
    );
  }
  try {
    await _initialiserGoogle();
    if (!GoogleSignIn.instance.supportsAuthenticate()) {
      throw const ApiException(
        statusCode: 0,
        code: 'GOOGLE_NON_CONFIGURE',
        message: _messageClientManquant,
      );
    }
    final compte = await GoogleSignIn.instance.authenticate();
    final idToken = compte.authentication.idToken;
    if (idToken == null || idToken.isEmpty) {
      throw const ApiException(
        statusCode: 0,
        code: 'GOOGLE_NON_CONFIGURE',
        message: _messageClientManquant,
      );
    }
    return idToken;
  } on ApiException {
    rethrow;
  } on GoogleSignInException catch (e) {
    if (e.code == GoogleSignInExceptionCode.canceled ||
        e.code == GoogleSignInExceptionCode.interrupted) {
      return null;
    }
    if (e.code == GoogleSignInExceptionCode.clientConfigurationError ||
        e.code == GoogleSignInExceptionCode.providerConfigurationError) {
      final detail = e.description?.trim();
      throw ApiException(
        statusCode: 0,
        code: 'GOOGLE_NON_CONFIGURE',
        message: detail == null || detail.isEmpty
            ? _messageClientManquant
            : '$_messageClientManquant ($detail)',
      );
    }
    throw ApiException(
      statusCode: 0,
      code: e.code.name,
      message: e.description?.trim().isNotEmpty == true
          ? e.description!.trim()
          : 'La connexion Google a échoué.',
    );
  } on PlatformException catch (e) {
    if (e.code == 'sign_in_canceled' || e.code == 'canceled') return null;
    throw ApiException(
      statusCode: 0,
      code: e.code,
      message: e.message ?? 'La connexion Google a échoué.',
    );
  }
}

/// Connexion Google : ID token natif, puis `POST /mobile-auth/google`.
class ConnexionGoogle {
  final MobileAuthApi _api;
  final Future<String?> Function() _obtenirIdToken;

  ConnexionGoogle({
    MobileAuthApi? api,
    Future<String?> Function()? obtenirIdToken,
  }) : _api = api ?? MobileAuthApi(),
       _obtenirIdToken = obtenirIdToken ?? obtenirIdTokenGoogle;

  /// Session mobile, ou `null` si l'utilisateur annule (pas une erreur).
  Future<MobileAuthSession?> connecter() async {
    final idToken = await _obtenirIdToken();
    if (idToken == null) return null;
    if (idToken.isEmpty) {
      throw const ApiException(
        statusCode: 0,
        code: 'GOOGLE_NON_CONFIGURE',
        message: _messageClientManquant,
      );
    }
    return _api.connexionGoogle(idToken);
  }
}
