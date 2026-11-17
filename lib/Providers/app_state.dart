import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../Configuration/langues.dart';
import '../Configuration/matieres.dart';
import '../Services/api_exception.dart';
import '../Services/auth_storage.dart';
import '../Services/mobile_auth_api.dart';
import '../Services/profile_api.dart';
import '../Services/push_router.dart';
import '../Services/push_service.dart';
import '../Services/social_api.dart';

/// État de session côté app (langue, progression, forfait).
/// À brancher sur l'API : les valeurs sont initialisées en local pour la démo.
class AppState extends ChangeNotifier {
  static const _cleLangue = 'langue';
  static const _cleLangueAudio = 'langueAudio';
  static const _cleLangueInterface = 'langueInterface';
  static const _cleConnecte = 'connecte';

  /// Langue de **lecture** — gouverne les contenus écrits (quiz, fiches,
  /// flashcards, cartes mentales). Restreinte à `{fr, en}` : le backend ne
  /// génère pas de texte en langue locale (voir plan Phase 3).
  Langue _langue = langueLectureParDefaut;

  /// Langue d'**écoute** — gouverne les podcasts. Peut valoir n'importe
  /// quelle langue de [languesAudio], y compris les langues locales.
  Langue _langueAudio = langueAudioParDefaut;

  /// Langue affichée par le chip et la feuille de sélection. Suit le dernier
  /// choix de ce sélecteur : la langue de lecture quand elle est fr/en, sinon
  /// la langue audio qui vient d'être choisie. Les réglages continuent de
  /// piloter [langue] et [langueAudio] séparément.
  Langue _langueInterface = langueLectureParDefaut;

  bool _connecte = false;

  /// Token JWT courant, en mémoire uniquement. La persistance sécurisée est
  /// dans [AuthStorage]. `null` si l'utilisateur n'est pas connecté.
  String? _accessToken;

  /// Catalogue public des features backend (chargé au démarrage via
  /// `GET /platform/features`). Vide tant que l'appel n'a pas abouti —
  /// les écrans qui dépendent d'une feature doivent tolérer l'absence.
  Map<String, dynamic> features = const {};

  int points = 1240;
  int serieJours = 5;
  int niveau = 4;
  String nomNiveau = 'Griot en herbe';
  int pointsNiveauSuivant = 1500;
  int generationsRestantes = 2;
  String forfait = 'Gratuit';

  int bonnesReponsesSerie = 8;
  int questionsSerie = 10;

  // Abonnements (ids de créateurs suivis). Mutable pour permettre la
  // synchronisation depuis GET /mobile/me/following au login (Phase 5).
  Set<String> suivis = {'kone', 'klemi', 'diallo'};

  // Préférences (écran Paramètres)
  bool notifStreak = true;
  bool notifNouveauxContenus = true;
  bool notifResultats = true;
  bool telechargerWifiSeulement = true;
  bool lectureAutoPodcast = true;
  int stockageHorsLigneMo = 142;

  /// Notifications non lues — mis à jour par le centre de notifs ou via SSE
  /// quand le badge décrémente temps réel (plan Phase 5).
  int notificationsNonLues = 0;

  /// Intent de deep-link push en attente — déposé par `MyApp._surMessageTappe`
  /// (après `popUntil(isFirst)`) et consommé par `AppShell` qui exécute la
  /// navigation (bascule onglet feed, assure le contenu via le repo, ouvre la
  /// sheet commentaires si demandé). `AppShell` remet à null une fois traité.
  final ValueNotifier<DecisionPush?> intentPush = ValueNotifier(null);

  @override
  void dispose() {
    intentPush.dispose();
    super.dispose();
  }

  // Niveau d'études et matières (ajustables : collège, lycée, université…)
  static const _cleNiveau = 'niveau';
  static const _cleMatieres = 'matieres';
  NiveauEtudes _niveau = NiveauEtudes.college;
  String classe = '3e';
  String etablissement = 'Lycée Askia, Bamako';
  List<String>? _matieresPerso; // null = liste par défaut du niveau

