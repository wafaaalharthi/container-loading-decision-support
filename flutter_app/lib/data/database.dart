import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Local SQLite database (one file on the device).
class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();

  static const _fileName = 'senior_project1.db';
  static const _version = 4;

  Database? _db;

  Database get db {
    final d = _db;
    if (d == null) throw StateError('Database is not open');
    return d;
  }

  Future<void> open() async {
    if (_db != null) return;
    final dir = await getDatabasesPath();
    _db = await openDatabase(
      p.join(dir, _fileName),
      version: _version,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, version) async {
        final batch = db.batch();
        for (final sql in _schema) {
          batch.execute(sql);
        }
        await batch.commit(noResult: true);
        await _upgrade(db, 1, version);
      },
      onUpgrade: _upgrade,
    );
  }

  // Schema changes after version 1
  static Future<void> _upgrade(Database db, int from, int to) async {
    if (from < 2 && to >= 2) {
      final b = db.batch();
      for (final sql in const [
        'ALTER TABLE shipments ADD COLUMN cont_l INTEGER NOT NULL DEFAULT 5900',
        'ALTER TABLE shipments ADD COLUMN cont_w INTEGER NOT NULL DEFAULT 2352',
        'ALTER TABLE shipments ADD COLUMN cont_h INTEGER NOT NULL DEFAULT 2395',
        'ALTER TABLE shipments ADD COLUMN door_w INTEGER NOT NULL DEFAULT 2340',
        'ALTER TABLE shipments ADD COLUMN door_h INTEGER NOT NULL DEFAULT 2292',
        'ALTER TABLE shipments ADD COLUMN payload_kg REAL NOT NULL DEFAULT 28130',
        "ALTER TABLE box_groups ADD COLUMN custom TEXT NOT NULL DEFAULT ''",
        "ALTER TABLE box_groups ADD COLUMN stacking TEXT NOT NULL DEFAULT 'any'",
      ]) {
        b.execute(sql);
      }
      await b.commit(noResult: true);
    }
    if (from < 3 && to >= 3) {
      final b = db.batch();
      for (final sql in const [
        'ALTER TABLE plans ADD COLUMN valid INTEGER NOT NULL DEFAULT 1',
        'ALTER TABLE plans ADD COLUMN issues INTEGER NOT NULL DEFAULT 0',
        'ALTER TABLE plans ADD COLUMN loaded_weight_kg REAL',
        "ALTER TABLE plans ADD COLUMN unplaced_json TEXT NOT NULL DEFAULT '{}'",
      ]) {
        b.execute(sql);
      }
      await b.commit(noResult: true);
    }
    if (from < 4 && to >= 4) {
      await db.execute('ALTER TABLE reports ADD COLUMN data_json TEXT');
    }
  }

  // Lengths in mm, weights in kg, booleans as 0/1, dates as ISO-8601 text.
  static const List<String> _schema = [
    '''
    CREATE TABLE users (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      email TEXT NOT NULL UNIQUE,
      password_hash TEXT NOT NULL,
      salt TEXT NOT NULL,
      created_at TEXT NOT NULL
    )''',
    '''
    CREATE TABLE settings (
      key TEXT PRIMARY KEY,
      value TEXT
    )''',
    '''
    CREATE TABLE shipments (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      code TEXT NOT NULL,
      name TEXT,
      container_code TEXT NOT NULL,
      status TEXT NOT NULL DEFAULT 'draft',
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    )''',
    '''
    CREATE TABLE box_groups (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      shipment_id INTEGER NOT NULL REFERENCES shipments(id) ON DELETE CASCADE,
      code TEXT NOT NULL,
      contents TEXT,
      category TEXT NOT NULL DEFAULT 'other',
      length_mm INTEGER NOT NULL,
      width_mm INTEGER NOT NULL,
      height_mm INTEGER NOT NULL,
      weight_kg REAL NOT NULL,
      quantity INTEGER NOT NULL,
      priority INTEGER NOT NULL DEFAULT 1,
      fragile INTEGER NOT NULL DEFAULT 0,
      stackable INTEGER NOT NULL DEFAULT 1,
      max_stack_kg REAL,
      floor_only INTEGER NOT NULL DEFAULT 0,
      upright INTEGER NOT NULL DEFAULT 0
    )''',
    '''
    CREATE TABLE plans (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      shipment_id INTEGER NOT NULL REFERENCES shipments(id) ON DELETE CASCADE,
      mode TEXT NOT NULL,
      algorithm TEXT NOT NULL,
      status TEXT NOT NULL DEFAULT 'draft',
      utilization REAL,
      loaded INTEGER,
      total INTEGER,
      unplaced INTEGER,
      time_ms REAL,
      unload_blocking REAL,
      saved INTEGER NOT NULL DEFAULT 0,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    )''',
    '''
    CREATE TABLE placements (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      plan_id INTEGER NOT NULL REFERENCES plans(id) ON DELETE CASCADE,
      seq INTEGER NOT NULL,
      box_id TEXT NOT NULL,
      group_code TEXT NOT NULL,
      x INTEGER NOT NULL, y INTEGER NOT NULL, z INTEGER NOT NULL,
      dx INTEGER NOT NULL, dy INTEGER NOT NULL, dz INTEGER NOT NULL
    )''',
    '''
    CREATE TABLE plan_events (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      plan_id INTEGER NOT NULL REFERENCES plans(id) ON DELETE CASCADE,
      type TEXT NOT NULL,
      detail TEXT,
      created_at TEXT NOT NULL
    )''',
    '''
    CREATE TABLE reports (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      plan_id INTEGER REFERENCES plans(id) ON DELETE SET NULL,
      kind TEXT NOT NULL,
      title TEXT NOT NULL,
      file_path TEXT,
      created_at TEXT NOT NULL
    )''',
    '''
    CREATE TABLE notifications (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      title TEXT NOT NULL,
      body TEXT,
      is_read INTEGER NOT NULL DEFAULT 0,
      created_at TEXT NOT NULL
    )''',
    'CREATE INDEX idx_shipments_user ON shipments(user_id)',
    'CREATE INDEX idx_groups_shipment ON box_groups(shipment_id)',
    'CREATE INDEX idx_plans_shipment ON plans(shipment_id)',
    'CREATE INDEX idx_placements_plan ON placements(plan_id)',
    'CREATE INDEX idx_events_plan ON plan_events(plan_id)',
    'CREATE INDEX idx_reports_user ON reports(user_id)',
    'CREATE INDEX idx_notifications_user ON notifications(user_id)',
  ];
}
