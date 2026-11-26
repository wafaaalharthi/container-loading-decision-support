/// Block-Building and Beam Search.
///
/// Block-Building fills the container with *blocks*: rectangular groups of
/// identical boxes in the same orientation (nx x ny x nz). Free space is kept
/// as a list of maximal empty cuboids. At each step the deepest, lowest free
/// space is chosen and the largest block that fits there (and passes every
/// constraint) is placed (Eley, 2002; Zhu & Lim, 2012).
///
/// Unloading priorities are handled group by group: the boxes unloaded last
/// are placed first (deepest). When no block of the current group fits
/// anywhere, its remaining boxes are left unplaced and the next group starts.
///
/// Beam Search (Araya & Riff, 2014 style) explores several block choices at
/// each step instead of one. Each partial plan is scored by completing it
/// greedily; the best [width] partial plans survive to the next step. The
/// width doubles while time remains, and the best complete plan seen is kept.
library;

import '../metrics.dart';
import '../models.dart';
import '../validator.dart';

class Space {
  final int x, y, z, x2, y2, z2;
  const Space(this.x, this.y, this.z, this.x2, this.y2, this.z2);

  int get dx => x2 - x;
  int get dy => y2 - y;
  int get dz => z2 - z;
  int get volume => dx * dy * dz;
  String get key => '$x,$y,$z,$x2,$y2,$z2';

  bool intersects(int bx, int by, int bz, int bx2, int by2, int bz2) =>
      x < bx2 && bx < x2 && y < by2 && by < y2 && z < bz2 && bz < z2;

  bool containsSpace(Space o) => x <= o.x && y <= o.y && z <= o.z && o.x2 <= x2 && o.y2 <= y2 && o.z2 <= z2;
}

int _compareSpaces(Space a, Space b) {
  if (a.x != b.x) return a.x.compareTo(b.x);
  if (a.z != b.z) return a.z.compareTo(b.z);
  if (a.y != b.y) return a.y.compareTo(b.y);
  return b.volume.compareTo(a.volume);
}

class Block {
  final String type;
  final Rotation rotation;
  final int a, b, h; // oriented size of one box
  final int nx, ny, nz;
  const Block(this.type, this.rotation, this.a, this.b, this.h, this.nx, this.ny, this.nz);

  int get count => nx * ny * nz;
  int get volume => count * a * b * h;
  int get depth => nx * a;
}

class BlockMove {
  final Space space;
  final Block block;
  const BlockMove(this.space, this.block);
}

class BlockState {
  final LoadingCase c;
  final Validator v;
  List<Space> spaces;
  final Map<String, List<BoxItem>> remaining;
  final Map<String, BoxItem> prototypes;
  final Set<int> exhaustedGroups;
  final Set<String> deadSpaces;

  BlockState._(this.c, this.v, this.spaces, this.remaining, this.prototypes, this.exhaustedGroups,
      this.deadSpaces);

  factory BlockState.initial(LoadingCase c) {
    final remaining = <String, List<BoxItem>>{};
    final prototypes = <String, BoxItem>{};
    for (final b in c.boxes) {
      remaining.putIfAbsent(b.type, () => <BoxItem>[]).add(b);
      prototypes.putIfAbsent(b.type, () => b);
    }
    final k = c.container;
    return BlockState._(c, Validator(c), [Space(0, 0, 0, k.length, k.width, k.height)], remaining, prototypes,
        <int>{}, <String>{});
  }

  BlockState clone() => BlockState._(
        c,
        v.clone(),
        List<Space>.of(spaces),
        {for (final e in remaining.entries) e.key: List<BoxItem>.of(e.value)},
        prototypes,
        Set<int>.of(exhaustedGroups),
        Set<String>.of(deadSpaces),
      );

  Plan toPlan({bool timedOut = false}) => Plan(List<Placement>.of(v.placed), timedOut: timedOut);

  int? currentGroup() {
    int? best;
    for (final e in remaining.entries) {
      if (e.value.isEmpty) continue;
      final g = prototypes[e.key]!.priorityKey;
      if (exhaustedGroups.contains(g)) continue;
      if (best == null || g > best) best = g;
    }
    return best;
  }

  int _minRemainingDimension() {
    int? m;
    for (final e in remaining.entries) {
      if (e.value.isEmpty) continue;
      final d = prototypes[e.key]!.minDimension;
      if (m == null || d < m) m = d;
    }
    return m ?? 0;
  }

