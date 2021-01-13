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
    if (square) {

      group.sort((a, b) => -(a.sequence.length.compareTo(b.sequence.length)));
      int size = group[1].sequence.length;
      group = group.sublist(0, size);
      group.sort((a, b) => -(a.top.compareTo(b.top)));

      List<SequenceCapture> sortedGroup = [];
      List<SequenceCapture> result = [];
      for (int i = 0; i < group.length; i++) {
        SequenceCapture lastCapture = sortedGroup.length == 0 ? null : sortedGroup.last;
        if (sortedGroup.length > 0 && ((lastCapture.top - group[i].top).abs() > lastCapture.length() / 1.25)) {
          double minLeft = sortedGroup.map((e) => e.left).reduce(min);
          double left = result.length > 0 ? result.last.left : minLeft;
          if ((minLeft - left) >= 40) {
            sortedGroup.first.sequence.insertAll(0, List.filled(max(0, size - sortedGroup.map((g) => g.sequence.length).fold(0, (a, b) => a + b)), "?"));
          } else {
            lastCapture.sequence += List.filled(max(0, size - sortedGroup.map((g) => g.sequence.length).fold(0, (a, b) => a + b)), "?");
          }
          result.add(sortedGroup.reduce((a, b) => a + b));
          sortedGroup.clear();
        }
        sortedGroup.add(group[i]);
        if (sortedGroup.map((g) => g.sequence.length).fold(0, (a, b) => a + b) == size) {
          sortedGroup.sort((a, b) => a.left.compareTo(b.left));
          result.add(sortedGroup.reduce((a, b) => a + b));
          sortedGroup.clear();
        }
      }

      if (sortedGroup.length != 0) {
        sortedGroup.sort((a, b) => a.left.compareTo(b.left));
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

  double length() {
    return (right - left) / sequence.length;
  }

  SequenceCapture operator +(SequenceCapture other) {
    if (this == other || other == null) return this;
    if (other.left >= left - length() / 1.75 && other.right >= right + length() / 1.75){
      int i = 0;
      while (i * other.length() + other.left < right) {
        i++;
      }
      return SequenceCapture(
        left,
        other.right,
        bottom,
        top,
        sequence + other.sequence.sublist(i)
      );
    } else if (other.left <= left - length() / 1.75 && other.right <= right - length() / 1.75) {
      int i = 0;
      while (i * other.length() + other.left < left) {
        i++;
      }
      return SequenceCapture(
          left,
          other.right,
          bottom,
          top,
          other.sequence.sublist(0, i) + sequence
      );
    }
    return SequenceCapture(
        min(left, other.left),
        max(right, other.right),
        max(bottom, other.bottom),
        min(top, other.top),
        left < other.left ? sequence + other.sequence : left > other.left ? other.sequence + sequence : right > other.right ? other.sequence + sequence : sequence + other.sequence);
  }
}