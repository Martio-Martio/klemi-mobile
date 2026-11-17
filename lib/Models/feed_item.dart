/// Modèles des contenus du feed. Les données réelles viendront de l'API
/// (`GET /feed`) ; ici la forme attendue est fixée pour brancher l'UI.
enum TypeContenu { quiz, fiche, podcast }

class Auteur {
  final String pseudo;
  final String etablissement;
  final String initiales;

  const Auteur({
    required this.pseudo,
    required this.etablissement,
    required this.initiales,
  });
}

abstract class FeedItem {
  final String id;
  final TypeContenu type;
  final String titre;
  final String langue;
  final Auteur auteur;
  final String legende;
  final List<String> hashtags;
  final int likes;

  const FeedItem({
    required this.id,
    required this.type,
    required this.titre,
    required this.langue,
    required this.auteur,
    required this.legende,
    this.hashtags = const [],
    this.likes = 0,
  });
}

class QuizItem extends FeedItem {
  final String matiere;
  final int numero;
  final int total;
  final List<String> reponses;
  final int bonneReponse;
  final String explication;

  const QuizItem({
    required super.id,
    required super.titre,
    required super.langue,
    required super.auteur,
    required super.legende,
    super.hashtags,
    super.likes,
    required this.matiere,
    required this.numero,
    required this.total,
    required this.reponses,
    required this.bonneReponse,
    required this.explication,
  }) : super(type: TypeContenu.quiz);
}

class DateCle {
  final String annee;
  final String evenement;
  const DateCle(this.annee, this.evenement);
}

class EntreeLexique {
  final String mot;
  final String definition;
  final String traduction;
  const EntreeLexique(this.mot, this.definition, this.traduction);
}

class FicheItem extends FeedItem {
  final String sousTitre;
  final List<String> essentiel;
  final String leSaviezVous;
  final List<DateCle> dates;
  final List<EntreeLexique> lexique;
  final int dureeLectureMin;

  const FicheItem({
    required super.id,
    required super.titre,
    required super.langue,
    required super.auteur,
    required super.legende,
    super.hashtags,
    super.likes,
    required this.sousTitre,
    required this.essentiel,
    required this.leSaviezVous,
    required this.dates,
    required this.lexique,
    this.dureeLectureMin = 3,
  }) : super(type: TypeContenu.fiche);
}

class LigneTranscript {
  final String voix;
  final String texte;
  final int debutMs;
  const LigneTranscript(this.voix, this.texte, this.debutMs);
}

class PodcastItem extends FeedItem {
  final String nomLangue;
  final List<String> voix;
  final List<LigneTranscript> transcript;
  final int dureeSec;

  const PodcastItem({
    required super.id,
    required super.titre,
    required super.langue,
    required super.auteur,
    required super.legende,
    super.hashtags,
    super.likes,
    required this.nomLangue,
    required this.voix,
    required this.transcript,
    required this.dureeSec,
  }) : super(type: TypeContenu.podcast);
}

// ────────────────────────── Sérialisation JSON (Phase 7) ────────────────────

/// Round-trip `FeedItem` → Map pour le cache local (`SharedPreferences`).
/// Les champs doivent rester compatibles avec [feedItemDepuisJson] pour que
/// le cache serve correctement l'offline.
Map<String, dynamic> feedItemVersJson(FeedItem item) {
  final base = {
    'id': item.id,
    'titre': item.titre,
    'langue': item.langue,
    'auteur': {
      'pseudo': item.auteur.pseudo,
      'etablissement': item.auteur.etablissement,
      'initiales': item.auteur.initiales,
    },
    'legende': item.legende,
    'hashtags': item.hashtags,
    'likes': item.likes,
  };
  switch (item) {
    case QuizItem q:
      return {
        ...base,
        'type': 'quiz',
        'matiere': q.matiere,
        'numero': q.numero,
        'total': q.total,
        'reponses': q.reponses,
        'bonneReponse': q.bonneReponse,
        'explication': q.explication,
      };
    case FicheItem f:
      return {
        ...base,
        'type': 'fiche',
        'sousTitre': f.sousTitre,
        'essentiel': f.essentiel,
        'leSaviezVous': f.leSaviezVous,
        'dates': [
          for (final d in f.dates) {'annee': d.annee, 'evenement': d.evenement}
        ],
        'lexique': [
          for (final e in f.lexique)
            {'mot': e.mot, 'definition': e.definition, 'traduction': e.traduction}
        ],
        'dureeLectureMin': f.dureeLectureMin,
      };
    case PodcastItem p:
      return {
        ...base,
        'type': 'podcast',
        'nomLangue': p.nomLangue,
        'voix': p.voix,
        'transcript': [
          for (final t in p.transcript)
            {'voix': t.voix, 'texte': t.texte, 'debutMs': t.debutMs}
        ],
        'dureeSec': p.dureeSec,
      };
    default:
      throw ArgumentError('Type FeedItem non sérialisable : ${item.runtimeType}');
  }
}

