import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import 'database.dart';
import 'shipment_repository.dart';

class ReportRecord {
  final int id;
  final int? planId;
  final String kind; // csv | pdf | comparison
  final String title;
  final String? fileName;
  final Map<String, dynamic> data;
  final DateTime createdAt;
  const ReportRecord(this.id, this.planId, this.kind, this.title, this.fileName, this.data, this.createdAt);
}

class ReportRepository {
  Database get _db => AppDatabase.instance.db;

  Future<void> add(int userId, int? planId, String kind, String title,
      {String? fileName, Map<String, Object?>? data}) async {
    await _db.insert('reports', {
      'user_id': userId,
      'plan_id': planId,
      'kind': kind,
      'title': title,
      'file_path': fileName,
      'data_json': data == null ? null : jsonEncode(data),
      'created_at': DateTime.now().toIso8601String(),
    });
    dataRevision.value++;
  }

  Future<List<ReportRecord>> listForUser(int userId) async {
    final rows = await _db.query('reports', where: 'user_id = ?', whereArgs: [userId], orderBy: 'created_at DESC');
    return [
      for (final r in rows)
        ReportRecord(
          r['id'] as int,
          r['plan_id'] as int?,
          r['kind'] as String,
          r['title'] as String,
          r['file_path'] as String?,
          r['data_json'] == null ? const {} : jsonDecode(r['data_json'] as String) as Map<String, dynamic>,
          DateTime.parse(r['created_at'] as String),
        ),
    ];
  }

  Future<void> delete(int id) async {
    await _db.delete('reports', where: 'id = ?', whereArgs: [id]);
    dataRevision.value++;
  }
}

/// In-app notification. [key] is a text key, [args] fill its placeholders.
class AppNotification {
  final int id;
  final String key;
  final Map<String, Object> args;
  final bool read;
  final DateTime createdAt;
  const AppNotification(this.id, this.key, this.args, this.read, this.createdAt);
}

class NotificationRepository {
  Database get _db => AppDatabase.instance.db;

  Future<void> add(int userId, String key, Map<String, Object> args) async {
    await _db.insert('notifications', {
      'user_id': userId,
      'title': key,
      'body': jsonEncode(args),
      'is_read': 0,
      'created_at': DateTime.now().toIso8601String(),
    });
    dataRevision.value++;
  }

  Future<List<AppNotification>> listForUser(int userId) async {
    final rows =
        await _db.query('notifications', where: 'user_id = ?', whereArgs: [userId], orderBy: 'created_at DESC');
    return [
      for (final r in rows)
        AppNotification(
          r['id'] as int,
          r['title'] as String,
          (jsonDecode(r['body'] as String? ?? '{}') as Map<String, dynamic>).map((k, v) => MapEntry(k, v as Object)),
          (r['is_read'] as int) == 1,
          DateTime.parse(r['created_at'] as String),
        ),
    ];
  }

  Future<int> unreadCount(int userId) async {
    final rows = await _db.rawQuery('SELECT COUNT(*) FROM notifications WHERE user_id = ? AND is_read = 0', [userId]);
    return Sqflite.firstIntValue(rows) ?? 0;
  }

  Future<void> markAllRead(int userId) async {
    await _db.update('notifications', {'is_read': 1}, where: 'user_id = ? AND is_read = 0', whereArgs: [userId]);
    dataRevision.value++;
  }

  Future<void> clear(int userId) async {
    await _db.delete('notifications', where: 'user_id = ?', whereArgs: [userId]);
    dataRevision.value++;
  }
}
