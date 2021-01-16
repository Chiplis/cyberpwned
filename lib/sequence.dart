import 'dart:math';

import 'package:firebase_ml_vision/firebase_ml_vision.dart';

class IncompleteSequenceException implements Exception {}

class SequenceGroup {
  List<SequenceCapture> group = [];
  final bool square;

  SequenceGroup(this.group, this.square);

  void _order() {
    double minDiff = double.infinity;

    List<int> matchIndexes = [];
    List<SequenceCapture> matchCaptures = [];
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
          double minLeft = capture.left;
          double left = result.length > 0 ? result.last.left : minLeft;
          if (minLeft - left >= (result.length > 0 ? result.last : lastCapture).length()) {
            capture.sequence.insertAll(0, List.filled(max(0, size - capture.sequence.length), "?"));
          } else {
            capture.sequence += List.filled(max(0, size - capture.sequence.length), "?");
          }
          capture.sequence = capture.sequence.sublist(0, size);
        }
        result.add(capture);
        sortedGroup.clear();
      }
      sortedGroup.add(group[i]);
      if (sortedGroup.map((g) => g.sequence.length).fold(0, (a, b) => a + b) >= size) {
        sortedGroup.sort((a, b) => a.left.compareTo(b.left));
        SequenceCapture capture = sortedGroup.reduce((a, b) => a + b);
        capture.sequence = square ? capture.sequence.sublist(0, size) : capture.sequence;
        result.add(capture);
        sortedGroup.clear();
      }
    }

    if (sortedGroup.length != 0) {
      sortedGroup.sort((a, b) => a.left.compareTo(b.left));
      SequenceCapture capture = sortedGroup.reduce((a, b) => a + b);
      if (square) {
        double minLeft = capture.left;
        double left = result.length > 0 ? result.last.left : minLeft;
        if (minLeft - left >= capture.length()) {
          capture.sequence.insertAll(0, List.filled(max(0, size - capture.sequence.length), "?"));
        } else {
          capture.sequence += List.filled(max(0, size - capture.sequence.length), "?");
        }
        capture.sequence = capture.sequence.sublist(0, size);
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
    double len = (length() + other.length()) / 2;
    if (other.left >= right + len / 1.1) {
      int i = 0;
      while (other.left >= right + i * len) {
        i++;
      }
      return SequenceCapture(min(left, other.left), max(right, other.right), max(bottom, other.bottom), min(top, other.top),
          sequence + (square ? List.filled(max(0, i - 1), "?") : []) + other.sequence);
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
