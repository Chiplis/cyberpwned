import 'package:Cyberpwned/score.dart';
import 'package:Cyberpwned/path.dart';
import 'package:Cyberpwned/cell.dart';

import 'dart:ui';

import 'package:flutter/material.dart';


class AppColor {

  static Color getDeactivated() {
    return Colors.grey;
  }

  static Color getInteractable() {
    return Colors.blueAccent;
  }

  static Color getNeutral() {
    return Colors.orange;
  }

  static Color getSuccess() {
    return Colors.teal;
  }

  static Color getFailure() {
    return Colors.red;
  }
}

class Solution {
  static bool calculationEnabled(Map<String, String> error, int bufferSize, CellGroup matrix, CellGroup sequences) {
    return allErrors(error).isEmpty && bufferSize != null && matrix.isNotEmpty && sequences.isNotEmpty;
  }

  static String allErrors(Map<String, String> _error) {
    String result = "";
    for (String key in _error.keys) {
      if (_error[key] != "") {
        result += "\n" + _error[key];
      }
    }
    return result.trim();
  }

  static TraversedPath calculateSolution(map) {
    CellGroup matrix = map["matrix"];
    CellGroup sequences = map["sequences"];
    int bufferSize = map["bufferSize"];
    List<TraversedPath> allPaths = PathGenerator(matrix, sequences, bufferSize).generate();
    int maxScore = 0;
    TraversedPath maxPath = TraversedPath([]);
    for (TraversedPath path in allPaths) {
      int newScore = PathScore(matrix, path, sequences, bufferSize).compute();
      if (newScore > maxScore) {
        maxScore = newScore;
        maxPath = path;
      }
    }
    return maxPath;
  }

  static String parseError(String s) {
    return "$s parsing failed, try to take another picture.";
  }
}