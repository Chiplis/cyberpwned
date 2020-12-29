import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:firebase_ml_vision/firebase_ml_vision.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';

Future<void> main() async {
  runApp(MaterialApp(
      theme: ThemeData(primarySwatch: Colors.amber, fontFamily: GoogleFonts.rajdhani().fontFamily, textTheme: GoogleFonts.solwayTextTheme()),
      home: MyApp(),
      debugShowCheckedModeBanner: false));
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

enum CellType { MATRIX, SEQUENCE }

class DisplayCell {
  int x;
  int y;
  int bufferSize;
  Path solution;
  bool showIndex = false;
  List<List<String>> sequences;
  List<List<String>> matrix;
  CellType _cellType;

  DisplayCell.forMatrix(this.x, this.y, this.bufferSize, this.sequences, this.solution, this.matrix, {this.showIndex = true}) {
    this._cellType = CellType.MATRIX;
  }

  DisplayCell.forSequence(this.x, this.y, this.bufferSize, this.sequences, this.solution, this.matrix, {this.showIndex = false}) {
    this._cellType = CellType.SEQUENCE;
  }

  int _isPartOfSolution() {
    if (bufferSize != solution.coords.length) return null;
    for (int i = 0; i < solution.coords.length; i++) {
      if (solution.coords[i][0] == x && solution.coords[i][1] == y) {
        return i + 1;
      }
    }
    return null;
  }

  Color _colorForCell(Color found, Color notFound) {
    if (bufferSize != solution.coords.length) return _MyAppState.getInteractable();
    if (solution.coords.isEmpty) return _MyAppState.getInteractable();

    if (_cellType == CellType.SEQUENCE) {
      for (List<String> sequence in sequences) {
        if (SequenceScore(sequence.where((element) => element.isNotEmpty), bufferSize).isCompletedBy(solution, matrix)) {
          return _MyAppState.getSuccess();
        }
      }
      return _MyAppState.getFailure();
    } else if (_cellType == CellType.MATRIX) {
      return (_isPartOfSolution() != null) ? _MyAppState.getSuccess() : _MyAppState.getFailure();
    }
    return null;
  }

  Widget render() {
    if (matrix.isEmpty || sequences.isEmpty) return Text("");
    return Padding(
        padding: EdgeInsets.symmetric(vertical: 1),
        child: AnimatedContainer(
            decoration: BoxDecoration(color: _colorForCell(_MyAppState.getSuccess(), _MyAppState.getFailure())),
            duration: Duration(milliseconds: 300),
            child:Text(
              showIndex ? (_isPartOfSolution()?.toString() ?? matrix[x][y].toString()) : (_cellType == CellType.MATRIX ? matrix[x][y] : sequences[0][y]),
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  fontFamily: GoogleFonts.rajdhani().fontFamily))));
  }
}

class _MyAppState extends State<MyApp> {
  Map<String, String> _error = {"MISSING BUFFER SIZE": "Specify buffer size before calculating path."};
  final TextRecognizer _textRecognizer = FirebaseVision.instance.textRecognizer();
  int _bufferSize;
  List<List<String>> _matrix = [
    ["1C", "BD", "55", "E9", "55"],
    ["1C", "BD", "1C", "55", "E9"],
    ["55", "E9", "E9", "BD", "BD"],
    ["55", "FF", "FF", "1C", "1C"],
    ["FF", "E9", "1C", "BD", "FF"]
  ];
  List<List<String>> _sequences = [
    ["1C", "1C", "55"],
    ["55", "FF", "1C"],
    ["BD", "E9", "BD", "55"],
    ["55", "1C", "FF", "BD"]
  ];
  final List<String> _validHex = ["1C", "FF", "E9", "BD", "55", "7A"];
  Map<String, String> _processing = {};
  Path _solution = Path([]);

