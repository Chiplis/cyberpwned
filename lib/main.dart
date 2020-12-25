import 'dart:async';
import 'dart:math';
import 'package:firebase_ml_vision/firebase_ml_vision.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

Future<void> main() async {
  runApp(MaterialApp(
    home: MyApp(),
    debugShowCheckedModeBanner: false,
  ));
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String _error = "";
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

  ElevatedButton _ocrButton(String text, String processingMsg, String processingKey, List<List<String>> result, MaterialStateProperty<Color> color, {bool square: false}) {
    return ElevatedButton(
        style: ButtonStyle(backgroundColor: color),
        onPressed: () async {
          String parseError = "There was a problem parsing the matrix/sequences. Try again, and remember that the clearer the pictures the better the chances of parsing them correctly.";
          try {
            _error = "";
            _solution = Path([]);
            result.clear();

            var file = await ImagePicker().getImage(source: ImageSource.camera);

            if (file == null) {
              return;
            }

            _processing[processingKey] = processingMsg;

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
            _error = parseError;
          }
          _processing[processingKey] = null;
          setState(() {});
        },
        child: Text(_processing[processingMsg] ?? text));
  }

  bool _calculationEnabled() {
    return _bufferSize != null && _matrix.isNotEmpty && _sequences.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
          appBar: AppBar(
            centerTitle: true,
            backgroundColor: Colors.amber,
            title: const Text('Cyberpwned'),
          ),
          body: Container(
            color: Colors.black,
            child: ListView(
              children: <Widget>[
                SizedBox(height: 40),
                SizedBox(
                    height: 65,
                    child: TextField(
                        style: TextStyle(color: Colors.white),
                        decoration: new InputDecoration(
                            fillColor: Colors.white,
                            focusColor: Colors.white,
                            hoverColor: Colors.white,
                            labelText: "Input your buffer size",
                            labelStyle: TextStyle(color: Colors.white)),
                        keyboardType: TextInputType.number,
                        cursorColor: Colors.white,
                        inputFormatters: <TextInputFormatter>[FilteringTextInputFormatter.digitsOnly],
                        onSubmitted: (buffer) async {
                          int newBuffer = int.parse(buffer, radix: 10);
                          if (newBuffer != _bufferSize) {
                            _bufferSize = newBuffer;
                            setState(() {});
                          }
                        })),
                SizedBox(
                    height: 40,
                    child: _ocrButton('Upload Code Matrix', "Parsing code matrix...", "matrix", _matrix, MaterialStateProperty.all(Colors.deepPurple),
                        square: true)),
                SizedBox(height: 40),
                SizedBox(
                    height: 40,
                    child: _ocrButton('Upload Sequences', "Parsing sequences...", "sequences", _sequences, MaterialStateProperty.all(Colors.deepOrange))),
                SizedBox(height: 40),
                SizedBox(
                    height: 40,
                    child: ElevatedButton(
                        style: ButtonStyle(backgroundColor: MaterialStateProperty.all(_calculationEnabled() ? Colors.green : Colors.grey)),
                        onPressed: () async {
                          if (_calculationEnabled()) {
                            _computeSolution("Calculating optimal path...", "path");
                          }
                        },
                        child: Text(_processing["path"]  ?? "Calculate Path"))),
                SizedBox(height: 40),
                Column(children: [
                  Container(
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
                                              duration: Duration(milliseconds: 300),
                                              // Color cell depending on whether the coordinate is part of the optimal path
                                              color: _isPartOfSolution(row.key, column.key) == null ? Colors.lightBlue : Colors.green,
                                              // If the coordinate is part of the optimal path, show when it should be visited instead of displaying its value
                                              child: Text(_isPartOfSolution(row.key, column.key)?.toString() ?? column.value,
                                                  textAlign: TextAlign.center, style: TextStyle(fontSize: 20)))))
                                      .toList()))
                              .toList())),
                  SizedBox(height: 16),
                  Container(
                      child: Table(
                          children: _sequences
                              .map((row) =>
                                  // Make all rows the same length to prevent rendering error. TODO: Find a layout which removes the need for doing this
                                  row + List.filled(max(0, _sequences.map((r) => r.length).fold(0, max) - row.length), ""))
                              .map((filledRow) => TableRow(
                                  children: filledRow
                                      .map((elm) => Padding(
                                          padding: EdgeInsets.symmetric(vertical: 2),
                                          child: AnimatedContainer(
                                              duration: Duration(milliseconds: 300),
                                              // Ignore the previously generated empty cells
                                              color: elm.isEmpty
                                                  ? Colors.transparent
                                                  // Set cell color depending on whether sequence is completed or not. TODO: Find a layout which removes the need for doing this
                                                  : SequenceScore(filledRow.where((e) => e != ""), _bufferSize).isCompletedBy(_solution, _matrix)
                                                      ? Colors.green
                                                      : Colors.red,
                                              child: Text(elm, textAlign: TextAlign.center, style: TextStyle(fontSize: 20)))))
                                      .toList()))
                              .toList()))
                ]),
                Text(_error, style: TextStyle(backgroundColor: Colors.red, color: Colors.white), textAlign: TextAlign.justify),
              ],
            ),
          )),
    );
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
    if (_error.length == 0 && _bufferSize != null) {
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
        _error = error.toString();
      });
    }
  }

  int _isPartOfSolution(int row, int column) {
    for (int i = 0; i < _solution.coords.length; i++) {
      if (_solution.coords[i][0] == row && _solution.coords[i][1] == column) {
        return i + 1;
      }
    }
    return null;
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
  int score = 0;
  int maxProgress;

  SequenceScore(Iterable<String> sequence, this.bufferSize, [this.rewardLevel = 0]) {
    this.sequence = sequence.toList();
    maxProgress = this.sequence.length;
  }

  void compute(String compare) {
    if (_completed()) {
      return;
    }
    if (sequence[score] == compare) {
      _increase();
    } else {
      _decrease();
    }
  }

  bool isCompletedBy(Path path, List<List<String>> matrix) {
    path.coords.forEach((coord) => compute(matrix[coord[0]][coord[1]]));
    return score == maxScore();
  }

  int maxScore() {
    // Can be adjusted to maximize either:
    //  a) highest quality rewards, possibly lesser quantity
    return pow(10, rewardLevel + 1);
    //  b) highest amount of rewards, possibly lesser quality
    // this.score = 100 * (this.rewardLevel + 1);
  }

  int minScore() {
    return -rewardLevel - 1;
  }

  // When the head of the sequence matches the targeted node, increase the score by 1
  // If the sequence has been completed, set the score depending on the reward level
  void _increase() {
    bufferSize--;
    score++;
    if (_completed()) {
      score = maxScore();
    }
  }

  // When an incorrect value is matched against the current head of the sequence, the score is decreased by 1 (can't go below 0)
  // If it's not possible to complete the sequence, set the score to a negative value depending on the reward
  void _decrease() {
    this.bufferSize--;
    if (score > 0) {
      score--;
    }
    if (_completed()) {
      score = minScore();
    }
  }

  // A sequence is considered completed if no further progress is possible or necessary
  bool _completed() {
    return score < 0 || score >= maxProgress || bufferSize < maxProgress - score;
  }
}

