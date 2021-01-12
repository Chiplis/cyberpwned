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
    bool partialSequence = false;
    if (square) {
      int totalLength = group.map((e) => e.sequence.length).fold(0, (total, element) => total + element);
      int size = sqrt(totalLength).ceil();

      if (size <= 3) {
        throw Exception("Could not parse enough matrix elements: $totalLength values parsed.");
      }

      group.sort((a, b) => -(a.top.compareTo(b.top)));

      List<SequenceCapture> sortedGroup = [];

      List<SequenceCapture> result = [];
      for (int i = 0; i < group.length; i++) {
        SequenceCapture lastCapture = sortedGroup.length == 0 ? null : sortedGroup[sortedGroup.length - 1];
        if (sortedGroup.length > 0 && ((lastCapture.top - group[i].top).abs() > 70)) {
          lastCapture.sequence += List.filled(max(0, size - sortedGroup.map((g) => g.sequence.length).fold(0, (a, b) => a + b)), "?");
          if (lastCapture.sequence.where((element) => element == "?").length <= 3) {
            result.add(sortedGroup.reduce((a, b) => a + b));
          }
          sortedGroup.clear();
        } else if (sortedGroup.length > 0 && ((lastCapture.right - group[i].left).abs() > 70)) {
          if ((lastCapture.right - group[i].left) >= 70) {
            lastCapture.sequence.insertAll(0, group[i].sequence);
          } else if ((lastCapture.right - group[i].left) <= -70) {
            lastCapture.sequence += group[i].sequence;
          }
          lastCapture.left = min(lastCapture.left, group[i].left);
          lastCapture.right = max(lastCapture.right, group[i].right);
          continue;
        }
        sortedGroup.add(group[i]);
        if (sortedGroup.map((g) => g.sequence.length).fold(0, (a, b) => a + b) == size) {
          result.add(sortedGroup.reduce((a, b) => a + b));
          sortedGroup.clear();
        }
      }

      if (sortedGroup.length != 0) {
        SequenceCapture lastCapture = sortedGroup[sortedGroup.length - 1];
        lastCapture.sequence += List.filled(max(0, size - sortedGroup.map((g) => g.sequence.length).fold(0, (a, b) => a + b)), "?");
        result.add(sortedGroup.reduce((a, b) => a + b));
      }

      group.clear();
      group.addAll(result);
      return;
    }

    for (int i = 0; i < group.length; i++) {
      for (int j = 0; j < group.length; j++) {
        if (i == j) {
          continue;
        }
        SequenceCapture a = group[i];
        SequenceCapture b = group[j];
        double newDiff = (a.top - b.top).abs();
        if (newDiff < minDiff && newDiff < 70) {
          minDiff = newDiff;
          matchIndexes = [i, j];
          matchCaptures = [a, b];
        }
      }
      if (matchIndexes.isNotEmpty) {
        break;
      }
    }

    if (matchIndexes.isNotEmpty) {
      group.remove(matchCaptures[0]);
      group.remove(matchCaptures[1]);
      group.add(matchCaptures.reduce((value, element) => value + element));
      _order();
    }
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

  SequenceCapture(this.left, this.right, this.bottom, this.top, this.sequence);

  final List<String> _validHex = ["1C", "FF", "E9", "BD", "55", "7A"];

  SequenceCapture.fromBlock(TextBlock block) {
    left = block.boundingBox.left;
    right = block.boundingBox.right;
    top = block.boundingBox.top;
    bottom = block.boundingBox.bottom;
    sequence = block.text.split(" ").where((element) => _validHex.contains(element)).toList();
  }

  SequenceCapture operator +(SequenceCapture other) {
    if (this == other || other == null) return this;
    return SequenceCapture(
        min(left, other.left),
        max(right, other.right),
        max(bottom, other.bottom),
        min(top, other.top),
        left < other.left ? sequence + other.sequence : left > other.left ? other.sequence + sequence : right > other.right ? other.sequence + sequence : sequence + other.sequence);
  }
}