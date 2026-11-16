/// Niveaux d'études et matières par défaut. L'utilisateur peut ajouter ou
/// retirer des matières (voir `AppState.matieres`) : la liste sert à
/// Explorer, Créer, Mes cours et aux recommandations du feed.
enum NiveauEtudes { primaire, college, lycee, superieur, formation }

extension NiveauEtudesLibelle on NiveauEtudes {
  String get libelle => switch (this) {
        NiveauEtudes.primaire => 'Primaire',
        NiveauEtudes.college => 'Collège',
        NiveauEtudes.lycee => 'Lycée',
        NiveauEtudes.superieur => 'Université / supérieur',
        NiveauEtudes.formation => 'Formation pro / concours',
      };

  String get exempleClasse => switch (this) {
        NiveauEtudes.primaire => 'CM2',
        NiveauEtudes.college => '3e',
        NiveauEtudes.lycee => 'Terminale D',
        NiveauEtudes.superieur => 'Licence 2 Droit',
        NiveauEtudes.formation => 'Concours ENA',
      };
}

const Map<NiveauEtudes, List<String>> matieresParDefaut = {
  NiveauEtudes.primaire: [
    'Français', 'Mathématiques', 'Sciences', 'Histoire', 'Géographie', 'Éducation civique', 'Anglais',
  ],
  NiveauEtudes.college: [
    'Histoire', 'Géographie', 'Maths', 'SVT', 'Physique‑chimie', 'Français', 'Anglais', 'Éducation civique',
  ],
  NiveauEtudes.lycee: [
    'Histoire', 'Géographie', 'Maths', 'SVT', 'Physique', 'Chimie', 'Français', 'Philosophie', 'Anglais', 'Économie',
  ],
  NiveauEtudes.superieur: [
    'Droit', 'Économie', 'Gestion', 'Comptabilité', 'Informatique', 'Médecine', 'Pharmacie', 'Biologie',
    'Sociologie', 'Communication', 'Génie civil', 'Agronomie',
  ],
  NiveauEtudes.formation: [
    'Culture générale', 'Droit administratif', 'Finances publiques', 'Anglais pro', 'Informatique', 'Comptabilité',
  ],
};

/// Suggestions supplémentaires proposées dans « Ajouter une matière ».
const List<String> matieresSuggerees = [
  'Arabe', 'Espagnol', 'Allemand', 'Marketing', 'Statistiques', 'Anatomie', 'Électronique', 'Mécanique',
  'Architecture', 'Psychologie', 'Sciences politiques', 'Nutrition', 'Bamanankan', 'Pular', 'Soso',
];
