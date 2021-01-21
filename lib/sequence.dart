import 'dart:math';

import 'package:extended_math/extended_math.dart';
import 'package:firebase_ml_vision/firebase_ml_vision.dart';

class IncompleteSequenceException implements Exception {}

class SequenceGroup {
  List<SequenceCapture> _group = [];

  final bool square;

  bool ordered = false;

  SequenceGroup(this._group, this.square);

  void _complete(List<SequenceCapture> partial, int size, minLeft, maxRight) {
    if (!square) return;
    if (partial.map((s) => s.sequence.length).fold(0, (a, b) => a + b) == size) return;

    partial.sort((p, q) => -(p.sequence.length.compareTo(q.sequence.length)));
    double len = partial.first.length();
    partial.sort((p, q) => p.left.compareTo(q.left));
    if (partial.first.left > minLeft + len * 0.85) {
      while (partial.first.left > minLeft) {
        partial.insert(0, SequenceCapture(partial.first.left - len, partial.first.left - 1, partial.first.bottom, partial.first.top, ["?"], square));
      }
    }
    if (partial.last.right < maxRight - len * 0.85) {
      while (partial.last.right < maxRight) {
        partial.add(SequenceCapture(partial.last.right + 1, partial.last.right + len, partial.last.bottom, partial.last.top, ["?"], square));
      }
    }
    var idxs = [];
    for (int i = 1; i < partial.length; i++) {
      if (partial[i].left - partial[i - 1].right > len * 1.5) {
        idxs.add(i - 1);
      }
    }
    for (int i = 0; i < idxs.length; i++) {
      var idx = idxs[i];
      partial.insert(
          i + idx, SequenceCapture(partial[idx].right + 1, partial[idx].right + len, partial[idx].bottom, partial[idx].top, ["?"], square));
    }
    return;
  }

  void _order() {
    if (_group.length == 0) throw Exception("No elements were parsed, please try again.");

    deduplicate();

    double minLeft = _group.map((g) => g.left).reduce(min);
    double maxRight = _group.map((g) => g.right).reduce(max);

    int size = sqrt(_group.map((s) => s.sequence.length).fold(0, (a, b) => a + b)).round();

    sortGroup(size, square);

    List<SequenceCapture> result = [];
    List<SequenceCapture> partial = [];
    for (int i = 0; i < _group.length; i++) {
      SequenceCapture current = _group[i];
      partial.sort((a, b) => a.left.compareTo(b.left));
      if (square && partial.map((s) => s.sequence.length).fold(0, (a, b) => a + b) == size) {
        result.add(partial.reduce((a, b) => a + b));
        partial.clear();
      } else if (partial.isNotEmpty && partial.last.left > current.left && partial.last.top + partial.last.height() * 1.25 < current.top) {
        _complete(partial, size, minLeft, maxRight);
        result.add(partial.reduce((a, b) => a + b));
        partial.clear();
      }
      partial.add(current);
    }
    if (partial.isNotEmpty) {
      _complete(partial, size, minLeft, maxRight);
      result.insert(0, partial.reduce((a, b) => a + b));
    }
    _group.clear();
    _group.addAll(result);
    ordered = true;
  }

  sortGroup(int size, bool square) {
    var keypoints = _group;
    List<SequenceCapture> points = [];
    int hold = 0;
    List<SequenceCapture> rowPoints = [];
    while (keypoints.length > 0) {
      keypoints.sort((p, q) => (p.left + p.top).compareTo(q.left + q.top));
      var a = Vector([keypoints[0].left, keypoints[0].top, 0]);
      keypoints.sort((p, q) => (p.left - p.top).compareTo(q.left - q.top));
      var b = Vector([keypoints.last.left, keypoints.last.top, 0]);
      List<SequenceCapture> remainingPoints = [];

      keypoints.sort((a, b) => a.top.compareTo(b.top));
      for (SequenceCapture k in keypoints) {
        var p = Vector([k.left, k.top, 0]);
        var d = sqrt((k.right - k.left) * (k.bottom - k.top));
        var dist = ((p - a).cross(b - a)).euclideanNorm() / b.euclideanNorm();
        if (d / 2 + hold > dist) {
          rowPoints.add(k);
          rowPoints.sort((a, b) => a.left.compareTo(b.left));
        } else {
          remainingPoints.add(k);
        }
      }
      if ((square && rowPoints.length != size) || (!square && rowPoints.length == 0)) {
        hold += 50;
      } else {
        points.addAll(rowPoints);
        rowPoints.clear();
      }

      keypoints = remainingPoints;
    }
    if (rowPoints.isNotEmpty) {
      points.addAll(rowPoints);
    }
    _group.clear();
    _group.addAll(points);
  }

  void deduplicate() {
    List<SequenceCapture> result = [];
    for (SequenceCapture a in _group) {
      var found = false;
      for (SequenceCapture b in result) {
        if ((a.right - b.right).abs() + (a.top - b.top).abs() < 100 ||
            (a.bottom - b.bottom).abs() + (a.left - b.left).abs() < 100 ||
            (a.right - b.right).abs() + (a.bottom - b.bottom).abs() < 100 ||
            (a.left - b.left).abs() + (a.top - b.top).abs() < 100) {
          found = true;
          break;
        }
      }
      if (!found) result.add(a);
    }
    _group.clear();
    _group.addAll(result);
  }

  List<SequenceCapture> get() {
    if (!ordered) _order();
    _group.sort((a, b) => a.top.compareTo(b.top)); // Sort result from top to bottom
    return _group;
  }
}

class SequenceCapture {
  double _left;
  double _right;
  double _top;
  double _bottom;
  List<String> sequence;
  bool square;

  double get left => _left;

  double get right => _right;

  double get top => _top;

  double get bottom => _bottom;

  SequenceCapture(this._left, this._right, this._bottom, this._top, this.sequence, this.square);

  final List<String> _validHex = ["1C", "FF", "E9", "BD", "55", "7A"];

  SequenceCapture.fromElement(TextElement block, this.square) {
    _left = block.boundingBox.left;
    _right = block.boundingBox.right;
    _top = block.boundingBox.top;
    _bottom = block.boundingBox.bottom;
    sequence = block.text
        .split(" ")
        .map((e) => e.length == 4 ? e.substring(0, 2) + " " + e.substring(2, 4) : e.substring(0, min(e.length, 2)))
        .join(" ")
        .split(" ")
        .where((e) => _validHex.contains(e))
        .toList();
  }

  double height() {
    return bottom - top;
  }

  double length() {
    return (right - left) / sequence.length;
  }

  SequenceCapture operator +(SequenceCapture other) {
    return SequenceCapture(
        min(left, other.left),
        max(right, other.right),
        max(bottom, other.bottom),
        min(top, other.top),
        left < other.left
            ? sequence + other.sequence
            : left > other.left
                ? other.sequence + sequence
                : right > other.right
                    ? other.sequence + sequence
                    : sequence + other.sequence,
        square);
  }
}