  static Color getInteractable() {
    return Colors.grey;
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

  OutlinedButton _parseButton(String text, String processingMsg, String entity, List<List<String>> result, {bool square: false}) {
    return OutlinedButton(
        style: OutlinedButton.styleFrom(
          shape: BeveledRectangleBorder(),
          onSurface: Colors.white,
          side: BorderSide(color: Colors.transparent),
          backgroundColor: result.isEmpty ? getInteractable() : getNeutral(),
        ),
        onPressed: () async {
          try {
            var file = await ImagePicker().getImage(source: ImageSource.camera);
            if (file == null) {
              return;
            }

            _processing[entity] = processingMsg;
            _error["${entity.toUpperCase()} PARSE ERROR"] = "";
            _solution = Path([]);
            result.clear();

            setState(() {});

            final FirebaseVisionImage visionImage = FirebaseVisionImage.fromFilePath(file.path);
            final VisionText visionText = await _textRecognizer.processImage(visionImage);
            // Ignore any blocks containing anything other than valid hexadecimal digits
            SequenceGroup allSequences = SequenceGroup(visionText.blocks
                .toList()
                .where((block) => !block.text.split(" ").any((possibleHex) => !_validHex.contains(possibleHex)))
                .map((block) => SequenceCapture.fromBlock(block))
                .toList());

            result.addAll(allSequences.get().map((seqGroup) => seqGroup.sequence));

            if (result.length == 0 || (square && result.any((row) => row.length != result.length))) {
              result.clear();
              throw Exception("Invalid size.");
            }
          } catch (e) {
            _error["${entity.toUpperCase()} PARSE ERROR"] = _parseError(entity);
          }
          _processing[entity] = null;
          setState(() {});
        },
        child: Text(_processing[entity] ?? text,
            style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 20,
                fontFamily: GoogleFonts.rajdhani().fontFamily)));
  }

  bool _calculationEnabled() {
    return _allErrors().isEmpty && _bufferSize != null && _matrix.isNotEmpty && _sequences.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
          appBar: AppBar(
            centerTitle: true,
            backgroundColor: Colors.black,
            title: Text('CYBERPWNED',
                style: TextStyle(color: getNeutral(), fontFamily: GoogleFonts.rajdhani().fontFamily, fontWeight: FontWeight.bold, fontSize: 25)),
          ),
          body: Container(
            color: Colors.black,
            child: ListView(
              children: <Widget>[
                SizedBox(height: 30),
                Padding(
                    padding: EdgeInsets.symmetric(horizontal: 0),
                    child: TextField(
                            textAlignVertical: TextAlignVertical.center,
                            maxLines: 1,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: getNeutral(), fontSize: 20, fontWeight: FontWeight.bold, fontFamily: GoogleFonts.rajdhani().fontFamily),
                            decoration: new InputDecoration(
                                enabledBorder: OutlineInputBorder(
                                  borderSide: BorderSide(color: _bufferSize == null ? getInteractable() : getNeutral(), width: 3),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderSide: BorderSide(color: _bufferSize == null ? getInteractable() : getNeutral(), width: 3),
                                ),
                                labelText: "BUFFER SIZE",
                                labelStyle: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: _bufferSize == null ? getInteractable() : getNeutral(),
                                  fontFamily: GoogleFonts.rajdhani().fontFamily,
                                )),
                            keyboardType: TextInputType.number,
                            cursorColor: Colors.white,
                            inputFormatters: <TextInputFormatter>[FilteringTextInputFormatter.digitsOnly],
                            onSubmitted: (buffer) async {
                              int newBuffer = int.tryParse(buffer, radix: 10);
                              _error["MISSING BUFFER SIZE"] = newBuffer != null ? "" : "Specify buffer size before calculating path.";

                              if (newBuffer != null) {
                                if (_bufferSize == null) {
                                  _bufferSize = newBuffer;
                                  setState(() {});
                                } else {
                                  _bufferSize = newBuffer;
                                }
                              } else {
                                _bufferSize = newBuffer;
                                setState(() {});
                              }
                            })),
                SizedBox(height: 10),
                Padding(
                    padding: EdgeInsets.symmetric(horizontal: 0),
                    child: _parseButton('UPLOAD CODE MATRIX', "PARSING CODE MATRIX...", "Matrix", _matrix, square: true)),
                Padding(
                    padding: EdgeInsets.symmetric(horizontal: 0),
                    child: Table(
                        children: _matrix
                            .asMap() // Need to know row's index
                            .entries
                            .map((row) => TableRow(
                                children: row.value
                                    .asMap() // Need to know column's index
                                    .entries
                                    .map((column) => Padding(
                                        padding: EdgeInsets.all(2),
                                        child: AnimatedContainer(
                                            duration: Duration(milliseconds: 1000),
                                            // Color cell depending on whether the coordinate is part of the optimal path
                                            // If the coordinate is part of the optimal path, show when it should be visited instead of displaying its value
                                            child: DisplayCell.forMatrix(row.key, column.key, _bufferSize, _sequences, _solution, _matrix).render())))
                                    .toList()))
                            .toList())),
                SizedBox(height: 10),
                Padding(
                    padding: EdgeInsets.symmetric(horizontal: 0),
                    child: _parseButton('UPLOAD SEQUENCES', "PARSING SEQUENCES...", "Sequences", _sequences)),
                Padding(
                    padding: EdgeInsets.all(0),
                    child: Table(
                        children: _sequences
                            .map((row) =>
                                // Make all rows the same length to prevent rendering error. TODO: Find a layout which removes the need for doing this
                                row + List.filled(max(0, _sequences.map((r) => r.length).fold(0, max) - row.length), ""))
                            .toList()
                            .asMap()
                            .entries
                            .map((sequence) => TableRow(
                                children: sequence.value
                                    .asMap()
                                    .entries
                                    .map((elm) => DisplayCell.forSequence(sequence.key, elm.key, _bufferSize, [sequence.value], _solution, _matrix).render()).toList()))
                                    .toList())),
                SizedBox(height: 10),
                Padding(
                    padding: EdgeInsets.symmetric(horizontal: 0),
                    child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          shape: BeveledRectangleBorder(),
                          side: BorderSide(
                              color: Colors.black,
                          ),
                          backgroundColor: _processing["path"] != null ? getInteractable() : (_calculationEnabled() ? getNeutral() : getFailure()),
                        ),
                        onPressed: () async {
                          _solution = Path([]);
                          setState(() {});
                          if (_calculationEnabled()) {
                            _computeSolution("CALCULATING OPTIMAL PATH...", "path");
                          }
                        },
                        child: Text(
                            _processing["path"] ??
                                (_error.keys.where((key) => _error[key] != "").map((key) => key + " ↓").toList() + ["CALCULATE PATH"])[0],
                            style: TextStyle(
                                fontFamily: GoogleFonts.rajdhani().fontFamily,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.black)))),
                Padding(
                    padding: EdgeInsets.symmetric(horizontal: 0),
                    child: Text(_allErrors(),
                        style: TextStyle(color: _MyAppState.getFailure(), fontSize: 20, fontWeight: FontWeight.bold, fontFamily: GoogleFonts.rajdhani().fontFamily),
                        textAlign: TextAlign.justify)),
              ],
            ),
          )),
    );
  }

  String _allErrors() {
    String result = "";
    for (String key in _error.keys) {
      if (_error[key] != "") {
        result += "\n" + _error[key];
      }
    }
    return result.trim();
  }

  static Path _calculateSolution(map) {
    List<List<String>> matrix = map["matrix"];
    List<List<String>> sequences = map["sequences"];
    int bufferSize = map["bufferSize"];
    List<Path> allPaths = PathGenerator(matrix, sequences, bufferSize).generate();
    int maxScore = 0;
    Path maxPath = Path([]);
    for (Path path in allPaths) {
      int newScore = PathScore(matrix, path, sequences, bufferSize).compute();
      if (newScore > maxScore) {
        maxScore = newScore;
        maxPath = path;
      }
    }
    return maxPath;
  }

  void _computeSolution(String processingMsg, String processingKey) {
    setState(() {});
    _processing[processingKey] = processingMsg;
    setState(() {});
    compute(_calculateSolution, {
      "bufferSize": _bufferSize,
      "matrix": _matrix.map((row) => row.where((elm) => elm != "").toList()).toList(),
      "sequences": _sequences.map((row) => row.where((elm) => elm != "").toList()).toList()
    }).then((solution) {
      _solution = solution;
      _processing[processingKey] = null;
      setState(() {});
    }, onError: (error) {
      _error["CALCULATION ERROR"] = error.toString();
    });
  }

  String _parseError(String s) {
    return "$s parsing failed, try to take another picture.";
  }
}

