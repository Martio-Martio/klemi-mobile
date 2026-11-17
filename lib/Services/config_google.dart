import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Plateforme sur laquelle on décide d'appeler (ou non) le SDK Google.
enum PlateformeMobile { ios, android, autre }

/// Faits lus hors du SDK : Info.plist côté iOS, ressource Gradle côté Android.
///
/// Aucun client ID n'est inventé. [gidClientId] est la valeur réelle de
/// `GIDClientID`, vide tant que la clé n'est pas dans Info.plist.
class FaitsConfigGoogle {
  final PlateformeMobile plateforme;
  final String? gidClientId;
  final List<String> schemesUrl;
  final bool clientWebAndroidPresent;

  const FaitsConfigGoogle({
    this.plateforme = PlateformeMobile.autre,
    this.gidClientId,
    this.schemesUrl = const [],
    this.clientWebAndroidPresent = false,
  });
}

/// Décision du garde-fou. [appelSdkAutorise] à faux : ne pas toucher à
/// `GoogleSignIn` (l'exception native iOS tuerait le process).
class VerdictConfigGoogle {
  final bool appelSdkAutorise;
  final String message;

  const VerdictConfigGoogle({
    required this.appelSdkAutorise,
    this.message = '',
  });

  const VerdictConfigGoogle.autorise() : appelSdkAutorise = true, message = '';
}

const _suffixeClientIos = '.apps.googleusercontent.com';
const _prefixeSchemeGoogle = 'com.googleusercontent.apps.';

const _messageIosAbsent =
    'Connexion Google indisponible : GIDClientID et le schéma d\'URL '
    'REVERSED_CLIENT_ID manquent dans Info.plist. Ajoute un client OAuth iOS '
    'dans la console Google, puis ces deux clés.';

const _messageIosClientInvalide =
    'Connexion Google indisponible : le GIDClientID dans Info.plist doit se '
    'terminer par .apps.googleusercontent.com.';

const _messageIosSchemeAbsent =
    'Connexion Google indisponible : le schéma d\'URL REVERSED_CLIENT_ID '
    'manque dans Info.plist (CFBundleURLTypes). Il doit accompagner le GIDClientID.';

const _messageAndroidAbsent =
    'Connexion Google indisponible : oauth_client est vide pour com.klemi.app '
    '(aucun client web, default_web_client_id absent). Ajoute les clients '
    'Android et Web dans la console Google.';

const _messagePlateforme =
    'Connexion Google indisponible sur cette plateforme.';

/// Schéma d'URL attendu pour un client iOS déjà présent dans la config.
/// `null` si l'identifiant est absent ou n'a pas la forme Google.
String? schemeInverseDepuisClientId(String? clientId) {
  final id = clientId?.trim() ?? '';
  if (!id.endsWith(_suffixeClientIos)) return null;
  final prefixe = id.substring(0, id.length - _suffixeClientIos.length);
  if (prefixe.isEmpty) return null;
  return '$_prefixeSchemeGoogle$prefixe';
}

/// Pure : vrai seulement si la config native que le SDK exige est là.
VerdictConfigGoogle evaluerConfigGoogle(FaitsConfigGoogle faits) {
  switch (faits.plateforme) {
    case PlateformeMobile.ios:
      final id = faits.gidClientId?.trim() ?? '';
      if (id.isEmpty) {
        return const VerdictConfigGoogle(
          appelSdkAutorise: false,
          message: _messageIosAbsent,
        );
      }
      final scheme = schemeInverseDepuisClientId(id);
      if (scheme == null) {
        return const VerdictConfigGoogle(
          appelSdkAutorise: false,
          message: _messageIosClientInvalide,
        );
      }
      final schemes = faits.schemesUrl.map((s) => s.trim());
      if (!schemes.contains(scheme)) {
        return const VerdictConfigGoogle(
          appelSdkAutorise: false,
          message: _messageIosSchemeAbsent,
        );
      }
      return const VerdictConfigGoogle.autorise();
    case PlateformeMobile.android:
      if (!faits.clientWebAndroidPresent) {
        return const VerdictConfigGoogle(
          appelSdkAutorise: false,
          message: _messageAndroidAbsent,
        );
      }
      return const VerdictConfigGoogle.autorise();
    case PlateformeMobile.autre:
      return const VerdictConfigGoogle(
        appelSdkAutorise: false,
        message: _messagePlateforme,
      );
  }
}

PlateformeMobile plateformeMobileCourante() {
  switch (defaultTargetPlatform) {
    case TargetPlatform.iOS:
      return PlateformeMobile.ios;
    case TargetPlatform.android:
      return PlateformeMobile.android;
    default:
      return PlateformeMobile.autre;
  }
}

typedef LecteurFaitsConfigGoogle = Future<FaitsConfigGoogle> Function();

const canalConfigGoogle = MethodChannel('klemi/config_google');

/// Remplaçable dans les tests pour ne pas interroger le canal natif.
LecteurFaitsConfigGoogle lecteurFaitsConfigGoogle = lireFaitsConfigGoogleNatif;

Future<FaitsConfigGoogle> lireFaitsConfigGoogleNatif() async {
  final plateforme = plateformeMobileCourante();
  if (plateforme == PlateformeMobile.autre) {
    return const FaitsConfigGoogle(plateforme: PlateformeMobile.autre);
  }
  try {
    final brut = await canalConfigGoogle.invokeMapMethod<String, Object?>(
      'lire',
    );
    return FaitsConfigGoogle(
      plateforme: plateforme,
      gidClientId: brut?['gidClientId'] as String?,
      schemesUrl: _lireSchemes(brut?['schemesUrl']),
      clientWebAndroidPresent: brut?['clientWebPresent'] == true,
    );
  } catch (_) {
    // Canal absent ou lecture impossible : même verdict qu'une config vide,
    // pour ne jamais enchaîner sur le SDK.
    return FaitsConfigGoogle(plateforme: plateforme);
  }
}

List<String> _lireSchemes(Object? brut) {
  if (brut is! List) return const [];
  return [
    for (final item in brut)
      if (item is String) item,
  ];
}
