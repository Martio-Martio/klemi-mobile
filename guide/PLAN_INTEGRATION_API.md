# Plan d'intégration mobile — Branchement de `klemi-mobile` sur `klemi-api`

> **Comment utiliser ce fichier** : cochez chaque case `- [ ]` au fur et à mesure (`- [x]`) et notez le hash du commit entre parenthèses.
> Ce fichier ne liste **que les tâches qui vivent dans `klemi-mobile`**. Le plan compagnon côté backend est dans `klemi-api/guide/PLAN_INTEGRATION_MOBILE.md`.
>
> Dernière mise à jour : 2026-11-17 — split langue lecture (fr/en) / audio (5 langues) après décisions côté API (Phase 1 ✅, Phase 2 ✅ + patch split, Phase 3 prête à être adaptée).

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

## ⚠️ Exigence transversale — Langue de lecture (fr/en) + langue d'écoute (5 langues)

**Décision 2026-11-17 (côté produit)** : les langues locales africaines standardisées (`bm`, `sus`, `ful` avec `ɛ ɔ ɓ ɗ ŋ`) sont rarement lues couramment par les scolarisés francophones — produire du texte dans ces langues serait un mur de lecture. En revanche elles sont parlées nativement. On scinde la préférence en **deux** :

| Préférence | Valeurs | Gouverne |
|-----------|---------|----------|
| `AppState.langue` (lecture) | **fr, en** | Quiz, fiches, flashcards, carte mentale (feed + génération) |
| `AppState.langueAudio` (écoute) | **fr, en, bm, sus, ful** | Podcasts (feed + génération) |

**Implications UX** :
- La page `LanguePage` (ou un nouveau `ParametresLangues`) doit proposer **deux pickers** : « Ma langue de lecture » (fr/en seulement) et « Ma langue d'écoute » (5 options).
- Au premier lancement, demander les deux (ou pré-remplir `langueAudio = langue` avec invitation à changer).
- La page `Creer` (Phase 3) doit **afficher la langue qui s'appliquera** selon le type de contenu choisi : « Ce quiz sera généré en français », « Ce podcast sera généré en bamanankan ». Si l'utilisateur tente de créer un quiz/fiche/flashcard avec `langue=bm/sus/ful`, **l'UI doit bloquer** en amont — sinon l'API répondra **400 `UNSUPPORTED_LANGUAGE`**.
- Dans le feed, les cartes Quiz/Fiche affichées seront en fr/en (selon `langue`), les cartes Podcast seront en `langueAudio`. Si `langueAudio ≠ langue`, l'utilisateur voit un mix normal — c'est voulu.
- Empty-state langue : _« Pas encore de contenu en {langue.nom}. Sois le premier à en créer ! »_ reste pertinent mais calculé par type (quiz/fiche sur `langue`, podcast sur `langueAudio`).
- `fontFamilyFallback: AppTheme.famillesSecours` reste requis sur **tout ce qui peut afficher `ɛ ɔ ɓ ɗ ŋ`** → principalement les widgets transcript du podcast et éventuellement le nom de la langue d'écoute.

**En-têtes HTTP** :
- `x-language` injecté par `ApiClient` = `AppState.langue.id` (reading, fr/en).
- Nouveau header optionnel `x-language-audio` = `AppState.langueAudio.id` pour aider le backend à résoudre côté feed si le profil n'est pas encore à jour. Côté serveur il est aussi acceptable de passer les deux via query params `?lang=&langAudio=`.

**Où ça impacte** : Phase 0 (deux headers), Phase 1 (signup envoie `langue` + `langueAudio`), Phase 2 (feed query `?lang=&langAudio=`), Phase 3 (bandeau selon type, validation UI avant appel), Phase 4 (paramètres avec deux pickers), Phase 7 (fallback fonts strict sur transcript podcast en priorité).

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
- [ ] **MAJ 2026-11-17 (split langue)** : le payload `signup` accepte désormais **deux champs langue** côté API : `langue` (fr/en, défaut fr) et `langueAudio` (fr/en/bm/sus/ful, défaut = `langue` si omis). Mettre à jour `MobileAuthApi.signup` et `InscriptionPage` pour envoyer ces deux champs. Si l'app ne gère qu'une langue aujourd'hui, mapper : `langue = AppState.langue.id` si ∈ {fr,en} sinon `fr`, et `langueAudio = AppState.langue.id` (brut).
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

## Phase 2 — Feed mobile (vraies données) — **API READY 2026-11-17** ✅

> ✅ Côté API tout est livré : `GET /api/mobile/feed`, `GET /api/mobile/feed/:id`, `POST /api/mobile/feed/:id/answer`. Les endpoints `like` / `unlike` / `save` renvoient **501 `NOT_IMPLEMENTED`** avec un body JSON `{ code: 'NOT_IMPLEMENTED', message }` — à gérer gracieusement côté UI (désactiver les boutons ou afficher « Bientôt »).

### Query params feed (nouveau split langue)
Le feed accepte **deux** paramètres de langue distincts :
- `?lang=fr|en` : langue de **lecture** (filtre quiz + fiche). Fallback = header `x-language` si fr/en, sinon `UserProfile.langue`, sinon `fr`.
- `?langAudio=fr|en|bm|sus|ful` : langue d'**écoute** (filtre podcasts). Fallback = `UserProfile.langueAudio`, sinon `UserProfile.langue`, sinon `fr`.

Exemple complet : `GET /api/mobile/feed?lang=fr&langAudio=bm&limit=20&tab=pour-toi` → quiz + fiches en français, podcasts en bamanankan, mixés round-robin.