enum OrderType { MATRIX, SEQUENCE }

class SequenceGroup {
  List<SequenceCapture> group = [];

  SequenceGroup(this.group);

  void _order() {
    double minDiff = double.infinity;

    List<int> matchIndexes = [];
    List<SequenceCapture> matchCaptures = [];

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
        left < other.left ? sequence + other.sequence : other.sequence + sequence);
  }
}

class InvalidSequenceAddition implements Exception {}

class SequenceScore {
  List<String> sequence;
  int bufferSize;
  int rewardLevel;
  int progress = 0;
  int maxProgress;
  int score = 0;

  SequenceScore(Iterable<String> sequence, this.bufferSize, {int progress: 0, int rewardLevel: 0}) {
    this.sequence = sequence.toList();
    this.rewardLevel = rewardLevel;
    this.progress = progress;
    this.score = 0;
    maxProgress = this.sequence.length;
  }

  int compute(String compare) {
    if (_completed() || compare == null) {
      if (progress == maxProgress) {
        score = maxScore();
        return maxScore();
      } else if (bufferSize < maxProgress - progress) {
        score = minScore();
        return minScore();
      } else {
        return score;
      }
    }
    int oldProgress = progress;
    progress += sequence[progress] == compare ? _increase() : _decrease();
    score += (progress - oldProgress) * pow(10, rewardLevel);
    bufferSize--;
    return score;
  }

