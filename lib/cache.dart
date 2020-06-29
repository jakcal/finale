import 'package:sqflite/sqflite.dart';

/// Stores image IDs in an SQLite database.
class ImageIdCache {
  Database db;

  static ImageIdCache _instance;

  factory ImageIdCache() {
    if (_instance == null) {
      _instance = ImageIdCache._();
    }

    return _instance;
  }

  ImageIdCache._();

  Future<void> setup() async {
    db = await openDatabase('imageId.db',
        version: 1,
        onCreate: (Database db, int version) =>
            db.execute('CREATE TABLE ImageId (url TEXT, imageId TEXT)'));
  }

  Future<int> insert(String url, String imageId) =>
      db.insert('ImageId', {'url': url, 'imageId': imageId});

  Future<String> get(String url) async {
    final results = await db.query('ImageId',
        columns: ['imageId'], where: 'url = ?', whereArgs: [url]);

    if (results.length > 0) {
      return results.first['imageId'];
    }

    return null;
  }

  Future<int> drop() => db.delete('ImageId');
}
