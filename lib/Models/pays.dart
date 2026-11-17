/// Pays du catalogue d'indicatifs (`lib/constants/pays.json`).
class Pays {
  final String name;
  final String callingCodes;
  final String text;
  final String? map;
  final String? code;

  const Pays({
    required this.name,
    required this.callingCodes,
    required this.text,
    this.map,
    this.code,
  });

  /// Distingue deux pays qui partagent un indicatif (`+1`).
  String get identifiant {
    final iso = code;
    if (iso != null && iso.isNotEmpty) return iso;
    if (name.isNotEmpty) return name;
    return callingCodes;
  }

  factory Pays.depuisJson(Map<String, dynamic> json) {
    final nom = (json['name'] as String?)?.trim() ?? '';
    return Pays(
      name: nom,
      callingCodes: (json['callingCodes'] as String?)?.trim() ?? '',
      text: (json['text'] as String?)?.trim().isNotEmpty == true
          ? (json['text'] as String).trim()
          : nom,
      map: _texteOuNull(json['map']),
      code: _texteOuNull(json['code']),
    );
  }
}

/// Mali, indicatif affiché par défaut sur la connexion.
const Pays paysMaliSecours = Pays(
  name: 'Mali',
  callingCodes: '+223',
  text: 'Mali',
  map: '🇲🇱',
  code: 'ML',
);

String? _texteOuNull(Object? valeur) {
  if (valeur is! String) return null;
  final texte = valeur.trim();
  return texte.isEmpty ? null : texte;
}
