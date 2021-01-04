import 'dart:math';

import 'package:firebase_ml_vision/firebase_ml_vision.dart';

class SequenceGroup {
  List<SequenceCapture> group = [];
  final bool square;
  SequenceGroup(this.group, this.square);

  void _order() {
    double minDiff = double.infinity;

    List<int> matchIndexes = [];
    List<SequenceCapture> matchCaptures = [];

    if (square) {
      double size = sqrt(group.map((e) => e.sequence.length).fold(0, (total, element) => total + element));
      if (size % 1 != 0) {
        throw Exception("Invalid size.");
      }
      group.sort((a, b) => -(a.top.compareTo(b.top)));

      List<SequenceCapture> sortedGroup = [];
      int sortedGroupSize = 0;

      List<SequenceCapture> result = [];
      for (int i = 0; i < group.length; i++) {
        sortedGroupSize += group[i].sequence.length;
        sortedGroup.add(group[i]);
        if (sortedGroupSize == size) {
          result.add(sortedGroup.reduce((a, b) => a + b));
          sortedGroup.clear();
          sortedGroupSize = 0;
        }
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

  SequenceCapture.fromBlock(TextBlock block) {
    left = block.boundingBox.left;
    right = block.boundingBox.right;
    top = block.boundingBox.top;
    bottom = block.boundingBox.bottom;
    sequence = block.text.split(" ");
  }

  SequenceCapture operator +(SequenceCapture other) {
    if (this == other || other == null) return this;
    return SequenceCapture(min(left, other.left), max(right, other.right), max(bottom, other.bottom), min(top, other.top),
        left <= other.left ? sequence + other.sequence : other.sequence + sequence);
  }
}