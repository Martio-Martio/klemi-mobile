import 'package:flutter/material.dart';

import '../../Configuration/app_theme.dart';
import '../../Data/mock_social.dart';
import '../../Models/social.dart';
import '../../Services/api_exception.dart';
import '../../Services/social_api.dart';
import '../../Widgets/klemi_widgets.dart';

/// Feuille de commentaires ouverte depuis le rail d'une carte du feed.
/// Si [contentId] est fourni, charge les commentaires via l'API ; sinon
/// retombe sur les données de démo (utile tant que l'API n'est pas branchée
/// ou pour la carte podcast qui n'a pas encore d'ID connu).
Future<void> ouvrirCommentaires(
  BuildContext context, {
  String? titre,
  String? contentId,
  SocialApi? api,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppTheme.beige,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _CommentairesSheet(titre: titre, contentId: contentId, api: api),
  );
}

class _CommentairesSheet extends StatefulWidget {
  final String? titre;
  final String? contentId;
  final SocialApi? api;
  const _CommentairesSheet({this.titre, this.contentId, this.api});

  @override
  State<_CommentairesSheet> createState() => _CommentairesSheetState();
}

class _CommentairesSheetState extends State<_CommentairesSheet> {
  List<Commentaire> _liste = const [];
  final _saisie = TextEditingController();
  bool _chargement = true;
  bool _envoi = false;
  String? _erreur;

  late final SocialApi _api = widget.api ?? SocialApi();

  @override
  void initState() {
    super.initState();
    _chargerPage();
  }

  @override
  void dispose() {
    _saisie.dispose();
    super.dispose();
  }

  Future<void> _chargerPage() async {
    final id = widget.contentId;
    if (id == null) {
      // Pas d'ID → fallback mock (comportement historique).
      setState(() {
        _liste = List.of(commentairesDemo);
        _chargement = false;
      });
      return;
    }
    try {
      final page = await _api.listComments(id);
      if (!mounted) return;
      setState(() {
        _liste = page.commentaires;
        _chargement = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _erreur = e.message;
        _chargement = false;
      });
    } catch (_) {
      // ApiClient pas branché : fallback mock.
      if (!mounted) return;
      setState(() {
        _liste = List.of(commentairesDemo);
        _chargement = false;
      });
    }
  }

  Future<void> _envoyer() async {
    final t = _saisie.text.trim();
    if (t.isEmpty || _envoi) return;
    _saisie.clear();
    final id = widget.contentId;
    if (id == null) {
      setState(() => _liste = [
            ..._liste,
            Commentaire(auteur: '@aminata_t', initiales: 'AT', texte: t, ilYA: 'à l\'instant'),
          ]);
      return;
    }
    // Optimiste : ajouter localement puis remplacer par la réponse serveur.
    final local = Commentaire(auteur: '@aminata_t', initiales: 'AT', texte: t, ilYA: 'à l\'instant');
    setState(() {
      _liste = [..._liste, local];
      _envoi = true;
    });
    try {
      final confirme = await _api.postComment(id, t);
      if (!mounted) return;
      setState(() {
        _liste = [..._liste.where((c) => c != local), confirme];
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _liste = _liste.where((c) => c != local).toList());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), behavior: SnackBarBehavior.floating),
      );
    } catch (_) {
      // Pas d'API dispo : on garde l'ajout local.
    } finally {
      if (mounted) setState(() => _envoi = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bas = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bas),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.72,
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.bordurePointillee,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
              child: Row(
                children: [
                  Text('${_liste.length} commentaires',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                  const Spacer(),
                  const Icon(Icons.verified_outlined, size: 16, color: AppTheme.vertFonce),
                  const SizedBox(width: 4),
                  const Text("Modérés par l'enseignant",
                      style: TextStyle(fontSize: 12, color: AppTheme.texteSecondaire)),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: _chargement
                  ? const Center(child: CircularProgressIndicator(color: AppTheme.bleu))
                  : (_erreur != null && _liste.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Text(
                              'Impossible de charger les commentaires : ${_erreur!}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 13, color: AppTheme.texteSecondaire),
                            ),
                          ),
                        )
                      : (_liste.isEmpty
                          ? const Center(
                              child: Text(
                                'Sois le premier à commenter.',
                                style: TextStyle(fontSize: 13, color: AppTheme.texteSecondaire),
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                              itemCount: _liste.length,
                              separatorBuilder: (_, _) => const SizedBox(height: 14),
                              itemBuilder: (_, i) => _Ligne(c: _liste[i]),
                            ))),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
              child: Row(
                children: [
                  const Avatar(initiales: 'AT', couleur: AppTheme.bleu, taille: 36),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _saisie,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _envoyer(),
                      decoration: const InputDecoration(
                        hintText: 'Pose une question ou aide un camarade…',
                        contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _envoyer,
                    style: IconButton.styleFrom(backgroundColor: AppTheme.navy),
                    icon: const Icon(Icons.send, size: 18, color: AppTheme.blanc),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Ligne extends StatelessWidget {
  final Commentaire c;
  const _Ligne({required this.c});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Avatar(initiales: c.initiales, taille: 36,
            couleur: c.enseignant ? AppTheme.orange : AppTheme.vert),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(c.auteur, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                  if (c.enseignant) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppTheme.orange,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text('Enseignant',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800)),
                    ),
                  ],
                  const Spacer(),
                  Text(c.ilYA, style: const TextStyle(fontSize: 11, color: AppTheme.texteDiscret)),
                ],
              ),
              const SizedBox(height: 3),
              Text(c.texte, style: const TextStyle(fontSize: 14, height: 1.4)),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.favorite_border, size: 14, color: AppTheme.texteDiscret),
                  const SizedBox(width: 4),
                  Text('${c.likes}', style: const TextStyle(fontSize: 12, color: AppTheme.texteDiscret)),
                  const SizedBox(width: 14),
                  const Text('Répondre',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.texteDiscret)),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
