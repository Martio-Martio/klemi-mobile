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
- [x] Ajouter à `pubspec.yaml` : `uuid: ^4.x`, `flutter_secure_storage: ^9.x`. Lancer `flutter pub get`. _(commit 4ee8199 + Phase 0)_
- [x] Remplir `lib/Configuration/api_url.dart` : `class ApiUrl { static const baseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'https://teach-me-api-development.up.railway.app/api'); }`. **Nota** : `api2-dev.klemi.ci` est commenté dans `.env.railway.dev` — ne plus l'utiliser. L'URL de référence dev est celle de Railway. _(+ flag `USE_MOCK` ajouté pour fallback debug Phase 2)_
- [x] Documenter dans `README.md` les 3 cibles : `--dart-define=API_BASE_URL=https://api.klemi.ci/api` (prod), Railway dev (défaut), `http://localhost:7501/api` (local avec `start:dev-safe`).

### Code transverse
- [x] Créer `lib/Configuration/api_client.dart` : wrapper `http` qui injecte automatiquement `Authorization: Bearer <token>`, `x-device-id`, `x-device-name`, `x-platform: ios|android`, `x-language: <langue.id>` (lue depuis `AppState.langue.id`). Un seul point d'entrée pour toutes les requêtes. _(Singleton `ApiClient.instance`, branché dans `main.dart` ; expose `get/post/patch/put/delete/multipart`.)_
- [x] **Test unitaire du client** : vérifier que `x-language` est bien injecté sur une requête quelle que soit la langue courante (`fr`, `en`, `bm`, `sus`, `ful`). Cette protection évite qu'une refacto future casse silencieusement le filtrage et la génération multilingues. _(5 tests dans `test/api_client_test.dart` — injection headers, absence Authorization sans token, changement de langue, parsing ApiException 404 `USER_NOT_FOUND`, query params.)_
- [x] Créer `lib/Services/auth_storage.dart` : stockage sécurisé `accessToken` + `refreshToken` via `flutter_secure_storage`. `SharedPreferences` ne sert **que** pour langue / niveau / matières / connecte — jamais pour les tokens.
- [x] Créer `lib/Services/api_exception.dart` : `class ApiException implements Exception { int statusCode; String code; String message; }` pour parser `{ statusCode, message, error }` NestJS. _(Supporte `message` en string ou en liste class-validator, `code` métier optionnel.)_
- [x] `lib/Providers/app_state.dart` : ajouter `String? _accessToken`, méthode `definirSession(...)`, appel à `AuthStorage.store` dans `marquerConnecte(true)`, nettoyage dans `deconnecter()`. _(Fallback de sécurité : si flag `connecte=true` mais token absent au reload, forcer déconnexion propre.)_
- [x] Générer un `deviceId` UUID v4 persistant au premier lancement (clé `deviceId` dans `SharedPreferences`). _(`lib/Services/device_info.dart` avec cache mémoire.)_

### Côté API
_Rien — CORS, JWT guard et headers déjà prêts. Voir `klemi-api/guide/PLAN_INTEGRATION_MOBILE.md` Phase 0._

### Feature flags (gain gratuit)
- [x] Au startup après `AppState.charger()`, appeler `GET /api/platform/features` (endpoint public existant, confirmé par audit — `src/controllers/platform-features.controller.ts:36-45`). Stocker le résultat dans `AppState.features`. _(Chargement en parallèle dans `splash_screen.dart`, échec silencieux pour ne pas bloquer le démarrage offline.)_
- [ ] Utiliser ce flag pour désactiver dans l'UI les fonctionnalités backend absentes (ex. si l'intégration YouTube est désactivée par flag, griser la carte source `youtube` dans `CreerPage`). **À brancher en Phase 3** (`CreerPage`).

