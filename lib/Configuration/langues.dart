/// Langues de contenu proposées par Klemi.
class Langue {
  final String code; // code court affiché (FR, EN, BM, SO, FF)
  final String id; // identifiant API (fr, en, bm, sus, ful)
  final String nom;
  final String description;
  final String cta; // libellé du bouton « Commencer » dans la langue

  const Langue({
    required this.code,
    required this.id,
    required this.nom,
    required this.description,
    required this.cta,
  });
}

const List<Langue> languesDisponibles = [
  Langue(
    code: 'FR',
    id: 'fr',
    nom: 'Français',
    description: 'Interface et contenus en français',
    cta: 'Commencer',
  ),
  Langue(
    code: 'EN',
    id: 'en',
    nom: 'English',
    description: 'Interface and content in English',
    cta: 'Get started',
  ),
  Langue(
    code: 'BM',
    id: 'bm',
    nom: 'Bamanankan',
    description: 'Mali · kalan bamanankan na',
    cta: 'A daminɛ',
  ),
  Langue(
    code: 'SO',
    id: 'sus',
    nom: 'Soso',
    description: 'Guinée · Sosoxui',
    cta: 'A fɔlɔ',
  ),
  Langue(
    code: 'FF',
    id: 'ful',
    nom: 'Pular',
    description: 'Guinée · ɗemngal Fulɓe',
    cta: 'Fuɗɗo',
  ),
];

const List<String> languesBientot = ['Wolof', 'Hausa', 'Dioula'];

/// Langues dans lesquelles le backend sait **générer du texte** (quiz, fiches,
/// flashcards, cartes mentales). Les langues locales (bm/sus/ful) sont
/// réservées à l'audio parce qu'elles sont rarement lues couramment par les
/// scolarisés francophones — produire du texte dedans serait un mur de
/// lecture.
const List<String> _idsLangueLecture = ['fr', 'en'];

List<Langue> get languesLecture =>
    languesDisponibles.where((l) => _idsLangueLecture.contains(l.id)).toList();

bool estLangueLecture(Langue l) => _idsLangueLecture.contains(l.id);

/// Toutes les langues sont acceptées pour les podcasts (générés via TTS +
/// transcript affiché avec `fontFamilyFallback: AppTheme.famillesSecours`).
List<Langue> get languesAudio => languesDisponibles;

/// Défauts de session utilisés quand aucune préférence n'a été persistée.
Langue get langueLectureParDefaut =>
    languesDisponibles.firstWhere((l) => l.id == 'fr');
Langue get langueAudioParDefaut =>
    languesDisponibles.firstWhere((l) => l.id == 'bm');
