/// Destination déduite d'un payload de notification push (plan Phase 5).
/// Les enums restent génériques pour que `main.dart` puisse les mapper vers
/// des routes Flutter sans coupler le routeur au Navigator.
enum DestinationPush {
  /// Centre de notifications (défaut). Garde l'historique.
  notifications,

  /// Un contenu spécifique du feed à ouvrir (quiz / fiche / podcast).
  /// Lire [DecisionPush.contentId] pour l'identifier.
  feedContenu,

  /// Page des commentaires sur un contenu.
  commentaires,

  /// Page des forfaits (rappel renouvellement, upsell…).
  forfaits,
}

/// Décision prise par [routerPourPush] — contient la destination et les
/// paramètres éventuels (ex. ID du contenu à ouvrir).
class DecisionPush {
  final DestinationPush destination;
  final String? contentId;
  final String? creatorId;

  const DecisionPush({
    required this.destination,
    this.contentId,
    this.creatorId,
  });
}

/// Types de notifications serveur (doivent matcher le `NotificationType`
/// enum backend). On tolère les variantes en lowercase/camelCase/snake_case.
const _types = {
  'NEW_CONTENT_FROM_FOLLOWED_CREATOR': DestinationPush.feedContenu,
  'nouveauContenu': DestinationPush.feedContenu,
  'COMMENT_ON_CONTENT': DestinationPush.commentaires,
  'commentaire': DestinationPush.commentaires,
  'LIKE_ON_CONTENT': DestinationPush.feedContenu,
  'STREAK_REMINDER': DestinationPush.notifications,
  'streak': DestinationPush.notifications,
  'RESULTAT': DestinationPush.notifications,
  'resultat': DestinationPush.notifications,
  'SUBSCRIPTION_EXPIRATION': DestinationPush.forfaits,
  'forfait': DestinationPush.forfaits,
};

/// Fonction pure : prend un payload de notification (celui remonté par
/// `PushService.messagesOuverts` ou `messageInitial`) et décide où naviguer.
///
/// Le payload attendu est la forme `{'titre', 'detail', ...data}` produite
/// par `FcmPushService._versPayload` — les champs métier (`type`, `contentId`,
/// `creatorId`) viennent du `data` du `RemoteMessage`.
DecisionPush routerPourPush(Map<String, dynamic> payload) {
  final type = (payload['type'] ?? payload['notificationType']) as String?;
  final destination = (type != null ? _types[type] : null) ?? DestinationPush.notifications;
  return DecisionPush(
    destination: destination,
    contentId: (payload['contentId'] ?? payload['itemId']) as String?,
    creatorId: (payload['creatorId'] ?? payload['createurId']) as String?,
  );
}
