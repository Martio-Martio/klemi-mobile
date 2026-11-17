import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';

import '../Configuration/api_client.dart';
import '../Models/feed_item.dart';
import 'api_exception.dart';

/// Types de contenus générables côté mobile. Les langues autorisées dépendent
/// du type — règle vérifiée côté UI *avant* l'appel (évite le round-trip
/// `UNSUPPORTED_LANGUAGE`).
enum TypeCreation { quiz, fiche, podcast }

/// Source utilisée pour nourrir le générateur IA. L'API accepte 4 formes :
/// fichier(s), lien YouTube, texte brut. Chacune a son endpoint dédié.
sealed class SourceCreation {
  const SourceCreation();
}

class SourceFichier extends SourceCreation {
  final File fichier;
  const SourceFichier(this.fichier);
}

class SourceImages extends SourceCreation {
  /// Liste **ordonnée** d'images. L'ordre pédagogique affiché à l'utilisateur
  /// est préservé dans le multipart (plan Phase 3).
  final List<File> images;
  const SourceImages(this.images);
}

class SourceYoutube extends SourceCreation {
  final String url;
  const SourceYoutube(this.url);
}

class SourceTexte extends SourceCreation {
  final String texte;
  const SourceTexte(this.texte);
}

/// Options spécifiques à chaque type de contenu. On centralise ici pour que
/// la signature de `CreationApi` reste stable.
class OptionsCreation {
  /// Nombre de questions (quiz uniquement). Clamped 5..40 côté UI.
  final int nombreQuestions;

  /// Durée du podcast : `'court'` (≈5 min) ou `'moyen'` (≈12 min).
  final String? dureePodcast;

  /// Titre optionnel pour les contenus où l'IA en génère un par défaut.
  final String? titre;

  const OptionsCreation({
    this.nombreQuestions = 10,
    this.dureePodcast,
    this.titre,
  });
}

/// Job asynchrone renvoyé par la plupart des endpoints de génération.
/// L'item final est servi via le polling [CreationApi.statutJob].
class JobCreation {
  final String jobId;

  /// Statut immédiat : parfois l'API renvoie l'item directement sans job
  /// (ex. génération de fiche depuis texte court).
  final FeedItem? itemImmediat;

  const JobCreation({required this.jobId, this.itemImmediat});
}

/// Statuts possibles d'un job côté backend. On garde une couche utilitaire
/// plutôt qu'une enum Dart stricte — les valeurs exactes dépendent du
/// module (Bull / SSE) et peuvent évoluer.
class StatutJob {
  final String etat; // 'pending' | 'processing' | 'done' | 'failed'
  final int pourcentage; // 0..100
  final String? message;
  final FeedItem? item; // non null quand etat == 'done'
  final String? erreur;

  const StatutJob({
    required this.etat,
    this.pourcentage = 0,
    this.message,
    this.item,
    this.erreur,
  });

  bool get termine => etat == 'done';
  bool get echoue => etat == 'failed';
}

/// Wrapper des endpoints de génération. Chaque méthode injecte
/// systématiquement `language` — jamais laisser optionnel côté client,
/// même si l'API le tolère (voir plan Phase 3).
class CreationApi {
  final ApiClient _client;

  CreationApi([ApiClient? client]) : _client = client ?? ApiClient.instance;

  // ─── Quiz ──────────────────────────────────────────────────────────────

  Future<JobCreation> genererQuizDepuisFichier(
    SourceFichier source, {
    required String language,
    required OptionsCreation options,
  }) async {
    return _uploadFichierVersJob(
      path: '/files/upload',
      champFichier: 'file',
      fichier: source.fichier,
      champs: _champsCommuns(language, TypeCreation.quiz, options),
    );
  }

  Future<JobCreation> genererQuizDepuisImages(
    SourceImages source, {
    required String language,
    required OptionsCreation options,
  }) async {
    return _uploadImagesVersJob(
      path: '/files/upload-multiple-images',
      images: source.images,
      champs: _champsCommuns(language, TypeCreation.quiz, options),
    );
  }

  Future<JobCreation> genererQuizDepuisYoutube(
    SourceYoutube source, {
    required String language,
    required OptionsCreation options,
  }) async {
    final reponse = await _client.post(
      '/files/youtube-qcm',
      body: {
        'url': source.url,
        'language': language,
        ..._champsCommuns(language, TypeCreation.quiz, options),
      },
    ) as Map<String, dynamic>;
    return _parserJob(reponse);
  }

  Future<JobCreation> genererQuizDepuisTexte(
    SourceTexte source, {
    required String language,
    required OptionsCreation options,
  }) async {
    final reponse = await _client.post(
      '/quiz',
      body: {
        'texte': source.texte,
        'language': language,
        ..._champsCommuns(language, TypeCreation.quiz, options),
      },
    ) as Map<String, dynamic>;
    return _parserJob(reponse);
  }

  // ─── Fiche ─────────────────────────────────────────────────────────────

  Future<JobCreation> genererFicheDepuisFichier(
    SourceFichier source, {
    required String language,
    required OptionsCreation options,
  }) async {
    return _uploadFichierVersJob(
      path: '/fiches-revision-files/upload',
      champFichier: 'file',
      fichier: source.fichier,
      champs: _champsCommuns(language, TypeCreation.fiche, options),
    );
  }

  Future<JobCreation> genererFicheDepuisImages(
    SourceImages source, {
    required String language,
    required OptionsCreation options,
  }) async {
    return _uploadImagesVersJob(
      path: '/revision-images/upload',
      images: source.images,
      champs: _champsCommuns(language, TypeCreation.fiche, options),
    );
  }

