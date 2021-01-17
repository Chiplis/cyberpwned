import 'dart:math';

import 'package:firebase_ml_vision/firebase_ml_vision.dart';

class IncompleteSequenceException implements Exception {}

class SequenceGroup {
  List<SequenceCapture> group = [];
  final bool square;

  SequenceGroup(this.group, this.square);

  void _order() {
    if (group.length == 0) throw Exception("No elements were parsed, please try again.");

    int size = group.map((g) => g.sequence.length).reduce(max);
    group.sort((a, b) => -(a.sequence.length.compareTo(b.sequence.length)));
    group = square ? group.sublist(0, size) : group;
    group.sort((a, b) => -(a.top.compareTo(b.top)));

    List<SequenceCapture> sortedGroup = [];
    List<SequenceCapture> result = [];
    for (int i = 0; i < group.length; i++) {
      sortedGroup.sort((a, b) => a.left.compareTo(b.left));
      SequenceCapture lastCapture = sortedGroup.length == 0 ? null : sortedGroup.last;
      if (sortedGroup.length > 0 && ((lastCapture.top - group[i].top).abs() > (lastCapture.bottom - lastCapture.top) * 0.9)) {
        SequenceCapture capture = sortedGroup.reduce((a, b) => a + b);
        if (square) {
          if ((capture.left > group[i].left + 50) || result.any((c) => capture.left > c.left + 50)) {
            int j = 0;
            while ((capture.left > group[i].left * 1.05 + j * capture.length()) || result.any((c) => capture.left > c.left * 1.05 + j * capture.length())) {
              j++;
            }
            capture.sequence.insertAll(0, List.filled(max(0, j), "?"));
            capture.left -= capture.length() * j;
          }
          if ((capture.right < group[i].right + 50) || result.any((c) => capture.right < c.right + 50)) {
            int j = 0;
            while ((capture.right + j * capture.length() < group[i].right * 0.95) || result.any((c) => capture.right + j * capture.length() < c.right * 0.95)) {
              j++;
            }
            capture.sequence += List.filled(max(0, j), "?");
            capture.right += capture.length() * j;
          }
          capture.sequence = capture.sequence.sublist(0, min(capture.sequence.length, size));
        }
        result.add(capture);
        sortedGroup.clear();
      }
      sortedGroup.add(group[i]);
      if (sortedGroup.map((g) => g.sequence.length).fold(0, (a, b) => a + b) >= size) {
        sortedGroup.sort((a, b) => a.left.compareTo(b.left));
        SequenceCapture capture = sortedGroup.reduce((a, b) => a + b);
        capture.sequence = square ? capture.sequence.sublist(0, min(capture.sequence.length, size)) : capture.sequence;
        result.add(capture);
        sortedGroup.clear();
      }
    }

    if (sortedGroup.length != 0) {
      sortedGroup.sort((a, b) => a.left.compareTo(b.left));
      SequenceCapture capture = sortedGroup.reduce((a, b) => a + b);
      if (square) {
        if (result.any((c) => capture.left > c.left * 1.05)) {
          int j = 0;
          while (result.any((c) => capture.left > c.left * 1.05 + j * capture.length())) {
            j++;
          }
          capture.sequence.insertAll(0, List.filled(j, "?"));
          capture.left -= capture.length() * j;
        }
        if (result.any((c) => capture.right < c.right * 0.95)) {
          int j = 0;
          while (result.any((c) => capture.right + j * capture.length() < c.right * 0.95)) {
            j++;
          }
          capture.sequence += List.filled(j, "?");
          capture.right += capture.length() * j;
        }
        capture.sequence = capture.sequence.sublist(0, min(capture.sequence.length, size));
      }
      result.insert(0, capture);
    }

    group.clear();
    group.addAll(square ? result.sublist(0, min(result.length, size)) : result);
  }

  List<SequenceCapture> get() {
    _order();
    group.sort((a, b) => a.top.compareTo(b.top)); // Sort result from top to bottom
    return group;
  }
}

class SequenceCapture {
  double left;
  double right;
  double top;
  double bottom;
  List<String> sequence;
  bool square;

  SequenceCapture(this.left, this.right, this.bottom, this.top, this.sequence);

  final List<String> _validHex = ["1C", "FF", "E9", "BD", "55", "7A"];

  SequenceCapture.fromBlock(TextBlock block, this.square) {
    left = block.boundingBox.left;
    right = block.boundingBox.right;
    top = block.boundingBox.top;
    bottom = block.boundingBox.bottom;
    sequence = block.text.split(" ").where((element) => _validHex.contains(element)).toList();
  }

  double length() {
    return (right - left) / sequence.length;
  }

  SequenceCapture operator +(SequenceCapture other) {
    if (this == other || other == null) return this;
    if ((other.left - left).abs() < other.length() && (other.right - right).abs() < other.length()) return this;
    double len = max(length(), other.length());
    if (other.left >= right + len / 1.1) {
      int i = 0;
      while (other.left >= right + i * len) {
        i++;
      }
      return SequenceCapture(min(left, other.left), max(right, other.right), max(bottom, other.bottom), min(top, other.top),
          sequence + (square ? List.filled(i, "?") : []) + other.sequence);
    }
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
                    : sequence + other.sequence);
  }
}
