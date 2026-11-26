import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:sqflite/sqflite.dart';

import 'database.dart';
import 'models.dart';

enum AuthError { exists, badLogin, wrongPassword }

class AuthException implements Exception {
  final AuthError error;
  const AuthException(this.error);
}

class UserRepository {
  Database get _db => AppDatabase.instance.db;

  static String _newSalt() {
    final r = Random.secure();
    return base64Url.encode(List<int>.generate(16, (_) => r.nextInt(256)));
  }

  // Salted SHA-256, repeated to slow down guessing
  static String _hash(String password, String salt) {
    List<int> bytes = utf8.encode('$salt:$password');
    for (var i = 0; i < 5000; i++) {
      bytes = sha256.convert(bytes).bytes;
    }
    return base64Url.encode(bytes);
  }

  Future<AppUser> signUp(String name, String email, String password) async {
    final e = email.trim().toLowerCase();
    final found = await _db.query('users', where: 'email = ?', whereArgs: [e], limit: 1);
    if (found.isNotEmpty) throw const AuthException(AuthError.exists);
    final salt = _newSalt();
    final now = DateTime.now().toIso8601String();
    final id = await _db.insert('users', {
      'name': name.trim(),
      'email': e,
      'password_hash': _hash(password, salt),
      'salt': salt,
      'created_at': now,
    });
    return AppUser(id: id, name: name.trim(), email: e, createdAt: DateTime.parse(now));
  }

  Future<AppUser> signIn(String email, String password) async {
    final e = email.trim().toLowerCase();
    final rows = await _db.query('users', where: 'email = ?', whereArgs: [e], limit: 1);
    if (rows.isEmpty) throw const AuthException(AuthError.badLogin);
    final r = rows.first;
    if (_hash(password, r['salt'] as String) != r['password_hash']) {
      throw const AuthException(AuthError.badLogin);
    }
    return AppUser.fromRow(r);
  }

  /// Changes name and email; the email must not belong to another account.
  Future<AppUser> updateProfile(int id, String name, String email) async {
    final e = email.trim().toLowerCase();
    final other = await _db.query('users', where: 'email = ? AND id != ?', whereArgs: [e, id], limit: 1);
    if (other.isNotEmpty) throw const AuthException(AuthError.exists);
    await _db.update('users', {'name': name.trim(), 'email': e}, where: 'id = ?', whereArgs: [id]);
    return (await byId(id))!;
  }

  /// Checks the current password, then stores the new one with a fresh salt.
  Future<void> changePassword(int id, String current, String next) async {
    final rows = await _db.query('users', where: 'id = ?', whereArgs: [id], limit: 1);
    final r = rows.first;
    if (_hash(current, r['salt'] as String) != r['password_hash']) {
      throw const AuthException(AuthError.wrongPassword);
    }
    final salt = _newSalt();
    await _db.update('users', {'password_hash': _hash(next, salt), 'salt': salt}, where: 'id = ?', whereArgs: [id]);
  }

  Future<AppUser?> byId(int id) async {
    final rows = await _db.query('users', where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : AppUser.fromRow(rows.first);
  }
}

class SettingsRepository {
  Database get _db => AppDatabase.instance.db;

  Future<String?> get(String key) async {
    final rows = await _db.query('settings', where: 'key = ?', whereArgs: [key], limit: 1);
    return rows.isEmpty ? null : rows.first['value'] as String?;
  }

  Future<void> set(String key, String? value) async {
    if (value == null) {
      await _db.delete('settings', where: 'key = ?', whereArgs: [key]);
    } else {
      await _db.insert('settings', {'key': key, 'value': value},
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }
}

class StatsRepository {
  Database get _db => AppDatabase.instance.db;

  Future<int> _count(String sql, List<Object?> args) async {
    final rows = await _db.rawQuery(sql, args);
    return Sqflite.firstIntValue(rows) ?? 0;
  }

  Future<HomeStats> forUser(int userId) async {
    final shipments = await _count('SELECT COUNT(*) FROM shipments WHERE user_id = ?', [userId]);
    final plans = await _count(
      'SELECT COUNT(*) FROM plans p JOIN shipments s ON s.id = p.shipment_id '
      'WHERE s.user_id = ? AND p.saved = 1',
      [userId],
    );
    final reports = await _count('SELECT COUNT(*) FROM reports WHERE user_id = ?', [userId]);
    return HomeStats(shipments, plans, reports);
  }
}
