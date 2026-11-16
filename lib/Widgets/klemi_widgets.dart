import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../Configuration/app_theme.dart';
import '../Providers/app_state.dart';
import 'langue_widgets.dart';

/// Bouton principal plein (bleu Klemi par défaut).
class KlemiBouton extends StatelessWidget {
  final String libelle;
  final VoidCallback? onPressed;
  final Color couleur;
  final Color couleurTexte;
  final IconData? icone;
  final bool iconeADroite;
  final double hauteur;

  const KlemiBouton({
    super.key,
    required this.libelle,
    required this.onPressed,
    this.couleur = AppTheme.bleu,
    this.couleurTexte = AppTheme.navy,
    this.icone,
    this.iconeADroite = true,
    this.hauteur = 56,
  });

  @override
  Widget build(BuildContext context) {
    final desactive = onPressed == null;
    final enfants = <Widget>[
      Text(
        libelle,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w800,
          fontFamilyFallback: AppTheme.famillesSecours,
          color: desactive ? AppTheme.texteDiscret : couleurTexte,
        ),
      ),
      if (icone != null) ...[
        const SizedBox(width: 10),
        Icon(icone, size: 20, color: desactive ? AppTheme.texteDiscret : couleurTexte),
      ],
    ];
    return SizedBox(
      height: hauteur,
      width: double.infinity,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: couleur,
          disabledBackgroundColor: AppTheme.sable,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusCarte),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: iconeADroite ? enfants : enfants.reversed.toList(),
        ),
      ),
    );
  }
}

/// Bouton secondaire blanc avec bordure.
class KlemiBoutonSecondaire extends StatelessWidget {
  final String libelle;
  final VoidCallback? onPressed;
  final IconData? icone;
  final double hauteur;

