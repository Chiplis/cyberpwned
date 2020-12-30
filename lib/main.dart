import 'package:Cyberpwned/path.dart';
import 'package:Cyberpwned/sequence.dart';
import 'package:Cyberpwned/util.dart';
import 'package:Cyberpwned/cell.dart';

import 'dart:async';
import 'dart:math';

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

class _MyAppState extends State<MyApp> {
  Map<String, String> _error = {"MISSING BUFFER SIZE": "Specify buffer size before calculating path."};

  final TextRecognizer _textRecognizer = FirebaseVision.instance.textRecognizer();

  int _bufferSize;

  CellGroup _matrix = CellGroup([
    ["1C", "BD", "55", "E9", "55"],
    ["1C", "BD", "1C", "55", "E9"],
    ["55", "E9", "E9", "BD", "BD"],
    ["55", "FF", "FF", "1C", "1C"],
    ["FF", "E9", "1C", "BD", "FF"]
  ]);

  CellGroup _sequences = CellGroup([
    ["1C", "1C", "55"],
    ["55", "FF", "1C"],
    ["BD", "E9", "BD", "55"],
    ["55", "1C", "FF", "BD"]
  ]);

  final List<String> _validHex = ["1C", "FF", "E9", "BD", "55", "7A"];

  Map<String, String> _processing = {};
  Path _solution = Path([]);

  OutlinedButton _parseButton(String text, String processingMsg, String entity, CellGroup result, {bool square: false}) {
    return OutlinedButton(
        style: OutlinedButton.styleFrom(
          shape: BeveledRectangleBorder(),
          onSurface: Colors.white,
          side: BorderSide(color: Colors.transparent),
          backgroundColor: result.isEmpty ? AppColor.getInteractable() : AppColor.getNeutral(),
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
            _error["${entity.toUpperCase()} PARSE ERROR"] = Solution.parseError(entity);
          }
          _processing[entity] = null;
          setState(() {});
        },
        child: Text(_processing[entity] ?? text,
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 20, fontFamily: GoogleFonts.rajdhani().fontFamily)));
  }

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
                SizedBox(height: 30),
                Padding(
                    padding: EdgeInsets.symmetric(horizontal: 0),
                    child: TextField(
                        textAlignVertical: TextAlignVertical.center,
                        maxLines: 1,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: AppColor.getNeutral(), fontSize: 20, fontWeight: FontWeight.bold, fontFamily: GoogleFonts.rajdhani().fontFamily),
                        decoration: new InputDecoration(
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: _bufferSize == null ? AppColor.getInteractable() : AppColor.getNeutral(), width: 3),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: _bufferSize == null ? AppColor.getInteractable() : AppColor.getNeutral(), width: 3),
                            ),
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
                            .asMap()
                            .entries
                            .map((sequence) => TableRow(
                                children: sequence.value
                                    .asMap()
                                    .entries
                                    .map((elm) =>
                                        DisplayCell.forSequence(sequence.key, elm.key, _bufferSize, CellGroup([sequence.value]), _solution, _matrix)
                                            .render())
                                    .toList()))
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
                          backgroundColor: _processing["path"] != null
                              ? AppColor.getInteractable()
                              : (Solution.calculationEnabled(_error, _bufferSize, _matrix, _sequences)
                                  ? AppColor.getNeutral()
                                  : AppColor.getFailure()),
                        ),
                        onPressed: () async {
                          _solution = Path([]);
                          setState(() {});
                          if (Solution.calculationEnabled(_error, _bufferSize, _matrix, _sequences)) {
                            _computeSolution("CALCULATING OPTIMAL PATH...", "path");
                          }
                        },
                        child: Text(
                            _processing["path"] ??
                                (_error.keys.where((key) => _error[key] != "").map((key) => key + " ↓").toList() + ["CALCULATE PATH"])[0],
                            style: TextStyle(
                                fontFamily: GoogleFonts.rajdhani().fontFamily, fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black)))),
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

  void _computeSolution(String processingMsg, String processingKey) {
    setState(() {});
    _processing[processingKey] = processingMsg;
    setState(() {});
    compute(Solution.calculateSolution, {"bufferSize": _bufferSize, "matrix": _matrix, "sequences": _sequences}).then((solution) {
      _solution = solution;
      _processing[processingKey] = null;
      setState(() {});
    }, onError: (error) {
      _error["CALCULATION ERROR"] = error.toString();
    });
  }
}
