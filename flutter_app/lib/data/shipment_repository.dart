import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../domain/containers.dart';
import '../domain/shipment.dart';
import 'database.dart';

/// Bumped after every data change so open screens can reload.
final ValueNotifier<int> dataRevision = ValueNotifier<int>(0);
void _changed() => dataRevision.value++;

class ShipmentRepository {
  Database get _db => AppDatabase.instance.db;
  String _now() => DateTime.now().toIso8601String();

  Map<String, Object?> _containerCols(ContainerDims c) => {
        'container_code': c.code,
        'cont_l': c.length,
        'cont_w': c.width,
        'cont_h': c.height,
        'door_w': c.doorWidth,
        'door_h': c.doorHeight,
        'payload_kg': c.payloadKg,
      };

  // ---------- Shipments ----------

  Future<List<ShipmentSummary>> listForUser(int userId) async {
    final rows = await _db.rawQuery(
      'SELECT s.*, COUNT(g.id) AS n_groups, COALESCE(SUM(g.quantity), 0) AS n_boxes, '
      'COALESCE(SUM(g.quantity * g.weight_kg), 0) AS total_kg '
      'FROM shipments s LEFT JOIN box_groups g ON g.shipment_id = s.id '
      'WHERE s.user_id = ? GROUP BY s.id ORDER BY s.updated_at DESC',
      [userId],
    );
    return [
      for (final r in rows)
        ShipmentSummary(
          Shipment.fromRow(r),
          r['n_groups'] as int,
          (r['n_boxes'] as num).toInt(),
          (r['total_kg'] as num).toDouble(),
        ),
    ];
  }

  Future<Shipment?> get(int id) async {
    final rows = await _db.query('shipments', where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : Shipment.fromRow(rows.first);
  }

  Future<bool> codeExists(int userId, String code, {int? exceptId}) async {
    final rows = await _db.query(
      'shipments',
      columns: ['id'],
      where: exceptId == null ? 'user_id = ? AND code = ?' : 'user_id = ? AND code = ? AND id != ?',
      whereArgs: exceptId == null ? [userId, code] : [userId, code, exceptId],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  /// SH-101, SH-102, ... first code not used by this user.
  Future<String> nextCode(int userId) async {
    final rows = await _db.query('shipments', columns: ['code'], where: 'user_id = ?', whereArgs: [userId]);
    final used = rows.map((r) => r['code'] as String).toSet();
    for (var n = 101;; n++) {
      if (!used.contains('SH-$n')) return 'SH-$n';
    }
  }

  Future<int> create(int userId, String code, String name, ContainerDims c) async {
    final now = _now();
    final id = await _db.insert('shipments', {
      'user_id': userId,
      'code': code.trim(),
      'name': name.trim(),
      'status': 'draft',
      'created_at': now,
      'updated_at': now,
      ..._containerCols(c),
    });
    _changed();
    return id;
  }

  Future<void> updateInfo(int id, String code, String name) async {
    await _db.update('shipments', {'code': code.trim(), 'name': name.trim(), 'updated_at': _now()},
        where: 'id = ?', whereArgs: [id]);
    _changed();
  }

  /// Changing the container or the boxes sends the shipment back to draft.
  Future<void> updateContainer(int id, ContainerDims c) async {
    await _db.update('shipments', {..._containerCols(c), 'status': 'draft', 'updated_at': _now()},
        where: 'id = ?', whereArgs: [id]);
    _changed();
  }

  Future<void> setStatus(int id, String status) async {
    await _db.update('shipments', {'status': status, 'updated_at': _now()}, where: 'id = ?', whereArgs: [id]);
    _changed();
  }

  Future<void> delete(int id) async {
    await _db.delete('shipments', where: 'id = ?', whereArgs: [id]);
    _changed();
  }

  Future<void> _touch(DatabaseExecutor ex, int shipmentId) => ex.update(
        'shipments',
        {'status': 'draft', 'updated_at': _now()},
        where: 'id = ?',
        whereArgs: [shipmentId],
      );

  // ---------- Box groups ----------

  Future<List<BoxGroup>> groups(int shipmentId) async {
    final rows = await _db.query('box_groups', where: 'shipment_id = ?', whereArgs: [shipmentId], orderBy: 'code');
    return rows.map(BoxGroup.fromRow).toList();
  }

  Future<void> saveGroup(int shipmentId, BoxGroup g) async {
    await _db.transaction((tx) async {
      if (g.id == null) {
        await tx.insert('box_groups', g.toRow(shipmentId));
      } else {
        await tx.update('box_groups', g.toRow(shipmentId), where: 'id = ?', whereArgs: [g.id]);
      }
      await _touch(tx, shipmentId);
    });
    _changed();
  }

  Future<void> deleteGroup(int shipmentId, int groupId) async {
    await _db.transaction((tx) async {
      await tx.delete('box_groups', where: 'id = ?', whereArgs: [groupId]);
      await _touch(tx, shipmentId);
    });
    _changed();
  }

  /// Adds many groups at once; with [replace] the old groups are removed first.
  Future<void> addGroups(int shipmentId, List<BoxGroup> list, {bool replace = false}) async {
    await _db.transaction((tx) async {
      if (replace) await tx.delete('box_groups', where: 'shipment_id = ?', whereArgs: [shipmentId]);
      for (final g in list) {
        await tx.insert('box_groups', g.toRow(shipmentId));
      }
      await _touch(tx, shipmentId);
    });
    _changed();
  }
}
