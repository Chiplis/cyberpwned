import 'package:Cyberpwned/path.dart';
import 'package:Cyberpwned/sequence.dart';
import 'package:Cyberpwned/util.dart';
import 'package:Cyberpwned/cell.dart';
import 'package:app_review/app_review.dart';

import 'dart:async';
import 'dart:math';

import 'package:firebase_ml_vision/firebase_ml_vision.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';

import 'dart:io' show Platform;

/// If the current platform is desktop, override the default platform to
/// a supported platform (iOS for macOS, Android for Linux and Windows).
/// Otherwise, do nothing.
void _setTargetPlatformForDesktop() {
  TargetPlatform targetPlatform;
  if (Platform.isMacOS) {
    targetPlatform = TargetPlatform.iOS;
  } else if (Platform.isLinux || Platform.isWindows) {
    targetPlatform = TargetPlatform.android;
  }
  if (targetPlatform != null) {
    debugDefaultTargetPlatformOverride = targetPlatform;
  }
}

Future<void> main() async {
  if (!kIsWeb) _setTargetPlatformForDesktop();

  runApp(MaterialApp(
      theme: ThemeData(primarySwatch: Colors.amber, fontFamily: GoogleFonts.rajdhani().fontFamily, textTheme: GoogleFonts.solwayTextTheme()),
      home: MyApp(),
      debugShowCheckedModeBanner: false));
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class CyberpunkButtonPainter extends CustomPainter {
  final Color strokeColor;
  final PaintingStyle paintingStyle;
  final double strokeWidth;

  CyberpunkButtonPainter({this.strokeColor, this.strokeWidth = 3, this.paintingStyle = PaintingStyle.fill});

  @override
  void paint(Canvas canvas, Size size) {
    Paint fillPaint = Paint()
      ..color = strokeColor.withOpacity(0.3)
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.fill;

    Paint strokePaint = Paint()
      ..color = strokeColor.withOpacity(1)
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    canvas.drawPath(getTrianglePath(size.width, size.height), fillPaint);
    canvas.drawPath(getTrianglePath(size.width, size.height), strokePaint);
  }

  Path getTrianglePath(double x, double y) {
    return Path()..lineTo(x, 0)..lineTo(x, y / 30 * 25)..lineTo(x / 30 * 28.5, y)..lineTo(0, y)..lineTo(0, 0);
  }

  @override
  bool shouldRepaint(CyberpunkButtonPainter oldDelegate) {
    return oldDelegate.strokeColor != strokeColor || oldDelegate.paintingStyle != paintingStyle || oldDelegate.strokeWidth != strokeWidth;
  }
}

class _MyAppState extends State<MyApp> {
  Map<String, String> _error = {"MISSING BUFFER SIZE": "Specify buffer size before calculating path."};

  CellGroup _matrix;
  CellGroup _sequences;

  bool _solutionFound = false;

  String appID = "";

  @override
  void initState() {
    _matrix = CellGroup([
      ["1C", "BD", "55", "E9", "55"],
      ["1C", "BD", "1C", "55", "E9"],
      ["55", "E9", "E9", "BD", "BD"],
      ["55", "FF", "FF", "1C", "1C"],
      ["FF", "E9", "1C", "BD", "FF"]
    ], _sequencesState);

    _sequences = CellGroup([
      ["1C", "1C", "55"],
      ["55", "FF", "1C"],
      ["BD", "E9", "BD", "55"],
      ["55", "1C", "FF", "BD"]
    ], _sequencesState);
    super.initState();
  }

  final TextRecognizer _textRecognizer = FirebaseVision.instance.textRecognizer();

  int _bufferSize;

  final List<String> _validHex = ["1C", "FF", "E9", "BD", "55", "7A"];

  Future<void> _calculatePath() async {
    if (_solutionFound) return;
    _solution = TraversedPath([]);
    _solutionFound = false;
    setState(() {});
    if (Solution.calculationEnabled(_error, _bufferSize, _matrix, _sequences)) {
      _computeSolution("CALCULATING OPTIMAL PATH...", "path");
    }
  }

  Future<void> _parseGroup(String entity, String processingMsg, CellGroup result, bool square) async {
    try {
      var file = await ImagePicker().getImage(source: ImageSource.camera);
      if (file == null) {
        return;
      }

      _processing[entity] = processingMsg;
      _error["${entity.toUpperCase()} PARSE ERROR"] = "";
      _error["exception"] = "";
      _solution = TraversedPath([]);
      _solutionFound = false;
      result.clear();
      _sequencesState.clear();
      setState(() {});

      final FirebaseVisionImage visionImage = FirebaseVisionImage.fromFilePath(file.path);
      final VisionText visionText = await _textRecognizer.processImage(visionImage);
      // Ignore any blocks containing anything other than valid hexadecimal digits
      SequenceGroup allSequences = SequenceGroup(visionText.blocks
          .toList()
          .where((block) => !block.text.split(" ").any((possibleHex) => !_validHex.contains(possibleHex)))
          .map((block) => SequenceCapture.fromBlock(block))
          .toList(), square);

      result.addAll(allSequences.get().map((seqGroup) => seqGroup.sequence));

      if (result.length == 0 || (square && result.any((row) => row.length != result.length))) {
        throw Exception("Invalid matrix size: ${result.map((r) => r.length).fold(0, (a, b) => a + b)} elements parsed.");
      }
    } catch (e) {
      result.clear();
      _error["${entity.toUpperCase()} PARSE ERROR"] = Solution.parseError(entity);
      _error["exception"] = e.message;
    }
    _processing[entity] = null;
    setState(() {});
  }

  Map<String, String> _processing = {};

  RawMaterialButton _parseButton(String text, String entity, Color strokeColor, Future<void> Function() onPressed) {
    return RawMaterialButton(
        child: CustomPaint(
            painter: CyberpunkButtonPainter(strokeColor: strokeColor, paintingStyle: PaintingStyle.fill),
            child: Padding(
                padding: EdgeInsets.all(5),
                child: Text(_processing[entity] ?? text,
                    style: TextStyle(
                        color: strokeColor.withOpacity(0.95),
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                        fontFamily: GoogleFonts.rajdhani().fontFamily)))),
        onPressed: onPressed);
  }

  TraversedPath _solution = TraversedPath([]);
  Map<String, bool> _sequencesState = {};

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
          appBar: AppBar(
            centerTitle: true,
            backgroundColor: Colors.black,
            title: Text('CYBERPWNED',
                style: TextStyle(
                    color: AppColor.getNeutral(), fontFamily: GoogleFonts.rajdhani().fontFamily, fontWeight: FontWeight.bold, fontSize: 25)),
          ),
          body: Container(
            color: Colors.black,
            child: ListView(
              children: <Widget>[
                Padding(
                    padding: EdgeInsets.symmetric(horizontal: 0),
                    child: TextField(
                        textAlignVertical: TextAlignVertical.center,
                        maxLines: 1,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: AppColor.getNeutral(), fontSize: 20, fontWeight: FontWeight.bold, fontFamily: GoogleFonts.rajdhani().fontFamily),
                        decoration: new InputDecoration(
                            filled: true,
                            hoverColor: (_bufferSize == null ? AppColor.getInteractable() : AppColor.getNeutral()).withOpacity(0.3),
                            focusColor: (_bufferSize == null ? AppColor.getInteractable() : AppColor.getNeutral()).withOpacity(0.3),
                            fillColor: (_bufferSize == null ? AppColor.getInteractable() : AppColor.getNeutral()).withOpacity(0.3),
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: _bufferSize == null ? AppColor.getInteractable() : AppColor.getNeutral(), width: 3),
                            ),
                            focusedBorder: OutlineInputBorder(
                                borderSide: BorderSide(color: _bufferSize == null ? AppColor.getInteractable() : AppColor.getNeutral(), width: 3)),
                            labelText: "BUFFER SIZE",
                            labelStyle: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: _bufferSize == null ? AppColor.getInteractable() : AppColor.getNeutral(),
                              fontFamily: GoogleFonts.rajdhani().fontFamily,
                            )),
                        keyboardType: TextInputType.number,
                        cursorColor: Colors.white,
                        inputFormatters: <TextInputFormatter>[FilteringTextInputFormatter.digitsOnly],
                        onSubmitted: (buffer) async {
                          int newBuffer = int.tryParse(buffer, radix: 10);
                          _error["MISSING BUFFER SIZE"] = newBuffer != null ? "" : "Specify buffer size before calculating path.";
                          if (newBuffer != _bufferSize) {
                            _solutionFound = false;
                            _bufferSize = newBuffer;
                            _solution = TraversedPath([]);
                          }
                          setState(() {});
                        })),
                SizedBox(height: 8),
                Padding(
                    padding: EdgeInsets.all(0),
                    child: AnimatedContainer(
                        duration: Duration(milliseconds: 10000),
                        child: _parseButton('SCAN CODE MATRIX', "Matrix", _matrix.isEmpty ? AppColor.getInteractable() : AppColor.getNeutral(),
                            () => _parseGroup("Matrix", "UPLOADING CODE MATRIX", _matrix, true)))),
                Padding(
                    padding: EdgeInsets.all(0),
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
                                        child: Padding(
                                            padding: EdgeInsets.all(0),
                                            // Color cell depending on whether the coordinate is part of the optimal path
                                            // If the coordinate is part of the optimal path, show when it should be visited instead of displaying its value
                                            child: DisplayCell.forMatrix(row.key, column.key, _bufferSize, _sequences, _solution, _matrix).render())))
                                    .toList()))
                            .toList())),
                SizedBox(height: 8),
                Padding(
                    padding: EdgeInsets.all(0),
                    child: _parseButton('SCAN SEQUENCES', "Sequences", _sequences.isEmpty ? AppColor.getInteractable() : AppColor.getNeutral(),
                        () => _parseGroup("Sequences", "UPLOADING SEQUENCES...", _sequences, false))),
                SizedBox(height: 8),
                Padding(
                    padding: EdgeInsets.all(0),
                    child: Table(
                        children: _sequences
                            .map((seq) =>
                                // Make all rows the same length to prevent rendering error. TODO: Find a layout which removes the need for doing this
                                seq + List.filled(max(0, _sequences.map((r) => r.length).fold(0, max) - seq.length), ""))
                            .toList()
                            .asMap()
                            .entries
                            .map((sequence) => TableRow(
                                children: ([MapEntry(-1, "")] + (sequence.value.asMap().entries.toList()))
                                    .map((elm) => elm.key >= 0
                                        ? Padding(padding: EdgeInsets.symmetric(vertical: 2), child: DisplayCell.forSequence(sequence.key, elm.key, _bufferSize, CellGroup([sequence.value], _sequencesState), _solution, _matrix).render())
                                        : Padding(padding: EdgeInsets.symmetric(horizontal: 2), child: DisplayCell.forToggle(null, null, _bufferSize, null, _solution, null).render(
                                            _sequencesState[sequence.value.where((e) => e != "").toList().toString()] == null ||
                                                    _sequencesState[sequence.value.where((e) => e != "").toList().toString()]
                                                ? "✓"
                                                : "✗",
                                            _sequencesState[sequence.value.where((e) => e != "").toList().toString()] == null ||
                                                    _sequencesState[sequence.value.where((e) => e != "").toList().toString()]
                                                ? AppColor.getInteractable()
                                                : AppColor.getDeactivated(), () async {
                                            _solutionFound = false;
                                            var key = sequence.value.where((e) => e != "").toList().toString();
                                            var enabled = _sequencesState[key];
                                            _sequencesState[key] = !(enabled == null || enabled);
                                            setState(() {});
                                          }, 23)))
                                    .toList()))
                            .toList())),
                SizedBox(height: 8),
                Padding(
                    padding: EdgeInsets.symmetric(horizontal: 0),
                    child: _parseButton(
                        _processing["path"] ??
                            (_error.keys.where((key) => _error[key] != "").map((key) => key + " ↓").toList() + ["CALCULATE PATH"])[0],
                        "Path",
                        _processing["path"] != null
                            ? AppColor.getInteractable()
                            : _error.keys.where((k) => _error[k] != "").length > 0
                                ? AppColor.getFailure()
                                : _solutionFound
                                    ? AppColor.getSuccess()
                                    : AppColor.getNeutral(),
                        () => _calculatePath())),
                Padding(
                    padding: EdgeInsets.symmetric(horizontal: 0),
                    child: Text(Solution.allErrors(_error),
                        style: TextStyle(
                            color: AppColor.getFailure(), fontSize: 20, fontWeight: FontWeight.bold, fontFamily: GoogleFonts.rajdhani().fontFamily),
                        textAlign: TextAlign.justify)),
              ],
            ),
          )),
    );
  }

  int _reviewCounter = 0;

  void _computeSolution(String processingMsg, String processingKey) {
    setState(() {});
    _processing[processingKey] = processingMsg;
    setState(() {});
    compute(Solution.calculateSolution, {
      "bufferSize": _bufferSize,
      "matrix": _matrix,
      "sequences": CellGroup(
          _sequences.where((element) => _sequencesState[element.toString()] == null || _sequencesState[element.toString()]).toList(), _sequencesState)
    }).then((solution) {
      _solution = solution;
      _solutionFound = true;
      _processing[processingKey] = null;
      _reviewCounter++;
      setState(() {});
      if (_reviewCounter % 2 == 0) {
        AppReview.requestReview.then((onValue) => setState(() {}));
      }
    }, onError: (error) {
      _error["CALCULATION ERROR"] = error.toString();
    });
  }
}
