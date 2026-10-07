import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

typedef Migration = Future<void> Function(Database db);

/// SQLite is the source of truth for history and profile (Design §9).
class AppDatabase {
  const AppDatabase._();

  static const version = 1;
  static const fileName = 'mather_sathi.db';

  /// `migrations[i]` upgrades schema version `i + 1` to `i + 2`.
  /// Append one entry per schema bump and raise [version].
  static final List<Migration> migrations = [];

  /// Opens the app DB. Pass [factory] and [path] (e.g. `inMemoryDatabasePath`) in tests.
  static Future<Database> open({String? path, DatabaseFactory? factory}) async {
    final f = factory ?? databaseFactory;
    final dbPath = path ?? p.join(await f.getDatabasesPath(), fileName);
    return f.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: version,
        onCreate: (db, _) => createSchemaV1(db),
        onUpgrade: (db, from, to) => runMigrations(db, from, to, migrations),
      ),
    );
  }

  static Future<void> runMigrations(
      Database db, int from, int to, List<Migration> steps) async {
    for (var v = from; v < to; v++) {
      await steps[v - 1](db);
    }
  }

  static Future<void> createSchemaV1(Database db) async {
    await db.execute('''
CREATE TABLE diagnosis_history (
  id               TEXT PRIMARY KEY,
  crop_type        TEXT NOT NULL,
  crop_label       TEXT,
  disease_id       TEXT,
  disease_name_bn  TEXT,
  kb_seq           INTEGER,
  advice_json      TEXT,
  confidence       TEXT,
  source           TEXT NOT NULL,
  photo_path       TEXT,
  diagnosed_at     TEXT NOT NULL,
  district         TEXT,
  upazila          TEXT,
  feedback         TEXT,
  feedback_actual  TEXT,
  is_synced        INTEGER NOT NULL DEFAULT 0,
  report_state     INTEGER NOT NULL DEFAULT 0,
  photo_synced     INTEGER NOT NULL DEFAULT 0
)''');
    await db.execute('''
CREATE TABLE user_profile (
  id               INTEGER PRIMARY KEY CHECK (id = 1),
  district         TEXT,
  upazila          TEXT,
  default_crop     TEXT,
  share_reports    INTEGER NOT NULL DEFAULT 1,
  photo_backup     INTEGER NOT NULL DEFAULT 0,
  photo_contribute INTEGER NOT NULL DEFAULT 0,
  notifications    INTEGER NOT NULL DEFAULT 1,
  tts_speed        TEXT NOT NULL DEFAULT 'normal',
  onboarding_done  INTEGER NOT NULL DEFAULT 0
)''');
    await db.execute(
        'CREATE INDEX idx_history_date ON diagnosis_history(diagnosed_at DESC)');
    await db.execute(
        'CREATE INDEX idx_history_unsynced ON diagnosis_history(is_synced, report_state, photo_synced)');
  }
}
