import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../Configuration/app_theme.dart';
import '../../Providers/app_state.dart';
import '../../Widgets/klemi_widgets.dart';

/// 2.2 · Résultat de la série + progression (points, streak, niveau).
class ResultatPage extends StatelessWidget {
  const ResultatPage({super.key});

  @override
  Widget build(BuildContext context) {
    final etat = context.watch<AppState>();
    final score = etat.bonnesReponsesSerie / etat.questionsSerie;
    final progression = etat.points / etat.pointsNiveauSuivant;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const BoutonRetour(),
                  Text('Série terminée · ${etat.questionsSerie} questions',
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.texteSecondaire)),
                  const SizedBox(width: 44),
                ],
              ),
              const SizedBox(height: 18),
              Center(
                child: SizedBox(
                  width: 190,
                  height: 190,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CustomPaint(
                        size: const Size(190, 190),
                        painter: _AnneauScore(score, AppTheme.orange),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          RichText(
                            text: TextSpan(
                              style: const TextStyle(
                                  fontFamily: 'Lato', fontWeight: FontWeight.w800, color: AppTheme.navy),
                              children: [
                                TextSpan(
                                    text: '${etat.bonnesReponsesSerie}',
                                    style: const TextStyle(fontSize: 54, letterSpacing: -2)),
                                TextSpan(
                                    text: '/${etat.questionsSerie}',
                                    style: const TextStyle(fontSize: 26, color: AppTheme.texteDiscret)),
                              ],
                            ),
                          ),
                          const Text('+160 pts',
                              style: TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.orangeFonce)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text('I ni baara, Aminata !',
                  textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 6),
              const Text('Tu fais mieux que 72 % des élèves de 3e sur cette série.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: AppTheme.texteSecondaire)),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(child: _Stat('${etat.serieJours}', 'jours de suite')),
                  const SizedBox(width: 10),
                  Expanded(child: _Stat(_milliers(etat.points), 'points totaux')),
                  const SizedBox(width: 10),
                  const Expanded(child: _Stat('#12', 'classe · Askia')),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Niveau ${etat.niveau} · ${etat.nomNiveau}',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                  Text('${_milliers(etat.points)} / ${_milliers(etat.pointsNiveauSuivant)}',
                      style: const TextStyle(fontSize: 13, color: AppTheme.texteSecondaire)),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: progression.clamp(0.0, 1.0).toDouble(),
                  minHeight: 10,
                  backgroundColor: AppTheme.bordure,
                  color: AppTheme.orange,
                ),
              ),
              const SizedBox(height: 18),
              CarteBlanche(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('2 questions à revoir',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                        Text('Q3 · Q7',
                            style: TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.rougeFonce)),
                      ],
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Klemi a ajouté une fiche « Kankou Moussa et Tombouctou » à ton feed pour combler ces lacunes.',
                      style: TextStyle(fontSize: 13, height: 1.5, color: AppTheme.texteSecondaire),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              KlemiBouton(
                libelle: 'Continuer le feed',
                icone: Icons.keyboard_arrow_up,
                couleur: AppTheme.orange,
                onPressed: () => Navigator.of(context).maybePop(),
              ),
              const SizedBox(height: 10),
              KlemiBoutonSecondaire(
                libelle: 'Partager mon score sur WhatsApp',
                icone: Icons.ios_share,
                onPressed: () {},
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _milliers(int n) {
    final s = n.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buffer.write(' ');
      buffer.write(s[i]);
    }
    return buffer.toString();
  }
}

class _Stat extends StatelessWidget {
  final String valeur;
  final String libelle;
  const _Stat(this.valeur, this.libelle);

  @override
  Widget build(BuildContext context) {
    return CarteBlanche(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(valeur, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(libelle, style: const TextStyle(fontSize: 12, color: AppTheme.texteSecondaire)),
        ],
      ),
    );
  }
}

class _AnneauScore extends CustomPainter {
  final double fraction;
  final Color couleur;
  _AnneauScore(this.fraction, this.couleur);

  @override
  void paint(Canvas canvas, Size size) {
    final centre = Offset(size.width / 2, size.height / 2);
    const epaisseur = 14.0;
    final rayon = size.width / 2 - epaisseur / 2;
    final fond = Paint()
      ..color = AppTheme.bordure
      ..style = PaintingStyle.stroke
      ..strokeWidth = epaisseur;
    final avant = Paint()
      ..color = couleur
      ..style = PaintingStyle.stroke
      ..strokeWidth = epaisseur
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(centre, rayon, fond);
    canvas.drawArc(
      Rect.fromCircle(center: centre, radius: rayon),
      -math.pi / 2,
      2 * math.pi * fraction,
      false,
      avant,
    );
  }

  @override
  bool shouldRepaint(_AnneauScore old) => old.fraction != fraction || old.couleur != couleur;
}
