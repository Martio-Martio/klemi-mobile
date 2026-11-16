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
