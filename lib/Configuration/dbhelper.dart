import 'dart:io' as io;

import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class DBHelper {
  static Database? _database;

  Future<Database?> get database async {
    _database ??= await initDatabase();
    return _database;
  }

  initDatabase() async {
    io.Directory directory = await getApplicationDocumentsDirectory();
    String path = join(directory.path, 'doma.db');
    // var db = await openDatabase(path, version: 1, onCreate: _onCreer);

    return await openDatabase(path, version: 2,
        onCreate: (Database db, int version) async {
          await _createTables(db);
        });

    // return db;
  }

  Future<void> _createTables(Database db) async {
    // Créez toutes vos tables ici
    await db.execute('CREATE TABLE presentationApplication(id INTEGER PRIMARY KEY, statut INTEGER, email TEXT)');
    await db.execute('CREATE TABLE calendrierStockage(id INTEGER PRIMARY KEY, date_stockage TEXT)');
    await db.execute('CREATE TABLE categorie(id INTEGER, name TEXT, slug TEXT, image TEXT)');
    await db.execute('CREATE TABLE sousCategorie(id INTEGER, name TEXT, slug TEXT, image TEXT, parent_id INTEGER)');
    await db.execute('CREATE TABLE nouveauArticle(id INTEGER, name TEXT, price TEXT, image TEXT, categorie_id INTEGER)');
    await db.execute('CREATE TABLE articleTendance(id INTEGER, name TEXT, price TEXT, image TEXT, categorie_id INTEGER)');
    await db.execute('CREATE TABLE utilisateurConnecte(id INTEGER, first_name TEXT, last_name TEXT, phone TEXT, email TEXT, token TEXT)');
    await db.execute('CREATE TABLE articlePanier(id INTEGER, name TEXT, price TEXT, image TEXT, stock INTEGER, quantite INTEGER)');
    await db.execute('CREATE TABLE panier(id INTEGER, nomAdresse TEXT, detailAdresse TEXT, typeAdresse INTEGER)');
  }

  // PRESENTATION APPLICATION
  Future<int> insertPresentationApplication(Map<String, dynamic> row) async {
    var db = await database;
    return await db!.insert('presentationApplication', row);
  }
  Future<List<dynamic>> recupererPresentationApplication() async {
    var dbClient = await database;
    final List<dynamic> queryResult = await dbClient!.query('presentationApplication');

    return queryResult;
  }
  Future<int> viderPresentationApplication() async {
    var dbClient = await database;

    return await dbClient!.delete('presentationApplication');
  }

  // CALENDRIER STOCKAGE
  Future<int> insertDateStockage(Map<String, dynamic> row) async {
    var db = await database;
    return await db!.insert('calendrierStockage', row);
  }
  Future<List<dynamic>> recupererDateStockage() async {
    var dbClient = await database;
    final List<dynamic> queryResult = await dbClient!.query('calendrierStockage');

    return queryResult;
  }
  Future<int> viderCalendrierStockage() async {
    var dbClient = await database;

    return await dbClient!.delete('calendrierStockage');
  }

  // CATEGORIE
  Future<int> insertCategorie(Map<String, dynamic> row) async {
    var db = await database;
    return await db!.insert('categorie', row);
  }
  Future<List<dynamic>> recupererCategorieStocker() async {
    var dbClient = await database;
    final List<dynamic> queryResult = await dbClient!.query('categorie');

    return queryResult;
  }
  Future<int> viderCategorieStocker() async {
    var dbClient = await database;

    return await dbClient!.delete('categorie');
  }

  // SOUS CATEGORIE
  Future<int> insertSousCategorie(Map<String, dynamic> row) async {
    var db = await database;
    return await db!.insert('sousCategorie', row);
  }
  Future<List<dynamic>> recupererListeSousCategorieByIdCategorie(int idCategorie) async {
    var dbClient = await database;
    final List<dynamic> queryResult = await dbClient!
        .query('sousCategorie', where: "parent_id = ?", whereArgs: [idCategorie]);

    return queryResult;
  }
  Future<int> viderSousCategorieStocker() async {
    var dbClient = await database;

    return await dbClient!.delete('sousCategorie');
  }

  // NOUVEAUX ARTICLES ou ARTICLES RECENT
  Future<int> insertNouveauxArticles(Map<String, dynamic> row) async {
    var db = await database;
    return await db!.insert('nouveauArticle', row);
  }
  Future<List<dynamic>> recupererNouveauxArticlesStocker() async {
    var dbClient = await database;
    final List<dynamic> queryResult = await dbClient!.query('nouveauArticle');

    return queryResult;
  }
  Future<int> viderNouveauxArticlesStocker() async {
    var dbClient = await database;

    return await dbClient!.delete('nouveauArticle');
  }

  // ARTICLES TENDANCES
  Future<int> insertArticlesTendance(Map<String, dynamic> row) async {
    var db = await database;
    return await db!.insert('articleTendance', row);
  }
  Future<List<dynamic>> recupererArticlesTendanceStocker() async {
    var dbClient = await database;
    final List<dynamic> queryResult = await dbClient!.query('articleTendance');

    return queryResult;
  }
  Future<int> viderArticlesTendanceStocker() async {
    var dbClient = await database;

    return await dbClient!.delete('articleTendance');
  }

  // UTILISATEUR CONNECTER
  Future<int> insertUtilisateurConnecter(Map<String, dynamic> row) async {
    var db = await database;
    return await db!.insert('utilisateurConnecte', row);
  }
  Future<List<dynamic>> recupererUtilisateurConnecter() async {
    var dbClient = await database;
    final List<dynamic> queryResult = await dbClient!.query('utilisateurConnecte');

    return queryResult;
  }
  Future<int> viderUtilisateurConnecter() async {
    var dbClient = await database;

    return await dbClient!.delete('utilisateurConnecte');
  }

  // PANIER
  Future<int> insertPanier(Map<String, dynamic> row) async {
    var db = await database;
    return await db!.insert('panier', row);
  }
  Future<List<dynamic>> recupererPanier() async {
    var dbClient = await database;
    final List<dynamic> queryResult = await dbClient!.query('panier');

    return queryResult;
  }
  Future<int> viderPanier() async {
    var dbClient = await database;

    return await dbClient!.delete('panier');
  }

  // ARTICLES PANIER
  Future<int> insertArticlePanier(Map<String, dynamic> row) async {
    var db = await database;
    return await db!.insert('articlePanier', row);
  }
  Future<List<dynamic>> recupererArticlePanier() async {
    var dbClient = await database;
    final List<dynamic> queryResult = await dbClient!.query('articlePanier');

    return queryResult;
  }
  Future<int> viderArticlePanier() async {
    var dbClient = await database;

    return await dbClient!.delete('articlePanier');
  }
  Future<dynamic> getArticlePanierById(int idArticle) async {
    var db = await database;
    final List<dynamic> result = await db!.query(
      'articlePanier',
      where: 'id = ?',
      whereArgs: [idArticle],
    );

    // return result;
    if (result.isNotEmpty) {
      return result.first;
    } else {
      return null;
    }
  }
  Future<int> updateArticlePanier(int id, Map<String, dynamic> updatedValues) async {
    var dbClient = await database;

    return await dbClient!.update('articlePanier', updatedValues,
        where: "id = ?", whereArgs: [id]);
  }
  Future<int> supprimerArticleDuPanier(int id) async {
    var dbClient = await database;

    return await dbClient!.delete('articlePanier', where: 'id = ?', whereArgs: [id]);
  }
}