  List<Block> blocksFor(Space s, BoxItem proto, int available) {
    final result = <Block>[];
    final opts = c.options;
    final k = c.container;
    if (proto.floorOnly && s.z != 0) return result;
    int limit = available;
    if (k.payloadKg != null && proto.weight > 0) {
      final int byWeight = ((k.payloadKg! - v.totalWeight) / proto.weight + 1e-9).floor();
      if (byWeight < limit) limit = byWeight;
    }
    if (limit <= 0) return result;
    final bool canStackSame = allowsOnTop(proto, proto, opts);
    final seenDims = <String>{};
    final seenShapes = <String>{};
    for (int ri = 0; ri < proto.rotations.length; ri++) {
      final r = proto.rotations[ri];
      final int a = proto.size[r[0]], b = proto.size[r[1]], h = proto.size[r[2]];
      final dimKey = opts.pressure ? '$a,$b,$h,${r[2]}' : '$a,$b,$h';
      if (!seenDims.add(dimKey)) continue;
      if (a > s.dx || b > s.dy || h > s.dz) continue;
      if (k.hasDoor && (b > k.doorWidth! || h > k.doorHeight!)) continue;
      final int nxMax = s.dx ~/ a;
      final int nyMax = s.dy ~/ b;
      int nzMax = s.dz ~/ h;
      if (proto.floorOnly || !canStackSame) nzMax = 1;
      if (opts.pressure && proto.pressure != null && proto.weight > 0) {
        final double capacity = proto.pressure![r[2]] * a * b / 100.0;
        final int above = (capacity / proto.weight + 1e-9).floor();
        if (above + 1 < nzMax) nzMax = above + 1;
      }
      if (nzMax < 1) continue;
      void addShape(int nx, int ny, int nz) {
        if (nx < 1 || ny < 1 || nz < 1) return;
        if (!seenShapes.add('$ri,$nx,$ny,$nz')) return;
        result.add(Block(proto.type, r, a, b, h, nx, ny, nz));
      }

      // column first (stack high, then across, then deep)
      int nz1 = _min(nzMax, limit);
      int ny1 = _min(nyMax, limit ~/ nz1);
      int nx1 = _min(nxMax, limit ~/ (ny1 * nz1));
      addShape(nx1, ny1, nz1);
      addShape(1, ny1, nz1);
      // row first (across, then high, then deep)
      int ny2 = _min(nyMax, limit);
      int nz2 = _min(nzMax, limit ~/ ny2);
      int nx2 = _min(nxMax, limit ~/ (ny2 * nz2));
      addShape(nx2, ny2, nz2);
      addShape(1, ny2, nz2);
    }
    return result;
  }

  /// Places (or, with [keep] = false, only tests) a block in the corner of space [s].
  bool _placeBlock(Space s, Block blk, bool keep) {
    final items = remaining[blk.type]!;
    if (items.length < blk.count) return false;
    final int mark = v.mark;
    int k = 0;
    for (int iz = 0; iz < blk.nz; iz++) {
      for (int ix = 0; ix < blk.nx; ix++) {
        for (int iy = 0; iy < blk.ny; iy++) {
          final box = items[items.length - 1 - k];
          k++;
          final p = Placement(box, s.x + ix * blk.a, s.y + iy * blk.b, s.z + iz * blk.h, blk.rotation);
          if (v.tryAdd(p) != null) {
            v.rollback(mark);
            return false;
          }
        }
      }
    }
    if (!keep) {
      v.rollback(mark);
      return true;
    }
    items.removeRange(items.length - blk.count, items.length);
    _updateSpaces(s.x, s.y, s.z, s.x + blk.nx * blk.a, s.y + blk.ny * blk.b, s.z + blk.nz * blk.h);
    return true;
  }

  bool fits(BlockMove m) => _placeBlock(m.space, m.block, false);

  void apply(BlockMove m) {
    if (!_placeBlock(m.space, m.block, true)) {
      throw StateError('block no longer fits'); // cannot happen: moves are tested on this state
    }
  }

  void _updateSpaces(int bx, int by, int bz, int bx2, int by2, int bz2) {
    final next = <Space>[];
    for (final s in spaces) {
      if (!s.intersects(bx, by, bz, bx2, by2, bz2)) {
        next.add(s);
        continue;
      }
      if (bx > s.x) next.add(Space(s.x, s.y, s.z, bx, s.y2, s.z2));
      if (bx2 < s.x2) next.add(Space(bx2, s.y, s.z, s.x2, s.y2, s.z2));
      if (by > s.y) next.add(Space(s.x, s.y, s.z, s.x2, by, s.z2));
      if (by2 < s.y2) next.add(Space(s.x, by2, s.z, s.x2, s.y2, s.z2));
      if (bz > s.z) next.add(Space(s.x, s.y, s.z, s.x2, s.y2, bz));
      if (bz2 < s.z2) next.add(Space(s.x, s.y, bz2, s.x2, s.y2, s.z2));
    }
    final int minDim = _minRemainingDimension();
    final usable = [
      for (final s in next)
        if (s.dx >= minDim && s.dy >= minDim && s.dz >= minDim) s
    ];
    // Drop spaces contained in another space (keep one copy of duplicates).
    usable.sort((a, b) => b.volume.compareTo(a.volume));
    final kept = <Space>[];
    for (final s in usable) {
      bool contained = false;
      for (final o in kept) {
        if (o.containsSpace(s)) {
          contained = true;
          break;
        }
      }
      if (!contained) kept.add(s);
    }
    spaces = kept;
  }
}

