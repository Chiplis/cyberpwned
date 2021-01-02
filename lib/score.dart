import 'package:Cyberpwned/cell.dart';
import 'package:Cyberpwned/path.dart';

import 'dart:math';

class SequenceScore {
  List<String> sequence;
  int bufferSize;
  int rewardLevel;
  int progress = 0;
  int maxProgress;
  int score = 0;

  SequenceScore(Iterable<String> sequence, this.bufferSize, {int score: 0, int progress: 0, int rewardLevel: 0}) {
    this.sequence = sequence.toList();
    this.rewardLevel = rewardLevel;
    this.progress = progress;
    this.score = score;
    maxProgress = this.sequence.length;
  }

  int compute(String compare) {
    if (_completed() || compare == null) {
      if (progress == maxProgress) {
        score = maxScore();
      } else if (bufferSize < maxProgress - progress) {
        score = minScore();
      }
      return score;
    }
    int oldProgress = progress;
    progress += sequence[progress] == compare ? _increase() : _decrease();
    score += (progress - oldProgress) * pow(2, rewardLevel + 1);
    bufferSize--;
    if (!_completed()) return score;
    if (progress == maxProgress) {
      score = maxScore();
    } else if (bufferSize < maxProgress - progress) {
      score = minScore();
    }
    return score;
  }

  bool isCompletedBy(Path path, CellGroup matrix) {
    if (path.coords.isEmpty) return null;
    path.coords.forEach((coord) => compute(matrix.get(coord[0], coord[1])));
    return compute(null) == maxScore();
  }

  // If the sequence has been completed, set the score depending on the reward level
  int maxScore() {
    // Can be adjusted to maximize either:
    //  a) highest quality rewards, possibly lesser quantity
    return pow(10, rewardLevel + 1);
    //  b) highest amount of rewards, possibly lesser quality
    // return 100 * (this.rewardLevel + 1);
  }

  // If it's not possible to complete the sequence, set the score to a negative value depending on the reward
  int minScore() {
    return -pow(10, rewardLevel + 1) * progress;
  }

  // When the head of the sequence matches the targeted node, increase the score by 1
  int _increase() {
    if (_completed()) return 0;
    return 1;
  }

  // When an incorrect value is matched against the current head of the sequence, the score is decreased by 1 (can't go below 0)
  int _decrease() {
    if (_completed()) return 0;
    return progress > 0 ? -1 : 0;
  }

  // A sequence is considered completed if no further progress is possible or necessary
  bool _completed() {
    return progress == maxProgress || bufferSize == null || bufferSize < maxProgress - progress;
  }
}

class PathScore {
  int score;
  Path path;
  int bufferSize;
  List<SequenceScore> sequenceScores = List<SequenceScore>();
  CellGroup matrix;
  static Map<Path, PathScore> previousScores = {};

  PathScore(this.matrix, this.path, CellGroup sequences, this.bufferSize) {
    sequences.asMap().forEach((rewardLevel, sequence) => sequenceScores.add(SequenceScore(sequence, bufferSize, rewardLevel: rewardLevel)));
  }

  int compute() {
    if (score != null) {
      return score;
    }
    path.coords.forEach((coord) {
      int row = coord[0];
      int column = coord[1];
      sequenceScores.forEach((seqScore) => seqScore.compute(matrix.get(row, column)));
    });
    score = sequenceScores.map((seq) => seq.compute(null)).fold(0, (a, b) => a + b);
    return score;
  }

  int maxScore() {
    return sequenceScores.map((score) => score.maxScore()).fold(0, (a, b) => a + b);
  }

  int minScore() {
    return sequenceScores.map((score) => score.minScore()).fold(0, (a, b) => a + b);
  }
}