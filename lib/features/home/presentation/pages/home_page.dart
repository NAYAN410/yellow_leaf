import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_tflite/flutter_tflite.dart';
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
  final imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadModel();
  }

  @override
  void dispose() {
    Tflite.close();
    super.dispose();
  }

  Future _loadModel() async {
    try {
      await Tflite.loadModel(
        model: AppAssets.plantModel,
        labels: AppAssets.plantLabels,
      );
    } catch (e) {
      debugPrint("Failed to load model: $e");
    }
  }

  Future _classifyImage(File image) async {
    setState(() {
      _loading = true;
      _diseaseInfo = null;
    });
    
    try {
      var output = await Tflite.runModelOnImage(
        path: image.path,
        numResults: 1,
        threshold: 0.2,
        imageMean: 127.5,
        imageStd: 127.5,
      );

      if (output != null && output.isNotEmpty) {
        setState(() {
          _diseaseInfo = PlantDiseaseInfo.fromLabel(output[0]['label']);
          _confidence = output[0]['confidence'] * 100;
          _loading = false;
        });
      } else {
        setState(() {
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint("Failed to run model: $e");
      setState(() {
        _loading = false;
      });
    }
  }

  Future _pickImage(ImageSource source) async {
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
            // Image Preview Card
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
            
            // Result Section
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
            
            // Buttons
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