### Vérification Phase 0
- [x] `flutter analyze` : 0 nouveau warning sur les fichiers Phase 0. Les 33 `deprecated_member_use` sur `package:flutter/material.dart` sont **pré-existants** (Flutter 3.47+ migration `material_ui` — hors scope Phase 0).
- [x] `flutter test` : les 2 tests langue + les 5 nouveaux tests `ApiClient` passent. Le 3ᵉ test existant « Le feed affiche une carte quiz jouable » échoue sur un `RenderFlex overflowed by 10.0 pixels` dans `lib/Widgets/carte_feed.dart:149` — fichier **non modifié** par Phase 0, bug de layout pré-existant à traiter séparément.
- [ ] Bouton debug « Ping API » (non essentiel — remplacé par les 5 tests unitaires `ApiClient` qui prouvent déjà la bonne construction des requêtes et le parsing des réponses).
- [x] `GET /api/platform/features` chargé au startup et exposé via `AppState.features`.

---

## Phase 1 — Auth mobile (phone + WhatsApp OTP)

> Suppose que `POST /api/mobile-auth/{signup,login,verify-otp,resend-otp,refresh,logout}` est livré côté API.

### Service
- [x] Créer `lib/Services/mobile_auth_api.dart` avec 6 méthodes : `signup`, `login`, `verifyOtp`, `resendOtp`, `refresh`, `logout`. Toutes basées sur `ApiClient`. _(`MobileAuthDemarrage` + `MobileAuthSession` + enum `RoleInscription`.)_

### Pages Auth
- [x] `lib/Pages/Auth/inscription_page.dart` : au submit → `signup(phone, role, nom, niveauEtudes, classe, etablissement, langue)` → navigue vers `code_page.dart(tempToken)`. _(EasyLoading + validation client minimale + propagation `AppState.choisirNiveau` avant navigation.)_
- [x] `lib/Pages/Auth/connexion_page.dart` : au submit → `login(phone)` → `code_page.dart(tempToken)`.
- [x] `lib/Pages/Auth/code_page.dart` : au submit → `verifyOtp(tempToken, code)` → store tokens → `AppState.definirSession(...)` → remplace la stack par `AppShell`. _(Fallback : si `tempToken=null`, va direct à AppShell → utile tant que l'API n'est pas branchée.)_
- [x] Gérer erreur **404 `USER_NOT_FOUND`** dans `connexion_page.dart` : afficher snackbar + CTA « s'inscrire ». _(SnackBarAction qui route vers `InscriptionPage`.)_
- [x] Gérer expiration OTP : bouton « Renvoyer le code » appelle `resendOtp(tempToken)`. _(Timer 60s + feedback snackbar après envoi.)_
- [x] `AppState.deconnecter()` : appelle aussi `MobileAuthApi.logout()` avant de nettoyer. _(Best-effort : si ApiException, nettoyage local continue.)_

