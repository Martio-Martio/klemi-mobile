import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'api_exception.dart';

/// Wrapper autour de `sentry_flutter` qui reste **inerte** quand aucun DSN
/// n'est fourni via `--dart-define=SENTRY_DSN=…`. Permet aux builds de dev
/// et aux tests de tourner sans réseau Sentry.
class SentryService {
  static const _dsn = String.fromEnvironment('SENTRY_DSN');
  static const _environnement = String.fromEnvironment(
    'SENTRY_ENVIRONMENT',
    defaultValue: 'dev',
  );

  static bool get actif => _dsn.isNotEmpty;

  /// Initialise Sentry si un DSN est fourni et lance l'application dans
  /// un `runZonedGuarded` qui remonte les exceptions non capturées.
  /// Si pas de DSN : lance directement `runApp` sans surcoût.
  static Future<void> executerAppLive(FutureOr<void> Function() body) async {
    if (!actif) {
      await body();
      return;
    }
    await SentryFlutter.init(
      (options) {
        options.dsn = _dsn;
        options.environment = _environnement;
        options.tracesSampleRate = 0.2;
        // Filtre évite de noyer Sentry avec des erreurs réseau transitoires
        // des appareils en 3G faible.
        options.beforeSend = (event, hint) {
          final throwable = event.throwable;
          if (throwable is ApiException &&
              (throwable.statusCode == 0 || throwable.statusCode == 408)) {
            return null;
          }
          return event;
        };
      },
      appRunner: () async => body(),
    );
  }

  /// Rapporte une exception avec un contexte minimal — pas-op si inactif.
  static Future<void> capturer(Object exception, {StackTrace? stack, String? contexte}) async {
    if (!actif) return;
    await Sentry.captureException(exception, stackTrace: stack, hint: Hint.withMap({
      'contexte': ?contexte,
    }));
  }

  /// Observer `FlutterError` global pour rapporter les exceptions de widgets.
  /// À brancher dans `main.dart` avant `runApp` quand Sentry est actif.
  static void brancherFlutterError() {
    if (!actif) return;
    final original = FlutterError.onError;
    FlutterError.onError = (details) {
      capturer(details.exception, stack: details.stack, contexte: 'FlutterError');
      original?.call(details);
    };
  }
}
