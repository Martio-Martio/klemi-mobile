import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../Configuration/app_theme.dart';
import '../../Providers/app_state.dart';
import '../../Widgets/klemi_widgets.dart';
import 'forfaits_page.dart';

class _MoyenPaiement {
  final String id;
  final String nom;
  final String pays;
  final String initiales;
  final Color couleur;
  final Color couleurTexte;
  final bool numero; // demande un numéro mobile money

  const _MoyenPaiement(this.id, this.nom, this.pays, this.initiales, this.couleur,
      {this.couleurTexte = AppTheme.blanc, this.numero = true});
}

const _moyens = [
  _MoyenPaiement('orange', 'Orange Money', "Mali · Côte d'Ivoire · Sénégal", 'OM', Color(0xFFFF7900)),
  _MoyenPaiement('mtn', 'MTN MoMo', "Côte d'Ivoire · Guinée · Bénin", 'MTN', Color(0xFFFFCC00),
      couleurTexte: AppTheme.navy),
  _MoyenPaiement('moov', 'Moov Money', "Mali · Côte d'Ivoire · Togo", 'MV', Color(0xFF0067B3)),
  _MoyenPaiement('wave', 'Wave', "Sénégal · Mali · Côte d'Ivoire", 'W', Color(0xFF1DC8FE),
      couleurTexte: AppTheme.navy),
  _MoyenPaiement('card', 'Carte bancaire', 'Visa · Mastercard', 'CB', AppTheme.navy, numero: false),
];

/// 3.4 · Paiement du forfait par mobile money ou carte.
class PaiementPage extends StatefulWidget {
  final Forfait forfait;
  final bool annuel;
  const PaiementPage({super.key, required this.forfait, required this.annuel});

  @override
  State<PaiementPage> createState() => _PaiementPageState();
}

class _PaiementPageState extends State<PaiementPage> {
  String _moyen = 'orange';

  @override
  Widget build(BuildContext context) {
    final f = widget.forfait;
    final montant = widget.annuel ? f.prixAnnuel : f.prixMensuel;
    final moyen = _moyens.firstWhere((m) => m.id == _moyen);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const BoutonRetour(),
                  Text('Paiement', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(width: 44),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                children: [
                  CarteBlanche(
                    couleurBordure: AppTheme.bleu,
                    largeurBordure: 2,
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppTheme.bleu,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.center,
                          child: Text(f.nom[0],
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${f.nom} · ${widget.annuel ? 'annuel' : 'mensuel'}',
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                              Text(
                                f.avantages.take(3).join(', '),
                                style: const TextStyle(fontSize: 12, color: AppTheme.texteSecondaire),
                              ),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(context).maybePop(),
                          child: const Text('Changer',
                              style: TextStyle(fontWeight: FontWeight.w700, color: AppTheme.bleuFonce)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Payer avec', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  for (final m in _moyens) ...[
                    InkWell(
                      onTap: () => setState(() => _moyen = m.id),
                      borderRadius: BorderRadius.circular(14),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                        decoration: BoxDecoration(
                          color: AppTheme.blanc,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: m.id == _moyen ? AppTheme.bleu : AppTheme.bordure, width: 2),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(color: m.couleur, shape: BoxShape.circle),
                              alignment: Alignment.center,
                              child: Text(m.initiales,
                                  style: TextStyle(
                                      fontSize: 11, fontWeight: FontWeight.w800, color: m.couleurTexte)),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(m.nom,
                                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                                  Text(m.pays,
                                      style: const TextStyle(fontSize: 12, color: AppTheme.texteDiscret)),
                                ],
                              ),
                            ),
                            Icon(
                              m.id == _moyen ? Icons.radio_button_checked : Icons.radio_button_off,
                              color: m.id == _moyen ? AppTheme.navy : AppTheme.bordure,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (moyen.numero) ...[
                    const SizedBox(height: 8),
                    KlemiChamp(
                      etiquette: 'Numéro ${moyen.nom}',
                      indice: '70 12 34 56',
                      type: TextInputType.phone,
                      prefixe: const IndicatifPays(),
                    ),
                    const SizedBox(height: 6),
                    const Text('Tu recevras une demande de confirmation sur ton téléphone.',
                        style: TextStyle(fontSize: 12, color: AppTheme.texteDiscret)),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Expanded(
                        child: TextField(
                          decoration: InputDecoration(hintText: 'Code promo (facultatif)'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: () {},
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 50),
                          foregroundColor: AppTheme.navy,
                          backgroundColor: AppTheme.blanc,
                          side: const BorderSide(color: AppTheme.bordure),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Appliquer', style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  CarteBlanche(
                    child: Column(
                      children: [
                        _ligne('${f.nom} · ${widget.annuel ? '12 mois' : '1 mois'}', formatFcfa(montant)),
                        const SizedBox(height: 6),
                        _ligne('Frais opérateur', '0 F'),
                        const Divider(height: 18),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Total', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                            Text('${formatFcfa(montant)} CFA',
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Column(
                children: [
                  KlemiBouton(
                    libelle: 'Payer ${formatFcfa(montant)}',
                    icone: Icons.lock_outline,
                    iconeADroite: false,
                    onPressed: () {
                      context.read<AppState>().changerForfait(f.nom);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Forfait ${f.nom} activé. Reçu envoyé par WhatsApp.'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                      Navigator.of(context).popUntil((r) => r.isFirst);
                    },
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Activation immédiate · rappel 7, 3 et 1 jour avant l'échéance · 7 jours de grâce · reçu envoyé par WhatsApp",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, height: 1.5, color: AppTheme.texteDiscret),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _ligne(String a, String b) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(a, style: const TextStyle(fontSize: 13, color: AppTheme.texteSecondaire)),
          Text(b, style: const TextStyle(fontSize: 13, color: AppTheme.texteSecondaire)),
        ],
      );
}