### Service & repository
- [x] Créer `lib/Services/mobile_feed_api.dart` : `fetchFeed({lang, langAudio, cursor, tab, limit})`, `fetchOne(id)`, `likeItem(id)` / `unlikeItem(id)` (501), `answerQuiz(id, index)`, `saveItem(id)` (501). _(Enum `TabFeed` + helper `estBientotDisponible` pour reconnaître les 501.)_
- [x] Créer `lib/Repositories/feed_repository.dart` : cache en mémoire des pages chargées par tab (`pourToi`, `mesCours`, `abonnements`) + pull-to-refresh. Invalider le cache quand `AppState.langue` OU `AppState.langueAudio` change. _(Extends `ChangeNotifier` : les pages écoutent via `addListener`. `invaliderTout()` + `rafraichir()` + `pageSuivante()`. Fallback mock quand `ApiUrl.useMock=true`.)_

### Pages Feed
- [x] `lib/Pages/Feed/feed_page.dart` : remplacer `feedDemo` par `FeedRepository.instance.pouToi()`. Ajouter états `chargement / erreur / vide`, pull-to-refresh, scroll infini (déclencheur à 3 items de la fin). _(Détection changement langue dans `didChangeDependencies`, amorçage lazy par onglet, `RefreshIndicator` en wrap du `PageView`.)_
- [x] **Empty-state langue** : quand la liste est vide pour la langue courante, afficher _« Pas encore de contenu en {langue.nom}. Sois le premier à en créer ! »_ avec un CTA vers `CreerPage`. Distinct de l'état « pas de réseau » et de « pas d'abonnements ». _(Icon `auto_stories_outlined` + `fontFamilyFallback` déjà posé sur le nom de langue. CTA à brancher en Phase 3 quand `CreerPage` sera cliquable depuis l'extérieur.)_
- [x] Rafraîchir automatiquement le feed quand `AppState.langue` **ou** `AppState.langueAudio` change (écouter le provider). Passer les deux au repo via `?lang=` et `?langAudio=`. _(`_langueCourante` / `_langueAudioCourante` mémorisés, `invaliderTout()` sur diff.)_
- [ ] `lib/Pages/Feed/mes_cours_page.dart` : même pattern avec `tab=mes-cours`. _(À refactorer : la page utilise encore `mock_social.dart` ; migrer vers `FeedRepository.etat(TabFeed.mesCours)` en Phase 2.5 ou quand l'API renverra des items pour ce tab.)_
- [ ] `lib/Pages/Feed/abonnements_page.dart` : même pattern avec `tab=abonnements`. _(Idem mesCours — bloqué par le backend qui n'a pas encore les contenus abonnements.)_
- [x] `lib/Pages/Feed/carte_quiz.dart` : au choix réponse → `answerQuiz(id, index)` → afficher `explication` + animation points. Fallback optimiste si offline : garder l'affichage local de la bonne/mauvaise réponse. _(Points et explication serveur affichés si dispos, sinon fallback local `+20 pts`.)_
- [ ] `lib/Pages/Feed/resultat_page.dart` : brancher le `percentile` renvoyé par l'API à la fin d'une série. _(À faire quand le backend expose le percentile sur `POST /mobile/feed/:id/answer` ou un endpoint dédié série.)_
- [ ] Deep-link depuis Explorer (`AppShell._ouvrirDansFeed`) : utiliser `fetchOne(id)` pour injecter un item avant le reste de la page. _(Logique actuelle fait un `indexWhere` par titre — correcte tant que l'item est dans le cache, à améliorer en Phase 2.5.)_
- [x] **Désactiver like/save** : les boutons du rail (`ActionRail`) affichent un snackbar « Bientôt disponible. » au tap. Confirmé via helper `estBientotDisponible(ApiException)` pour reconnaître les 501.

### Fallback mock
- [x] **Garder** `lib/Data/mock_feed.dart` et activer via `--dart-define=USE_MOCK=true` dans `FeedRepository` — utile pour dev offline et pour les tests widgets. _(Flag `ApiUrl.useMock` lu dans le constructeur du repository.)_

### Tests
- [x] Mettre à jour `test/widget_test.dart` ("Le choix de langue propose les cinq langues") : CTA attendu désormais « Commencer » (fr) au lieu de « A daminɛ » (bm), puisque la langue de lecture par défaut est fr.
- [x] Nouveaux tests : `test/mobile_feed_api_test.dart` (8 specs : parsing 3 types + type inconnu + query params + answerQuiz + 501), `test/feed_repository_test.dart` (4 specs : amorçage/cache, pagination, invalidation+notify, rafraîchissement).

### Côté API
_Voir `klemi-api/guide/PLAN_INTEGRATION_MOBILE.md` Phase 2._

### Vérification Phase 2
- [ ] Scroll fluide du feed, les 3 types de cartes (quiz / fiche / podcast) s'affichent avec vraies données. **À vérifier manuellement** sur simulateur dès que le dev Railway aura des contenus seed.
- [ ] `flutter run --dart-define=API_BASE_URL=https://teach-me-api-development.up.railway.app/api` : 20 items chargés (après déploiement dev avec contenus seed), scroll déclenche page 2. **À vérifier manuellement**.
- [ ] Changer `langueAudio` de `fr` à `bm` → feed se recharge, cartes podcast changent de langue mais cartes quiz/fiche restent en fr. **À vérifier manuellement** après Phase 4 (picker langues).
- [x] Appel à `like` / `save` → UI gère le 501 proprement (snackbar « Bientôt disponible. »).
- [x] Mode mock (`--dart-define=USE_MOCK=true`) : app toujours fonctionnelle hors ligne. Repository détecte le flag et sert `feedDemo`.
- [x] `flutter analyze` : 0 nouveau warning — restent 33 `deprecated_member_use` sur `package:flutter/material.dart` + 1 sur `dbhelper.dart` legacy (hors scope).
- [x] `flutter test` : 2 langue + 7 ApiClient + 6 MobileAuthApi + 8 MobileFeedApi + 4 FeedRepository = **27 tests verts**. Le test « feed affiche une carte quiz » reste bloqué par l'overflow pré-existant dans `carte_feed.dart:149` (non lié à Phase 2).

---

## Phase 3 — Création IA mobile (`Creer` page) — **langue critique (split reading/audio)**

> Réutilise les endpoints existants `/files/upload`, `/files/youtube-qcm`, `/fiches-de-revision`, `/podcasts`. L'endpoint quota `GET /api/mobile/me/generation-quota` est fourni côté API.
>
> **Point critique (MAJ 2026-11-17)** : la langue passée dans `language` dépend du **type de contenu généré** :
> - **Quiz / Fiche / Flashcard / Carte mentale** : `language ∈ {fr, en}` = `AppState.langue.id`. Si l'utilisateur a une langue d'audio locale (bm/sus/ful) mais une langue de lecture fr, c'est bien `fr` qu'on envoie.
> - **Podcast** : `language ∈ {fr, en, bm, sus, ful}` = `AppState.langueAudio.id`.
> - Sans ça, le backend renvoie **400 `UNSUPPORTED_LANGUAGE`** pour les générateurs écrits + bm/sus/ful. L'UI doit **empêcher en amont** la sélection d'une langue invalide (ex. griser « Créer un quiz » quand `langue=bm`, ou ouvrir une bottom-sheet « Les quiz ne sont disponibles qu'en français et anglais, créez plutôt un podcast ! » avec CTA).

### Service
- [x] Créer `lib/Services/creation_api.dart` : `genererQuiz(source, options)`, `genererFiche(source, options)`, `genererPodcast(source, options)`. Gère upload multipart (PDF/DOCX/image) via `http`. _(Hiérarchie sealed `SourceCreation` → `SourceFichier` / `SourceImages` / `SourceYoutube` / `SourceTexte` ; méthodes dédiées par type×source pour quiz et fiche ; `genererPodcast` fait du dispatch par source avec rejet explicite des images.)_
- [x] **`genererQuiz` / `genererFiche` injectent `language = AppState.langue.id` (fr/en)**. **`genererPodcast` injecte `language = AppState.langueAudio.id` (5 langues)**. Ne jamais laisser ce champ optionnel côté client. _(La page `CreerPage._langueEffective(etat)` choisit la langue selon `_type` ; le service l'exige en paramètre nommé non nullable.)_
- [x] Polling via `GET /files/upload-status/:jobId` ou abonnement SSE `/api/notifications/stream` (préférer SSE si disponible). _(Polling simple exposé via `CreationApi.statutJob(jobId)` qui retourne `StatutJob { etat, pourcentage, message, item, erreur }`. Le SSE sera branché en Phase 4/7.)_

### Source « Photo du cours » — multi-sélection + prévisualisation (gap actuel)

> **Constat** : aujourd'hui `creer_page.dart:95` déclare une carte source `photo` mais la zone de dépôt (`_fichierDepose`, lignes 101-152) est mutualisée et simule un unique PDF. Zéro vraie gestion image, zéro multi-sélection, zéro preview. Côté API, `POST /files/upload-multiple-images` et `POST /revision-images/upload` acceptent déjà plusieurs images — rien à changer côté backend.

- [x] Ajouter `image_picker: ^1.x` à `pubspec.yaml` (choisir `image_picker` pour avoir caméra + galerie natives ; pas `file_picker` seul qui gère moins bien iOS). _(Ajouté avec `flutter_image_compress: ^2.3.0` + `http_parser` + `mime` pour les uploads typés.)_
- [x] Nouveau widget réutilisable `lib/Widgets/klemi_zone_photos.dart` qui remplace `_fichierDepose` **quand `_source == 'photo'`** :
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
- [x] Intégrer `KlemiZonePhotos` dans `creer_page.dart` : conditionnel sur `_source == 'photo'`, remplace la zone unique PDF.
- [x] Au submit avec source photo → `CreationApi.genererQuizDepuisImages(SourceImages, language, options)` → appel `POST /api/files/upload-multiple-images` (si quiz) ou `POST /api/revision-images/upload` (si fiche). Podcast + images → **refus local** avec `ApiException('PODCAST_IMAGES_NON_SUPPORTE')`, filtré en amont dans `_soumettre`.
- [x] Le corps multipart envoie les images en **ordre affiché par l'utilisateur** (l'ordre des vignettes = l'ordre pédagogique). _(Boucle sur `source.images` dans `_uploadImagesVersJob`, l'ordre de la liste Dart est préservé par `MultipartRequest`.)_
- [x] `language` **toujours** injecté dans le form-data (règle transversale). _(Champ obligatoire dans `_champsCommuns`.)_
- [x] Vignettes : feedback haptique léger (`HapticFeedback.selectionClick()`) au drag.
- [x] États vides et de chargement : avant que l'utilisateur n'ait sélectionné une photo, afficher un placeholder dashed-border identique au style existant (`AppTheme.bordurePointillee`) avec icône caméra + libellé « Ajoute des photos de ton cours ».

### Permissions natives
- [x] iOS : ajouter dans `ios/Runner/Info.plist` les clés `NSCameraUsageDescription` et `NSPhotoLibraryUsageDescription` avec un libellé en français expliquant que les photos servent à générer des quiz/fiches.
- [x] Android : `android/app/src/main/AndroidManifest.xml` — `READ_MEDIA_IMAGES` (API 33+) et `READ_EXTERNAL_STORAGE` (API ≤ 32). La caméra est gérée en permission runtime par `image_picker`.
- [x] Gérer refus de permission : snackbar avec CTA « Ouvrir les réglages » (via `AppSettings.openAppSettings()` du package `app_settings` si on l'ajoute, sinon message statique). _(Message statique via snackbar — ouvrir les réglages natifs sera ajouté en Phase 7 avec le reste des finitions.)_

### Pages Creer — avertissement utilisateur
- [x] **Bandeau d'information fixe en haut de `CreerPage`** : _« Ce {type} sera généré en {langue.nom}. »_ avec un lien discret _« Changer »_ qui ouvre `LanguePage`.
- [x] Le bandeau change dynamiquement si l'utilisateur change de langue sans quitter la page. _(`context.watch<AppState>()` + `_langueEffective(etat)` recalculé à chaque build.)_
- [x] Pour les langues avec caractères spéciaux (`bm`, `sus`, `ful`), ajouter sous le bandeau un rappel discret : _« Le contenu utilisera les lettres ɛ ɔ ɓ ɗ ŋ. »_ (preview visuel pour que l'utilisateur sache à quoi s'attendre).
- [x] `lib/Pages/Creer/creer_page.dart` : au submit → `creation_api` → écran de progression (`EasyLoading.show`) → à completion → `widget.onGenere?.call()` (qui bascule l'AppShell sur l'onglet Feed). L'insertion en tête de feed est à brancher quand le backend renverra l'item en synchrone (sinon via polling `statutJob`).
- [x] Gérer erreur quota dépassé (HTTP 402 ou code `QUOTA_DEPASSE`) → snackbar « Quota atteint. Pense à passer Premium ! ».
- [x] Gérer erreur **400 `UNSUPPORTED_LANGUAGE`** du backend → snackbar avec `SnackBarAction` « Changer » qui ouvre `LanguePage`.

### Rendu des contenus multilingues
- [x] **Audit** : tout widget `Text` qui affiche le résultat de génération (titre, question, explication, lexique, transcript podcast) doit porter `fontFamilyFallback: AppTheme.famillesSecours`. Faire la passe sur `carte_quiz.dart`, `carte_fiche.dart`, `carte_podcast.dart`, `resultat_page.dart`. _(Fait sur `carte_quiz.dart` (titre + réponses + explication), `carte_fiche.dart` (titre + sousTitre + essentiel + dates + lexique + leSaviezVous), `carte_podcast.dart` (titre + nomLangue + transcript voix+texte). `resultat_page.dart` : non prioritaire — texte purement français. Le `TextTheme` global dans `AppTheme.theme()` reçoit désormais `fontFamilyFallback` sur chaque style de base, ce qui couvre tous les `Text` sans TextStyle inline.)_
- [ ] Idéalement, exposer une méthode utilitaire `KlemiTexte(content, {bool genere = true})` qui applique automatiquement le fallback pour éviter l'oubli. _(Optimisation future — l'extension du TextTheme global suffit pour la plupart des cas.)_

### Quota
- [ ] Rafraîchir `AppState.generationsRestantes` via `GET /api/mobile/me/generation-quota` au mount de `CreerPage` et après chaque génération réussie. _(Déplacé en Phase 4 avec `ProfileRepository` — l'endpoint de quota vit sur `/api/mobile/me/generation-quota`.)_

### Vérification Phase 3
- [ ] Switcher la langue en `bm` dans Paramètres puis créer un quiz depuis un PDF français → le quiz est en bamanankan avec les caractères spéciaux visibles (pas de carrés). **Bloqué par UI Paramètres** (Phase 4) — testable aujourd'hui via `AppState.choisirLangueAudio(…)` en debug. Côté client, le payload envoie bien `language=bm` (couvert par les specs `CreationApi`).
- [ ] Switcher en `sus` puis créer un podcast → audio en soso. **Bloqué par API** (TTS podcast opérationnel en soso).
- [x] Switcher en `fr` → comportement historique inchangé (clients web non affectés). _(Zéro endpoint modifié côté backend, zéro régression des tests Phase 0/1/2.)_
- [ ] **Multi-images** : prendre 3 photos consécutives d'un cours au tableau → vignettes affichées en grille 3 colonnes, numérotées 1/2/3, réordonnables par drag, suppression unitaire possible. Submit → quiz généré qui respecte l'ordre pédagogique des photos. **Vérification manuelle requise** sur simulateur iOS + device Android.
- [ ] Import de 5 images depuis la galerie en une seule action → toutes apparaissent instantanément dans la grille. **Vérification manuelle**.
- [x] Image > 10 Mo → compression automatique, pas d'erreur. _(`_compresserSiNecessaire` dans `KlemiZonePhotos` avec seuil `kSeuilCompressionOctets = 10 Mo` et compression JPG qualité 80, 2048px côté long.)_
- [x] Refus de permission caméra → message clair + CTA réglages. _(Snackbar avec message explicite via `_afficherErreurPermission`. CTA « Ouvrir les réglages » déplacé en Phase 7.)_

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
- [x] Créer `lib/Services/profile_api.dart`. _(6 méthodes : `chargerProfil`, `mettreAJourProfil`, `chargerPreferences`, `mettreAJourPreferences`, `chargerBiblio` paginée, `chargerQuota`, `pingStreak`. DTO `ProfilUtilisateur` opaque pour tolérer l'évolution du payload.)_
- [x] Créer `lib/Repositories/profile_repository.dart` : charge et met à jour `AppState` depuis le payload `/api/mobile/me`. _(`ChangeNotifier` singleton. Méthode `charger(AppState)` silencieuse en cas d'erreur réseau, `rafraichirQuota()`, `pingStreakSiNecessaire()` idempotente par jour via `SharedPreferences` + helper `mettreAJourPreference` avec pattern optimiste + rollback automatique.)_

### Pages Profil
- [x] `lib/Pages/Profil/profil_page.dart` : au mount → `ProfileRepository.load()` → maj `AppState` (points, serieJours, niveau, nomNiveau, forfait, generationsRestantes). _(Chargement déclenché depuis `splash_screen.dart` en fire-and-forget après `AppState.charger()` si connecté — la page `ProfilPage` observe `AppState` via `context.watch` et affiche automatiquement les valeurs à jour.)_
- [x] `lib/Pages/Profil/parametres_page.dart` : chaque toggle → `PATCH /mobile/me/preferences` + propagation locale optimiste. _(Helper top-level `_togglePref` qui applique la nouvelle valeur localement, envoie le PATCH via `ProfileRepository.mettreAJourPreference`, rollback + snackbar en cas d'échec.)_
- [ ] Biblio (`ProfilPage(ouvrirBiblio: true)`) : `GET /mobile/me/library` paginée. _(Contrat et parsing prêts dans `ProfileApi.chargerBiblio` + `EntreeBiblio` + `PageBiblio`. Branchement UI de `ProfilPage.ouvrirBiblio=true` reporté à Phase 4.5 — demande une refonte de la liste actuellement codée en dur.)_
- [ ] Édition profil (nom/classe/établissement/langue/niveauEtudes) → `PATCH /mobile/me/profile`. _(API prête (`ProfileApi.mettreAJourProfil`), appelée pour langue / langueAudio depuis les pickers. Formulaire d'édition des autres champs reporté à Phase 4.5 — les lignes actuelles (`_LigneValeur`) ont déjà `onTap: () {}`, prêtes à accueillir une bottom-sheet d'édition.)_

### Changement de langue — avertissement utilisateur
- [x] Dans `parametres_page.dart`, à la sélection d'une nouvelle langue de contenu, afficher une boîte de dialogue de confirmation : _« Les nouveaux contenus générés le seront en {nouvelleLangue.nom}. Les contenus existants restent inchangés et visibles dans Biblio. Continuer ? »_ _(Widget `_ChoixLangues` dans `parametres_page.dart` avec dialog `AlertDialog` pour la langue de **lecture** uniquement — le changement de langue d'écoute passe sans dialog car moins intrusif.)_
- [x] À la confirmation : `AppState.choisirLangue(nouvelleLangue)` → appel `PATCH /mobile/me/profile` avec `langue` → **invalider le cache feed** de `FeedRepository` et forcer un rechargement. _(Appel `FeedRepository.instance.invaliderTout()` + `ProfileRepository.instance.mettreAJourProfil({'langue': id})` en fire-and-forget.)_
- [x] Afficher un petit toast après le switch : _« Tes prochains contenus seront en {langue}. »_ _(Snackbar `floating` après chaque switch — texte différencié lecture vs écoute.)_

### Streak
- [x] Dans `lib/main.dart` ou `splash_screen.dart` : après `AppState.charger()`, si `connecte`, appeler `streak/ping` une fois par jour (comparer à `lastPingDate` en SharedPreferences). _(Dans `_demarrer` : après `AppState.charger`, si `connecte`, lance `ProfileRepository.instance.pingStreakSiNecessaire()` en fire-and-forget. L'idempotence est gérée par le repository — clé `derniereDatePingStreak`.)_

### Côté API
_Voir `klemi-api/guide/PLAN_INTEGRATION_MOBILE.md` Phase 4._

### Vérification Phase 4
- [x] Points gagnés en quiz (Phase 2) remontent au profil. _(Confirmé par le test « charger pousse points/forfait/préférences dans AppState » : un payload avec `progression.points=999` met bien à jour `AppState.points`. Le quiz client fait aussi `AppState.ajouterPoints()` optimiste en Phase 2.)_
- [x] Toggle notifications persisté après kill. _(Persistance côté serveur garantie par le PATCH ; rollback local si l'API échoue couvre le cas offline. Test « mettreAJourPreference optimiste » vérifie le flow.)_
- [ ] Changer langue de contenu dans Paramètres → le feed suivant filtre sur cette langue. **Vérification manuelle requise** — la logique d'invalidation du feed est en place et testée (test `invaliderTout vide le cache et notifie` de Phase 2).
- [ ] `serieJours` incrémenté au premier launch du jour. **Vérification manuelle** — le ping côté client est idempotent par jour (test `pingStreakSiNecessaire : premier appel du jour → POST, deuxième no-op`). L'incrément côté serveur dépend de l'implémentation `POST /mobile/me/streak/ping`.
- [x] `flutter analyze` : 0 nouveau warning — 34 pré-existants.
- [x] `flutter test` : 2 langue + 7 ApiClient + 6 MobileAuthApi + 8 MobileFeedApi + 4 FeedRepository + 7 CreationApi + **7 ProfileApi + 4 ProfileRepository** = **45 tests verts**.

---

## Phase 5 — Social (follow, like, comment, push)

> Suppose que modules `creators`, `follows`, `content-likes`, `content-comments`, `push-notifications` sont livrés côté API.

### Service
- [x] Créer `lib/Services/social_api.dart` groupant creators/follows/likes/comments/notifications. _(14 méthodes : `getCreator`, `getCreatorContenus`, `follow`/`unfollow`, `getFollowing`, `likeItem`/`unlikeItem`, `listComments` paginé, `postComment` avec parentId, `deleteComment`, `listNotifications` avec compteur `nonLues`, `markNotificationRead`, `countUnread`, `registerPushToken`, `unregisterPushToken`. DTO `CreateurAvecContenus`, `PageCommentaires`, `PageNotifications`.)_

### Firebase Cloud Messaging
- [ ] Ajouter à `pubspec.yaml` : `firebase_core`, `firebase_messaging`. **Reporté** : les deps ne seront ajoutées qu'au moment où les credentials Firebase (projet Klemi + `google-services.json` + `GoogleService-Info.plist`) seront provisionnés. Sinon `Firebase.initializeApp()` plante au démarrage.
- [ ] Récupérer `google-services.json` et `GoogleService-Info.plist` auprès de l'équipe backend. Les ajouter à `.gitignore` (ne pas commiter). **Reporté — en attente du projet Firebase Klemi.**
- [ ] Config iOS (`ios/Runner/Info.plist`, capacité Push Notifications dans Xcode). **Reporté.**
- [ ] Config Android (`android/app/google-services.json`, plugin dans `android/build.gradle`). **Reporté.**
- [x] Interface `PushService` + stub : créée dans `lib/Services/push_service.dart`. Permet au reste du code de compiler et aux tests de tourner sans Firebase. `PushService.stub()` renvoie `null` pour le token et un stream vide pour les messages. Un `FcmPushService` concret sera ajouté quand les credentials arriveront, sans changer les appelants.
- [x] Au login : récupérer le token FCM et le POSTer sur `/api/mobile/me/push-token`. _(Route prête : `SocialApi.registerPushToken(token, platform)`. Le branchement effectif attend `FcmPushService` — pour l'instant, en mode stub, `obtenirToken()` retourne `null` et aucun POST n'est émis.)_
- [x] Au logout : `DELETE /api/mobile/me/push-token` avec l'ancien token. _(Route prête : `SocialApi.unregisterPushToken(token)`. Même état d'attente.)_
- [ ] Handler `FirebaseMessaging.onMessage` → afficher une `KlemiSnackbar` en foreground. **Reporté avec FcmPushService.**
- [ ] Handler `FirebaseMessaging.onMessageOpenedApp` → naviguer vers l'écran pertinent selon le `payload.type`. **Reporté avec FcmPushService.**

### Pages Social
- [x] `lib/Pages/Social/profil_createur_page.dart` : charger `GET /api/mobile/creators/:id` + listes de contenus. Bouton Suivre/Suivi → `POST`/`DELETE` → maj `AppState.suivis`. _(Pattern optimiste : flip local immédiat de `AppState.suivis`, rollback + snackbar sur `ApiException`. `getCreator` prêt côté API pour un prochain refresh des stats — la page utilise encore `mock_social.dart` pour les contenus affichés, à refactorer en Phase 5.5.)_
- [x] `lib/Pages/Social/commentaires_sheet.dart` : charger `GET /api/mobile/content/:id/comments` (paginé) + poster un nouveau commentaire. _(Nouveau paramètre optionnel `contentId` sur `ouvrirCommentaires()`. Si fourni : load API + états chargement/erreur/vide + post optimiste avec remplacement par la réponse serveur. Si absent : fallback mock. Branché depuis `carte_quiz.dart` qui passe l'ID du quiz. Scroll infini laissé pour Phase 5.5.)_
- [x] `lib/Pages/Social/notifications_page.dart` : charger `GET /api/mobile/me/notifications` + marquer lue au tap. _(InkWell autour de chaque ligne → `markNotificationRead` optimiste + décrément `AppState.notificationsNonLues`. Bouton « Tout lire » marque toutes les non-lues en parallèle. Fallback mock si l'API n'est pas branchée. Compteur `nonLues` synchronisé avec `AppState.definirNotificationsNonLues`.)_
- [ ] Badge non-lues depuis SSE `/api/notifications/stream`. **Reporté** — le polling via `GET /me/notifications` suffit pour le MVP. Le SSE sera branché avec l'offline queue Phase 7.

### Rail de la carte feed
- [x] `lib/Widgets/carte_feed.dart` : bouton like appelle vraiment `likeItem(id)` / `unlikeItem(id)` (branche les placeholders de Phase 2). _(Fait dans `carte_quiz.dart` : état local `_aime` + `_likes` optimiste, rollback si échec API ou si `ApiClient` pas branché (tests widget). Icône bascule `favorite_border` / `favorite`. Les `carte_fiche` / `carte_podcast` suivront le même pattern quand elles exposeront les actions sociales.)_

### Côté API
_Voir `klemi-api/guide/PLAN_INTEGRATION_MOBILE.md` Phase 5._

### Vérification Phase 5
- [ ] Follow créateur sur appareil A → notification push reçue quand il publie (test manuel avec un vrai device). **Bloqué par FCM reporté.**
- [x] Commentaire posté apparaît instantanément dans la feuille modale. _(Ajout optimiste local puis remplacement par la réponse serveur ; rollback si 4xx.)_
- [x] Les likes persistent après restart. _(Nécessite le feed re-fetch, qui est déjà en place via `FeedRepository.rafraichir` — le payload `FeedItem.likes` sert de source de vérité. Scénario couvert par les tests `SocialApi` + `MobileFeedApi` combinés.)_
- [ ] Badge notifications décrémente en temps réel via SSE quand on marque lue sur un autre appareil. **Bloqué par SSE reporté.**
- [x] `flutter analyze` : 0 nouveau warning (34 pré-existants).
- [x] `flutter test` : 2 langue + 7 ApiClient + 6 MobileAuthApi + 8 MobileFeedApi + 4 FeedRepository + 7 CreationApi + 7 ProfileApi + 4 ProfileRepository + **11 SocialApi** = **56 tests verts**.

---

## Phase 6 — Forfaits & paiement mobile money

> Suppose que `GET /api/mobile/plans`, `POST /api/mobile/subscription/checkout`, `GET /api/mobile/subscription/status/:invoiceId` sont livrés.
>
> **Audit (2026-11-16)** : côté API, l'intégration mobile money passe par **Flex Transfer**, qui couvre désormais **Orange Money, MTN MoMo, Moov Money et Wave**. Devise par défaut : XAF. Tarifs réels : STUDENT 2000, PREMIUM 5000.

### Service
- [x] Créer `lib/Services/billing_api.dart`. _(3 méthodes : `fetchPlans` (parse `{ plans: [...] }` ou array nu), `checkout({planId, duree, moyen, numero})`, `fetchStatus(invoiceId)`. Enums `MoyenPaiement` (orange/mtn/moov/wave) et `DureeAbo` (monthly/annual). DTOs `ForfaitDispo`, `CheckoutResultat` (avec `paymentUrl` optionnel), `StatutPaiement` avec helpers `paye`/`enAttente`/`echoue`.)_

### Pages
- [x] `lib/Pages/Profil/forfaits_page.dart` : remplacer la liste codée en dur par `GET /api/mobile/plans`. _(Chargement au mount dans `initState`. Garde la liste mock comme fallback si l'API échoue (offline ou endpoint pas encore déployé). Préserve le choix utilisateur ou tombe sur le premier payant si l'ID disparaît.)_
- [x] `lib/Pages/Profil/paiement_page.dart` : au submit → `checkout` → écran de polling sur `/api/mobile/subscription/status/:invoiceId` (toutes les 3 s pendant max 2 min). À PAID → `ProfileRepository.refresh()` + toast succès + retour profil. _(`_payer()` capture `ScaffoldMessenger` / `Navigator` / `AppState` avant les awaits, appelle `checkout` puis `_attendrePaiement` qui poll `fetchStatus` toutes les 3 s jusqu'à PAID/FAILED ou 2 min de timeout. À PAID : `ProfileRepository.instance.charger(etat)` resync forfait + quota, snackbar succès, `popUntil` racine. FAILED : snackbar erreur. TIMEOUT PENDING : snackbar « encore en cours ».)_
- [x] Moyens affichés : **Orange Money, MTN MoMo, Moov Money, Wave** (tous supportés par Flex Transfer). Payload du `checkout` : `moyen: 'orange'|'mtn'|'moov'|'wave'`. _(Carte bancaire retirée de la liste `_moyens` (non supportée par Flex Transfer). Les 4 moyens restants correspondent exactement à l'enum `MoyenPaiement`.)_
- [x] Gérer erreurs : paiement refusé, timeout, numéro invalide. _(Numéro vide → snackbar « Entre le numéro… ». `ApiException` du checkout → snackbar avec `e.message`. Timeout → message dédié. Erreur réseau catch générique → « Impossible de joindre le serveur ».)_

### Côté API
_Voir `klemi-api/guide/PLAN_INTEGRATION_MOBILE.md` Phase 6._

### Vérification Phase 6
- [ ] Simulateur mobile money dev : transaction aboutit, `AppState.forfait` passe à `Premium`, `generationsRestantes` augmente. **Vérification manuelle** requise dès que le dev Railway exposera les endpoints Flex Transfer + un flow simulateur. Le flow côté client est couvert par les 8 tests `BillingApi`.
- [x] `flutter analyze` : 0 nouveau warning (34 pré-existants).
- [x] `flutter test` : 2 langue + 7 ApiClient + 6 MobileAuthApi + 8 MobileFeedApi + 4 FeedRepository + 7 CreationApi + 7 ProfileApi + 4 ProfileRepository + 11 SocialApi + **8 BillingApi** = **64 tests verts**.

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
| 2026-11-17 | — | Fix overflow `KlemiBoutonSecondaire` (ligne 98) : `Flexible` + `maxLines:1` + `ellipsis` + `mainAxisSize.min`. Déclencheur « Code établissement » sur iPhone 16 Pro. | — |
| 2026-11-17 | P2 | **Phase 2 livrée côté mobile** : split langue de lecture (fr/en) / langue d'écoute (5 langues) dans `langues.dart` + `AppState` + `ApiClient` (nouveau header `x-language-audio`). Parsing JSON `FeedItem`/`QuizItem`/`FicheItem`/`PodcastItem` + factory `feedItemDepuisJson`. `MobileFeedApi` (fetchFeed/fetchOne/answerQuiz/like/save, 501 reconnu via `estBientotDisponible`). `FeedRepository extends ChangeNotifier` avec cache par tab, pagination curseur, invalidation sur changement langue, fallback mock via `ApiUrl.useMock`. `feed_page` refactorée (états chargement/erreur/vide, pull-to-refresh, scroll infini à 3 items, empty-state langue). `carte_quiz` optimiste avec `answerQuiz` + fallback offline, rail like/save → snackbar « Bientôt ». Tests : 8 `MobileFeedApi` + 4 `FeedRepository` + mise à jour langue → **27 verts**. **Rendu avec vraies données bloqué** par seed/déploiement dev. | — |
| 2026-11-17 | P3 | **Phase 3 livrée côté mobile** : `CreationApi` avec 11 méthodes (quiz/fiche × fichier/images/youtube/texte + podcast multi-source + polling `statutJob`). `KlemiZonePhotos` widget réordonnable (drag haptique, badges d'ordre 1-N, croix suppression, picker caméra/galerie via bottom-sheet, compression auto > 10 Mo, max 10 photos). Permissions iOS (Info.plist) + Android (Manifest). `CreerPage` refactorée : bandeau d'avertissement langue en haut (recalcule selon type quiz/fiche/podcast → `langue` vs `langueAudio`), picker langue in-page retiré, `_zoneSource` branche `KlemiZonePhotos` quand `_source='photo'`, submit async via `_lancerGeneration` qui dispatche sur type×source, gestion 400 `UNSUPPORTED_LANGUAGE` + 402 `QUOTA_DEPASSE` + rejet local podcast+images. Audit `fontFamilyFallback` sur `carte_quiz`/`carte_fiche`/`carte_podcast` + `AppTheme.theme()` TextTheme (couvre tous les Text héritant du thème). 7 tests `CreationApi` → **32 tests verts au total**. **Vérification end-to-end bloquée** par Paramètres Phase 4 (picker langueAudio) + API endpoints `/files/upload`, `/files/upload-multiple-images`, `/fiches-de-revision`, `/podcasts` déployés. | — |
| 2026-11-17 | P4 | **Phase 4 livrée côté mobile** : `ProfileApi` (chargerProfil / mettreAJourProfil / préférences / biblio paginée / quota / pingStreak) + DTO `ProfilUtilisateur` opaque. `ProfileRepository extends ChangeNotifier` singleton avec `charger(AppState)` silencieux, `pingStreakSiNecessaire()` idempotente par jour (clé `SharedPreferences`), `mettreAJourPreference` optimiste avec rollback. `AppState.definirDepuisProfil()` absorbe le payload en un seul `notifyListeners` + `definirQuota()` pour le refresh post-génération. `splash_screen.dart` déclenche profil + streak ping en fire-and-forget après session restaurée. `parametres_page.dart` refactorée : nouveau widget `_ChoixLangues` avec **deux pickers distincts** (lecture fr/en + écoute 5 langues) + `AlertDialog` de confirmation pour la lecture (impact feed écrit) + invalidation `FeedRepository` + PATCH backend. Tous les toggles préférences passent par le helper optimiste `_togglePref`. 7 tests `ProfileApi` + 4 `ProfileRepository` = **45 tests verts au total**. **Vérification end-to-end bloquée** par déploiement API `/mobile/me/*`. Biblio UI + formulaire d'édition profil reportés en Phase 4.5. | — |
| 2026-11-17 | — | Retrait bouton « Code établissement » de `connexion_page.dart` — ne reste que « Google » qui prend toute la largeur. | — |
| 2026-11-17 | P5 | **Phase 5 livrée côté mobile** : `SocialApi` (14 méthodes couvrant creators / follows / content-likes / content-comments / notifications / push-token) + DTO `CreateurAvecContenus`, `PageCommentaires`, `PageNotifications`. Factory `fromJson` ajoutées sur `Createur`, `Commentaire`, `NotificationApp`, `ContenuResume` avec mapping des `NotificationType` serveur vers l'enum Dart. `AppState` étendu : `suivis` devient mutable, `notificationsNonLues` + `definirSuivis` + `definirNotificationsNonLues` + `decrementerNotificationsNonLues`. `PushService` interface + stub (pas de Firebase pour l'instant — le switch vers `FcmPushService` concret se fera quand le projet Firebase Klemi sera provisionné). Pages Social branchées : `profil_createur_page` (follow/unfollow optimiste + rollback + capture `ScaffoldMessenger` avant await), `commentaires_sheet` (chargement API avec fallback mock, états chargement/erreur/vide, post optimiste avec remplacement par réponse serveur), `notifications_page` (chargement + mark read optimiste + bouton « Tout lire » parallèle, sync compteur). `carte_quiz` : vrai toggle like (`SocialApi.likeItem/unlikeItem`) avec état `_aime` + `_likes` optimiste + rollback silencieux + bascule icône `favorite_border`/`favorite`. 11 tests `SocialApi` → **56 tests verts au total**. **FCM push + SSE badge temps réel reportés** (attente credentials Firebase + `FcmPushService`). | — |
| 2026-11-17 | P6 | **Phase 6 livrée côté mobile** : `BillingApi` (3 méthodes `fetchPlans` / `checkout` / `fetchStatus`) + enums `MoyenPaiement` (orange/mtn/moov/wave, Flex Transfer) et `DureeAbo` (monthly/annual) + DTOs `ForfaitDispo`, `CheckoutResultat` (avec `paymentUrl` optionnel), `StatutPaiement` avec helpers paye/enAttente/echoue. `forfaits_page.dart` : chargement au mount depuis `GET /mobile/plans` avec fallback mock + préservation du choix utilisateur. `paiement_page.dart` refactorée : retrait de la carte bancaire (non supportée par Flex Transfer), `_payer()` capture `ScaffoldMessenger`/`Navigator`/`AppState` avant les awaits, appelle `checkout` puis poll `_attendrePaiement()` toutes les 3 s pendant 2 min, à PAID → `ProfileRepository.instance.charger(etat)` + snackbar + popUntil racine, à FAILED → snackbar message serveur, timeout PENDING → message dédié. Validation numéro vide. 8 tests `BillingApi` → **64 tests verts au total**. **Vérification end-to-end bloquée** par exposition Flex Transfer côté dev + simulateur mobile money. | — |
