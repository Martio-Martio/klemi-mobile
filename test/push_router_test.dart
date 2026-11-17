import 'package:flutter_test/flutter_test.dart';

import 'package:klemi/Services/push_router.dart';

void main() {
  group('routerPourPush', () {
    test('NEW_CONTENT_FROM_FOLLOWED_CREATOR → feedContenu + contentId extrait', () {
      final d = routerPourPush({
        'type': 'NEW_CONTENT_FROM_FOLLOWED_CREATOR',
        'contentId': 'q-42',
        'creatorId': 'c-7',
        'titre': 'Prof Koné vient de publier',
      });
      expect(d.destination, DestinationPush.feedContenu);
      expect(d.contentId, 'q-42');
      expect(d.creatorId, 'c-7');
    });

    test('COMMENT_ON_CONTENT → commentaires', () {
      final d = routerPourPush({'type': 'COMMENT_ON_CONTENT', 'contentId': 'f-1'});
      expect(d.destination, DestinationPush.commentaires);
      expect(d.contentId, 'f-1');
    });

    test('LIKE_ON_CONTENT → feedContenu', () {
      final d = routerPourPush({'type': 'LIKE_ON_CONTENT', 'itemId': 'p-3'});
      expect(d.destination, DestinationPush.feedContenu);
      expect(d.contentId, 'p-3');
    });

    test('STREAK_REMINDER → notifications (page d\'historique)', () {
      final d = routerPourPush({'type': 'STREAK_REMINDER'});
      expect(d.destination, DestinationPush.notifications);
      expect(d.contentId, isNull);
    });

    test('SUBSCRIPTION_EXPIRATION → forfaits', () {
      final d = routerPourPush({'type': 'SUBSCRIPTION_EXPIRATION'});
      expect(d.destination, DestinationPush.forfaits);
    });

    test('type en camelCase (variante serveur) accepté', () {
      final d = routerPourPush({'type': 'nouveauContenu', 'contentId': 'q-9'});
      expect(d.destination, DestinationPush.feedContenu);
    });

    test('type inconnu → notifications (défaut sûr)', () {
      final d = routerPourPush({'type': 'DIGEST_WEEKLY'});
      expect(d.destination, DestinationPush.notifications);
    });

    test('payload vide → notifications sans contentId', () {
      final d = routerPourPush(const {});
      expect(d.destination, DestinationPush.notifications);
      expect(d.contentId, isNull);
      expect(d.creatorId, isNull);
    });

    test('champ alternatif `notificationType` honoré', () {
      final d = routerPourPush({'notificationType': 'COMMENT_ON_CONTENT'});
      expect(d.destination, DestinationPush.commentaires);
    });
  });
}
