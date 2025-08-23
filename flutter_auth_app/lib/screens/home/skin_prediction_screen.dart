import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_auth_app/config.dart';
import 'package:flutter_auth_app/screens/home/disease_info_screen.dart';
import 'package:provider/provider.dart';
import 'package:flutter_auth_app/providers/auth_provider.dart';
import 'package:flutter_auth_app/services/prediction_history_service.dart';
import 'package:flutter_auth_app/widgets/app_bottom_nav.dart';
import 'package:flutter_auth_app/screens/home/main_screen.dart';

class SkinPredictionScreen extends StatefulWidget {
  final bool showFooter;
  const SkinPredictionScreen({super.key, this.showFooter = true});

  @override
  State<SkinPredictionScreen> createState() => _SkinPredictionScreenState();
}

class _SkinPredictionScreenState extends State<SkinPredictionScreen> {
  File? _image;
  final picker = ImagePicker();
  String _prediction = '';
  double _confidence = 0.0;
  bool _loading = false;

  final Map<String, String> _predictionMap = {
    'Eczema': 'Atopic Dermatitis',
    'Melanoma': 'Malignant Melanoma',
    'Basal Cell Carcinoma (BCC)': 'Basal Cell Carcinoma',
    'Melanocytic Nevi (NV)': 'Moles',
    'Benign Keratosis-like Lesions (BKL)': 'Seborrheic Keratosis',
    'Psoriasis pictures Lichen Planus and related diseases': 'Psoriasis',
    'Seborrheic Keratoses and other Benign Tumors': 'Seborrheic Keratosis',
    'Tinea Ringworm Candidiasis and other Fungal Infections': 'Tinea',
    'Warts Molluscum and other Viral Infections': 'Molluscum Contagiosum',
  };

  String _getMappedPrediction(String originalPrediction) {
    return _predictionMap[originalPrediction] ?? originalPrediction;
  }

  Future<void> _pickImage() async {
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
        _prediction = '';
        _confidence = 0.0;
      });
    }
  }

  Future<void> _predict() async {
    if (_image == null) return;

    setState(() {
      _loading = true;
    });

    var request = http.MultipartRequest(
      'POST',
      Uri.parse('$backendUrl/predict'),
    );
    request.files.add(
      await http.MultipartFile.fromPath(
        'image',
        _image!.path,
      ),
    );

    try {
      final response = await request.send();
      if (response.statusCode == 200) {
        final responseData = await response.stream.bytesToString();
        final result = json.decode(responseData);
        setState(() {
          _prediction = _getMappedPrediction(result['predicted_class']);
          _confidence = result['confidence'];
        });

        // Save to history if logged in
        final auth = Provider.of<AuthProvider>(context, listen: false);
        final token = auth.token;
        if (token != null && token.isNotEmpty) {
          try {
            await PredictionHistoryService.savePrediction(
              image: _image!,
              prediction: _prediction,
              confidence: _confidence,
              token: token,
            );
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Saved to history')),
              );
            }
          } catch (e) {
            // Non-fatal; just log or show a subtle message
            debugPrint('Failed to save history: $e');
          }
        }
      } else {
        setState(() {
          _prediction = 'Error: ${response.reasonPhrase}';
        });
      }
    } catch (e) {
      setState(() {
        _prediction = 'Error: $e';
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Skin Disease Prediction'),
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              _image == null
                  ? const Text('No image selected.')
                  : Image.file(_image!),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _pickImage,
                child: const Text('Select Image'),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _predict,
                child: const Text('Predict'),
              ),
              const SizedBox(height: 20),
              if (_loading)
                const SizedBox.shrink()
              else if (_prediction.isNotEmpty)
                Text(
                  'Prediction: $_prediction\nConfidence: ${(_confidence * 100).toStringAsFixed(2)}%',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 18),
                ),
              if (_prediction.isNotEmpty &&
                  !_loading &&
                  !_prediction.startsWith('Error'))
                Padding(
                  padding: const EdgeInsets.only(top: 20.0),
                  child: ElevatedButton(
                    onPressed: () async {
                      // Use AuthProvider for the token instead of secure storage
                      final auth =
                          Provider.of<AuthProvider>(context, listen: false);
                      final token = auth.token;
                      if (token == null || token.isEmpty) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text(
                                    'Please log in to get more information.')),
                          );
                          // Optionally take user to login
                          Navigator.pushNamed(context, '/login');
                        }
                        return;
                      }

                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => DiseaseInfoScreen(
                            initialDisease: _prediction,
                            token: token,
                          ),
                        ),
                      );
                    },
                    child: const Text('Get More Information'),
                  ),
                ),
            ],
          ),
        ),
      ),
      // Only show footer when used as a standalone route; when embedded in MainScreen, footer is provided there
      bottomNavigationBar: widget.showFooter
          ? AppBottomNav(
              currentIndex: 1,
              onIndexSelected: (idx) {
                if (idx == 1) return; // already on Scan
                // Map footer index to MainScreen index: Home=0 -> 0, History=2 -> 2->1, Skin Tips=3 -> 3->2
                int mainIndex;
                if (idx == 0) {
                  mainIndex = 0;
                } else if (idx == 2) {
                  mainIndex = 2 - 1; // History
                } else {
                  mainIndex = 3 - 1; // Skin Tips
                }
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MainScreen(initialIndex: mainIndex),
                  ),
                );
              },
            )
          : null,
    );
  }
}