  Future<JobCreation> genererFicheDepuisYoutube(
    SourceYoutube source, {
    required String language,
    required OptionsCreation options,
  }) async {
    final reponse = await _client.post(
      '/youtube-fiche-revision',
      body: {
        'url': source.url,
        'language': language,
        ..._champsCommuns(language, TypeCreation.fiche, options),
      },
    ) as Map<String, dynamic>;
    return _parserJob(reponse);
  }

  Future<JobCreation> genererFicheDepuisTexte(
    SourceTexte source, {
    required String language,
    required OptionsCreation options,
  }) async {
    final reponse = await _client.post(
      '/fiches-de-revision',
      body: {
        'texte': source.texte,
        'language': language,
        ..._champsCommuns(language, TypeCreation.fiche, options),
      },
    ) as Map<String, dynamic>;
    return _parserJob(reponse);
  }

  // ─── Podcast ───────────────────────────────────────────────────────────

  Future<JobCreation> genererPodcast(
    SourceCreation source, {
    required String language,
    required OptionsCreation options,
  }) async {
    // Le module podcast accepte plusieurs sources via un unique endpoint
    // discriminé par le champ `source` du body.
    final body = <String, dynamic>{
      'language': language,
      'longueur': options.dureePodcast ?? 'moyen',
      if (options.titre != null) 'titre': options.titre,
    };
    switch (source) {
      case SourceTexte(:final texte):
        body['source'] = 'TEXT';
        body['texte'] = texte;
      case SourceYoutube(:final url):
        body['source'] = 'YOUTUBE';
        body['url'] = url;
      case SourceFichier(:final fichier):
        // Pour les fichiers PDF, upload préalable Cloudinary puis URL envoyée.
        // Pour l'instant on envoie directement le fichier en multipart —
        // à adapter quand l'API confirme le format attendu.
        return _uploadFichierVersJob(
          path: '/podcasts',
          champFichier: 'file',
          fichier: fichier,
          champs: {
            'language': language,
            'longueur': options.dureePodcast ?? 'moyen',
            'source': 'PDF',
          },
        );
      case SourceImages():
        throw ApiException(
          statusCode: 400,
          message: 'Les podcasts ne peuvent pas être générés depuis des photos. '
              'Utilise plutôt un fichier, un lien YouTube ou du texte.',
          code: 'PODCAST_IMAGES_NON_SUPPORTE',
        );
    }
    final reponse = await _client.post('/podcasts', body: body) as Map<String, dynamic>;
    return _parserJob(reponse);
  }

  // ─── Polling job ───────────────────────────────────────────────────────

  Future<StatutJob> statutJob(String jobId) async {
    final reponse = await _client.get('/files/upload-status/$jobId') as Map<String, dynamic>;
    return StatutJob(
      etat: reponse['status'] as String? ?? 'pending',
      pourcentage: (reponse['progress'] as num?)?.toInt() ?? 0,
      message: reponse['message'] as String?,
      item: reponse['item'] is Map<String, dynamic>
          ? feedItemDepuisJson(reponse['item'] as Map<String, dynamic>)
          : null,
      erreur: reponse['error'] as String?,
    );
  }

  // ─── Helpers privés ────────────────────────────────────────────────────

  Map<String, String> _champsCommuns(
    String language,
    TypeCreation type,
    OptionsCreation options,
  ) {
    return {
      'language': language,
      'type': type.name,
      if (type == TypeCreation.quiz) 'numberOfQuestions': options.nombreQuestions.toString(),
      if (options.titre != null) 'titre': options.titre!,
    };
  }

  Future<JobCreation> _uploadFichierVersJob({
    required String path,
    required String champFichier,
    required File fichier,
    required Map<String, String> champs,
  }) async {
    final mediaType = _mediaType(fichier.path);
    final multipartFile = await http.MultipartFile.fromPath(
      champFichier,
      fichier.path,
      contentType: mediaType,
    );
    final reponse = await _client.multipart(
      path,
      champs: champs,
      fichiers: [multipartFile],
    ) as Map<String, dynamic>;
    return _parserJob(reponse);
  }

  Future<JobCreation> _uploadImagesVersJob({
    required String path,
    required List<File> images,
    required Map<String, String> champs,
  }) async {
    // L'API accepte les N fichiers sous le nom de champ `file` dans un
    // `FileFieldsInterceptor` — l'ordre est préservé (audit confirmé).
    final fichiers = <http.MultipartFile>[];
    for (final img in images) {
      fichiers.add(await http.MultipartFile.fromPath(
        'file',
        img.path,
        contentType: _mediaType(img.path),
      ));
    }
    final reponse = await _client.multipart(
      path,
      champs: champs,
      fichiers: fichiers,
    ) as Map<String, dynamic>;
    return _parserJob(reponse);
  }

  MediaType? _mediaType(String chemin) {
    final m = lookupMimeType(chemin);
    if (m == null) return null;
    final parts = m.split('/');
    return parts.length == 2 ? MediaType(parts[0], parts[1]) : null;
  }

  JobCreation _parserJob(Map<String, dynamic> reponse) {
    final jobId = (reponse['jobId'] ?? reponse['id'] ?? '') as String;
    final itemBrut = reponse['item'];
    return JobCreation(
      jobId: jobId,
      itemImmediat: itemBrut is Map<String, dynamic> ? feedItemDepuisJson(itemBrut) : null,
    );
  }
}
