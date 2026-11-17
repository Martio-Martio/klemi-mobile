import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../Configuration/app_theme.dart';
import '../../Data/mock_social.dart';
import '../../Models/social.dart';
import '../../Providers/app_state.dart';
import '../../Services/api_exception.dart';
import '../../Services/social_api.dart';
import '../../Widgets/klemi_widgets.dart';

/// Centre de notifications (streak, nouveaux contenus, résultats, commentaires, forfait).
class NotificationsPage extends StatefulWidget {
  final SocialApi? api;
  const NotificationsPage({super.key, this.api});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  List<NotificationApp> _liste = const [];
  bool _chargement = true;
  String? _erreur;

  late final SocialApi _api = widget.api ?? SocialApi();

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    try {
      final page = await _api.listNotifications();
      if (!mounted) return;
      setState(() {
        _liste = page.notifications;
        _chargement = false;
      });
      if (mounted) {
        context.read<AppState>().definirNotificationsNonLues(page.nonLues);
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _erreur = e.message;
        _chargement = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _liste = List.of(notificationsDemo);
        _chargement = false;
      });
    }
  }

  Future<void> _marquerLue(NotificationApp n) async {
    if (n.lue) return;
    // Optimiste.
    final idx = _liste.indexOf(n);
    if (idx < 0) return;
    setState(() {
      _liste = [..._liste]..[idx] = n.copier(lue: true);
    });
    context.read<AppState>().decrementerNotificationsNonLues();
    try {
      await _api.markNotificationRead(n.id);
    } catch (_) {
      // Pas d'API ou erreur : l'UX reste optimiste, resync au prochain load.
    }
  }

  Future<void> _toutLire() async {
    final nonLues = _liste.where((n) => !n.lue).toList();
    if (nonLues.isEmpty) return;
    setState(() {
      _liste = _liste.map((n) => n.lue ? n : n.copier(lue: true)).toList();
    });
    context.read<AppState>().definirNotificationsNonLues(0);
    try {
      await Future.wait(nonLues.map((n) => _api.markNotificationRead(n.id)));
    } catch (_) {
      // Resync au prochain load.
    }
  }

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
                  TextButton(onPressed: _toutLire, child: const Text('Tout lire')),
                ],
              ),
            ),
            Expanded(child: _corps()),
          ],
        ),
      ),
    );
  }

  Widget _corps() {
    if (_chargement) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.bleu));
    }
    if (_erreur != null && _liste.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            'Impossible de charger les notifications : $_erreur',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: AppTheme.texteSecondaire),
          ),
        ),
      );
    }
    if (_liste.isEmpty) {
      return const Center(
        child: Text(
          'Rien de nouveau pour l\'instant.',
          style: TextStyle(fontSize: 13, color: AppTheme.texteSecondaire),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      itemCount: _liste.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (_, i) => _Ligne(n: _liste[i], onTap: () => _marquerLue(_liste[i])),
    );
  }
}

class _Ligne extends StatelessWidget {
  final NotificationApp n;
  final VoidCallback onTap;
  const _Ligne({required this.n, required this.onTap});

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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusCarte),
      child: CarteBlanche(
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
      ),
    );
  }
}
