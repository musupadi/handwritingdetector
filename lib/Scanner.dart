import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tflite_v2/tflite_v2.dart';

class Scanner extends StatefulWidget {
  const Scanner({Key? key}) : super(key: key);

  @override
  State<Scanner> createState() => _ScannerState();
}

class _ScannerState extends State<Scanner> {
  bool isDetecting = false;
  bool isDialogShowing = false;
  var _recognitions = [];
  String result = '';
  XFile? _selectedImage; // Untuk menyimpan gambar yang diambil atau diupload

  @override
  void initState() {
    super.initState();
    loadModel();
  }

  Future<void> loadModel() async {
    try {
      await Tflite.loadModel(
        model: "assets/tensorflow/model_unquant.tflite",
        labels: "assets/tensorflow/labels.txt",
      );
    } catch (e) {
      print("Error loading model: $e");
    }
  }

  Future<void> pickImageFromGallery() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _selectedImage = pickedFile;
        result = "Gambar dari galeri dipilih.";
      });

      // Tambahkan logika untuk memproses gambar yang diambil dari galeri
      await detectImage(pickedFile);
    }
  }

  Future<void> takeImageFromCamera() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.camera);

    if (pickedFile != null) {
      setState(() {
        _selectedImage = pickedFile;
        result = "Gambar dari kamera diambil.";
      });

      // Tambahkan logika untuk memproses gambar yang diambil dari kamera
      await detectImage(pickedFile);
    }
  }

  Future<void> detectImage(XFile image) async {
    try {
      int startTime = DateTime.now().millisecondsSinceEpoch;

      var recognitions = await Tflite.runModelOnImage(
        path: image.path,
        numResults: 6,
        threshold: 0.05,
        imageMean: 127.5,
        imageStd: 127.5,
      );

      setState(() {
        _recognitions = recognitions ?? [];
        result = recognitions?.isNotEmpty == true ? recognitions.toString() : "No object detected";
      });

      int endTime = DateTime.now().millisecondsSinceEpoch;
      print("Inference took ${endTime - startTime}ms");

      if (recognitions != null && recognitions.isNotEmpty) {
        for (var recog in recognitions) {
          double confidence = recog["confidence"] ?? 0.0;
          String label = recog["label"] ?? 'Unknown';
          if (confidence > 0.9) {
            await _showHighConfidenceDialog(label, confidence);
            break;
          }
        }
      }
    } catch (e) {
      print("Error during image detection: $e");
    }
  }

  Future<void> _showHighConfidenceDialog(String label, double confidence) async {
    isDialogShowing = true;
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("High Confidence Detection"),
          content: Text(
              "Label: $label\nConfidence: ${(confidence * 100).toStringAsFixed(2)}%"),
          actions: <Widget>[
            TextButton(
              child: const Text("OK"),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
    isDialogShowing = false;
  }

  @override
  void dispose() {
    Tflite.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hand Writer', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.blue,
        actions: [
          IconButton(
            icon: Icon(Icons.photo_library, color: Colors.white),
            onPressed: pickImageFromGallery, // Memilih gambar dari galeri
          ),
          IconButton(
            icon: Icon(Icons.camera_alt, color: Colors.white),
            onPressed: takeImageFromCamera, // Mengambil gambar dari kamera
          ),
        ],
      ),
      body: Stack(
        children: <Widget>[
          Align(
            alignment: Alignment.center,
            child: _selectedImage != null
                ? Image.file(
              File(_selectedImage!.path),
              fit: BoxFit.cover,
              width: MediaQuery.of(context).size.width,
              height: MediaQuery.of(context).size.height * 0.6,
            )
                : const Text("No image selected"),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              padding: const EdgeInsets.all(10),
              color: Colors.black.withOpacity(0.5),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: _recognitions.map((recog) {
                  String className = recog["label"] ?? 'Unknown';
                  double confidence = recog["confidence"] ?? 0.0;

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: Text(
                            className.substring(2),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16.0,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 5,
                          child: LinearProgressIndicator(
                            value: confidence,
                            backgroundColor: Colors.grey,
                            color: Colors.blue,
                            minHeight: 8,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          "${(confidence * 100).toStringAsFixed(0)}%",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14.0,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
