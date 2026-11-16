import '../Models/feed_item.dart';
import '../Models/social.dart';

/// Données de démonstration pour Mes cours, Abonnements, Explorer, etc.
const createurs = [
  Createur(
    id: 'kone',
    pseudo: '@prof_kone',
    nom: 'Amadou Koné',
    etablissement: 'Lycée Askia, Bamako',
    initiales: 'AK',
    abonnes: 1280,
    contenus: 42,
    bio: "Professeur d'histoire‑géographie. Je publie une série de quiz par chapitre, en français et en bamanankan.",
  ),
  Createur(
    id: 'diallo',
    pseudo: '@mme_diallo',
    nom: 'Fatoumata Diallo',
    etablissement: 'Collège Moderne, Conakry',
    initiales: 'FD',
    abonnes: 860,
    contenus: 27,
    bio: 'Maths 3e · fiches courtes + podcasts en pular.',
  ),
  Createur(
    id: 'klemi',
    pseudo: '@klemi',
    nom: 'Klemi',
    etablissement: 'Équipe Klemi',
    initiales: 'K',
    abonnes: 15400,
    contenus: 310,
    bio: 'Sélections officielles brevet et bac, dans toutes les langues de Klemi.',
  ),
  Createur(
    id: 'traore',
    pseudo: '@svt_traore',
    nom: 'Boubacar Traoré',
    etablissement: 'Lycée Technique, Ségou',
    initiales: 'BT',
    abonnes: 410,
    contenus: 18,
    bio: 'SVT · schémas expliqués en vidéo et fiches.',
  ),
];

Createur createurParId(String id) => createurs.firstWhere((c) => c.id == id);

final _maintenant = DateTime(2026, 11, 16, 9);

final List<Cours> mesCours = [
  Cours(
    id: 'hist3',
    matiere: 'Histoire‑géographie',
    classe: '3e A · Lycée Askia',
    enseignantId: 'kone',
    chapitres: [
      Chapitre('Chap. 4 · Les grands empires du Sahel', [
        ContenuResume(
          id: 'c1', type: TypeContenu.fiche, titre: "L'empire du Ghana",
          meta: 'Fiche · 3 min · FR · BM', createurId: 'kone',
          publieLe: _maintenant.subtract(const Duration(days: 9)), fait: true, horsLigne: true),
        ContenuResume(
          id: 'c2', type: TypeContenu.quiz, titre: "L'empire du Ghana — 8 questions",
          meta: 'Quiz · 8 questions · 7/8', createurId: 'kone',
          publieLe: _maintenant.subtract(const Duration(days: 8)), fait: true),
        ContenuResume(
          id: 'c3', type: TypeContenu.fiche, titre: 'Kankou Moussa et Tombouctou',
          meta: 'Fiche · 3 min · FR · BM', createurId: 'kone',
          publieLe: _maintenant.subtract(const Duration(days: 2)), fait: true, horsLigne: true),
        ContenuResume(
          id: 'c4', type: TypeContenu.quiz, titre: 'Les grands empires du Sahel',
          meta: 'Quiz · 10 questions · en cours 3/10', createurId: 'kone',
          publieLe: _maintenant.subtract(const Duration(days: 1))),
        ContenuResume(
          id: 'c5', type: TypeContenu.podcast, titre: 'Mali mansaya : Kankou Musa ni Tumutu',
          meta: 'Podcast · 12 min · BM', createurId: 'kone',
          publieLe: _maintenant.subtract(const Duration(hours: 5))),
      ]),
      Chapitre("Chap. 5 · L'empire songhaï", [
        ContenuResume(
          id: 'c6', type: TypeContenu.fiche, titre: 'Sonni Ali Ber et Askia Mohammed',
          meta: 'Fiche · 4 min · FR', createurId: 'kone',
          publieLe: _maintenant.add(const Duration(days: 2))),
      ]),
    ],
  ),
  Cours(
    id: 'math3',
    matiere: 'Mathématiques',
    classe: '3e A · Lycée Askia',
    enseignantId: 'diallo',
    chapitres: [
      Chapitre('Chap. 3 · Théorème de Thalès', [
        ContenuResume(
          id: 'm1', type: TypeContenu.fiche, titre: 'Thalès : énoncé et réciproque',
          meta: 'Fiche · 2 min · FR', createurId: 'diallo',
          publieLe: _maintenant.subtract(const Duration(days: 4)), fait: true),
        ContenuResume(
          id: 'm2', type: TypeContenu.quiz, titre: 'Thalès — 10 questions',
          meta: 'Quiz · 10 questions', createurId: 'diallo',
          publieLe: _maintenant.subtract(const Duration(days: 3))),
      ]),
    ],
  ),
];

