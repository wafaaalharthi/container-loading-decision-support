import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../domain/planning.dart';
import '../domain/shipment.dart';
import 'database.dart';
import 'records_repository.dart';
import 'shipment_repository.dart';

/// A stored plan with its placements.
class StoredPlan {
  final int id;
  final int shipmentId;
  final String shipmentCode;
  final PlanOutcome outcome;
  final bool saved;
  final DateTime createdAt;
  const StoredPlan(this.id, this.shipmentId, this.shipmentCode, this.outcome, this.saved, this.createdAt);
}

/// Row for plan lists (no placements).
class PlanSummary {
  final int id;
  final int shipmentId;
  final String shipmentCode;
  final String mode;
  final double utilization;
  final int loaded;
  final int total;
  final bool saved;
  final DateTime createdAt;
  const PlanSummary(this.id, this.shipmentId, this.shipmentCode, this.mode, this.utilization, this.loaded,
      this.total, this.saved, this.createdAt);
}

class PlanRepository {
  Database get _db => AppDatabase.instance.db;

  Future<int> insert(Shipment s, PlanOutcome o) async {
    final now = DateTime.now().toIso8601String();
    final id = await _db.transaction((tx) async {
      final planId = await tx.insert('plans', {
        'shipment_id': s.id,
        'mode': o.mode,
        'algorithm': o.algorithm,
        'status': 'done',
        'utilization': o.utilization,
        'loaded': o.placed.length,
        'total': o.total,
        'unplaced': o.unplaced.length,
        'time_ms': o.timeMs,
        'unload_blocking': o.blockingPct,
        'saved': 0,
        'valid': o.valid ? 1 : 0,
        'issues': o.issues,
        'loaded_weight_kg': o.weightKg,
        'unplaced_json': jsonEncode(o.unplaced),
        'created_at': now,
        'updated_at': now,
      });
      final b = tx.batch();
      for (var i = 0; i < o.placed.length; i++) {
        final p = o.placed[i];
        b.insert('placements', {
          'plan_id': planId,
          'seq': i + 1,
          'box_id': p.id,
          'group_code': p.group,
          'x': p.x,
          'y': p.y,
          'z': p.z,
          'dx': p.dx,
          'dy': p.dy,
          'dz': p.dz,
        });
      }
      b.insert('plan_events', {'plan_id': planId, 'type': 'generated', 'detail': o.algorithm, 'created_at': now});
      await b.commit(noResult: true);
      return planId;
    });
    await NotificationRepository().add(s.userId, 'notif_planGenerated', {
      'code': s.code,
      'mode': o.mode,
      'util': o.utilization.toStringAsFixed(1),
    });
    return id;
  }

  Future<StoredPlan?> get(int planId) async {
    final rows = await _db.rawQuery(
      'SELECT p.*, s.code AS ship_code FROM plans p JOIN shipments s ON s.id = p.shipment_id WHERE p.id = ?',
      [planId],
    );
    if (rows.isEmpty) return null;
    final r = rows.first;
    final pl = await _db.query('placements', where: 'plan_id = ?', whereArgs: [planId], orderBy: 'seq');
    final placed = [
      for (final q in pl)
        PlanBox(q['box_id'] as String, q['group_code'] as String, q['x'] as int, q['y'] as int, q['z'] as int,
            q['dx'] as int, q['dy'] as int, q['dz'] as int),
    ];
    final unplaced = (jsonDecode(r['unplaced_json'] as String? ?? '{}') as Map<String, dynamic>)
        .map((k, v) => MapEntry(k, v as String));
    final o = PlanOutcome(
      mode: r['mode'] as String,
      algorithm: r['algorithm'] as String,
      placed: placed,
      unplaced: unplaced,
      total: r['total'] as int,
      utilization: (r['utilization'] as num).toDouble(),
      weightKg: (r['loaded_weight_kg'] as num?)?.toDouble() ?? 0,
      timeMs: (r['time_ms'] as num).toDouble(),
      blockingPct: (r['unload_blocking'] as num?)?.toDouble(),
      valid: (r['valid'] as int? ?? 1) == 1,
      issues: r['issues'] as int? ?? 0,
    );
    return StoredPlan(planId, r['shipment_id'] as int, r['ship_code'] as String, o, (r['saved'] as int) == 1,
        DateTime.parse(r['created_at'] as String));
  }

  Future<List<PlanSummary>> listForUser(int userId) async {
    final rows = await _db.rawQuery(
      'SELECT p.id, p.shipment_id, p.mode, p.utilization, p.loaded, p.total, p.saved, p.created_at, '
      's.code AS ship_code FROM plans p JOIN shipments s ON s.id = p.shipment_id '
      'WHERE s.user_id = ? ORDER BY p.created_at DESC',
      [userId],
    );
    return [
      for (final r in rows)
        PlanSummary(
          r['id'] as int,
          r['shipment_id'] as int,
          r['ship_code'] as String,
          r['mode'] as String,
          (r['utilization'] as num).toDouble(),
          r['loaded'] as int,
          r['total'] as int,
          (r['saved'] as int) == 1,
          DateTime.parse(r['created_at'] as String),
        ),
    ];
  }

  Future<void> markSaved(int planId) async {
    final now = DateTime.now().toIso8601String();
    await _db.transaction((tx) async {
      await tx.update('plans', {'saved': 1, 'updated_at': now}, where: 'id = ?', whereArgs: [planId]);
      await tx.insert('plan_events', {'plan_id': planId, 'type': 'saved', 'created_at': now});
    });
    final rows = await _db.rawQuery(
      'SELECT s.user_id, s.code FROM plans p JOIN shipments s ON s.id = p.shipment_id WHERE p.id = ?',
      [planId],
    );
    if (rows.isNotEmpty) {
      await NotificationRepository()
          .add(rows.first['user_id'] as int, 'notif_planSaved', {'code': rows.first['code'] as String});
    }
  }

  Future<void> delete(int planId) async {
    await _db.delete('plans', where: 'id = ?', whereArgs: [planId]);
    dataRevision.value++;
  }
}