class DuplicateCoordinateException implements Exception {}

class Path {
  List<List<int>> coords;

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
}

class PathScore {
  int score;
  Path path;
  int bufferSize;
  List<SequenceScore> sequenceScores = List<SequenceScore>();
  List<List<String>> matrix;

  PathScore(this.matrix, this.path, List<List<String>> sequences, this.bufferSize) {
    sequences.asMap().forEach((rewardLevel, sequence) => sequenceScores.add(SequenceScore(sequence, bufferSize, rewardLevel)));
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
    score = sequenceScores.map((seq) => seq.score).fold(0, (a, b) => a + b);
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
    return (turn % 2 == 0
            ? matrix.asMap().entries.map((column) => [coordinate[0], column.key])
            : matrix.asMap().entries.map((row) => [row.key, coordinate[1]]))
        .toList();
  }

  void _walkPaths(List<Path> partialPathsStack, int turn, List<List<int>> candidates) {
    Path path = partialPathsStack.removeAt(partialPathsStack.length - 1);
    for (List<int> coord in candidates) {
      Path newPath;
      try {
        newPath = path + Path([coord]);
      } on DuplicateCoordinateException {
        continue;
      }

      if (newPath.coords.length == bufferSize) {
        completedPaths.add(newPath);
      } else {
        PathScore pathScore = PathScore(matrix, newPath, sequences, bufferSize);
        int score = pathScore.compute();
        if (score == pathScore.maxScore()) {
          completedPaths.add(newPath);
          return;
        } else if (score == pathScore.minScore()) {
          continue;
        }
        partialPathsStack.add(newPath);
        _walkPaths(partialPathsStack, turn + 1, _candidateCoords(turn + 1, coord));
      }
    }
  }

  List<Path> generate() {
    if (bufferSize == 0) {
      return [Path([])];
    }
    if (completedPaths.length == 0) {
      _walkPaths([Path([])], 0, _candidateCoords(0, [0, 0]));
    }
    return completedPaths;
  }
}
