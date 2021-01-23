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
import 'package:shared_preferences/shared_preferences.dart';

import 'dart:io' show File, Platform;

import 'package:url_launcher/url_launcher.dart';

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
  _MyAppState createState() =>_MyAppState();
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

    if (this.paintingStyle == PaintingStyle.fill) canvas.drawPath(getTrianglePath(size.width, size.height), fillPaint);
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
  Map<String, String> _error = {};

  CellGroup _matrix;
  CellGroup _sequences;

  bool _solutionFound = false;

  String appID = "";

  @override
  void initState() {
    _matrix = CellGroup([], _sequencesState);

    _sequences = CellGroup([], _sequencesState);
    verifyValidMatrix();
    loadBufferSize();
    super.initState();
  }

  void loadBufferSize() async {
    _bufferSize = (await SharedPreferences.getInstance()).getInt("bufferSize");
    if (_bufferSize != null) {
      _bufferSizeController = TextEditingController(text: _bufferSize.toString());
    } else {
      _bufferSizeController = TextEditingController();
    }
    _error["MISSING BUFFER SIZE"] = _bufferSize == null ? "Specify buffer size before calculating path." : "";
    setState(() {});
  }

  final TextRecognizer _textRecognizer = FirebaseVision.instance.textRecognizer();

  int _bufferSize;
  TextEditingController _bufferSizeController;

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

  Future<void> _parseGroup(String entity, String processingMsg, CellGroup result, bool square, bool both) async {
    try {
      var file = await ImagePicker().getImage(source: ImageSource.camera);
      if (file == null) {
        return;
      }

      _processing[entity] = processingMsg;
      _error["SCREEN SCAN ERROR"] = "";
      _error["${entity.toUpperCase()} SCAN ERROR"] = "";
      _error["exception"] = "";
      _solution = TraversedPath([]);
      _solutionFound = false;
      if (!both) result.clear();
      _sequencesState.clear();
      setState(() {});

      final FirebaseVisionImage visionImage = FirebaseVisionImage.fromFilePath(file.path);
      final VisionText visionText = await _textRecognizer.processImage(visionImage);
      List<SequenceCapture> captures = [];
      visionText.blocks.where((block) => block.text.split(" ").any((possibleHex) => _validHex.contains(possibleHex))).forEach((block) =>
          block.lines.map((l) => l.elements).forEach((elms) =>
              elms.forEach((e) {
                if (_validHex.contains(e.text.substring(0, min(e.text.length, 2)))) captures.add(SequenceCapture.fromElement(e, square));
              })));

      await File(file.path).delete();

      if (both) {
        _matrix.clear();
        _sequences.clear();
        _matrix.addAll(SequenceGroup(captures, true, both).get().map((s) => s.sequence));
        _sequences.addAll(SequenceGroup(captures, false, both).get().map((s) => s.sequence));
        _error["MATRIX SCAN ERROR"] = "";
        _error["SEQUENCE SCAN ERROR"] = "";
      } else {
        result.clear();
        var x = SequenceGroup(captures, square, both).get().map((s) => s.sequence);
        result.addAll(x);
      }

      if (_matrix.length == 0 || (_matrix.any((row) => row.length != _matrix.length))) {
        var e = Exception("Invalid matrix size: ${_matrix.map((r) => r.length).fold(0, (a, b) => a + b)} elements parsed.");
        _matrix.clear();
        throw e;
      }

      if (_sequences.length == 0) {
        var e = Exception("No sequences parsed.");
        _sequences.clear();
        throw e;
      }
    } on Exception catch(e) {
      if (result != null) result.clear();
      _error["${entity.toUpperCase()} SCAN ERROR"] = Solution.parseError(entity);
      _error["exception"] = e.toString();
    }
    _processing[entity] = null;
    verifyValidMatrix();
  }

  void verifyValidMatrix() {
    if (_matrix.any((row) => row.any((e) => !_validHex.contains(e)))) {
      _error["INCOMPLETE MATRIX"] = "Some matrix elements couldn't be parsed. Any matrix value can be tapped and changed. You can also re-scan the matrix.";
    } else {
      _error["INCOMPLETE MATRIX"] = "";
    }
    setState(() {});
  }

  _launchURL() async {
    const url = 'https://www.buymeacoffee.com/nicolas.siplis';
    if (await canLaunch(url)) {
      await launch(url, forceWebView: true, enableJavaScript: true);
    } else {
      throw 'Could not launch $url';
    }
  }


  Map<String, String> _processing = {};

  RawMaterialButton _parseButton(String text, String entity, Color strokeColor, Future<void> Function() onPressed, {fontSize: 20.0, padding: 5.0, opacity: 0.95}) {
    return RawMaterialButton(
        child: CustomPaint(
            painter: CyberpunkButtonPainter(strokeColor: strokeColor, paintingStyle: PaintingStyle.stroke),
            child: Padding(
                padding: EdgeInsets.all(padding),
                child: Text(_processing[entity] ?? text,
                    style: TextStyle(
                        color: strokeColor,
                        fontWeight: FontWeight.bold,
                        fontSize: fontSize,
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
                        controller: _bufferSizeController,
                        style: TextStyle(
                            color: AppColor.getNeutral(), fontSize: 20, fontWeight: FontWeight.bold, fontFamily: GoogleFonts.rajdhani().fontFamily),
                        decoration: new InputDecoration(
                            filled: true,
                            hoverColor: (_bufferSize == null ? AppColor.getInteractable() : AppColor.getNeutral()).withOpacity(0.3),
                            focusColor: (_bufferSize == null ? AppColor.getInteractable() : AppColor.getNeutral()).withOpacity(0.3),
                            fillColor: (_bufferSize == null ? AppColor.getInteractable() : AppColor.getNeutral()).withOpacity(0.3),
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: _bufferSize == null ? AppColor.getInteractable() : AppColor.getNeutral(), width: 2),
                            ),
                            focusedBorder: OutlineInputBorder(
                                borderSide: BorderSide(color: _bufferSize == null ? AppColor.getInteractable() : AppColor.getNeutral(), width: 2)),
                            labelText: "BUFFER SIZE",
                            labelStyle: TextStyle(
                              fontSize: 20,
                              height: 1.75,
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
                            (await SharedPreferences.getInstance()).setInt("bufferSize", newBuffer);
                            _solution = TraversedPath([]);
                          }
                          setState(() {});
                        })),
                SizedBox(height: 8),
                Padding(
                    padding: EdgeInsets.all(0),
                    child: _parseButton('SCAN BREACH SCREEN', "Sequences", _matrix.isEmpty ? AppColor.getInteractable() : AppColor.getNeutral(),
                            () => _parseGroup("Screen", "SCANNING SCREEN...", null, false, true), fontSize: 25.0, padding: 10.0, opacity: 1.0)),
                SizedBox(height: 8),
                Padding(
                    padding: EdgeInsets.all(0),
                    child: _matrix.isNotEmpty ? AnimatedContainer(
                        duration: Duration(milliseconds: 10000),
                        child: _parseButton('RE-SCAN CODE MATRIX', "Matrix", _matrix.any((r) => r.contains("?")) ? AppColor.getInteractable() : AppColor.getNeutral(),
                            () => _parseGroup("Matrix", "SCANNING CODE MATRIX...", _matrix, true, false))) : Container()),
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
                                            child: matrixCell(row.key, column.key, _bufferSize, _solution, _matrix.get(row.key, column.key)))))
                                    .toList()))
                            .toList())),
                Padding(
                    padding: EdgeInsets.all(0),
                    child: _sequences.isNotEmpty ? _parseButton('RE-SCAN SEQUENCES', "Sequences", AppColor.getInteractable(),
                        () => _parseGroup("Sequence", "SCANNING SEQUENCES...", _sequences, false, false)) : Container()),
                Padding(
                    padding: EdgeInsets.all(0),
                    child: Table(
                        children: _sequences
                            .map((seq) =>
                                // Make all rows the same length to prevent rendering error. TODO: Find a layout which removes the need for doing this
                                seq + List.filled(max(5, _sequences.map((r) => r.length).fold(0, max)) - seq.length, ""))
                            .toList()
                            .asMap()
                            .entries
                            .map((sequence) => TableRow(
                                children: ([MapEntry(-1, "")] + (sequence.value.asMap().entries.toList()))
                                    .map((elm) => elm.key >= 0
                                        ? Padding(
                                            padding: EdgeInsets.symmetric(vertical: 2),
                                            child: DisplayCell.forSequence(sequence.key, elm.key, _bufferSize, _sequences.getRow(sequence.key), _solution, _matrix, _solutionFound)
                                                .render(callback: () {
                                                  _solutionFound = false;
                                                  setState((){});
                                                }))
                                        : Padding(
                                            padding: EdgeInsets.symmetric(vertical: 2),
                                            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Container(height: 52.0, width: 52.0, child: DisplayCell.forToggle(null, null, _bufferSize, null, _solution, null).render(
                                                elm: _sequencesState[sequence.value.where((e) => e != "").toList().toString()] ?? true ? "✓" : "✗",
                                                color: _sequencesState[sequence.value.where((e) => e != "").toList().toString()] ?? true
                                                    ? AppColor.getInteractable()
                                                    : AppColor.getDeactivated(),
                                                    onTap: () async {
                                              _solutionFound = false;
                                              var key = sequence.value.where((e) => e != "" && e != "-").toList().toString();
                                              var enabled = _sequencesState[key];
                                              _sequencesState[key] = !(enabled == null || enabled);
                                              setState(() {});
                                            }))])))
                                    .toList()))
                            .toList())),
                Padding(
                    padding: EdgeInsets.all(0),
                    child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                      Expanded(flex: 10, child: _parseButton(
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
                        () => _calculatePath(), fontSize: 25.0))
                    ])),
                Padding(
                    padding: EdgeInsets.all(0),
                    child: Text(Solution.allErrors(_error),
                        style: TextStyle(
                            color: AppColor.getFailure(), fontSize: Solution.allErrors(_error).isEmpty ? 0 : 20, fontWeight: FontWeight.bold, fontFamily: GoogleFonts.rajdhani().fontFamily),
                        textAlign: TextAlign.justify)),
                _parseButton(
                    "☕",
                    "Donate",
                    Colors.transparent,
                        () => _launchURL())
              ],
            ),
          )),
    );
  }

  int _reviewCounter = 0;

  void _computeSolution(String processingMsg, String processingKey) {
    _processing[processingKey] = processingMsg;
    setState(() {});
    compute(Solution.calculateSolution, {
      "bufferSize": _bufferSize,
      "matrix": _matrix,
      "sequences": CellGroup(
          _sequences.map((row) => row.where((element) => element != "" && element != "-").toList()).where((element) => _sequencesState[element.toString()] == null || _sequencesState[element.toString()]).toList(), _sequencesState)
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

  Color _colorForCell(int bufferSize, TraversedPath solution, int x, int y, String dropdownValue) {
    if (dropdownValue == "?") return AppColor.getInteractable();
    if (bufferSize == null) return AppColor.getDeactivated();
    return (_isPartOfSolution(bufferSize, solution, x, y, dropdownValue) != null) ? AppColor.getSuccess() : (_solutionFound ? AppColor.getFailure() : AppColor.getNeutral());
  }

  String _isPartOfSolution(int bufferSize, TraversedPath solution, int x, int y, String dropdownValue) {
    if (!_solutionFound) return null;
    if (bufferSize == null) return null;
    if (solution.coords.length > bufferSize) return null;
    for (int i = 0; i < solution.coords.length; i++) {
      if (solution.coords[i][0] == x && solution.coords[i][1] == y) {
        return (i + 1).toString();
      }
    }
    return null;
  }

  List<String> _items = ['1C', '55', 'FF', '7A', 'BD', 'E9', '?'];
  Widget matrixCell(int x, int y, int bufferSize, TraversedPath solution, String dropdownValue) {
    TextStyle style = TextStyle(
        color: _colorForCell(bufferSize, solution, x, y, dropdownValue),
        fontSize: 22,
        fontWeight: FontWeight.bold,
        fontFamily: GoogleFonts.rajdhani().fontFamily);
    String isPart = _isPartOfSolution(bufferSize, solution, x, y, dropdownValue);
    return AnimatedContainer(duration: Duration(milliseconds: 1000), child: SizedBox(height: 27, child: DecoratedBox(
        decoration: BoxDecoration(color: _colorForCell(bufferSize, solution, x, y, dropdownValue).withOpacity(0), border: Border.all(color: _colorForCell(bufferSize, solution, x, y, dropdownValue), width: 1)),
        child: DropdownButtonHideUnderline(child: DropdownButton(
          value: _isPartOfSolution(bufferSize, solution, x, y, dropdownValue) ?? dropdownValue,
          style: style,
          isExpanded: true,
          iconSize: 0,
          onChanged: (String newValue) {
            dropdownValue = newValue;
            if (_items.contains(newValue)) {
              _matrix.set(x, y, newValue);
            }
            verifyValidMatrix();
            },
          items: (isPart != null ? [isPart] : _items).map((String value) {
            return DropdownMenuItem<String>(
              value: value,
              child: Container(alignment: Alignment.center, child: Text("${isPart != null ? _matrix.get(x, y) : value}${isPart == null ? '' : '/$isPart'}", style: style, textAlign: TextAlign.center)),
            );
          }).toList(),
        ))
    )));
  }

}
