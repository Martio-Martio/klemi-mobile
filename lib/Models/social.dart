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
  final String auteur;
  final String initiales;
  final String texte;
  final String ilYA;
  final int likes;
  final bool enseignant;
  const Commentaire({
    required this.auteur,
    required this.initiales,
    required this.texte,
    required this.ilYA,
    this.likes = 0,
    this.enseignant = false,
  });
}

enum TypeNotification { streak, nouveauContenu, resultat, commentaire, forfait }

class NotificationApp {
  final TypeNotification type;
  final String titre;
  final String detail;
  final String ilYA;
  final bool lue;
  const NotificationApp({
    required this.type,
    required this.titre,
    required this.detail,
    required this.ilYA,
    this.lue = false,
  });
}
