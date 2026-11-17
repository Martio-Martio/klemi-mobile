import 'dart:async';

import 'package:flutter/material.dart';

import '../../Configuration/app_theme.dart';
import '../../Models/feed_item.dart';
import '../../Widgets/carte_feed.dart';
import '../../Widgets/klemi_widgets.dart';
import '../Social/commentaires_sheet.dart';

/// 2.4 · Carte podcast à deux voix avec transcription synchronisée.
/// La lecture est simulée (compteur) en attendant le lecteur audio réel.
class CartePodcast extends StatefulWidget {
  final PodcastItem podcast;
  final String prochain;

  const CartePodcast({super.key, required this.podcast, required this.prochain});

  @override
  State<CartePodcast> createState() => _CartePodcastState();
}

class _CartePodcastState extends State<CartePodcast> {
  bool _lecture = false;
  int _positionMs = 192000; // 03:12 pour la démo
  Timer? _timer;

  static const _barres = [
    18, 30, 44, 26, 52, 38, 20, 46, 56, 34, 24, 48, 30, 40, 54, 22, 36, 50, 28, 44,
    18, 32, 46, 26, 40, 20, 34, 48, 30, 22,
  ];

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _basculer() {
    setState(() => _lecture = !_lecture);
    _timer?.cancel();
    if (_lecture) {
      _timer = Timer.periodic(const Duration(milliseconds: 500), (_) {
        setState(() {
          _positionMs += 500;
          if (_positionMs >= widget.podcast.dureeSec * 1000) {
            _positionMs = widget.podcast.dureeSec * 1000;
            _lecture = false;
            _timer?.cancel();
          }
        });
      });
    }
  }

  void _decaler(int ms) {
    setState(() {
      _positionMs = (_positionMs + ms).clamp(0, widget.podcast.dureeSec * 1000).toInt();
    });
  }

  String _mmss(int ms) {
    final s = ms ~/ 1000;
    return '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';
  }

  int get _ligneActive {
    final t = widget.podcast.transcript;
    // Démo : la ligne active tourne sur le transcript pour illustrer la synchro.
    final relatif = (_positionMs ~/ 10000) % t.length;
    return relatif;
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.podcast;
    final total = p.dureeSec * 1000;
    final lues = (_barres.length * _positionMs / total).round();

    return CarteFeed(
      item: p,
      prochain: widget.prochain,
      couleurAccent: AppTheme.bleu,
      actions: [
        ActionRail(Icons.favorite_border, formatCompteur(p.likes)),
        ActionRail(Icons.chat_bubble_outline, 'Avis', onTap: () => ouvrirCommentaires(context)),
        const ActionRail(Icons.bookmark_border, 'Garder'),
        const ActionRail(Icons.ios_share, 'Partager'),
      ],
      contenu: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const ChipType(libelle: 'Podcast', icone: Icons.mic_none, couleur: AppTheme.bleu),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: AppTheme.bleuFonce),
                ),
                child: Text('${p.nomLangue} · ${p.langue.toUpperCase()}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.bleuFonce,
                      fontFamilyFallback: AppTheme.famillesSecours,
                    )),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(p.titre,
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                height: 1.2,
                letterSpacing: -0.3,
                fontFamilyFallback: AppTheme.famillesSecours,
              )),
          const SizedBox(height: 12),
          Row(
            children: [
              for (var i = 0; i < p.voix.length; i++) ...[
                _Voix(nom: p.voix[i], couleur: i == 0 ? AppTheme.bleu : AppTheme.vert),
                const SizedBox(width: 10),
              ],
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.blanc,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.bordure),
            ),
            child: Column(
              children: [
                SizedBox(
                  height: 56,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      for (var i = 0; i < _barres.length; i++)
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 1.5),
                            child: Container(
                              height: _barres[i].toDouble(),
                              decoration: BoxDecoration(
                                color: i < lues ? AppTheme.bleu : AppTheme.bordure,
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_mmss(_positionMs), style: _styleTemps),
                    Text(_mmss(total), style: _styleTemps),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _Petit(libelle: '1×', onTap: () {}),
                    IconButton(
                      tooltip: 'Reculer de 15 s',
                      onPressed: () => _decaler(-15000),
                      icon: const Icon(Icons.replay_10, size: 28, color: AppTheme.navy),
                    ),
                    InkWell(
                      onTap: _basculer,
                      customBorder: const CircleBorder(),
                      child: Container(
                        width: 64,
                        height: 64,
                        decoration: const BoxDecoration(color: AppTheme.bleu, shape: BoxShape.circle),
                        child: Icon(_lecture ? Icons.pause : Icons.play_arrow,
                            size: 32, color: AppTheme.navy),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Avancer de 15 s',
                      onPressed: () => _decaler(15000),
                      icon: const Icon(Icons.forward_10, size: 28, color: AppTheme.navy),
                    ),
                    _Petit(icone: Icons.download_outlined, onTap: () {}),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          for (var i = 0; i < p.transcript.length; i++)
            _LigneTranscription(
              ligne: p.transcript[i],
              active: i == _ligneActive,
              couleurVoix: p.transcript[i].voix == p.voix.first ? AppTheme.bleuFonce : AppTheme.vertFonce,
            ),
        ],
      ),
    );
  }

  static const _styleTemps =
      TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.texteSecondaire);
}

class _Voix extends StatelessWidget {
  final String nom;
  final Color couleur;
  const _Voix({required this.nom, required this.couleur});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 6, 12, 6),
      decoration: BoxDecoration(
        color: AppTheme.blanc,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTheme.bordure),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Avatar(initiales: nom[0], couleur: couleur, taille: 28),
          const SizedBox(width: 8),
          Text(nom, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _Petit extends StatelessWidget {
  final String? libelle;
  final IconData? icone;
  final VoidCallback onTap;
  const _Petit({this.libelle, this.icone, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.bordure),
        ),
        alignment: Alignment.center,
        child: icone != null
            ? Icon(icone, size: 20, color: AppTheme.navy)
            : Text(libelle ?? '', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
      ),
    );
  }
}

class _LigneTranscription extends StatelessWidget {
  final LigneTranscript ligne;
  final bool active;
  final Color couleurVoix;
  const _LigneTranscription({
    required this.ligne,
    required this.active,
    required this.couleurVoix,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: active ? 1 : 0.55,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: active ? AppTheme.blanc : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 48,
              child: Text(ligne.voix,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: couleurVoix,
                    fontFamilyFallback: AppTheme.famillesSecours,
                  )),
            ),
            Expanded(
              child: Text(
                ligne.texte,
                style: TextStyle(
                  fontSize: active ? 15 : 14,
                  height: 1.45,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                  fontFamilyFallback: AppTheme.famillesSecours,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