### Refresh token
- [x] `ApiClient` : interceptor 401 → tente `refresh()` une fois, rejoue la requête initiale. Si refresh échoue → `AppState.deconnecter()` + route vers `ConnexionPage`. _(Via callback `rafraichirSession` injecté dans `main.dart` → `AppState.tenterRafraichirSession()`. Liste `_cheminsSansRefresh` bloque la boucle sur les endpoints `/mobile-auth/*`. La redirection vers `ConnexionPage` à la 2ᵉ 401 sera traitée en Phase 4 avec le ProfileRepository, pour l'instant l'appelant reçoit juste l'ApiException et affiche le message.)_

### Tests
- [x] Mettre à jour `test/widget_test.dart` pour injecter un `MobileAuthApi` mocké (ne pas casser les 3 tests existants). _(Les 2 tests langue existants restent verts. Le 3ᵉ test « feed affiche une carte quiz » échoue toujours sur overflow pré-existant hors Phase 1.)_
- [x] Nouveau fichier `test/mobile_auth_api_test.dart` : 6 specs unitaires (payload signup bien formé, trim phone, etablissement omis si vide, USER_NOT_FOUND propagé via `ApiException.code`, verifyOtp/refresh parsing, resend/logout POST silencieux).

### Côté API
_Voir `klemi-api/guide/PLAN_INTEGRATION_MOBILE.md` Phase 1._

### Vérification Phase 1
- [ ] `flutter run` avec API dev : inscription réelle, réception OTP WhatsApp sur numéro de test. **Bloqué par API** : l'endpoint `/mobile-auth/signup` n'existe pas encore (choix provider WhatsApp requis côté API — cf. plan backend Phase 1).
- [ ] Après kill de l'app, session restaurée automatiquement au relancement. **Bloqué par API**.
- [ ] Après 401 forcé (token expiré manuellement) → auto-refresh transparent OU redirection connexion si refresh invalide. **Bloqué par API**.
- [x] Compilation : `flutter analyze` sans nouveau warning (33 `deprecated_member_use` pré-existants hors scope).
- [x] Tests unitaires : 5 ApiClient + 6 MobileAuthApi + 2 langue = **13 tests verts**. Non-régression confirmée.

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

### Source « Photo du cours » — multi-sélection + prévisualisation (gap actuel)

> **Constat** : aujourd'hui `creer_page.dart:95` déclare une carte source `photo` mais la zone de dépôt (`_fichierDepose`, lignes 101-152) est mutualisée et simule un unique PDF. Zéro vraie gestion image, zéro multi-sélection, zéro preview. Côté API, `POST /files/upload-multiple-images` et `POST /revision-images/upload` acceptent déjà plusieurs images — rien à changer côté backend.

- [ ] Ajouter `image_picker: ^1.x` à `pubspec.yaml` (choisir `image_picker` pour avoir caméra + galerie natives ; pas `file_picker` seul qui gère moins bien iOS).
- [ ] Nouveau widget réutilisable `lib/Widgets/klemi_zone_photos.dart` qui remplace `_fichierDepose` **quand `_source == 'photo'`** :
  - État interne `List<XFile> _photos`.
  - Boutons côte à côte : « Prendre une photo » (`ImagePicker().pickImage(source: ImageSource.camera)`) et « Importer » (`ImagePicker().pickMultiImage(maxWidth: 2048)`).
  - Grille `GridView.builder` 3 colonnes de vignettes carrées (Image.file + `fit: BoxFit.cover`, `borderRadius: AppTheme.radiusCarte`). Aspect 1:1.
  - Chaque vignette porte un badge d'ordre `1`, `2`, `3`… en overlay (coin haut-gauche) — l'ordre compte pour la cohérence pédagogique de la fiche/quiz générée.
  - Croix de suppression en overlay (coin haut-droit) qui retire l'image de la liste.
  - Dernière case de la grille = tuile « + » qui rouvre le picker (toggle caméra/galerie dans un `showModalBottomSheet`).
  - Drag-to-reorder sur les vignettes (`ReorderableGridView` du package `reorderables` ou implémentation manuelle avec `LongPressDraggable`) — permet à l'utilisateur de recomposer l'ordre des pages du cours photographié.
  - Compteur en bas : `N photo(s) · ~X,Y Mo` (calcul via `File(path).lengthSync()`).
  - Validation : min 1, **max 10 photos** (limite backend `maxCount: 10` dans `FileFieldsInterceptor`, confirmée par audit). Au-delà, snackbar d'erreur avec message _« 10 photos maximum par génération »_.
  - Chaque image > 10 Mo → compresser automatiquement avant envoi (package `flutter_image_compress`, résolution cible 2048px côté long).
- [ ] Intégrer `KlemiZonePhotos` dans `creer_page.dart` : conditionnel sur `_source == 'photo'`, remplace la zone unique PDF.
- [ ] Au submit avec source photo → `CreationApi.genererDepuisImages(List<XFile> photos, type, langue, options)` → appel `POST /api/files/upload-multiple-images` (si quiz) ou `POST /api/revision-images/upload` (si fiche) ou `POST /api/podcasts` avec source image (si podcast — vérifier le support côté API, sinon désactiver l'option photo pour podcast avec un message explicite).
- [ ] Le corps multipart envoie les images en **ordre affiché par l'utilisateur** (l'ordre des vignettes = l'ordre pédagogique).
- [ ] `language` **toujours** injecté dans le form-data (règle transversale).
- [ ] Vignettes : feedback haptique léger (`HapticFeedback.selectionClick()`) au drag.
- [ ] États vides et de chargement : avant que l'utilisateur n'ait sélectionné une photo, afficher un placeholder dashed-border identique au style existant (`AppTheme.bordurePointillee`) avec icône caméra + libellé « Ajoute des photos de ton cours ».

### Permissions natives
- [ ] iOS : ajouter dans `ios/Runner/Info.plist` les clés `NSCameraUsageDescription` et `NSPhotoLibraryUsageDescription` avec un libellé en français expliquant que les photos servent à générer des quiz/fiches.
- [ ] Android : `android/app/src/main/AndroidManifest.xml` — `READ_MEDIA_IMAGES` (API 33+) et `READ_EXTERNAL_STORAGE` (API ≤ 32). La caméra est gérée en permission runtime par `image_picker`.
- [ ] Gérer refus de permission : snackbar avec CTA « Ouvrir les réglages » (via `AppSettings.openAppSettings()` du package `app_settings` si on l'ajoute, sinon message statique).

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
- [ ] **Multi-images** : prendre 3 photos consécutives d'un cours au tableau → vignettes affichées en grille 3 colonnes, numérotées 1/2/3, réordonnables par drag, suppression unitaire possible. Submit → quiz généré qui respecte l'ordre pédagogique des photos.
- [ ] Import de 5 images depuis la galerie en une seule action → toutes apparaissent instantanément dans la grille.
- [ ] Image > 10 Mo → compression automatique, pas d'erreur.
- [ ] Refus de permission caméra → message clair + CTA réglages.

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
>
> **Audit (2026-11-16)** : côté API, l'intégration mobile money passe par **Flex Transfer**, qui couvre désormais **Orange Money, MTN MoMo, Moov Money et Wave**. Devise par défaut : XAF. Tarifs réels : STUDENT 2000, PREMIUM 5000.

### Service
- [ ] Créer `lib/Services/billing_api.dart`.

### Pages
- [ ] `lib/Pages/Profil/forfaits_page.dart` : remplacer la liste codée en dur par `GET /api/mobile/plans`.
- [ ] `lib/Pages/Profil/paiement_page.dart` : au submit → `checkout` → écran de polling sur `/api/mobile/subscription/status/:invoiceId` (toutes les 3 s pendant max 2 min). À PAID → `ProfileRepository.refresh()` + toast succès + retour profil.
- [ ] Moyens affichés : **Orange Money, MTN MoMo, Moov Money, Wave** (tous supportés par Flex Transfer). Payload du `checkout` : `moyen: 'orange'|'mtn'|'moov'|'wave'`.
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
| 3 | `lib/Widgets/klemi_zone_photos.dart` | Nouveau (multi-images + preview) |
| 3 | `lib/Pages/Creer/creer_page.dart` | Étendre (bandeau langue + brancher zone photos) |
| 3 | `ios/Runner/Info.plist`, `android/app/src/main/AndroidManifest.xml` | Permissions caméra + galerie |
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
| 2026-11-16 | — | Ajout gap « multi-images + preview » dans Phase 3 (`KlemiZonePhotos`) | — |
| 2026-11-16 | — | Audit croisé API : URL dev Railway, limite 10 images, Wave retiré, `GET /platform/features` ajouté P0 | — |
| 2026-11-16 | — | Correction : Wave désormais supporté par Flex Transfer → remis dans les moyens de paiement | — |
| 2026-11-16 | P0 | **Phase 0 livrée** : `ApiUrl`, `ApiClient` + singleton, `AuthStorage`, `ApiException`, `DeviceInfo`, `PlatformFeaturesApi`, extension `AppState` (session + features), chargement au splash, 5 tests `ApiClient` verts. | — |
| 2026-11-16 | P1 | **Phase 1 livrée côté mobile** : `MobileAuthApi` (6 méthodes), interceptor 401 → refresh → retry dans `ApiClient`, `AppState.tenterRafraichirSession()` + `deconnecter()` qui appelle logout backend, pages Auth branchées (inscription/connexion/code) avec EasyLoading + gestion erreurs + `USER_NOT_FOUND` snackbar, resend OTP avec timer 60s. 6 tests `MobileAuthApi` + 2 tests langue + 5 tests `ApiClient` = 13 verts. **Exécution réelle bloquée par l'API** (choix provider WhatsApp + endpoints à livrer). | — |
