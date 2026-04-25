import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;
import '../../../../core/constants/app_assets.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/models/plant_disease_info.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.title});

  final String title;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  File? _image;
  PlantDiseaseInfo? _diseaseInfo;
  double _confidence = 0.0;
  bool _loading = false;
  
  Interpreter? _interpreter;
  List<String>? _labels;
  final imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadModel();
    _loadLabels();
  }

  @override
  void dispose() {
    _interpreter?.close();
    super.dispose();
  }

  Future<void> _loadModel() async {
    try {
      _interpreter = await Interpreter.fromAsset(AppAssets.plantModel);
      debugPrint("Interpreter loaded successfully");
    } catch (e) {
      debugPrint("Failed to load model: $e");
    }
  }

  Future<void> _loadLabels() async {
    try {
      final labelsData = await rootBundle.loadString(AppAssets.plantLabels);
      _labels = labelsData.split('\n').where((s) => s.isNotEmpty).toList();
      debugPrint("Labels loaded: ${_labels?.length}");
    } catch (e) {
      debugPrint("Failed to load labels: $e");
    }
  }

  Future<void> _classifyImage(File image) async {
    if (_interpreter == null || _labels == null) {
      debugPrint("Interpreter or labels not loaded");
      return;
    }

    setState(() {
      _loading = true;
      _diseaseInfo = null;
    });

    try {
      // 1. Read image and preprocess
      final imageData = await image.readAsBytes();
      img.Image? originalImage = img.decodeImage(imageData);
      if (originalImage == null) return;

      // Resize to match model input (typically 224x224)
      img.Image resizedImage = img.copyResize(originalImage, width: 224, height: 224);

      // Convert to Float32List and normalize (0-255 -> -1.0 to 1.0 using mean 127.5, std 127.5)
      var input = Float32List(1 * 224 * 224 * 3);
      var buffer = Float32List.view(input.buffer);
      int pixelIndex = 0;
      for (int y = 0; y < 224; y++) {
        for (int x = 0; x < 224; x++) {
          final pixel = resizedImage.getPixel(x, y);
          buffer[pixelIndex++] = (img.getRed(pixel) - 127.5) / 127.5;
          buffer[pixelIndex++] = (img.getGreen(pixel) - 127.5) / 127.5;
          buffer[pixelIndex++] = (img.getBlue(pixel) - 127.5) / 127.5;
        }
      }

      // 2. Prepare output buffer
      // Based on previous error, shape is [1, 15]
      var output = List.filled(1 * 15, 0.0).reshape([1, 15]);

      // 3. Run inference
      _interpreter!.run(input.buffer.asFloat32List().reshape([1, 224, 224, 3]), output);

      // 4. Process output
      List<double> probabilities = List<double>.from(output[0]);
      double maxProb = -1.0;
      int maxIndex = -1;

      for (int i = 0; i < probabilities.length; i++) {
        if (probabilities[i] > maxProb) {
          maxProb = probabilities[i];
          maxIndex = i;
        }
      }

      if (maxIndex != -1 && maxIndex < _labels!.length) {
        setState(() {
          _diseaseInfo = PlantDiseaseInfo.fromLabel(_labels![maxIndex]);
          _confidence = maxProb * 100;
          _loading = false;
        });
      } else {
        setState(() {
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint("Inference error: $e");
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    final pickedFile = await imagePicker.pickImage(source: source);
    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
      });
      _classifyImage(_image!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.yellow[50],
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: AppColors.primary,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              child: Container(
                height: 300,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                  color: Colors.white,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child: _image != null
                      ? Image.file(_image!, fit: BoxFit.cover)
                      : const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.image, size: 100, color: Colors.grey),
                            Text("No Image Selected", style: TextStyle(color: Colors.grey)),
                          ],
                        ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            
            if (_loading)
              const CircularProgressIndicator()
            else if (_diseaseInfo != null)
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildResultRow("Disease", _diseaseInfo!.disease),
                      _buildResultRow("Confidence", "${_confidence.toStringAsFixed(0)}%"),
                      _buildResultRow("Status", _diseaseInfo!.status, 
                          color: _diseaseInfo!.isHealthy ? Colors.green : Colors.red),
                      const Divider(),
                      const Text(
                        "Suggestion:",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        _diseaseInfo!.suggestion,
                        style: const TextStyle(fontSize: 16, color: Colors.black87),
                      ),
                    ],
                  ),
                ),
              ),
            
            const SizedBox(height: 30),
            
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildActionButton(
                  icon: Icons.camera_alt,
                  label: "Take Photo",
                  onPressed: () => _pickImage(ImageSource.camera),
                ),
                _buildActionButton(
                  icon: Icons.photo_library,
                  label: "Upload Photo",
                  onPressed: () => _pickImage(ImageSource.gallery),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(fontSize: 18, color: Colors.black),
          children: [
            TextSpan(text: "$label: ", style: const TextStyle(fontWeight: FontWeight.bold)),
            TextSpan(text: value, style: TextStyle(color: color ?? Colors.black87)),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({required IconData icon, required String label, required VoidCallback onPressed}) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
