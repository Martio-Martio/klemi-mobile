import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../Configuration/app_theme.dart';

/// Limite backend : `FileFieldsInterceptor({maxCount: 10})` dans
/// `klemi-api/src/controllers/files.controller.ts:81-100` (audit).
const int kMaxPhotos = 10;

/// Au-delà, on compresse automatiquement avant envoi.
const int kSeuilCompressionOctets = 10 * 1024 * 1024; // 10 Mo

/// Zone de dépôt multi-images pour `CreerPage`. Expose la liste ordonnée
/// des photos sélectionnées via [onChanged] — l'ordre affiché = l'ordre
/// envoyé au backend.
class KlemiZonePhotos extends StatefulWidget {
  final List<File> photos;
  final ValueChanged<List<File>> onChanged;

  /// Overrides pour les tests — en prod on utilise les singletons du plugin.
  final ImagePicker? picker;

  const KlemiZonePhotos({
    super.key,
    required this.photos,
    required this.onChanged,
    this.picker,
  });

  @override
  State<KlemiZonePhotos> createState() => _KlemiZonePhotosState();
}

class _KlemiZonePhotosState extends State<KlemiZonePhotos> {
  late final ImagePicker _picker = widget.picker ?? ImagePicker();

  Future<void> _ouvrirPicker() async {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.blanc,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.bordure,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined, color: AppTheme.navy),
              title: const Text('Prendre une photo'),
              onTap: () {
                Navigator.of(ctx).pop();
                _prendrePhoto();
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: AppTheme.navy),
              title: const Text('Importer depuis la galerie'),
              onTap: () {
                Navigator.of(ctx).pop();
                _importerGalerie();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _prendrePhoto() async {
    try {
      final xfile = await _picker.pickImage(source: ImageSource.camera, maxWidth: 2048);
      if (xfile != null) await _ajouter([xfile]);
    } on PlatformException catch (e) {
      _afficherErreurPermission(e);
    }
  }

  Future<void> _importerGalerie() async {
    try {
      final xfiles = await _picker.pickMultiImage(maxWidth: 2048);
      if (xfiles.isNotEmpty) await _ajouter(xfiles);
    } on PlatformException catch (e) {
      _afficherErreurPermission(e);
    }
  }

  Future<void> _ajouter(List<XFile> xfiles) async {
    final courantes = List<File>.of(widget.photos);
    final libres = kMaxPhotos - courantes.length;
    if (libres <= 0) {
      _afficherMessage('$kMaxPhotos photos maximum par génération.');
      return;
    }
    final aAjouter = xfiles.take(libres);
    if (xfiles.length > libres) {
      _afficherMessage('Seules les $libres premières photos ont été ajoutées (limite : $kMaxPhotos).');
    }

    for (final xf in aAjouter) {
      final f = File(xf.path);
      final compresse = await _compresserSiNecessaire(f);
      courantes.add(compresse);
    }
    widget.onChanged(courantes);
  }

  Future<File> _compresserSiNecessaire(File f) async {
    final taille = await f.length();
    if (taille <= kSeuilCompressionOctets) return f;
    final dir = await getTemporaryDirectory();
    final cible = p.join(dir.path, 'klemi_${DateTime.now().microsecondsSinceEpoch}.jpg');
    final resultat = await FlutterImageCompress.compressAndGetFile(
      f.absolute.path,
      cible,
      quality: 80,
      minWidth: 2048,
      minHeight: 2048,
    );
    return resultat == null ? f : File(resultat.path);
  }

  void _retirer(int index) {
    final liste = List<File>.of(widget.photos)..removeAt(index);
    widget.onChanged(liste);
  }

  void _reordonner(int ancien, int nouveau) {
    final liste = List<File>.of(widget.photos);
    final file = liste.removeAt(ancien);
    liste.insert(nouveau > ancien ? nouveau - 1 : nouveau, file);
    HapticFeedback.selectionClick();
    widget.onChanged(liste);
  }

  void _afficherErreurPermission(PlatformException e) {
    final msg = e.code == 'camera_access_denied' || e.code == 'photo_access_denied'
        ? 'Permission refusée. Active l\'accès dans les réglages de ton téléphone.'
        : 'Impossible d\'ouvrir : ${e.message ?? e.code}';
    _afficherMessage(msg);
  }

  void _afficherMessage(String m) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(m), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.photos.isEmpty) return _vuePlaceholder();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _grille(),
        const SizedBox(height: 8),
        _ligneCompteur(),
      ],
    );
  }

  Widget _vuePlaceholder() {
    return InkWell(
      onTap: _ouvrirPicker,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.beigeClair,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.bordurePointillee, width: 2),
        ),
        child: const Column(
          children: [
            Icon(Icons.photo_camera_outlined, size: 36, color: AppTheme.navy),
            SizedBox(height: 8),
            Text(
              'Ajoute des photos de ton cours',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.navy),
            ),
            SizedBox(height: 4),
            Text(
              '1 à $kMaxPhotos photos · appareil ou galerie',
              style: TextStyle(fontSize: 12, color: AppTheme.texteDiscret),
            ),
          ],
        ),
      ),
    );
  }

  Widget _grille() {
    // ReorderableListView (horizontal) + wrap aurait été plus idiomatique mais
    // moins propre visuellement — on construit une grille 3 col à la main,
    // chaque cellule étant un `LongPressDraggable`. Flutter n'a pas de
    // ReorderableGridView en SDK ; cette implémentation évite une dep tierce.
    return LayoutBuilder(
      builder: (context, contraintes) {
        const colonnes = 3;
        const espace = 8.0;
        final tuileLargeur = (contraintes.maxWidth - espace * (colonnes - 1)) / colonnes;
        final items = widget.photos;
        final nbCases = items.length + (items.length < kMaxPhotos ? 1 : 0);
        return Wrap(
          spacing: espace,
          runSpacing: espace,
          children: [
            for (var i = 0; i < nbCases; i++)
              SizedBox(
                width: tuileLargeur,
                height: tuileLargeur,
                child: i < items.length
                    ? _tuilePhoto(i, items[i])
                    : _tuileAjouter(),
              ),
          ],
        );
      },
    );
  }

  Widget _tuilePhoto(int index, File file) {
    return LongPressDraggable<int>(
      data: index,
      feedback: Material(
        color: Colors.transparent,
        child: Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.radiusCarte),
            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10)],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppTheme.radiusCarte),
            child: Image.file(file, fit: BoxFit.cover),
          ),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.3, child: _apercu(file)),
      child: DragTarget<int>(
        onAcceptWithDetails: (details) => _reordonner(details.data, index),
        builder: (ctx, _, _) => Stack(
          children: [
            Positioned.fill(child: _apercu(file)),
            // Badge d'ordre
            Positioned(
              top: 4,
              left: 4,
              child: Container(
                width: 22,
                height: 22,
                decoration: const BoxDecoration(
                  color: AppTheme.navy,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(
                    color: AppTheme.blanc,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            // Croix suppression
            Positioned(
              top: 2,
              right: 2,
              child: InkWell(
                onTap: () => _retirer(index),
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: const BoxDecoration(
                    color: AppTheme.blanc,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: const Icon(Icons.close, size: 16, color: AppTheme.navy),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _apercu(File file) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppTheme.radiusCarte),
      child: Image.file(file, fit: BoxFit.cover),
    );
  }

  Widget _tuileAjouter() {
    return InkWell(
      onTap: _ouvrirPicker,
      borderRadius: BorderRadius.circular(AppTheme.radiusCarte),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.beigeClair,
          borderRadius: BorderRadius.circular(AppTheme.radiusCarte),
          border: Border.all(color: AppTheme.bordurePointillee, width: 2),
        ),
        child: const Center(child: Icon(Icons.add, size: 28, color: AppTheme.navy)),
      ),
    );
  }

  Widget _ligneCompteur() {
    final n = widget.photos.length;
    return FutureBuilder<int>(
      future: _tailleTotaleOctets(),
      builder: (ctx, snap) {
        final mo = snap.hasData ? (snap.data! / (1024 * 1024)).toStringAsFixed(1) : '…';
        return Text(
          '$n photo${n > 1 ? 's' : ''} · ~$mo Mo',
          style: const TextStyle(fontSize: 12, color: AppTheme.texteDiscret),
        );
      },
    );
  }

  Future<int> _tailleTotaleOctets() async {
    var total = 0;
    for (final f in widget.photos) {
      total += await f.length();
    }
    return total;
  }
}
