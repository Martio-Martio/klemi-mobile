import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../Configuration/langues.dart';
import '../Configuration/matieres.dart';
import '../Services/api_exception.dart';
import '../Services/auth_storage.dart';
import '../Services/mobile_auth_api.dart';

/// État de session côté app (langue, progression, forfait).
/// À brancher sur l'API : les valeurs sont initialisées en local pour la démo.
class AppState extends ChangeNotifier {
  static const _cleLangue = 'langue';
  static const _cleLangueAudio = 'langueAudio';
  static const _cleConnecte = 'connecte';

  /// Langue de **lecture** — gouverne les contenus écrits (quiz, fiches,
  /// flashcards, cartes mentales). Restreinte à `{fr, en}` : le backend ne
  /// génère pas de texte en langue locale (voir plan Phase 3).
  Langue _langue = langueLectureParDefaut;

  /// Langue d'**écoute** — gouverne les podcasts. Peut valoir n'importe
  /// quelle langue de [languesAudio], y compris les langues locales.
  Langue _langueAudio = langueAudioParDefaut;

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

  // Abonnements (ids de créateurs suivis)
  final Set<String> suivis = {'kone', 'klemi', 'diallo'};

  // Préférences (écran Paramètres)
  bool notifStreak = true;
  bool notifNouveauxContenus = true;
  bool notifResultats = true;
  bool telechargerWifiSeulement = true;
  bool lectureAutoPodcast = true;
  int stockageHorsLigneMo = 142;

  // Niveau d'études et matières (ajustables : collège, lycée, université…)
  static const _cleNiveau = 'niveau';
  static const _cleMatieres = 'matieres';
  NiveauEtudes _niveau = NiveauEtudes.college;
  String classe = '3e';
  String etablissement = 'Lycée Askia, Bamako';
  List<String>? _matieresPerso; // null = liste par défaut du niveau

  Langue get langue => _langue;
  Langue get langueAudio => _langueAudio;
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

  void basculerSuivi(String createurId) {
    if (!suivis.remove(createurId)) suivis.add(createurId);
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

  Future<void> charger() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString(_cleLangue);
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
      }
    }
    final idAudio = prefs.getString(_cleLangueAudio);
    if (idAudio != null) {
      _langueAudio = languesDisponibles.firstWhere(
        (l) => l.id == idAudio,
        orElse: () => _langueAudio,
      );
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

  /// Fixe la langue de **lecture** (quiz/fiche). Si [langue] n'est pas une
  /// langue de lecture valide (fr/en), on la redirige vers [choisirLangueAudio]
  /// pour préserver l'intention utilisateur.
  Future<void> choisirLangue(Langue langue) async {
    if (!estLangueLecture(langue)) {
      return choisirLangueAudio(langue);
    }
    _langue = langue;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cleLangue, langue.id);
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
