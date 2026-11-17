import '../Configuration/api_client.dart';

/// Forfait exposé par `GET /api/mobile/plans` (plan Phase 6). La liste
/// couvre les plans publics (FREE / STUDENT / PREMIUM) ; le plan PRO est
/// « sur mesure » et n'est pas listé par l'API publique.
class ForfaitDispo {
  final String id;
  final String nom;
  final int prixMensuel;
  final int prixAnnuel;
  final String accroche;
  final List<String> avantages;
  final bool recommande;

  const ForfaitDispo({
    required this.id,
    required this.nom,
    required this.prixMensuel,
    required this.prixAnnuel,
    required this.accroche,
    required this.avantages,
    this.recommande = false,
  });

  factory ForfaitDispo.depuisJson(Map<String, dynamic> json) => ForfaitDispo(
        id: json['id'] as String? ?? '',
        nom: json['nom'] as String? ?? '',
        prixMensuel: (json['prixMensuel'] as num?)?.toInt() ?? 0,
        prixAnnuel: (json['prixAnnuel'] as num?)?.toInt() ?? 0,
        accroche: json['accroche'] as String? ?? '',
        avantages:
            ((json['avantages'] as List?) ?? const []).map((e) => e.toString()).toList(),
        recommande: json['recommande'] as bool? ?? false,
      );
}

/// Moyen de paiement supporté par Flex Transfer (audit 2026-11-17).
enum MoyenPaiement { orange, mtn, moov, wave }

extension MoyenPaiementApi on MoyenPaiement {
  String get idApi => name; // 'orange' | 'mtn' | 'moov' | 'wave'
}

/// Durée d'abonnement choisie au checkout.
enum DureeAbo { monthly, annual }

/// Résultat du `POST /mobile/subscription/checkout`. Le champ `paymentUrl`
/// est présent pour les flows qui redirigent vers une page provider
/// (ex. Wave web) ; sinon le client se contente de poller le statut.
class CheckoutResultat {
  final String invoiceId;
  final String? paymentUrl;
  final String statut; // 'PENDING' généralement
  const CheckoutResultat({
    required this.invoiceId,
    required this.statut,
    this.paymentUrl,
  });

  factory CheckoutResultat.depuisJson(Map<String, dynamic> json) => CheckoutResultat(
        invoiceId: (json['invoiceId'] ?? json['id'] ?? '') as String,
        paymentUrl: json['paymentUrl'] as String?,
        statut: json['status'] as String? ?? 'PENDING',
      );
}

/// Snapshot du statut d'une invoice Flex Transfer.
class StatutPaiement {
  final String statut; // 'PENDING' | 'PAID' | 'FAILED' | 'EXPIRED'
  final String? messageErreur;
  const StatutPaiement({required this.statut, this.messageErreur});

  bool get paye => statut == 'PAID';
  bool get enAttente => statut == 'PENDING';
  bool get echoue => statut == 'FAILED' || statut == 'EXPIRED';
}

/// Wrapper des endpoints Flex Transfer côté mobile.
class BillingApi {
  final ApiClient _client;

  BillingApi([ApiClient? client]) : _client = client ?? ApiClient.instance;

  Future<List<ForfaitDispo>> fetchPlans() async {
    final reponse = await _client.get('/mobile/plans');
    final items = reponse is Map<String, dynamic>
        ? (reponse['plans'] as List? ?? reponse['items'] as List? ?? const [])
        : (reponse as List? ?? const []);
    return items.cast<Map<String, dynamic>>().map(ForfaitDispo.depuisJson).toList();
  }

  Future<CheckoutResultat> checkout({
    required String planId,
    required DureeAbo duree,
    required MoyenPaiement moyen,
    required String numero,
  }) async {
    final reponse = await _client.post(
      '/mobile/subscription/checkout',
      body: {
        'planId': planId,
        'duree': duree.name,
        'moyen': moyen.idApi,
        'numero': numero,
      },
    ) as Map<String, dynamic>;
    return CheckoutResultat.depuisJson(reponse);
  }

  Future<StatutPaiement> fetchStatus(String invoiceId) async {
    final reponse = await _client.get('/mobile/subscription/status/$invoiceId')
        as Map<String, dynamic>;
    return StatutPaiement(
      statut: reponse['status'] as String? ?? 'PENDING',
      messageErreur: reponse['error'] as String? ?? reponse['message'] as String?,
    );
  }
}
