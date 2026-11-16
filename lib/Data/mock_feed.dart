import '../Models/feed_item.dart';

/// Contenus de démonstration, en attendant `GET /feed` de l'API.
/// Le feed boucle dessus pour simuler le scroll infini.
const Auteur _profKone = Auteur(
  pseudo: '@prof_kone',
  etablissement: 'Lycée Askia, Bamako',
  initiales: 'AK',
);

const Auteur _klemiIa = Auteur(
  pseudo: 'Klemi IA',
  etablissement: 'générée depuis ton cours',
  initiales: 'K',
);

const List<FeedItem> feedDemo = [
  QuizItem(
    id: 'q1',
    titre:
        "En quelle année l'empire du Mali atteint‑il son apogée sous Kankou Moussa ?",
    langue: 'fr',
    auteur: _profKone,
    legende:
        'Révision brevet · Les grands empires du Sahel. Série de 10 questions générées depuis mon cours PDF.',
    hashtags: ['#histoire', '#brevet', '#mali'],
    likes: 2400,
    matiere: 'Histoire · 3e',
    numero: 3,
    total: 10,
    reponses: ['1235', '1325', '1455', '1591'],
    bonneReponse: 1,
    explication:
        'Vers 1325, au retour de son pèlerinage à La Mecque, Kankou Moussa fait de Tombouctou un centre intellectuel majeur.',
  ),
  FicheItem(
    id: 'f1',
    titre: 'Kankou Moussa et Tombouctou',
    langue: 'fr',
    auteur: _klemiIa,
    legende: 'Lecture 3 min · disponible hors ligne · aussi en Bamanankan et English.',
    likes: 961,
    sousTitre: 'Recommandée après ton quiz',
    essentiel: [
      "Mansa de l'empire du Mali de 1312 à 1337, Kankou Moussa règne sur un territoire allant du Sénégal au Niger.",
      "Pèlerinage de 1324‑1325 : son passage au Caire, chargé d'or, fait chuter le cours du métal pendant des années.",
      'Tombouctou devient un centre du savoir : mosquée Djingareyber, université de Sankoré, manuscrits.',
    ],
    leSaviezVous:
        "L'architecte andalou Abu Ishaq al‑Sahili l'accompagne au retour et construit à Tombouctou.",
    dates: [
      DateCle('1312', 'Début du règne'),
      DateCle('1324', 'Départ pour La Mecque'),
      DateCle('1325', "Retour, apogée de l'empire"),
      DateCle('1337', 'Mort de Kankou Moussa'),
      DateCle('1375', "Atlas catalan : il y est dessiné avec une pépite d'or"),
    ],
    lexique: [
      EntreeLexique('Mansa', "Titre du souverain de l'empire du Mali", 'mansa'),
      EntreeLexique('Hajj', 'Pèlerinage à La Mecque', 'hiji'),
      EntreeLexique('Manuscrit', 'Texte copié à la main, souvent en arabe', 'sɛbɛn'),
      EntreeLexique('Or', "Richesse de l'empire", 'sanu'),
    ],
  ),
  PodcastItem(
    id: 'p1',
    titre: 'Mali mansaya : Kankou Musa ni Tumutu',
    langue: 'bm',
    auteur: _profKone,
    legende: 'Kalan 12 min · kumakan fila · Bamanankan. Aussi en français et en anglais.',
    likes: 1100,
    nomLangue: 'Bamanankan',
    voix: ['Fanta', 'Musa'],
    dureeSec: 760,
    transcript: [
      LigneTranscript('Fanta', 'I ni sɔgɔma, Musa ! Bi an bɛna kuma Kankou Musa kan.', 0),
      LigneTranscript('Musa', 'Awɔ ! Ale tun ye Mali mansa ye san 1312 fo san 1337.', 9000),
      LigneTranscript('Fanta', 'A taara Makan san 1324, ni sanu caman ye…', 19000),
    ],
  ),
  QuizItem(
    id: 'q2',
    titre: 'Quel fleuve traverse Bamako ?',
    langue: 'fr',
    auteur: _profKone,
    legende: 'Géographie du Mali · série de 10 questions.',
    hashtags: ['#geographie', '#mali'],
    likes: 870,
    matiere: 'Géographie · 6e',
    numero: 1,
    total: 10,
    reponses: ['Le Sénégal', 'Le Niger', 'La Volta', 'Le Bani'],
    bonneReponse: 1,
    explication:
        'Le fleuve Niger traverse Bamako avant de poursuivre vers Ségou, Mopti et Tombouctou.',
  ),
];
