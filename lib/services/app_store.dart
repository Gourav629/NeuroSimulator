
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../models/patient_profile.dart';
import '../models/simulation_config.dart';

class AppStore {
  Database? _db;

  Future<void> open() async {
    final base = await getApplicationDocumentsDirectory();

    _db = await openDatabase(
      p.join(base.path, 'neuro_simulator.db'),
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE profile (
            id INTEGER PRIMARY KEY CHECK (id = 1),
            name TEXT NOT NULL,
            photo_blob BLOB,
            age INTEGER NOT NULL,
            gender TEXT NOT NULL,
            clinician TEXT NOT NULL,
            hospital TEXT NOT NULL,
            pin_salt TEXT NOT NULL,
            pin_hash TEXT NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE simulation_configs (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            channel INTEGER NOT NULL,
            period_ms INTEGER NOT NULL,
            frequency_hz INTEGER NOT NULL,
            pulse_width_us INTEGER NOT NULL,
            gap_us INTEGER NOT NULL,
            created_at TEXT NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE communication_logs (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            level TEXT NOT NULL,
            message TEXT NOT NULL,
            created_at TEXT NOT NULL
          )
        ''');
      },
    );
  }

  Database get db {
    final database = _db;

    if (database == null) {
      throw StateError(
        'Database is not initialized. Call AppStore.open() first.',
      );
    }

    return database;
  }

  Future<PatientProfile?> getProfile() async {
    final rows = await db.query(
      'profile',
      where: 'id = 1',
    );

    if (rows.isEmpty) {
      return null;
    }

    return PatientProfile.fromMap(rows.first);
  }

  Future<void> saveProfile(PatientProfile profile) async {
    await db.insert(
      'profile',
      {
        'id': 1,
        ...profile.toMap(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> saveConfig(SimulationConfig config) async {
    await db.insert(
      'simulation_configs',
      {
        ...config.toMap(),
        'created_at': DateTime.now().toIso8601String(),
      },
    );
  }

  Future<void> log(String level, String message) async {
    await db.insert(
      'communication_logs',
      {
        'level': level,
        'message': message,
        'created_at': DateTime.now().toIso8601String(),
      },
    );
  }

  Future<List<Map<String, Object?>>> recentLogs() {
    return db.query(
      'communication_logs',
      orderBy: 'id DESC',
      limit: 100,
    );
  }

  Future<List<Map<String, Object?>>> recentConfigs() {
    return db.query(
      'simulation_configs',
      orderBy: 'id DESC',
      limit: 30,
    );
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
