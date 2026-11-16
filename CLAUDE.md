# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Klemi Mobile — a Flutter app (package name `klemi`, Dart SDK `^3.9.2`) that replaces the old launcher-to-website setup with a native vertical "TikTok-style" feed of educational content: quizzes, revision sheets (`fiches`), and podcasts. The content is multilingual: French, English, Bamanankan, Soso, Pular.

The reference design is the canvas **« Klemi Mobile — Feed »**. Screen numbers (1.1 → 3.4) from that canvas are referenced in page comments — when editing or adding a page, keep that numbering in sync so the mapping to the design stays legible.

## Common commands

```bash
flutter pub get          # install dependencies
flutter run              # run on the connected device/emulator (portrait only)
flutter analyze          # static analysis (uses analysis_options.yaml)
flutter test             # run widget tests under test/
flutter test test/widget_test.dart -p "name of test"   # run a single test by name
flutter pub run flutter_launcher_icons                 # regenerate app icons from assets/logos/K_white.png
```

`analysis_options.yaml` excludes `build/`, `android/`, `ios/`, `web/`, `windows/`, `macos/`, `linux/` from analysis — don't try to lint-fix anything under those directories.

## Architecture

### Entry point and shell
- `lib/main.dart` locks orientation to portrait, configures `EasyLoading`, and wraps the app in a single `ChangeNotifierProvider<AppState>` before `MaterialApp`.
- `lib/splash_screen.dart` triggers `AppState.charger()` (load persisted session) then routes to either `ConnexionPage` (not logged in) or `AppShell` (logged in).
- `lib/Pages/app_shell.dart` is the authenticated shell: a bottom tab bar (`BarreNavigation`) with 5 slots — Feed · Explorer · Créer · Biblio · Profil — rendered inside an `IndexedStack` so tab state is preserved. The shell also owns a `ValueNotifier<ContenuResume?>` so Explorer can deep-link a piece of content into the Feed tab via `_ouvrirDansFeed`.

### State
- Single global store: `lib/Providers/app_state.dart` (`AppState extends ChangeNotifier`), consumed via `provider`. It persists a small subset to `SharedPreferences`: language id (`langue`), auth flag (`connecte`), study level (`niveau`), and the custom subjects list (`matieres`). The rest (points, streak, forfait, generations left, follows) lives in memory for the demo and is expected to come from the API later.
- Two separate "niveau" concepts coexist on `AppState` and must not be conflated:
  - `niveau` (int) + `nomNiveau` / `pointsNiveauSuivant` → gamification tier.
  - `niveauEtudes` (`NiveauEtudes` enum from `Configuration/matieres.dart`) → school level (primaire, college, lycee, superieur, formation). This drives the default `matieres` list.

### Content model and mock data
- `lib/Models/feed_item.dart` defines the sealed-style hierarchy: `FeedItem` (abstract) → `QuizItem` / `FicheItem` / `PodcastItem`, keyed by `TypeContenu` enum. Each type has its own card page under `lib/Pages/Feed/` (`carte_quiz.dart`, `carte_fiche.dart`, `carte_podcast.dart`) rendered inside the feed scroller.
- `lib/Models/social.dart` defines `Createur`, `ContenuResume`, `Cours`, `Commentaire`, `Notification` for the Explorer/Social surfaces.
- All current data is stubbed: `lib/Data/mock_feed.dart` and `lib/Data/mock_social.dart`. These are marked as placeholders for a real API (`GET /feed` paginated by cursor, filtered by language). Treat them as fixtures — when wiring real endpoints, keep the model shapes stable so the UI doesn't need rewriting.
- `lib/Configuration/api_url.dart` is intentionally empty. `lib/Configuration/dbhelper.dart` is legacy sqflite code carried over from a previous e-commerce project (tables like `panier`, `articleTendance`) — **it is not used by the Klemi feed UI**. Don't extend it; new persistence should go through `SharedPreferences` or a new layer.

### Naming convention (important)
The codebase mixes French and English deliberately: domain/UI names are **French** (`KlemiBouton`, `carte_feed.dart`, `creer_page.dart`, `matieres`, `forfait`, `suivis`, `connecte`, `langue`), framework primitives stay English. New code should follow this — don't rename existing French identifiers to English, and name new widgets/pages in French to match (`carte_*.dart` for feed cards, `*_page.dart` for routes, `KlemiXxx` for reusable widgets).

Top-level directory names under `lib/` are PascalCase (`Pages/`, `Widgets/`, `Models/`, `Data/`, `Providers/`, `Configuration/`), while file names inside are snake_case. Keep that split.

### Design system
- `lib/Configuration/app_theme.dart` is the single source of truth for colors, radii, and the Material 3 `ThemeData`. Palette: beige backgrounds, navy text, with accent colors `bleu` (actions), `orange` (quiz), `vert` (fiches/success), `rouge` (errors). Use the named constants (`AppTheme.bleu`, `AppTheme.navy`, `AppTheme.radiusCarte`) rather than hard-coded hex or magic numbers.
- Font: **Lato** (bundled under `assets/fonts/Lato/`). Lato does not render the characters `ɛ ɔ ɓ ɗ ŋ` used by Bamanankan, Soso and Pular — any `Text` widget that may display translated content must set `fontFamilyFallback: AppTheme.famillesSecours` (which points to the bundled `NotoSansFallback`). This is easy to forget in new widgets.
- Shared UI kit: `lib/Widgets/klemi_widgets.dart` (buttons, inputs, segments, chips, avatars), `barre_navigation.dart` (bottom tabs + `OngletApp` enum), `carte_feed.dart` (feed card frame with rail/caption/swipe), `ligne_contenu.dart`, `langue_widgets.dart` (language picker sheet). Prefer extending these over building ad-hoc widgets.

### Languages
`lib/Configuration/langues.dart` is the canonical list of content languages, each with a short `code` (FR, EN, BM, SO, FF), an **API id** (`fr`, `en`, `bm`, `sus`, `ful`), and a localized CTA label. When calling the (future) API, always use the `id` field, not `code`. `languesBientot` holds "coming soon" languages shown read-only in the UI.

## Branches

`main` for PRs in this repo is `devJeanLouisAGOUSSI` (not `master`/`main`). Developer branches are named `dev<Name>` (e.g. `devYvesBoah`).