int _min(int a, int b) => a < b ? a : b;

const int _maxTriesPerSpace = 12;

/// Returns up to [maxMoves] tested block moves for the current state, an empty
/// list when nothing more can be loaded, or null when the deadline passed.
List<BlockMove>? movesFor(BlockState st, int maxMoves, Deadline deadline) {
  while (true) {
    final group = st.currentGroup();
    if (group == null) return const <BlockMove>[];
    final types = <String>[
      for (final e in st.remaining.entries)
        if (e.value.isNotEmpty && st.prototypes[e.key]!.priorityKey == group) e.key
    ];
    final ordered = List<Space>.of(st.spaces)..sort(_compareSpaces);
    for (final s in ordered) {
      if (deadline.passed) return null;
      final deadKey = '$group|${s.key}';
      if (st.deadSpaces.contains(deadKey)) continue;
      final candidates = <Block>[];
      for (final t in types) {
        candidates.addAll(st.blocksFor(s, st.prototypes[t]!, st.remaining[t]!.length));
      }
      candidates.sort((a, b) {
        if (a.volume != b.volume) return b.volume.compareTo(a.volume);
        if (a.depth != b.depth) return a.depth.compareTo(b.depth);
        return a.type.compareTo(b.type);
      });
      final valid = <BlockMove>[];
      int tries = 0;
      for (final blk in candidates) {
        if (valid.length >= maxMoves || tries >= _maxTriesPerSpace) break;
        tries++;
        final move = BlockMove(s, blk);
        if (st.fits(move)) valid.add(move);
      }
      if (valid.isNotEmpty) return valid;
      st.deadSpaces.add(deadKey);
    }
    st.exhaustedGroups.add(group);
  }
}

/// Greedy completion: always takes the best block. Returns false if the deadline passed.
bool greedyComplete(BlockState st, Deadline deadline) {
  while (true) {
    final moves = movesFor(st, 1, deadline);
    if (moves == null) return false;
    if (moves.isEmpty) return true;
    st.apply(moves.first);
  }
}

/// Block-Building: one greedy pass. Deterministic.
Plan blockBuilding(LoadingCase c, Deadline deadline, int seed) {
  final st = BlockState.initial(c);
  final finished = greedyComplete(st, deadline);
  return st.toPlan(timedOut: !finished);
}

const int _branching = 3;
const int _maxWidth = 256;

/// Beam Search over block moves. Deterministic. Never worse than Block-Building,
/// because the greedy plan is computed first and kept as the starting best.
Plan beamSearch(LoadingCase c, Deadline deadline, int seed) {
  final root = BlockState.initial(c);
  final greedy = root.clone();
  final bool greedyDone = greedyComplete(greedy, deadline);
  Plan best = greedy.toPlan(timedOut: !greedyDone);
  if (!greedyDone) return best;
  Score bestScore = Score.of(best);
  bool cut = false;
  int width = 2;
  while (!deadline.passed && width <= _maxWidth) {
    var beam = <BlockState>[root.clone()];
    while (beam.isNotEmpty && !cut) {
      final children = <(Score, BlockState)>[];
      for (final st in beam) {
        final moves = movesFor(st, _branching, deadline);
        if (moves == null) {
          cut = true;
          break;
        }
        for (final m in moves) {
          final child = st.clone()..apply(m);
          final probe = child.clone();
          final bool finished = greedyComplete(probe, deadline);
          final plan = probe.toPlan();
          final s = Score.of(plan);
          if (s.betterThan(bestScore)) {
            best = plan;
            bestScore = s;
          }
          if (!finished) {
            cut = true;
            break;
          }
          children.add((s, child));
        }
        if (cut) break;
      }
      if (cut) break;
      children.sort((a, b) => b.$1.compareTo(a.$1));
      beam = [for (int i = 0; i < width && i < children.length; i++) children[i].$2];
    }
    if (cut) break;
    width *= 2;
  }
  return cut ? best.withTimedOut() : best;
}