final List<ContenuResume> nouveautesAbonnements = [
  ContenuResume(
    id: 'a1', type: TypeContenu.podcast, titre: 'Mali mansaya : Kankou Musa ni Tumutu',
    meta: 'Podcast · 12 min · BM', createurId: 'kone',
    publieLe: _maintenant.subtract(const Duration(hours: 5))),
  ContenuResume(
    id: 'a2', type: TypeContenu.quiz, titre: 'Brevet blanc · 20 questions de révision',
    meta: 'Quiz · 20 questions · FR', createurId: 'klemi',
    publieLe: _maintenant.subtract(const Duration(hours: 20))),
  ContenuResume(
    id: 'a3', type: TypeContenu.fiche, titre: 'Thalès : énoncé et réciproque (pular)',
    meta: 'Fiche · 2 min · FF', createurId: 'diallo',
    publieLe: _maintenant.subtract(const Duration(days: 1, hours: 3))),
  ContenuResume(
    id: 'a4', type: TypeContenu.quiz, titre: 'Les grands empires du Sahel',
    meta: 'Quiz · 10 questions · FR', createurId: 'kone',
    publieLe: _maintenant.subtract(const Duration(days: 1, hours: 8))),
];

final List<ContenuResume> tendances = [
  ...nouveautesAbonnements,
  ContenuResume(
    id: 't1', type: TypeContenu.fiche, titre: 'La photosynthèse en 5 points',
    meta: 'Fiche · 3 min · FR', createurId: 'traore',
    publieLe: _maintenant.subtract(const Duration(days: 2))),
  ContenuResume(
    id: 't2', type: TypeContenu.podcast, titre: 'Pourquoi le ciel est bleu ?',
    meta: 'Podcast · 6 min · FR', createurId: 'klemi',
    publieLe: _maintenant.subtract(const Duration(days: 3))),
];


const commentairesDemo = [
  Commentaire(
    auteur: '@prof_kone', initiales: 'AK', enseignant: true,
    texte: "Indice : pensez au retour du pèlerinage, pas au départ.", ilYA: '2 h', likes: 41),
  Commentaire(
    auteur: '@moussa_k', initiales: 'MK',
    texte: "J'ai mis 1324 à cause de la fiche, c'est piégeux !", ilYA: '1 h', likes: 12),
  Commentaire(
    auteur: '@awa_s', initiales: 'AS',
    texte: 'Merci pour la version en bamanankan, ma grand‑mère écoute avec moi.', ilYA: '40 min', likes: 27),
];

const notificationsDemo = [
  NotificationApp(
    type: TypeNotification.streak,
    titre: 'Ta série est à 5 jours',
    detail: "Joue une question aujourd'hui pour la garder.",
    ilYA: '1 h'),
  NotificationApp(
    type: TypeNotification.nouveauContenu,
    titre: '@prof_kone a publié un podcast',
    detail: 'Mali mansaya : Kankou Musa ni Tumutu · en bamanankan',
    ilYA: '5 h'),
  NotificationApp(
    type: TypeNotification.commentaire,
    titre: '@prof_kone a répondu à ton commentaire',
    detail: '« Indice : pensez au retour du pèlerinage… »',
    ilYA: 'hier', lue: true),
  NotificationApp(
    type: TypeNotification.resultat,
    titre: 'Résultat : 8/10 aux grands empires du Sahel',
    detail: 'Tu fais mieux que 72 % de ta classe.',
    ilYA: 'hier', lue: true),
  NotificationApp(
    type: TypeNotification.forfait,
    titre: 'Plus que 2 générations IA ce mois‑ci',
    detail: 'Passe à Student pour 40 quiz et 40 fiches par mois.',
    ilYA: 'il y a 3 j', lue: true),
];
