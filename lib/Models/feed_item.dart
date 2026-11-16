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
