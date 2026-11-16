import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../Configuration/langues.dart';
import '../Configuration/matieres.dart';

/// État de session côté app (langue, progression, forfait).
/// À brancher sur l'API : les valeurs sont initialisées en local pour la démo.
class AppState extends ChangeNotifier {
  static const _cleLangue = 'langue';
  static const _cleConnecte = 'connecte';

  Langue _langue = languesDisponibles[2]; // Bamanankan par défaut (démo)
  bool _connecte = false;

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
  bool get connecte => _connecte;
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
    _connecte = false;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_cleConnecte, false);
  }

  Future<void> charger() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString(_cleLangue);
    if (id != null) {
      _langue = languesDisponibles.firstWhere(
        (l) => l.id == id,
        orElse: () => _langue,
      );
    }
    _connecte = prefs.getBool(_cleConnecte) ?? false;
    final niveau = prefs.getString(_cleNiveau);
    if (niveau != null) {
      _niveau = NiveauEtudes.values.firstWhere((n) => n.name == niveau, orElse: () => _niveau);
    }
    final matieres = prefs.getStringList(_cleMatieres);
    if (matieres != null && matieres.isNotEmpty) _matieresPerso = matieres;
    notifyListeners();
  }

  Future<void> choisirLangue(Langue langue) async {
    _langue = langue;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cleLangue, langue.id);
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
