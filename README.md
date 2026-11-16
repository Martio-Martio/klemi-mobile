# Klemi Mobile (Flutter)

Application mobile native Klemi : feed vertical façon TikTok (quiz, fiches de révision, podcasts), multilingue (FR · EN · Bamanankan · Soso · Pular). Remplace l'ancien lanceur qui ouvrait le site web.

Le design de référence est le canvas « Klemi Mobile — Feed » (numéros d'écrans 1.1 → 3.4 repris dans les commentaires des pages).

## Lancer

```bash
flutter pub get
flutter run
flutter analyze
flutter test
```

## Environnements API

L'URL de base de `klemi-api` est injectée au build via `--dart-define=API_BASE_URL=…`.
Default : dev Railway.

```bash
# Dev (Railway, défaut si --dart-define absent)
flutter run

# Prod
flutter run --dart-define=API_BASE_URL=https://api.klemi.ci/api

# Backend local (npm run start:dev côté klemi-api)
flutter run --dart-define=API_BASE_URL=http://localhost:7501/api

# Mode mock (ignore l'API, utilise mock_feed.dart / mock_social.dart)
flutter run --dart-define=USE_MOCK=true
```

## Structure

```
lib/
  main.dart                      # MaterialApp + Provider + thème
  splash_screen.dart             # démarrage → Connexion ou AppShell
  Configuration/
    app_theme.dart               # charte (beige, navy, bleu/orange/vert/rouge Klemi)
    langues.dart                 # langues de contenu disponibles
  Models/feed_item.dart          # QuizItem, FicheItem, PodcastItem
  Data/mock_feed.dart            # contenus de démo (à remplacer par GET /feed)
  Providers/app_state.dart       # langue, session, points, forfait
  Widgets/
    klemi_widgets.dart           # boutons, champs, segments, avatar, chips…
    barre_navigation.dart        # Feed · Explorer · Créer · Biblio · Profil
    carte_feed.dart              # gabarit d'une carte du feed (rail, légende, swipe)
    ligne_contenu.dart           # ligne compacte d'un contenu + bouton Suivre
  Models/social.dart             # Createur, ContenuResume, Cours, Commentaire, Notification
  Data/mock_social.dart          # créateurs, cours, nouveautés, tendances…
  Pages/
    app_shell.dart               # coque à onglets (ouvre un contenu dans le feed depuis Explorer)
    Auth/     inscription · connexion · code WhatsApp · langue
    Feed/     feed_page (Pour toi · Mes cours · Abonnements) · carte_quiz · resultat · carte_fiche · carte_podcast
    Explorer/ explorer_page (recherche, matières, enseignants, tendances)
    Creer/    creer_page
    Profil/   profil (+ biblio) · forfaits · paiement · parametres
    Social/   profil_createur · commentaires_sheet · notifications
```

## À brancher sur l'API

- OTP par WhatsApp / SMS (`/auth/register`, `/auth/verify-otp`)
- `GET /feed` paginé par curseur (quiz, fiches, podcasts mélangés, filtre langue)
- Réponse hors session, points / streak / niveau
- Lecteur audio réel pour les podcasts (`audioUrl` + `transcript[].startMs`)
- Paiement mobile money via la passerelle existante
