import 'dart:convert';

import 'package:flutter/services.dart';

import '../Models/pays.dart';

/// Charge et filtre le catalogue d'indicatifs.
class CataloguePays {
  static List<Pays>? _cache;

  static Future<List<Pays>> charger() async {
    final deja = _cache;
    if (deja != null) return deja;
    final brut = await rootBundle.loadString('lib/constants/pays.json');
    return _cache = paysDepuisJson(brut);
  }
}

List<Pays> paysDepuisJson(String source) {
  final brut = jsonDecode(source);
  if (brut is! List) return const [];
  final liste = <Pays>[];
  for (final entree in brut) {
    if (entree is! Map) continue;
    final pays = Pays.depuisJson(Map<String, dynamic>.from(entree));
    if (pays.callingCodes.isEmpty) continue;
    liste.add(pays);
  }
  liste.sort(
    (a, b) => normaliserRecherche(a.text).compareTo(normaliserRecherche(b.text)),
  );
  return liste;
}

Pays paysParDefaut(List<Pays> liste) {
  for (final pays in liste) {
    if (pays.code == 'ML') return pays;
  }
  for (final pays in liste) {
    if (pays.callingCodes == '+223') return pays;
  }
  return liste.isEmpty ? paysMaliSecours : liste.first;
}

List<Pays> filtrerPays(List<Pays> pays, String requete) {
  final q = normaliserRecherche(requete.trim());
  if (q.isEmpty) return pays;
  return pays.where((p) {
    final blob = normaliserRecherche(
      '${p.text} ${p.name} ${p.code ?? ''} ${p.callingCodes}',
    );
    return blob.contains(q);
  }).toList();
}

/// Minuscules, sans accents, pour la recherche et le tri.
String normaliserRecherche(String valeur) {
  const remplacements = {
    'à': 'a',
    'á': 'a',
    'â': 'a',
    'ä': 'a',
    'ã': 'a',
    'å': 'a',
    'è': 'e',
    'é': 'e',
    'ê': 'e',
    'ë': 'e',
    'ì': 'i',
    'í': 'i',
    'î': 'i',
    'ï': 'i',
    'ò': 'o',
    'ó': 'o',
    'ô': 'o',
    'ö': 'o',
    'õ': 'o',
    'ù': 'u',
    'ú': 'u',
    'û': 'u',
    'ü': 'u',
    'ý': 'y',
    'ÿ': 'y',
    'ç': 'c',
    'ñ': 'n',
    'œ': 'oe',
    'æ': 'ae',
  };
  final buffer = StringBuffer();
  for (final rune in valeur.toLowerCase().runes) {
    final caractere = String.fromCharCode(rune);
    buffer.write(remplacements[caractere] ?? caractere);
  }
  return buffer.toString();
}
