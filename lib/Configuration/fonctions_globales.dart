import 'package:intl/intl.dart';

class FonctionsGlobales {

  static String separateurMillierString(String montant) {
    final formatter = NumberFormat('#,##0', 'fr_FR');
    double value = double.tryParse(montant) ?? 0.0;

    String nombreFormate = formatter.format(value).replaceAll(',', ' ');
    return nombreFormate;
  }

  static String formaterDateSansHeure(String dateStr) {
    DateTime date = DateTime.parse(dateStr);
    DateFormat dateFormat = DateFormat('dd/MM/yyyy');
    String formattedDate = dateFormat.format(date);

    return formattedDate;
  }

  String formaterDateAvecHeure(String dateStr) {
    DateTime date = DateTime.parse(dateStr);
    DateFormat dateFormat = DateFormat('dd/MM/yyyy HH:mm');
    String formattedDate = dateFormat.format(date);

    return formattedDate;
  }

  /**
   * VOICI COMMENT J'APPEL LES PAGES AVEC LES ANIMATIONS QUI VONT AVEC.
   * */
  // Navigator.push(
  //   context,
  //   PageRouteBuilder(
  //     transitionDuration: const Duration(milliseconds: 400),
  //     pageBuilder: (context, animation, secondaryAnimation) => DetailArticlePage(idArticle: _listeNouveauxArtcle[index]["id"]),
  //     transitionsBuilder: (context, animation, secondaryAnimation, child) {
  //       const begin = Offset(0.0, 1.0);
  //       const end = Offset.zero;
  //       const curve = Curves.ease;
  //
  //       var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
  //
  //       return SlideTransition(
  //         position: animation.drive(tween),
  //         child: child,
  //       );
  //     },
  //
  //   ),
  // );

}


