import 'package:Cyberpwned/score.dart';
import 'package:Cyberpwned/cell.dart';

class DuplicateCoordinateException implements Exception {}

class TraversedPath {
  final List<List<int>> coords;

  TraversedPath(this.coords);

  TraversedPath operator +(TraversedPath other) {
    List<List<int>> newCoords = coords + other.coords;
    for (List<int> otherCoord in other.coords) {
      for (List<int> coord in coords) {
        if (coord[0] == otherCoord[0] && coord[1] == otherCoord[1]) {
          throw DuplicateCoordinateException();
        }
      }
    }
    return TraversedPath(newCoords);
  }

  @override
  String toString() {
    return coords.toString();
  }
}

class PathGenerator {
  int bufferSize;
  CellGroup matrix;
  CellGroup sequences;

  PathGenerator(this.matrix, this.sequences, this.bufferSize);

  List<TraversedPath> completedPaths = [];

  List<List<int>> _candidateCoords(int turn, List<int> coordinate) {
    List<List<int>> coords = (turn % 2 == 0
        ? matrix.asMap().entries.map((column) => [coordinate[0], column.key])
        : matrix.asMap().entries.map((row) => [row.key, coordinate[1]]))
        .toList();
    return coords;
  }

  void _walkPaths(List<TraversedPath> partialPathsStack, int turn, List<List<int>> candidates, {List<TraversedPath> ls}) {
    TraversedPath path = partialPathsStack.removeAt(partialPathsStack.length - 1);
    candidates = candidates.where((candidate) => !path.coords.any((coord) => coord[0] == candidate[0] && coord[1] == candidate[1])).toList();
    for (List<int> coord in candidates) {
      TraversedPath newPath;
      newPath = path + TraversedPath([coord]);

      PathScore score = PathScore(matrix, newPath, sequences, bufferSize);
      if (score.compute() == score.maxScore()) {
        completedPaths = [newPath];
        throw PathCompletedException();
      }

      if (score.compute() < score.minScore()) {
        ls.add(newPath);
        continue;
      }

      if (newPath.coords.length == bufferSize) {
        completedPaths.add(newPath);
      } else {
        partialPathsStack.add(newPath);
        _walkPaths(partialPathsStack, turn + 1, _candidateCoords(turn + 1, coord), ls: ls);
      }
    }
  }

  List<TraversedPath> generate() {
    completedPaths.clear();
    if (bufferSize == 0) {
      return [TraversedPath([])];
    }
    List<TraversedPath> ls = [];
    if (completedPaths.length == 0) {
      try {
        _walkPaths([TraversedPath([])], 0, _candidateCoords(0, [0, 0]), ls: ls);
      } on PathCompletedException {
        return completedPaths;
      }
    }
    return completedPaths;
  }
}

class PathCompletedException implements Exception{}