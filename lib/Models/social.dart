import 'feed_item.dart';

/// Créateur / enseignant que l'on peut suivre.
class Createur {
  final String id;
  final String pseudo;
  final String nom;
  final String etablissement;
  final String initiales;
  final int abonnes;
  final int contenus;
  final String bio;

  const Createur({
    required this.id,
    required this.pseudo,
    required this.nom,
    required this.etablissement,
    required this.initiales,
    required this.abonnes,
    required this.contenus,
    required this.bio,
  });
}

/// Contenu résumé (liste compacte) : utilisé dans Mes cours, Abonnements,
/// Explorer, profil créateur, notifications.
class ContenuResume {
  final String id;
  final TypeContenu type;
  final String titre;
  final String meta; // « Quiz · 10 questions · FR »
  final String createurId;
  final DateTime publieLe;
  final bool fait;
  final bool horsLigne;

  const ContenuResume({
    required this.id,
    required this.type,
    required this.titre,
    required this.meta,
    required this.createurId,
    required this.publieLe,
    this.fait = false,
    this.horsLigne = false,
  });
}

/// Chapitre d'un cours (onglet « Mes cours »).
class Chapitre {
  final String titre;
  final List<ContenuResume> contenus;
  const Chapitre(this.titre, this.contenus);
}

/// Classe ou groupe auquel l'élève est rattaché.
class Cours {
  final String id;
  final String matiere;
  final String classe;
  final String enseignantId;
  final List<Chapitre> chapitres;

  const Cours({
    required this.id,
    required this.matiere,
    required this.classe,
    required this.enseignantId,
    required this.chapitres,
  });

  int get total => chapitres.fold(0, (n, c) => n + c.contenus.length);
  int get faits => chapitres.fold(0, (n, c) => n + c.contenus.where((x) => x.fait).length);
}

class Commentaire {
  final String id;
  final String auteur;
  final String initiales;
  final String texte;
  final String ilYA;
  final int likes;
  final bool enseignant;
  const Commentaire({
    this.id = '',
    required this.auteur,
    required this.initiales,
    required this.texte,
    required this.ilYA,
    this.likes = 0,
    this.enseignant = false,
  });

  factory Commentaire.depuisJson(Map<String, dynamic> json) => Commentaire(
        id: json['id'] as String? ?? '',
        auteur: json['auteur'] as String? ?? '',
        initiales: json['initiales'] as String? ?? '',
        texte: json['texte'] as String? ?? '',
        ilYA: json['ilYA'] as String? ?? '',
        likes: (json['likes'] as num?)?.toInt() ?? 0,
        enseignant: json['enseignant'] as bool? ?? false,
      );
}

enum TypeNotification { streak, nouveauContenu, resultat, commentaire, forfait }

TypeNotification _typeNotifDepuisString(String raw) {
  switch (raw) {
    case 'streak':
    case 'STREAK':
    case 'STREAK_REMINDER':
      return TypeNotification.streak;
    case 'nouveauContenu':
    case 'NEW_CONTENT_FROM_FOLLOWED_CREATOR':
      return TypeNotification.nouveauContenu;
    case 'resultat':
    case 'RESULTAT':
      return TypeNotification.resultat;
    case 'commentaire':
    case 'COMMENT_ON_CONTENT':
      return TypeNotification.commentaire;
    case 'forfait':
    case 'SUBSCRIPTION_EXPIRATION':
      return TypeNotification.forfait;
    default:
      return TypeNotification.nouveauContenu;
  }
}

class NotificationApp {
  final String id;
  final TypeNotification type;
  final String titre;
  final String detail;
  final String ilYA;
  final bool lue;
  const NotificationApp({
    this.id = '',
    required this.type,
    required this.titre,
    required this.detail,
    required this.ilYA,
    this.lue = false,
  });

  factory NotificationApp.depuisJson(Map<String, dynamic> json) => NotificationApp(
        id: json['id'] as String? ?? '',
        type: _typeNotifDepuisString(json['type'] as String? ?? 'nouveauContenu'),
        titre: json['titre'] as String? ?? '',
        detail: json['detail'] as String? ?? '',
        ilYA: json['ilYA'] as String? ?? '',
        lue: json['lue'] as bool? ?? json['isRead'] as bool? ?? false,
      );

  NotificationApp copier({bool? lue}) => NotificationApp(
        id: id,
        type: type,
        titre: titre,
        detail: detail,
        ilYA: ilYA,
        lue: lue ?? this.lue,
      );
}

// ─── Parsing factories (Phase 5) ────────────────────────────────────────

extension CreateurJson on Createur {
  static Createur depuisJson(Map<String, dynamic> json) => Createur(
        id: json['id'] as String? ?? '',
        pseudo: json['pseudo'] as String? ?? '',
        nom: json['nom'] as String? ?? '',
        etablissement: json['etablissement'] as String? ?? '',
        initiales: json['initiales'] as String? ?? '',
        abonnes: (json['abonnes'] as num?)?.toInt() ?? 0,
        contenus: (json['contenus'] as num?)?.toInt() ?? 0,
        bio: json['bio'] as String? ?? '',
      );
}

extension ContenuResumeJson on ContenuResume {
  static ContenuResume depuisJson(Map<String, dynamic> json) {
    final typeRaw = json['type'] as String? ?? 'quiz';
    final type = switch (typeRaw) {
      'fiche' => TypeContenu.fiche,
      'podcast' => TypeContenu.podcast,
      _ => TypeContenu.quiz,
    };
    DateTime parseDate(Object? raw) {
      if (raw is String) {
        return DateTime.tryParse(raw) ?? DateTime.now();
      }
      return DateTime.now();
    }

    return ContenuResume(
      id: json['id'] as String? ?? '',
      type: type,
      titre: json['titre'] as String? ?? '',
      meta: json['meta'] as String? ?? '',
      createurId: json['createurId'] as String? ?? '',
      publieLe: parseDate(json['publieLe']),
      fait: json['fait'] as bool? ?? false,
      horsLigne: json['horsLigne'] as bool? ?? false,
    );
  }
}