  Langue get langue => _langue;
  Langue get langueAudio => _langueAudio;
  Langue get langueInterface => _langueInterface;
  bool get connecte => _connecte;
  String? get accessToken => _accessToken;
  /// Niveau d'études (collège, lycée…). Distinct de [niveau], le palier de progression.
  NiveauEtudes get niveauEtudes => _niveau;

  /// Matières de l'utilisateur : celles qu'il a personnalisées, sinon la
  /// liste par défaut de son niveau.
  List<String> get matieres =>
      List.unmodifiable(_matieresPerso ?? matieresParDefaut[_niveau] ?? const []);

  Future<void> choisirNiveau(NiveauEtudes n, {bool reinitialiserMatieres = true}) async {
    _niveau = n;
    if (reinitialiserMatieres) _matieresPerso = null;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cleNiveau, n.name);
    if (reinitialiserMatieres) await prefs.remove(_cleMatieres);
  }

  Future<void> ajouterMatiere(String nom) async {
    final n = nom.trim();
    if (n.isEmpty || matieres.any((m) => m.toLowerCase() == n.toLowerCase())) return;
    _matieresPerso = [...matieres, n];
    notifyListeners();
    await _sauverMatieres();
  }

  Future<void> retirerMatiere(String nom) async {
    _matieresPerso = matieres.where((m) => m != nom).toList();
    notifyListeners();
    await _sauverMatieres();
  }

  Future<void> reinitialiserMatieres() async {
    _matieresPerso = null;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cleMatieres);
  }

  Future<void> _sauverMatieres() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_cleMatieres, _matieresPerso ?? const []);
  }

  bool suit(String createurId) => suivis.contains(createurId);

  /// Toggle local — utilisé pour un rollback UI ou en mode mock.
  /// Les appels serveur (`SocialApi.follow` / `unfollow`) sont déclenchés
  /// côté `ProfilCreateurPage` avec un pattern optimiste.
  void basculerSuivi(String createurId) {
    if (!suivis.remove(createurId)) suivis.add(createurId);
    notifyListeners();
  }

  /// Synchronise la liste des créateurs suivis depuis l'API — appelé après
  /// `GET /mobile/me/following` au login ou au pull-to-refresh du profil.
  void definirSuivis(Set<String> ids) {
    suivis = {...ids};
    notifyListeners();
  }

  /// Met à jour le compteur de notifications non lues (badge en tête de
  /// `ProfilPage` + onglet Notifications).
  void definirNotificationsNonLues(int n) {
    if (notificationsNonLues == n) return;
    notificationsNonLues = n;
    notifyListeners();
  }

  void decrementerNotificationsNonLues() {
    if (notificationsNonLues <= 0) return;
    notificationsNonLues--;
    notifyListeners();
  }

  void majPreference(void Function() changement) {
    changement();
    notifyListeners();
  }

  void viderStockage() {
    stockageHorsLigneMo = 0;
    notifyListeners();
  }

  Future<void> deconnecter() async {
    // Essayer de prévenir le backend avant de couper localement. Si le
    // réseau est indispo (ou si le token est déjà périmé), on ignore et
    // on nettoie quand même — l'utilisateur ne doit jamais rester coincé
    // en "deconnexion".
    if (_accessToken != null) {
      // Retire le token FCM avant le logout — sinon on perd le droit
      // d'appeler /push-token côté API (auth déjà révoquée).
      try {
        final token = await PushService.instance.obtenirToken();
        if (token != null && token.isNotEmpty) {
          await SocialApi().unregisterPushToken(token);
        }
      } catch (_) {
        // Firebase pas init ou réseau indispo : best-effort.
      }
      try {
        await MobileAuthApi().logout();
      } on ApiException {
        // best-effort — on continue le nettoyage local.
      }
    }
    _connecte = false;
    _accessToken = null;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_cleConnecte, false);
    await AuthStorage.vider();
  }

  /// Enregistre une session authentifiée : tokens persistés en Keychain /
  /// EncryptedSharedPreferences via [AuthStorage], flag `connecte` persisté
  /// en SharedPreferences.
  Future<void> definirSession({required String accessToken, String? refreshToken}) async {
    _accessToken = accessToken;
    _connecte = true;
    notifyListeners();
    await AuthStorage.enregistrer(accessToken: accessToken, refreshToken: refreshToken);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_cleConnecte, true);
  }

  /// Tente de renouveler l'access token à partir du refresh token persisté.
  /// Branché sur [ApiClient.rafraichirSession] dans `main.dart`.
  /// Retourne `true` si un nouveau token est en place, `false` sinon
  /// (l'appelant doit alors déclencher la déconnexion).
  Future<bool> tenterRafraichirSession() async {
    final refresh = await AuthStorage.refreshToken();
    if (refresh == null || refresh.isEmpty) return false;
    try {
      final session = await MobileAuthApi().refresh(refresh);
      await definirSession(
        accessToken: session.accessToken,
        refreshToken: session.refreshToken,
      );
      return true;
    } on ApiException {
      return false;
    }
  }

  /// Met à jour le catalogue de features exposé par le backend.
  void definirFeatures(Map<String, dynamic> nouvelles) {
    features = Map.unmodifiable(nouvelles);
    notifyListeners();
  }

  /// Absorbe le payload `GET /api/mobile/me` en un seul `notifyListeners`
  /// — évite N rebuilds pendant le chargement initial du profil (Phase 4).
  /// Les champs absents du payload préservent leur valeur courante.
  void definirDepuisProfil(ProfilUtilisateur p) {
    final profil = p.profil;
    final progression = p.progression;
    final forfait = p.forfait;
    final prefs = p.preferences;

    // Profil
    final idLangue = profil['langue'] as String?;
    if (idLangue != null) {
      final trouve = languesDisponibles.firstWhere(
        (l) => l.id == idLangue,
        orElse: () => _langue,
      );
      if (estLangueLecture(trouve)) _langue = trouve;
    }
    final idAudio = profil['langueAudio'] as String?;
    if (idAudio != null) {
      _langueAudio = languesDisponibles.firstWhere(
        (l) => l.id == idAudio,
        orElse: () => _langueAudio,
      );
    }
    final niveau = profil['niveauEtudes'] as String?;
    if (niveau != null) {
      _niveau = NiveauEtudes.values.firstWhere(
        (n) => n.name == niveau,
        orElse: () => _niveau,
      );
    }
    final c = profil['classe'];
    if (c is String && c.isNotEmpty) classe = c;
    final e = profil['etablissement'];
    if (e is String && e.isNotEmpty) etablissement = e;

    // Progression
    points = (progression['points'] as num?)?.toInt() ?? points;
    serieJours = (progression['serieJours'] as num?)?.toInt() ?? serieJours;
    this.niveau = (progression['niveau'] as num?)?.toInt() ?? this.niveau;
    nomNiveau = progression['nomNiveau'] as String? ?? nomNiveau;
    pointsNiveauSuivant =
        (progression['pointsNiveauSuivant'] as num?)?.toInt() ?? pointsNiveauSuivant;
    bonnesReponsesSerie =
        (progression['bonnesReponsesSerie'] as num?)?.toInt() ?? bonnesReponsesSerie;
    questionsSerie =
        (progression['questionsSerie'] as num?)?.toInt() ?? questionsSerie;

    // Forfait
    final nomForfait = forfait['nom'] as String?;
    if (nomForfait != null && nomForfait.isNotEmpty) this.forfait = nomForfait;
    generationsRestantes =
        (forfait['generationsRestantes'] as num?)?.toInt() ?? generationsRestantes;

    // Préférences
    notifStreak = prefs['notifStreak'] as bool? ?? notifStreak;
    notifNouveauxContenus = prefs['notifNouveauxContenus'] as bool? ?? notifNouveauxContenus;
    notifResultats = prefs['notifResultats'] as bool? ?? notifResultats;
    telechargerWifiSeulement =
        prefs['telechargerWifiSeulement'] as bool? ?? telechargerWifiSeulement;
    lectureAutoPodcast = prefs['lectureAutoPodcast'] as bool? ?? lectureAutoPodcast;
    stockageHorsLigneMo =
        (prefs['stockageHorsLigneMo'] as num?)?.toInt() ?? stockageHorsLigneMo;

    notifyListeners();
  }

  /// Met à jour le quota IA restant seulement (endpoint dédié Phase 3/4).
  void definirQuota(QuotaGeneration q) {
    generationsRestantes = q.restantes;
    if (q.forfait.isNotEmpty) forfait = q.forfait;
    notifyListeners();
  }

  Future<void> charger() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString(_cleLangue);
    var interfaceDepuisAncienneLangue = false;
    if (id != null) {
      final trouve = languesDisponibles.firstWhere(
        (l) => l.id == id,
        orElse: () => _langue,
      );
      // Un ancien build pouvait avoir persisté une langue locale en langue
      // de lecture : on la remet en langue audio pour ne pas perdre la préf.
      if (estLangueLecture(trouve)) {
        _langue = trouve;
      } else {
        _langueAudio = trouve;
        _langueInterface = trouve;
        interfaceDepuisAncienneLangue = true;
      }
    }
    final idAudio = prefs.getString(_cleLangueAudio);
    if (idAudio != null) {
      _langueAudio = languesDisponibles.firstWhere(
        (l) => l.id == idAudio,
        orElse: () => _langueAudio,
      );
    }
    final idInterface = prefs.getString(_cleLangueInterface);
    if (idInterface != null) {
      _langueInterface = languesDisponibles.firstWhere(
        (l) => l.id == idInterface,
        orElse: () => _langue,
      );
    } else if (!interfaceDepuisAncienneLangue) {
      _langueInterface = _langue;
    }
    _connecte = prefs.getBool(_cleConnecte) ?? false;
    if (_connecte) {
      _accessToken = await AuthStorage.accessToken();
      // Session invalide : flag levé mais token absent → forcer la déconnexion.
      if (_accessToken == null || _accessToken!.isEmpty) {
        _connecte = false;
        await prefs.setBool(_cleConnecte, false);
      }
    }
    final niveau = prefs.getString(_cleNiveau);
    if (niveau != null) {
      _niveau = NiveauEtudes.values.firstWhere((n) => n.name == niveau, orElse: () => _niveau);
    }
    final matieres = prefs.getStringList(_cleMatieres);
    if (matieres != null && matieres.isNotEmpty) _matieresPerso = matieres;
    notifyListeners();
  }

  /// Fixe la langue de **lecture** (quiz/fiche) et la langue affichée par le
  /// chip. Si [langue] n'est pas une langue de lecture valide (fr/en), la
  /// lecture ne change pas : le choix part vers [choisirLangueAudio] et le
  /// chip affiche cette langue audio.
  Future<void> choisirLangue(Langue langue) async {
    if (!estLangueLecture(langue)) {
      _langueInterface = langue;
      await choisirLangueAudio(langue);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cleLangueInterface, langue.id);
      return;
    }
    _langue = langue;
    _langueInterface = langue;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cleLangue, langue.id);
    await prefs.setString(_cleLangueInterface, langue.id);
  }

  /// Fixe la langue d'**écoute** (podcast). Accepte les 5 langues de
  /// [languesAudio].
  Future<void> choisirLangueAudio(Langue langue) async {
    _langueAudio = langue;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cleLangueAudio, langue.id);
  }

  Future<void> marquerConnecte(bool valeur) async {
    _connecte = valeur;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_cleConnecte, valeur);
  }

  void ajouterPoints(int n) {
    points += n;
    notifyListeners();
  }

  void changerForfait(String nom) {
    forfait = nom;
    notifyListeners();
  }
}
