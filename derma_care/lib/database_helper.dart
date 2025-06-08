import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  DatabaseHelper._internal();

  static DatabaseHelper get instance => _instance;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'dermacare.db');

    return await openDatabase(
      path,
      version: 2, // Incremented version for migration
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE users(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        email TEXT UNIQUE NOT NULL,
        password TEXT NOT NULL,
        phone TEXT,
        profile_image TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    await db.execute('''
      CREATE TABLE user_preferences(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        notifications_enabled INTEGER DEFAULT 1,
        dark_mode_enabled INTEGER DEFAULT 0,
        auto_save_enabled INTEGER DEFAULT 1,
        offline_mode_enabled INTEGER DEFAULT 0,
        selected_language TEXT DEFAULT 'English',
        selected_theme TEXT DEFAULT 'Light',
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE scan_history(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        image_path TEXT NOT NULL,
        result TEXT,
        confidence REAL,
        scan_date TEXT NOT NULL,
        notes TEXT,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
      )
    ''');

    // Create indexes for better performance
    await db.execute('CREATE INDEX idx_users_email ON users(email)');
    await db.execute('CREATE INDEX idx_user_preferences_user_id ON user_preferences(user_id)');
    await db.execute('CREATE INDEX idx_scan_history_user_id ON scan_history(user_id)');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add any migration logic here for future updates
      try {
        await db.execute('ALTER TABLE users ADD COLUMN updated_at TEXT DEFAULT CURRENT_TIMESTAMP');
      } catch (e) {
        // Column might already exist
      }
    }
  }

  // User operations
  Future<int> insertUser(Map<String, dynamic> user) async {
    final db = await database;
    
    try {
      // Ensure required fields
      if (user['name'] == null || user['email'] == null || user['password'] == null) {
        throw Exception('Name, email, and password are required');
      }

      // Check if email already exists
      final existingUser = await db.query(
        'users',
        where: 'email = ?',
        whereArgs: [user['email']],
      );

      if (existingUser.isNotEmpty) {
        throw Exception('Email already exists');
      }

      user['created_at'] = DateTime.now().toIso8601String();
      user['updated_at'] = DateTime.now().toIso8601String();
      
      int userId = await db.insert('users', user);

      // Create default preferences for the user
      await db.insert('user_preferences', {
        'user_id': userId,
        'notifications_enabled': 1,
        'dark_mode_enabled': 0,
        'auto_save_enabled': 1,
        'offline_mode_enabled': 0,
        'selected_language': 'English',
        'selected_theme': 'Light',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      return userId;
    } catch (e) {
      throw Exception('Failed to create user: ${e.toString()}');
    }
  }

  Future<Map<String, dynamic>?> loginUser(String email, String password) async {
    final db = await database;
    
    try {
      final List<Map<String, dynamic>> maps = await db.query(
        'users',
        where: 'email = ? AND password = ?',
        whereArgs: [email.trim().toLowerCase(), password],
      );

      if (maps.isNotEmpty) {
        return maps.first;
      }
      return null;
    } catch (e) {
      throw Exception('Login failed: ${e.toString()}');
    }
  }

  Future<Map<String, dynamic>?> getUser(int userId) async {
    final db = await database;
    
    try {
      final List<Map<String, dynamic>> maps = await db.query(
        'users',
        where: 'id = ?',
        whereArgs: [userId],
      );

      if (maps.isNotEmpty) {
        return maps.first;
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get user: ${e.toString()}');
    }
  }

  Future<bool> checkEmailExists(String email) async {
    final db = await database;
    
    try {
      final List<Map<String, dynamic>> maps = await db.query(
        'users',
        where: 'email = ?',
        whereArgs: [email.trim().toLowerCase()],
      );
      
      return maps.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  Future<int> updateUser(int userId, Map<String, dynamic> user) async {
    final db = await database;
    
    try {
      user['updated_at'] = DateTime.now().toIso8601String();
      
      return await db.update(
        'users',
        user,
        where: 'id = ?',
        whereArgs: [userId],
      );
    } catch (e) {
      throw Exception('Failed to update user: ${e.toString()}');
    }
  }

  Future<int> deleteUser(int userId) async {
    final db = await database;
    
    try {
      return await db.delete(
        'users',
        where: 'id = ?',
        whereArgs: [userId],
      );
    } catch (e) {
      throw Exception('Failed to delete user: ${e.toString()}');
    }
  }

  // User preferences operations
  Future<Map<String, dynamic>?> getUserPreferences(int userId) async {
    final db = await database;
    
    try {
      final List<Map<String, dynamic>> maps = await db.query(
        'user_preferences',
        where: 'user_id = ?',
        whereArgs: [userId],
      );

      if (maps.isNotEmpty) {
        return maps.first;
      }
      
      // Create default preferences if they don't exist
      await db.insert('user_preferences', {
        'user_id': userId,
        'notifications_enabled': 1,
        'dark_mode_enabled': 0,
        'auto_save_enabled': 1,
        'offline_mode_enabled': 0,
        'selected_language': 'English',
        'selected_theme': 'Light',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });
      
      // Return the newly created preferences
      final newMaps = await db.query(
        'user_preferences',
        where: 'user_id = ?',
        whereArgs: [userId],
      );
      
      return newMaps.isNotEmpty ? newMaps.first : null;
    } catch (e) {
      throw Exception('Failed to get user preferences: ${e.toString()}');
    }
  }

  Future<int> updateUserPreferences(int userId, Map<String, dynamic> preferences) async {
    final db = await database;
    
    try {
      preferences['updated_at'] = DateTime.now().toIso8601String();
      
      return await db.update(
        'user_preferences',
        preferences,
        where: 'user_id = ?',
        whereArgs: [userId],
      );
    } catch (e) {
      throw Exception('Failed to update user preferences: ${e.toString()}');
    }
  }

  // Scan history operations
  Future<int> insertScanHistory(Map<String, dynamic> scan) async {
    final db = await database;
    
    try {
      scan['created_at'] = DateTime.now().toIso8601String();
      scan['scan_date'] = scan['scan_date'] ?? DateTime.now().toIso8601String();
      
      return await db.insert('scan_history', scan);
    } catch (e) {
      throw Exception('Failed to save scan history: ${e.toString()}');
    }
  }

  Future<List<Map<String, dynamic>>> getScanHistory(int userId, {int? limit}) async {
    final db = await database;
    
    try {
      return await db.query(
        'scan_history',
        where: 'user_id = ?',
        whereArgs: [userId],
        orderBy: 'scan_date DESC',
        limit: limit,
      );
    } catch (e) {
      throw Exception('Failed to get scan history: ${e.toString()}');
    }
  }

  Future<Map<String, dynamic>?> getScanById(int scanId) async {
    final db = await database;
    
    try {
      final List<Map<String, dynamic>> maps = await db.query(
        'scan_history',
        where: 'id = ?',
        whereArgs: [scanId],
      );

      if (maps.isNotEmpty) {
        return maps.first;
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get scan: ${e.toString()}');
    }
  }

  Future<int> deleteScanHistory(int userId) async {
    final db = await database;
    
    try {
      return await db.delete(
        'scan_history',
        where: 'user_id = ?',
        whereArgs: [userId],
      );
    } catch (e) {
      throw Exception('Failed to delete scan history: ${e.toString()}');
    }
  }

  Future<int> deleteScanById(int scanId) async {
    final db = await database;
    
    try {
      return await db.delete(
        'scan_history',
        where: 'id = ?',
        whereArgs: [scanId],
      );
    } catch (e) {
      throw Exception('Failed to delete scan: ${e.toString()}');
    }
  }

  Future<int> getScanCount(int userId) async {
    final db = await database;
    
    try {
      final List<Map<String, dynamic>> result = await db.rawQuery(
        'SELECT COUNT(*) as count FROM scan_history WHERE user_id = ?',
        [userId],
      );
      
      return result.first['count'] as int;
    } catch (e) {
      return 0;
    }
  }

  // Database maintenance
  Future<void> vacuum() async {
    final db = await database;
    await db.execute('VACUUM');
  }

  // Close database
  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }
}