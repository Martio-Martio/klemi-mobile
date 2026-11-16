import 'package:flutter/material.dart';

import '../../Configuration/app_theme.dart';
import '../../Data/mock_social.dart';
import '../../Models/social.dart';
import '../../Widgets/klemi_widgets.dart';

/// Centre de notifications (streak, nouveaux contenus, résultats, commentaires, forfait).
class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const BoutonRetour(),
                  Text('Notifications', style: Theme.of(context).textTheme.titleLarge),
                  TextButton(onPressed: () {}, child: const Text('Tout lire')),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                itemCount: notificationsDemo.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (_, i) => _Ligne(n: notificationsDemo[i]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Ligne extends StatelessWidget {
  final NotificationApp n;
  const _Ligne({required this.n});

  (IconData, Color) get _icone => switch (n.type) {
        TypeNotification.streak => (Icons.local_fire_department_outlined, AppTheme.orange),
        TypeNotification.nouveauContenu => (Icons.fiber_new_outlined, AppTheme.bleu),
        TypeNotification.resultat => (Icons.emoji_events_outlined, AppTheme.vert),
        TypeNotification.commentaire => (Icons.chat_bubble_outline, AppTheme.bleu),
        TypeNotification.forfait => (Icons.workspace_premium_outlined, AppTheme.orange),
      };

  @override
  Widget build(BuildContext context) {
    final (icone, couleur) = _icone;
    return CarteBlanche(
      padding: const EdgeInsets.all(12),
      couleurBordure: n.lue ? AppTheme.bordure : AppTheme.bleu,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: couleur, borderRadius: BorderRadius.circular(12)),
            child: Icon(icone, size: 20, color: AppTheme.navy),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(n.titre,
                    style: TextStyle(
                        fontSize: 14, fontWeight: n.lue ? FontWeight.w700 : FontWeight.w800)),
                const SizedBox(height: 2),
                Text(n.detail,
                    style: const TextStyle(fontSize: 13, height: 1.4, color: AppTheme.texteSecondaire)),
                const SizedBox(height: 4),
                Text(n.ilYA, style: const TextStyle(fontSize: 11, color: AppTheme.texteDiscret)),
              ],
            ),
          ),
          if (!n.lue)
            Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.only(top: 6),
              decoration: const BoxDecoration(color: AppTheme.bleuFonce, shape: BoxShape.circle),
            ),
        ],
      ),
    );
  }
}