// ────────────────────────── Parsing JSON (Phase 2) ──────────────────────────

/// Dispatch sur `type` et construit le sous-type approprié. Lève un
/// `FormatException` si le type est inconnu — à attraper côté repository.
FeedItem feedItemDepuisJson(Map<String, dynamic> json) {
  final type = json['type'] as String?;
  switch (type) {
    case 'quiz':
      return _quizDepuisJson(json);
    case 'fiche':
      return _ficheDepuisJson(json);
    case 'podcast':
      return _podcastDepuisJson(json);
    default:
      throw FormatException('Type de FeedItem inconnu : $type');
  }
}

Auteur _auteurDepuisJson(Map<String, dynamic> json) => Auteur(
      pseudo: json['pseudo'] as String? ?? '',
      etablissement: json['etablissement'] as String? ?? '',
      initiales: json['initiales'] as String? ?? '',
    );

List<String> _listeStrings(Object? raw) {
  if (raw is List) return raw.map((e) => e.toString()).toList();
  return const [];
}

QuizItem _quizDepuisJson(Map<String, dynamic> json) => QuizItem(
      id: json['id'] as String,
      titre: json['titre'] as String? ?? '',
      langue: json['langue'] as String? ?? 'fr',
      auteur: _auteurDepuisJson(json['auteur'] as Map<String, dynamic>? ?? const {}),
      legende: json['legende'] as String? ?? '',
      hashtags: _listeStrings(json['hashtags']),
      likes: (json['likes'] as num?)?.toInt() ?? 0,
      matiere: json['matiere'] as String? ?? '',
      numero: (json['numero'] as num?)?.toInt() ?? 1,
      total: (json['total'] as num?)?.toInt() ?? 1,
      reponses: _listeStrings(json['reponses']),
      bonneReponse: (json['bonneReponse'] as num?)?.toInt() ?? 0,
      explication: json['explication'] as String? ?? '',
    );

FicheItem _ficheDepuisJson(Map<String, dynamic> json) => FicheItem(
      id: json['id'] as String,
      titre: json['titre'] as String? ?? '',
      langue: json['langue'] as String? ?? 'fr',
      auteur: _auteurDepuisJson(json['auteur'] as Map<String, dynamic>? ?? const {}),
      legende: json['legende'] as String? ?? '',
      hashtags: _listeStrings(json['hashtags']),
      likes: (json['likes'] as num?)?.toInt() ?? 0,
      sousTitre: json['sousTitre'] as String? ?? '',
      essentiel: _listeStrings(json['essentiel']),
      leSaviezVous: json['leSaviezVous'] as String? ?? '',
      dates: ((json['dates'] as List?) ?? const [])
          .cast<Map<String, dynamic>>()
          .map((d) => DateCle(d['annee']?.toString() ?? '', d['evenement']?.toString() ?? ''))
          .toList(),
      lexique: ((json['lexique'] as List?) ?? const [])
          .cast<Map<String, dynamic>>()
          .map((l) => EntreeLexique(
                l['mot']?.toString() ?? '',
                l['definition']?.toString() ?? '',
                l['traduction']?.toString() ?? '',
              ))
          .toList(),
      dureeLectureMin: (json['dureeLectureMin'] as num?)?.toInt() ?? 3,
    );

PodcastItem _podcastDepuisJson(Map<String, dynamic> json) => PodcastItem(
      id: json['id'] as String,
      titre: json['titre'] as String? ?? '',
      langue: json['langue'] as String? ?? 'fr',
      auteur: _auteurDepuisJson(json['auteur'] as Map<String, dynamic>? ?? const {}),
      legende: json['legende'] as String? ?? '',
      hashtags: _listeStrings(json['hashtags']),
      likes: (json['likes'] as num?)?.toInt() ?? 0,
      nomLangue: json['nomLangue'] as String? ?? '',
      voix: _listeStrings(json['voix']),
      transcript: ((json['transcript'] as List?) ?? const [])
          .cast<Map<String, dynamic>>()
          .map((t) => LigneTranscript(
                t['voix']?.toString() ?? '',
                t['texte']?.toString() ?? '',
                (t['debutMs'] as num?)?.toInt() ?? 0,
              ))
          .toList(),
      dureeSec: (json['dureeSec'] as num?)?.toInt() ?? 0,
    );
