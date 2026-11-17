import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_exception.dart';
import 'mobile_feed_api.dart';
import 'social_api.dart';

/// Opérations différables quand l'utilisateur est offline. Chaque type
/// correspond à un endpoint côté backend. L'ordre d'enfilement est préservé
/// au rejeu (ex. like puis unlike) pour que la cohérence serveur suive la
/// dernière intention utilisateur.
enum ActionDifferee { like, unlike, save, repondreQuiz, follow, unfollow, marquerNotifLue }

/// Entrée immuable de la queue — sérialisable en JSON pour SharedPreferences.
class _Entree {
  final ActionDifferee action;
  final String cible; // ID principal (contentId, creatorId, notifId…)
  final Map<String, dynamic> extra; // params additionnels (answerIndex, etc.)
  final DateTime quand;

  const _Entree(this.action, this.cible, {this.extra = const {}, required this.quand});

  Map<String, dynamic> toJson() => {
        'action': action.name,
        'cible': cible,
        'extra': extra,
        'quand': quand.toIso8601String(),
      };

  factory _Entree.fromJson(Map<String, dynamic> json) => _Entree(
        ActionDifferee.values.firstWhere(
          (a) => a.name == json['action'],
          orElse: () => ActionDifferee.like,
        ),
        json['cible'] as String? ?? '',
        extra: (json['extra'] as Map<String, dynamic>?) ?? const {},
        quand: DateTime.tryParse(json['quand'] as String? ?? '') ?? DateTime.now(),
      );
}

/// File d'attente des actions utilisateur à rejouer à la reconnexion. Thread-safe
/// pour un usage mobile classique (un seul isolate).
///
/// Les écrans n'appellent pas directement cette queue : ils tentent l'appel
/// API, et si une `ApiException` « réseau » (statusCode 0) remonte, ils
/// enfilent ici. À la reconnexion (`Connectivity.onConnectivityChanged`),
/// `flush()` rejoue dans l'ordre d'enfilement, en supprimant les entrées
/// réussies.
class OfflineQueue {
  static const _cle = 'offlineQueue_v1';

  final MobileFeedApi _feedApi;
  final SocialApi _socialApi;
  final Connectivity _connectivity;

  List<_Entree> _entrees = [];
  bool _charge = false;
  bool _flushEnCours = false;
  StreamSubscription<List<ConnectivityResult>>? _abonnement;

  OfflineQueue({
    MobileFeedApi? feedApi,
    SocialApi? socialApi,
    Connectivity? connectivity,
  })  : _feedApi = feedApi ?? MobileFeedApi(),
        _socialApi = socialApi ?? SocialApi(),
        _connectivity = connectivity ?? Connectivity();

  static OfflineQueue? _instance;
  static OfflineQueue get instance => _instance ??= OfflineQueue();
  static void brancher(OfflineQueue q) => _instance = q;

  /// Nombre d'actions en attente — utile pour un badge UI éventuel.
  int get enAttente => _entrees.length;

  /// À appeler une fois au démarrage (par `main.dart`) pour charger la file
  /// persistée et s'abonner aux changements de connectivité.
  Future<void> demarrer() async {
    await _chargerSiNecessaire();
    _abonnement ??= _connectivity.onConnectivityChanged.listen((res) {
      final enLigne = res.any((r) => r != ConnectivityResult.none);
      if (enLigne) flush();
    });
    // Tentative immédiate au boot au cas où la connectivité est déjà revenue.
    unawaited(flush());
  }

  /// Libère l'abonnement — utilisé par les tests.
  Future<void> arreter() async {
    await _abonnement?.cancel();
    _abonnement = null;
  }

  /// Enfile une action et persiste.
  Future<void> enfiler(ActionDifferee action, String cible, {Map<String, dynamic> extra = const {}}) async {
    await _chargerSiNecessaire();
    _entrees.add(_Entree(action, cible, extra: extra, quand: DateTime.now()));
    await _sauvegarder();
  }

  /// Tente de rejouer toutes les actions. Les actions réussies sont
  /// retirées ; les échecs réseau restent dans la file. En cas d'erreur
  /// 4xx non récupérable (ex. commentaire supprimé, créateur bloqué),
  /// l'action est aussi retirée — inutile de boucler dessus.
  Future<void> flush() async {
    if (_flushEnCours) return;
    _flushEnCours = true;
    try {
      await _chargerSiNecessaire();
      final aRetirer = <int>{};
      for (var i = 0; i < _entrees.length; i++) {
        final e = _entrees[i];
        try {
          await _executer(e);
          aRetirer.add(i);
        } on ApiException catch (ex) {
          // Erreur réseau transitoire → on garde pour la prochaine fois.
          // Toute autre erreur (4xx non 408/429) → on abandonne cette action.
          if (ex.statusCode == 0 || ex.statusCode == 408 || ex.statusCode == 429) {
            // Garder.
          } else {
            aRetirer.add(i);
          }
        }
      }
      if (aRetirer.isNotEmpty) {
        final nouvelles = <_Entree>[];
        for (var i = 0; i < _entrees.length; i++) {
          if (!aRetirer.contains(i)) nouvelles.add(_entrees[i]);
        }
        _entrees = nouvelles;
        await _sauvegarder();
      }
    } finally {
      _flushEnCours = false;
    }
  }

  Future<void> _executer(_Entree e) async {
    switch (e.action) {
      case ActionDifferee.like:
        await _socialApi.likeItem(e.cible);
      case ActionDifferee.unlike:
        await _socialApi.unlikeItem(e.cible);
      case ActionDifferee.save:
        await _feedApi.saveItem(e.cible);
      case ActionDifferee.repondreQuiz:
        final idx = (e.extra['answerIndex'] as num?)?.toInt() ?? 0;
        await _feedApi.answerQuiz(e.cible, idx);
      case ActionDifferee.follow:
        await _socialApi.follow(e.cible);
      case ActionDifferee.unfollow:
        await _socialApi.unfollow(e.cible);
      case ActionDifferee.marquerNotifLue:
        await _socialApi.markNotificationRead(e.cible);
    }
  }

  Future<void> _chargerSiNecessaire() async {
    if (_charge) return;
    final prefs = await SharedPreferences.getInstance();
    final brut = prefs.getString(_cle);
    if (brut != null && brut.isNotEmpty) {
      try {
        final liste = jsonDecode(brut) as List;
        _entrees = liste
            .cast<Map<String, dynamic>>()
            .map(_Entree.fromJson)
            .toList();
      } catch (_) {
        _entrees = [];
      }
    }
    _charge = true;
  }

  Future<void> _sauvegarder() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cle, jsonEncode(_entrees.map((e) => e.toJson()).toList()));
  }
}