  bool isCompletedBy(Path path, List<List<String>> matrix) {
    if (path.coords.isEmpty) return null;
    path.coords.forEach((coord) => compute(matrix[coord[0]][coord[1]]));
    return compute(null) == maxScore();
  }

  int maxScore() {
    // Can be adjusted to maximize either:
    //  a) highest quality rewards, possibly lesser quantity
    return pow(10, rewardLevel + 1);
    //  b) highest amount of rewards, possibly lesser quality
    // this.score = 100 * (this.rewardLevel + 1);
  }

  int minScore() {
    return -rewardLevel-1;
  }

  // When the head of the sequence matches the targeted node, increase the score by 1
  // If the sequence has been completed, set the score depending on the reward level
  int _increase() {
    if (_completed()) return 0;
    score += pow(10 * progress, rewardLevel);
    return 1;
  }

  // When an incorrect value is matched against the current head of the sequence, the score is decreased by 1 (can't go below 0)
  // If it's not possible to complete the sequence, set the score to a negative value depending on the reward
  int _decrease() {
    if (_completed()) return 0;
    score -= pow(10 * progress, rewardLevel);
    return progress > 0 ? -1 : 0;
  }

  // A sequence is considered completed if no further progress is possible or necessary
  bool _completed() {
    return progress == maxProgress || bufferSize == null || bufferSize < maxProgress - progress;
  }
}

class DuplicateCoordinateException implements Exception {}

class Path {
  final List<List<int>> coords;

  Path(this.coords);

  Path operator +(Path other) {
    List<List<int>> newCoords = coords + other.coords;
    for (List<int> otherCoord in other.coords) {
      for (List<int> coord in coords) {
        if (coord[0] == otherCoord[0] && coord[1] == otherCoord[1]) {
          throw DuplicateCoordinateException();
        }
      }
    }
    return Path(newCoords);
  }

  @override
  String toString() {
    return coords.toString();
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (!(other is Path)) return false;
    return (other as Path).coords.every((element) => coords.any((coord) => element[0] == coord[0] && element[1] == coord[1]));
    // TODO: implement ==
    return super == other;
  }
}

class PathScore {
  int score;
  Path path;
  int bufferSize;
  List<SequenceScore> sequenceScores = List<SequenceScore>();
  List<List<String>> matrix;
  static Map<Path, PathScore> previousScores = {};

  PathScore(this.matrix, this.path, List<List<String>> sequences, this.bufferSize) {
    sequences.asMap().forEach((rewardLevel, sequence) => sequenceScores.add(SequenceScore(sequence, bufferSize, rewardLevel: rewardLevel)));
  }

  int compute() {
    if (score != null) {
      return score;
    }
    path.coords.forEach((coord) {
      int row = coord[0];
      int column = coord[1];
      sequenceScores.forEach((seqScore) => seqScore.compute(matrix[row][column]));
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

class PathGenerator {
  int bufferSize;
  List<List<String>> matrix;
  List<List<String>> sequences;

  PathGenerator(this.matrix, this.sequences, this.bufferSize);

  List<Path> completedPaths = [];

  List<List<int>> _candidateCoords(int turn, List<int> coordinate) {
    List<List<int>> coords = (turn % 2 == 0
            ? matrix.asMap().entries.map((column) => [coordinate[0], column.key])
            : matrix.asMap().entries.map((row) => [row.key, coordinate[1]]))
        .toList();
    return coords;
  }

  void _walkPaths(List<Path> partialPathsStack, int turn, List<List<int>> candidates, {List<Path> ls}) {
    Path path = partialPathsStack.removeAt(partialPathsStack.length - 1);
    candidates = candidates.where((candidate) => !path.coords.any((coord) => coord[0] == candidate[0] && coord[1] == candidate[1])).toList();
    for (List<int> coord in candidates) {
      Path newPath;
      newPath = path + Path([coord]);

      PathScore score = PathScore(matrix, newPath, sequences, bufferSize);
      if (score.compute() == score.maxScore()) {
        completedPaths = [newPath];
        throw PathCompletedException();
      }

      if (score.compute() < 0) {
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

  List<Path> generate() {
    completedPaths.clear();
    if (bufferSize == 0) {
      return [Path([])];
    }
    List<Path> ls = [];
    if (completedPaths.length == 0) {
      try {
        _walkPaths([Path([])], 0, _candidateCoords(0, [0, 0]), ls: ls);
      } on PathCompletedException {
        return completedPaths;
      }
    }
    return completedPaths;
  }
}

class PathCompletedException implements Exception{}