  const KlemiBoutonSecondaire({
    super.key,
    required this.libelle,
    required this.onPressed,
    this.icone,
    this.hauteur = 50,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: hauteur,
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: AppTheme.blanc,
          side: const BorderSide(color: AppTheme.bordure),
          foregroundColor: AppTheme.navy,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusCarte),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icone != null) ...[Icon(icone, size: 18), const SizedBox(width: 8)],
            Flexible(
              child: Text(
                libelle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bascule à deux ou trois segments (Numéro / E‑mail, Mensuel / Annuel…).
class KlemiSegments extends StatelessWidget {
  final List<String> libelles;
  final int index;
  final ValueChanged<int> onChanged;

  const KlemiSegments({
    super.key,
    required this.libelles,
    required this.index,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.sable,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          for (var i = 0; i < libelles.length; i++)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  height: 40,
                  decoration: BoxDecoration(
                    color: i == index ? AppTheme.blanc : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    libelles[i],
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.navy,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Champ avec étiquette au‑dessus.
class KlemiChamp extends StatelessWidget {
  final String etiquette;
  final String? indice;
  final TextInputType? type;
  final bool secret;
  final TextEditingController? controleur;
  final Widget? prefixe;

  const KlemiChamp({
    super.key,
    required this.etiquette,
    this.indice,
    this.type,
    this.secret = false,
    this.controleur,
    this.prefixe,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          etiquette,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            if (prefixe != null) ...[prefixe!, const SizedBox(width: 8)],
            Expanded(
              child: TextField(
                controller: controleur,
                keyboardType: type,
                obscureText: secret,
                style: const TextStyle(fontSize: 16, color: AppTheme.navy),
                decoration: InputDecoration(hintText: indice),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Indicatif pays (+223 Mali par défaut).
class IndicatifPays extends StatelessWidget {
  final String indicatif;
  const IndicatifPays({super.key, this.indicatif = '+223'});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppTheme.blanc,
        borderRadius: BorderRadius.circular(AppTheme.radiusChamp),
        border: Border.all(color: AppTheme.bordure),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: SizedBox(
              width: 22,
              height: 15,
              child: Row(
                children: const [
                  Expanded(child: ColoredBox(color: Color(0xFF14B53A))),
                  Expanded(child: ColoredBox(color: Color(0xFFFCD116))),
                  Expanded(child: ColoredBox(color: Color(0xFFCE1126))),
                ],
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            indicatif,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          const Icon(Icons.expand_more, size: 16),
        ],
      ),
    );
  }
}

/// Pastille d'avatar (initiales sur fond coloré).
class Avatar extends StatelessWidget {
  final String initiales;
  final Color couleur;
  final double taille;
  final bool bordure;

  const Avatar({
    super.key,
    required this.initiales,
    this.couleur = AppTheme.orange,
    this.taille = 44,
    this.bordure = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: taille,
      height: taille,
      decoration: BoxDecoration(
        color: couleur,
        shape: BoxShape.circle,
        border: bordure ? Border.all(color: AppTheme.blanc, width: 2) : null,
      ),
      alignment: Alignment.center,
      child: Text(
        initiales,
        style: TextStyle(
          fontSize: taille * 0.36,
          fontWeight: FontWeight.w800,
          color: AppTheme.navy,
        ),
      ),
    );
  }
}

/// Petite puce « Quiz », « Fiche », « Podcast ».
class ChipType extends StatelessWidget {
  final String libelle;
  final IconData icone;
  final Color couleur;

  const ChipType({
    super.key,
    required this.libelle,
    required this.icone,
    required this.couleur,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: couleur,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icone, size: 13, color: AppTheme.navy),
          const SizedBox(width: 6),
          Text(
            libelle.toUpperCase(),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
              color: AppTheme.navy,
            ),
          ),
        ],
      ),
    );
  }
}

/// Chip de langue (« FR ▾ ») en haut des écrans. Sans `code`, affiche la
/// langue courante ; sans `onTap`, ouvre le sélecteur de langue.
class ChipLangue extends StatelessWidget {
  final String? code;
  final VoidCallback? onTap;
  const ChipLangue({super.key, this.code, this.onTap});

  @override
  Widget build(BuildContext context) {
    final code = this.code ?? context.watch<AppState>().langue.code;
    return InkWell(
      onTap: onTap ?? () => ouvrirSelecteurLangue(context),
      borderRadius: BorderRadius.circular(999),
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: AppTheme.blanc,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppTheme.bordure),
        ),
        child: Row(
          children: [
            Text(
              code,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
            const Icon(Icons.expand_more, size: 14),
          ],
        ),
      ),
    );
  }
}

/// Bouton rond « retour ».
class BoutonRetour extends StatelessWidget {
  final VoidCallback? onTap;
  const BoutonRetour({super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap ?? () => Navigator.of(context).maybePop(),
      customBorder: const CircleBorder(),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: AppTheme.blanc,
          shape: BoxShape.circle,
          border: Border.all(color: AppTheme.bordure),
        ),
        child: const Icon(Icons.arrow_back, size: 20, color: AppTheme.navy),
      ),
    );
  }
}

/// Carte blanche standard.
class CarteBlanche extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? couleurBordure;
  final double largeurBordure;

  const CarteBlanche({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.couleurBordure,
    this.largeurBordure = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: AppTheme.blanc,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: couleurBordure ?? AppTheme.bordure,
          width: largeurBordure,
        ),
      ),
      child: child,
    );
  }
}

/// Logo Klemi + nom.
class LogoKlemi extends StatelessWidget {
  final double taille;
  const LogoKlemi({super.key, this.taille = 48});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset('assets/logos/logo_klemi.png', width: taille, height: taille),
        const SizedBox(width: 10),
        const Text(
          'Klemi',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
            color: AppTheme.navy,
          ),
        ),
      ],
    );
  }
}

/// Transition « glisser depuis le bas » utilisée entre les écrans.
Route<T> routeGlissante<T>(Widget page) {
  return PageRouteBuilder<T>(
    transitionDuration: const Duration(milliseconds: 350),
    pageBuilder: (_, _, _) => page,
    transitionsBuilder: (_, animation, _, child) {
      final tween = Tween(
        begin: const Offset(1, 0),
        end: Offset.zero,
      ).chain(CurveTween(curve: Curves.easeOutCubic));
      return SlideTransition(position: animation.drive(tween), child: child);
    },
  );
}
