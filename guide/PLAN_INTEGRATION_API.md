# Plan d'intégration mobile — Branchement de `klemi-mobile` sur `klemi-api`

> **Comment utiliser ce fichier** : cochez chaque case `- [ ]` au fur et à mesure (`- [x]`) et notez le hash du commit entre parenthèses.
> Ce fichier ne liste **que les tâches qui vivent dans `klemi-mobile`**. Le plan compagnon côté backend est dans `klemi-api/guide/PLAN_INTEGRATION_MOBILE.md`.
>
> Dernière mise à jour : 2026-11-16 — version initiale.

---

## Contexte

`klemi-mobile` est aujourd'hui une app Flutter entièrement **mockée** (`lib/Data/mock_feed.dart`, `lib/Data/mock_social.dart`) ; `lib/Configuration/api_url.dart` est vide, toute interaction utilisateur reste locale.

En face, `klemi-api` est un backend NestJS mature en production (~200 endpoints), qu'il ne faut **surtout pas régresser**. Le branchement se fait via de **nouveaux endpoints** `/api/mobile-auth/*`, `/api/mobile/feed/*`, `/api/mobile/me/*`, etc., ajoutés spécifiquement pour le mobile sans toucher aux endpoints web existants.

**Décisions clés** :
1. Auth = **phone + WhatsApp OTP** (nouveau flow côté API, à côté de l'email existant).
2. Social (follow, like, comment, notifs push) = nouveaux modules API.
3. Feed = nouveaux endpoints d'agrégation qui aplatissent Quiz/Fiche/Podcast vers `FeedItem`.
4. Base URL **configurable** via `--dart-define=API_BASE_URL=…` (dev / UAT / prod).

**Dépendance** : les tâches mobiles d'une phase supposent que les endpoints correspondants côté API sont livrés. Avant de démarrer une phase, vérifier son état dans `klemi-api/guide/PLAN_INTEGRATION_MOBILE.md`.

---

## ⚠️ Exigence transversale — Langue de génération ET de filtrage

**Règle absolue** : la langue courante de l'utilisateur (`AppState.langue.id` — `fr`, `en`, `bm`, `sus`, `ful`) gouverne **à la fois** :
- la **langue de génération** : tout contenu créé via la page `Creer` (quiz, fiche, podcast) doit être produit **directement dans cette langue** par l'IA — pas en français traduit ensuite.
- la **langue de filtrage** du feed : on ne doit afficher que des contenus dans la langue courante.
- l'en-tête `x-language` injecté automatiquement par `ApiClient` sur **toutes** les requêtes (Phase 0).

**Cas concret** : si l'utilisateur a sélectionné **bamanankan** (`bm`), un upload de PDF français doit produire un quiz **en bamanankan** côté backend, avec les caractères `ɛ ɔ ɓ ɗ ŋ` correctement rendus (donc `fontFamilyFallback: AppTheme.famillesSecours` **obligatoire** sur tous les widgets `Text` qui afficheront ce contenu — Lato seul produit des carrés).

**Implications UX** :
- La page `Creer` (Phase 3) doit **avertir visuellement** l'utilisateur de la langue dans laquelle sera généré le contenu. Un bandeau fixe en haut : _« Ce contenu sera généré en bamanankan — tu peux changer la langue dans Paramètres. »_ avec un raccourci.
- Changer la langue dans `Paramètres` (Phase 4) doit déclencher une petite alerte : _« Les nouveaux contenus générés le seront en <langue>. Les contenus existants restent inchangés. »_
- Au démarrage de l'app, si l'utilisateur n'a jamais choisi de langue, forcer `LanguePage` avant `AppShell` (comportement actuel du splash à préserver).
- Dans le feed, afficher un empty-state différencié quand il n'y a pas encore de contenu dans la langue courante : _« Pas encore de contenu en <langue>. Sois le premier à en créer ! »_ avec CTA vers `CreerPage`.

**Où ça impacte dans ce plan** : Phase 0 (header), Phase 2 (filtrage feed + empty-state), Phase 3 (bandeau + envoi du champ `language` à chaque génération), Phase 4 (paramètres + alerte au changement), Phase 5 (langue des commentaires), Phase 7 (fallback fonts stricte sur tout le contenu généré).

---

## Conventions mobile à respecter

- Noms **français** pour domaine/UI (`KlemiXxx`, `carte_*.dart`, `*_page.dart`, `matieres`, `forfait`, `suivis`) — voir `CLAUDE.md`.
- `lib/` : dossiers PascalCase, fichiers snake_case.
- Charte : `AppTheme.bleu` / `AppTheme.navy` / `AppTheme.radiusCarte`, jamais de hex en dur.
- Toute string potentiellement affichée en `bm/sus/ful` doit porter `fontFamilyFallback: AppTheme.famillesSecours` (Lato ne couvre pas `ɛ ɔ ɓ ɗ ŋ`).
- Avant chaque merge : `flutter analyze` + `flutter test` 100 % verts.

---

## Phase 0 — Fondations transverses mobile (bloquant)

> Permettre à toute page du mobile d'appeler l'API avec la bonne base URL, le bon token, les bons headers.

### Dépendances & configuration
- [ ] Ajouter à `pubspec.yaml` : `uuid: ^4.x`, `flutter_secure_storage: ^9.x`. Lancer `flutter pub get`.
- [ ] Remplir `lib/Configuration/api_url.dart` : `class ApiUrl { static const baseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'https://api2-dev.klemi.ci/api'); }`.
- [ ] Documenter dans `README.md` : `flutter run --dart-define=API_BASE_URL=https://api.klemi.ci/api` pour cibler prod.

### Code transverse
- [ ] Créer `lib/Configuration/api_client.dart` : wrapper `http` qui injecte automatiquement `Authorization: Bearer <token>`, `x-device-id`, `x-device-name`, `x-platform: ios|android`, `x-language: <langue.id>` (lue depuis `AppState.langue.id`). Un seul point d'entrée pour toutes les requêtes.
- [ ] **Test unitaire du client** : vérifier que `x-language` est bien injecté sur une requête quelle que soit la langue courante (`fr`, `en`, `bm`, `sus`, `ful`). Cette protection évite qu'une refacto future casse silencieusement le filtrage et la génération multilingues.
- [ ] Créer `lib/Services/auth_storage.dart` : stockage sécurisé `accessToken` + `refreshToken` via `flutter_secure_storage`. `SharedPreferences` ne sert **que** pour langue / niveau / matières / connecte — jamais pour les tokens.
- [ ] Créer `lib/Services/api_exception.dart` : `class ApiException implements Exception { int statusCode; String code; String message; }` pour parser `{ statusCode, message, error }` NestJS.
- [ ] `lib/Providers/app_state.dart` : ajouter `String? _accessToken`, méthode `definirSession(...)`, appel à `AuthStorage.store` dans `marquerConnecte(true)`, nettoyage dans `deconnecter()`.
- [ ] Générer un `deviceId` UUID v4 persistant au premier lancement (clé `deviceId` dans `SharedPreferences`).

### Côté API
_Rien — CORS, JWT guard et headers déjà prêts. Voir `klemi-api/guide/PLAN_INTEGRATION_MOBILE.md` Phase 0._

### Vérification Phase 0
- [ ] `flutter analyze` : 0 warning.
- [ ] `flutter test` : les 3 tests widgets existants passent toujours.
- [ ] Bouton debug « Ping API » affiche la réponse de `GET /api/health`.

---

## Phase 1 — Auth mobile (phone + WhatsApp OTP)

> Suppose que `POST /api/mobile-auth/{signup,login,verify-otp,resend-otp,refresh,logout}` est livré côté API.

### Service
- [ ] Créer `lib/Services/mobile_auth_api.dart` avec 6 méthodes : `signup`, `login`, `verifyOtp`, `resendOtp`, `refresh`, `logout`. Toutes basées sur `ApiClient`.

### Pages Auth
- [ ] `lib/Pages/Auth/inscription_page.dart` : au submit → `signup(phone, role, nom, niveauEtudes, classe, etablissement, langue)` → navigue vers `code_page.dart(tempToken)`.
- [ ] `lib/Pages/Auth/connexion_page.dart` : au submit → `login(phone)` → `code_page.dart(tempToken)`.
- [ ] `lib/Pages/Auth/code_page.dart` : au submit → `verifyOtp(tempToken, code)` → store tokens → `AppState.marquerConnecte(true)` → remplace la stack par `AppShell`.
- [ ] Gérer erreur **404 `USER_NOT_FOUND`** dans `connexion_page.dart` : afficher snackbar + CTA « s'inscrire ».
- [ ] Gérer expiration OTP : bouton « Renvoyer le code » appelle `resendOtp(tempToken)`.
- [ ] `AppState.deconnecter()` : appelle aussi `MobileAuthApi.logout()` avant de nettoyer.

### Refresh token
- [ ] `ApiClient` : interceptor 401 → tente `refresh()` une fois, rejoue la requête initiale. Si refresh échoue → `AppState.deconnecter()` + route vers `ConnexionPage`.

### Tests
- [ ] Mettre à jour `test/widget_test.dart` pour injecter un `MobileAuthApi` mocké (ne pas casser les 3 tests existants).
- [ ] Nouveau test widget : flow signup → code → AppShell.

### Côté API
_Voir `klemi-api/guide/PLAN_INTEGRATION_MOBILE.md` Phase 1._

### Vérification Phase 1
- [ ] `flutter run` avec API dev : inscription réelle, réception OTP WhatsApp sur numéro de test.
- [ ] Après kill de l'app, session restaurée automatiquement au relancement.
- [ ] Après 401 forcé (token expiré manuellement) → auto-refresh transparent OU redirection connexion si refresh invalide.

---

## Phase 2 — Feed mobile (vraies données)

> Suppose que `GET /api/mobile/feed`, `GET /api/mobile/feed/:id`, `POST /api/mobile/feed/:id/answer` (et placeholders like/save) sont livrés côté API.

### Service & repository
- [ ] Créer `lib/Services/mobile_feed_api.dart` : `fetchFeed({cursor, tab})`, `fetchOne(id)`, `likeItem(id)` / `unlikeItem(id)`, `answerQuiz(id, index)`, `saveItem(id)`.
- [ ] Créer `lib/Repositories/feed_repository.dart` : cache en mémoire des pages chargées par tab (`pourToi`, `mesCours`, `abonnements`) + pull-to-refresh.

### Pages Feed
- [ ] `lib/Pages/Feed/feed_page.dart` : remplacer `feedDemo` par `FeedRepository.instance.pouToi()`. Ajouter états `chargement / erreur / vide`, pull-to-refresh, scroll infini (déclencheur à 3 items de la fin).
- [ ] **Empty-state langue** : quand la liste est vide pour la langue courante, afficher _« Pas encore de contenu en {langue.nom}. Sois le premier à en créer ! »_ avec un CTA vers `CreerPage`. Distinct de l'état « pas de réseau » et de « pas d'abonnements ».
- [ ] Rafraîchir automatiquement le feed quand `AppState.langue` change (écouter le provider).
- [ ] `lib/Pages/Feed/mes_cours_page.dart` : même pattern avec `tab=mes-cours`.
- [ ] `lib/Pages/Feed/abonnements_page.dart` : même pattern avec `tab=abonnements`.
- [ ] `lib/Pages/Feed/carte_quiz.dart` : au choix réponse → `answerQuiz(id, index)` → afficher `explication` + animation points. Fallback optimiste si offline : garder l'affichage local de la bonne/mauvaise réponse.
- [ ] `lib/Pages/Feed/resultat_page.dart` : brancher le `percentile` renvoyé par l'API à la fin d'une série.
- [ ] Deep-link depuis Explorer (`AppShell._ouvrirDansFeed`) : utiliser `fetchOne(id)` pour injecter un item avant le reste de la page.

### Fallback mock
- [ ] **Garder** `lib/Data/mock_feed.dart` et activer via `--dart-define=USE_MOCK=true` dans `FeedRepository` — utile pour dev offline et pour les tests widgets.

### Tests
- [ ] Mettre à jour `test/widget_test.dart` ("Le feed affiche une carte quiz jouable") pour mocker `FeedRepository`.
- [ ] Nouveaux tests : pagination scroll infini, pull-to-refresh, erreur 500 affiche état erreur.

### Côté API
_Voir `klemi-api/guide/PLAN_INTEGRATION_MOBILE.md` Phase 2._

### Vérification Phase 2
- [ ] Scroll fluide du feed, les 3 types de cartes (quiz / fiche / podcast) s'affichent avec vraies données.
- [ ] `flutter run --dart-define=API_BASE_URL=https://api2-dev.klemi.ci/api` : 20 items chargés, scroll déclenche page 2.
- [ ] Mode mock (`--dart-define=USE_MOCK=true`) : app toujours fonctionnelle hors ligne.

---

## Phase 3 — Création IA mobile (`Creer` page) — **langue critique**

> Réutilise les endpoints existants `/files/upload`, `/files/youtube-qcm`, `/fiches-de-revision`, `/podcasts`. L'endpoint quota `GET /api/mobile/me/generation-quota` est fourni côté API.
>
> **Point critique** : chaque appel de génération **doit** envoyer le champ `language` = `AppState.langue.id`. Sans ça, le backend génère en français par défaut — bug silencieux côté UX.

### Service
- [ ] Créer `lib/Services/creation_api.dart` : `genererQuiz(source, options)`, `genererFiche(source, options)`, `genererPodcast(source, options)`. Gère upload multipart (PDF/DOCX/image) via `http`.
- [ ] **Chaque méthode injecte systématiquement `language: AppState.langue.id` dans le body/form** — ne jamais laisser ce champ optionnel côté client, même si l'API le tolère.
- [ ] Polling via `GET /files/upload-status/:jobId` ou abonnement SSE `/api/notifications/stream` (préférer SSE si disponible).

### Pages Creer — avertissement utilisateur
- [ ] **Bandeau d'information fixe en haut de `CreerPage`** : _« Ce {type} sera généré en {AppState.langue.nom}. »_ avec un lien discret _« changer »_ qui ouvre `LanguePage` (ou directement `ParametresPage` avec ancre sur « Langue des contenus »).
- [ ] Le bandeau change dynamiquement si l'utilisateur change de langue sans quitter la page.
- [ ] Pour les langues avec caractères spéciaux (`bm`, `sus`, `ful`), ajouter sous le bandeau un rappel discret : _« Le contenu utilisera les lettres ɛ ɔ ɓ ɗ ŋ. »_ (preview visuel pour que l'utilisateur sache à quoi s'attendre).
- [ ] `lib/Pages/Creer/creer_page.dart` : au submit → `creation_api` → écran de progression (reprendre `EasyLoading` existant ou créer un `KlemiProgression` avec pourcentage). À completion → `AppShell._onglet = feed` + insertion de l'item nouvellement créé en tête du feed via `FeedRepository.prepend`.
- [ ] Gérer erreur quota dépassé (HTTP 402 ou code spécifique) → modale qui propose l'upgrade de forfait.
- [ ] Gérer erreur **400 `UNSUPPORTED_LANGUAGE`** du backend → snackbar + rediriger vers `LanguePage`.

### Rendu des contenus multilingues
- [ ] **Audit** : tout widget `Text` qui affiche le résultat de génération (titre, question, explication, lexique, transcript podcast) doit porter `fontFamilyFallback: AppTheme.famillesSecours`. Faire la passe sur `carte_quiz.dart`, `carte_fiche.dart`, `carte_podcast.dart`, `resultat_page.dart`.
- [ ] Idéalement, exposer une méthode utilitaire `KlemiTexte(content, {bool genere = true})` qui applique automatiquement le fallback pour éviter l'oubli.

### Quota
- [ ] Rafraîchir `AppState.generationsRestantes` via `GET /api/mobile/me/generation-quota` au mount de `CreerPage` et après chaque génération réussie.

### Vérification Phase 3
- [ ] Switcher la langue en `bm` dans Paramètres puis créer un quiz depuis un PDF français → le quiz est en bamanankan avec les caractères spéciaux visibles (pas de carrés).
- [ ] Switcher en `sus` puis créer un podcast → audio en soso.
- [ ] Switcher en `fr` → comportement historique inchangé (clients web non affectés).

### Côté API
_Voir `klemi-api/guide/PLAN_INTEGRATION_MOBILE.md` Phase 3._

### Vérification Phase 3
- [ ] Upload PDF depuis le mobile → quiz dans le feed sous ~30 s.
- [ ] Quota diminue visuellement dans le profil.
- [ ] Erreur quota → modale upgrade affichée correctement.

---

## Phase 4 — Profil, progression, biblio, paramètres

> Suppose que `GET /api/mobile/me`, `PATCH /api/mobile/me/profile`, `GET /api/mobile/me/library`, `GET`/`PATCH /api/mobile/me/preferences`, `POST /api/mobile/me/streak/ping` sont livrés.

### Service & repository
- [ ] Créer `lib/Services/profile_api.dart`.
- [ ] Créer `lib/Repositories/profile_repository.dart` : charge et met à jour `AppState` depuis le payload `/api/mobile/me`.

### Pages Profil
- [ ] `lib/Pages/Profil/profil_page.dart` : au mount → `ProfileRepository.load()` → maj `AppState` (points, serieJours, niveau, nomNiveau, forfait, generationsRestantes).
- [ ] `lib/Pages/Profil/parametres_page.dart` : chaque toggle → `PATCH /mobile/me/preferences` + propagation locale optimiste.
- [ ] Biblio (`ProfilPage(ouvrirBiblio: true)`) : `GET /mobile/me/library` paginée.
- [ ] Édition profil (nom/classe/établissement/langue/niveauEtudes) → `PATCH /mobile/me/profile`.

### Changement de langue — avertissement utilisateur
- [ ] Dans `parametres_page.dart`, à la sélection d'une nouvelle langue de contenu, afficher une boîte de dialogue de confirmation : _« Les nouveaux contenus générés le seront en {nouvelleLangue.nom}. Les contenus existants restent inchangés et visibles dans Biblio. Continuer ? »_
- [ ] À la confirmation : `AppState.choisirLangue(nouvelleLangue)` → appel `PATCH /mobile/me/profile` avec `langue` → **invalider le cache feed** de `FeedRepository` et forcer un rechargement.
- [ ] Afficher un petit toast après le switch : _« Tes prochains contenus seront en {langue}. »_

### Streak
- [ ] Dans `lib/main.dart` ou `splash_screen.dart` : après `AppState.charger()`, si `connecte`, appeler `streak/ping` une fois par jour (comparer à `lastPingDate` en SharedPreferences).

### Côté API
_Voir `klemi-api/guide/PLAN_INTEGRATION_MOBILE.md` Phase 4._

### Vérification Phase 4
- [ ] Points gagnés en quiz (Phase 2) remontent au profil.
- [ ] Toggle notifications persisté après kill.
- [ ] Changer langue de contenu dans Paramètres → le feed suivant filtre sur cette langue.
- [ ] `serieJours` incrémenté au premier launch du jour.

---

## Phase 5 — Social (follow, like, comment, push)

> Suppose que modules `creators`, `follows`, `content-likes`, `content-comments`, `push-notifications` sont livrés côté API.

### Service
- [ ] Créer `lib/Services/social_api.dart` groupant creators/follows/likes/comments/notifications.

### Firebase Cloud Messaging
- [ ] Ajouter à `pubspec.yaml` : `firebase_core`, `firebase_messaging`.
- [ ] Récupérer `google-services.json` et `GoogleService-Info.plist` auprès de l'équipe backend. Les ajouter à `.gitignore` (ne pas commiter).
- [ ] Config iOS (`ios/Runner/Info.plist`, capacité Push Notifications dans Xcode).
- [ ] Config Android (`android/app/google-services.json`, plugin dans `android/build.gradle`).
- [ ] Au login : récupérer le token FCM (`FirebaseMessaging.instance.getToken()`) et le POSTer sur `/api/mobile/me/push-token`.
- [ ] Au logout : `DELETE /api/mobile/me/push-token` avec l'ancien token.
- [ ] Handler `FirebaseMessaging.onMessage` → afficher une `KlemiSnackbar` en foreground.
- [ ] Handler `FirebaseMessaging.onMessageOpenedApp` → naviguer vers l'écran pertinent selon le `payload.type`.

### Pages Social
- [ ] `lib/Pages/Social/profil_createur_page.dart` : charger `GET /api/mobile/creators/:id` + listes de contenus. Bouton Suivre/Suivi → `POST`/`DELETE` → maj `AppState.suivis`.
- [ ] `lib/Pages/Social/commentaires_sheet.dart` : charger `GET /api/mobile/content/:id/comments` (paginé) + poster un nouveau commentaire.
- [ ] `lib/Pages/Social/notifications_page.dart` : charger `GET /api/mobile/me/notifications` + marquer lue au tap. Badge non-lues depuis SSE `/api/notifications/stream`.

### Rail de la carte feed
- [ ] `lib/Widgets/carte_feed.dart` : bouton like appelle vraiment `likeItem(id)` / `unlikeItem(id)` (branche les placeholders de Phase 2).

### Côté API
_Voir `klemi-api/guide/PLAN_INTEGRATION_MOBILE.md` Phase 5._

### Vérification Phase 5
- [ ] Follow créateur sur appareil A → notification push reçue quand il publie (test manuel avec un vrai device).
- [ ] Commentaire posté apparaît instantanément dans la feuille modale.
- [ ] Les likes persistent après restart.
- [ ] Badge notifications décrémente en temps réel via SSE quand on marque lue sur un autre appareil.

---

## Phase 6 — Forfaits & paiement mobile money

> Suppose que `GET /api/mobile/plans`, `POST /api/mobile/subscription/checkout`, `GET /api/mobile/subscription/status/:invoiceId` sont livrés.

### Service
- [ ] Créer `lib/Services/billing_api.dart`.

### Pages
- [ ] `lib/Pages/Profil/forfaits_page.dart` : remplacer la liste codée en dur par `GET /api/mobile/plans`.
- [ ] `lib/Pages/Profil/paiement_page.dart` : au submit → `checkout` → écran de polling sur `/api/mobile/subscription/status/:invoiceId` (toutes les 3 s pendant max 2 min). À PAID → `ProfileRepository.refresh()` + toast succès + retour profil.
- [ ] Gérer erreurs : paiement refusé, timeout, numéro invalide.

### Côté API
_Voir `klemi-api/guide/PLAN_INTEGRATION_MOBILE.md` Phase 6._

### Vérification Phase 6
- [ ] Simulateur mobile money dev : transaction aboutit, `AppState.forfait` passe à `Premium`, `generationsRestantes` augmente.

---

## Phase 7 — Finitions mobile (observabilité, hors-ligne, i18n complet)

### Cache & offline
- [ ] Cache local du feed : persister les 20 derniers `FeedItem` en JSON (`SharedPreferences`) pour lecture hors ligne.
- [ ] File d'attente actions offline (like, answer, follow, save) rejouée à la reconnexion. Nouveau fichier `lib/Services/offline_queue.dart`.

### i18n
- [ ] Créer `lib/Configuration/i18n/<lang>.arb` pour les 5 langues. Utiliser `flutter_localizations` (déjà présent) + `intl`.
- [ ] Migrer les strings UI en dur vers les ARB au fur et à mesure.
- [ ] Script custom (ex. `tool/check_fallback_fonts.dart`) qui vérifie que tout `Text` affichant du contenu traduit porte `fontFamilyFallback: AppTheme.famillesSecours`.

### Observabilité
- [ ] Ajouter `sentry_flutter` dans `pubspec.yaml`. Initialiser dans `main.dart` avec DSN via `--dart-define=SENTRY_DSN=…`.
- [ ] Rapporter les 4xx/5xx mobile + exceptions UI non capturées.

### Côté API
_Voir `klemi-api/guide/PLAN_INTEGRATION_MOBILE.md` Phase 7 (ETag, rate limiting)._

### Vérification Phase 7
- [ ] Mode avion : 20 derniers quiz lisibles, un like est queued, rejoué au retour en ligne.
- [ ] App en pular (`ful`) : aucun caractère carré, textes traduits.
- [ ] Sentry reçoit une exception de test.

---

## Vérification end-to-end à chaque fin de phase

- [ ] `flutter analyze` → 0 warning.
- [ ] `flutter test` → 100 % vert (3 existants + nouveaux).
- [ ] Scénario de la phase déroulé à la main sur simulateur iOS **et** vrai Android.
- [ ] Commit référencé dans ce fichier (format : `- [x] … (commit abc1234)`).
- [ ] Vérifier que le plan API compagnon marque la même phase comme livrée.

---

## Fichiers critiques (côté mobile uniquement)

| Phase | Fichier | Nature |
|-------|---------|--------|
| 0 | `lib/Configuration/api_url.dart` | Remplir |
| 0 | `lib/Configuration/api_client.dart` | Nouveau |
| 0 | `lib/Services/auth_storage.dart`, `api_exception.dart` | Nouveaux |
| 0, 1, 4 | `lib/Providers/app_state.dart` | Étendre |
| 1 | `lib/Services/mobile_auth_api.dart` | Nouveau |
| 1 | `lib/Pages/Auth/*.dart` | Étendre |
| 2 | `lib/Services/mobile_feed_api.dart` | Nouveau |
| 2 | `lib/Repositories/feed_repository.dart` | Nouveau |
| 2 | `lib/Pages/Feed/*.dart` | Étendre |
| 3 | `lib/Services/creation_api.dart` | Nouveau |
| 3 | `lib/Pages/Creer/creer_page.dart` | Étendre |
| 4 | `lib/Services/profile_api.dart`, `lib/Repositories/profile_repository.dart` | Nouveaux |
| 4 | `lib/Pages/Profil/*.dart` | Étendre |
| 5 | `lib/Services/social_api.dart` | Nouveau |
| 5 | `lib/Pages/Social/*.dart`, `lib/Widgets/carte_feed.dart` | Étendre |
| 6 | `lib/Services/billing_api.dart`, `lib/Pages/Profil/{forfaits,paiement}_page.dart` | Nouveaux / étendre |
| 7 | `lib/Services/offline_queue.dart`, `lib/Configuration/i18n/` | Nouveaux |
| 0, 5, 7 | `pubspec.yaml` | Étendre (uuid, flutter_secure_storage, firebase_*, sentry_flutter) |
| 1, 2 | `test/widget_test.dart` | Étendre |

---

## Compagnon côté API

Plan backend cochable : `klemi-api/guide/PLAN_INTEGRATION_MOBILE.md`.

---

## Journal d'exécution

| Date | Phase | Action | Commit |
|------|-------|--------|--------|
| 2026-11-16 | — | Création initiale du plan mobile | — |
| 2026-11-16 | — | Ajout exigence transversale « langue de génération » (Phase 0/2/3/4) | — |
