import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:provider/provider.dart';

import '../../Configuration/app_theme.dart';
import '../../Providers/app_state.dart';
import '../../Repositories/profile_repository.dart';
import '../../Services/api_exception.dart';
import '../../Services/billing_api.dart';
import '../../Widgets/klemi_widgets.dart';
import 'forfaits_page.dart';

/// Affichage des moyens de paiement — Flex Transfer couvre Orange / MTN /
/// Moov / Wave (audit 2026-11-17). Pas de carte bancaire pour l'instant :
/// retirée par rapport à l'ancienne UI mock.
class _MoyenPaiement {
  final MoyenPaiement id;
  final String nom;
  final String pays;
  final String initiales;
  final Color couleur;
  final Color couleurTexte;

  const _MoyenPaiement(this.id, this.nom, this.pays, this.initiales, this.couleur,
      {this.couleurTexte = AppTheme.blanc});
}

const _moyens = [
  _MoyenPaiement(MoyenPaiement.orange, 'Orange Money', "Mali · Côte d'Ivoire · Sénégal", 'OM', Color(0xFFFF7900)),
  _MoyenPaiement(MoyenPaiement.mtn, 'MTN MoMo', "Côte d'Ivoire · Guinée · Bénin", 'MTN', Color(0xFFFFCC00),
      couleurTexte: AppTheme.navy),
  _MoyenPaiement(MoyenPaiement.moov, 'Moov Money', "Mali · Côte d'Ivoire · Togo", 'MV', Color(0xFF0067B3)),
  _MoyenPaiement(MoyenPaiement.wave, 'Wave', "Sénégal · Mali · Côte d'Ivoire", 'W', Color(0xFF1DC8FE),
      couleurTexte: AppTheme.navy),
];

/// 3.4 · Paiement du forfait par mobile money (Flex Transfer).
class PaiementPage extends StatefulWidget {
  final Forfait forfait;
  final bool annuel;
  final BillingApi? api; // injectable pour les tests
  const PaiementPage({super.key, required this.forfait, required this.annuel, this.api});

  @override
  State<PaiementPage> createState() => _PaiementPageState();
}

class _PaiementPageState extends State<PaiementPage> {
  MoyenPaiement _moyen = MoyenPaiement.orange;
  final _numero = TextEditingController();
  bool _enCours = false;

  late final BillingApi _api = widget.api ?? BillingApi();

  @override
  void dispose() {
    _numero.dispose();
    super.dispose();
  }

  Future<void> _payer(BuildContext context, Forfait f) async {
    if (_enCours) return;
    final n = _numero.text.trim();
    if (n.isEmpty) {
      _snack('Entre le numéro du compte mobile money.');
      return;
    }
    setState(() => _enCours = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final etat = context.read<AppState>();
    EasyLoading.show(status: 'Initialisation du paiement…');

    try {
      final checkout = await _api.checkout(
        planId: f.id,
        duree: widget.annuel ? DureeAbo.annual : DureeAbo.monthly,
        moyen: _moyen,
        numero: n,
      );
      EasyLoading.dismiss();
      if (!mounted) return;

      final statut = await _attendrePaiement(checkout.invoiceId);
      if (!mounted) return;

      if (statut.paye) {
        // Rafraîchir profil (nouveau forfait + quota) côté serveur.
        await ProfileRepository.instance.charger(etat);
        if (!mounted) return;
        messenger.showSnackBar(
          SnackBar(
            content: Text('Forfait ${f.nom} activé. Reçu envoyé par WhatsApp.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        navigator.popUntil((r) => r.isFirst);
      } else if (statut.echoue) {
        _snack(statut.messageErreur ?? 'Paiement refusé. Réessaie ou change de moyen.');
      } else {
        // PENDING au-delà du timeout : on informe sans marquer échoué.
        _snack('Le paiement est encore en cours. Tu recevras une confirmation WhatsApp.');
      }
    } on ApiException catch (e) {
      EasyLoading.dismiss();
      _snack(e.message);
    } catch (_) {
      EasyLoading.dismiss();
      _snack('Impossible de joindre le serveur. Vérifie ta connexion.');
    } finally {
      if (mounted) setState(() => _enCours = false);
    }
  }

  /// Poll /mobile/subscription/status/:invoiceId toutes les 3 s, max 2 min.
  Future<StatutPaiement> _attendrePaiement(String invoiceId) async {
    const intervalle = Duration(seconds: 3);
    const timeoutTotal = Duration(minutes: 2);
    final deadline = DateTime.now().add(timeoutTotal);
    StatutPaiement dernier = const StatutPaiement(statut: 'PENDING');
    while (DateTime.now().isBefore(deadline)) {
      await Future.delayed(intervalle);
      try {
        dernier = await _api.fetchStatus(invoiceId);
        if (!dernier.enAttente) return dernier;
      } on ApiException {
        // on continue à poller — erreur réseau transitoire.
      }
    }
    return dernier; // probablement PENDING → UI affiche message dédié
  }

  void _snack(String m) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(m), behavior: SnackBarBehavior.floating),
    );
  }

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
                  const SizedBox(height: 8),
                  KlemiChamp(
                    etiquette: 'Numéro ${moyen.nom}',
                    indice: '70 12 34 56',
                    type: TextInputType.phone,
                    controleur: _numero,
                    prefixe: const IndicatifPays(),
                  ),
                  const SizedBox(height: 6),
                  const Text('Tu recevras une demande de confirmation sur ton téléphone.',
                      style: TextStyle(fontSize: 12, color: AppTheme.texteDiscret)),
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
                    libelle: _enCours ? 'Paiement en cours…' : 'Payer ${formatFcfa(montant)}',
                    icone: Icons.lock_outline,
                    iconeADroite: false,
                    onPressed: _enCours ? null : () => _payer(context, f),
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
