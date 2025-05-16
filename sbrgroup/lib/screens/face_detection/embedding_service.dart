import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:tflite_flutter_plus/tflite_flutter_plus.dart'; // ✅ updated package

class FaceEmbeddingService {
  late Interpreter _interpreter;
  bool _isModelLoaded = false;

  FaceEmbeddingService();

  Future<void> init() async {
    try {
      print("Loading TFLite model...");
      _interpreter = await Interpreter.fromAsset('mobilefacenet.tflite');
      _isModelLoaded = true;

      print("Model loaded successfully.");
      final inputShape = _interpreter.getInputTensor(0).shape;
      final inputType = _interpreter.getInputTensor(0).type;
      print('Input Shape: $inputShape');
      print('Input Type: $inputType');
    } catch (e) {
      print('❌ Error loading model: $e');
    }
  }

  bool get isReady => _isModelLoaded;

  Future<List<double>> getEmbedding(img.Image image) async {
    if (!_isModelLoaded) {
      print('❌ Model not loaded yet.');
      return [];
    }

    final resizedImage = img.copyResizeCropSquare(image, size: 112);
    final input = imageToByteListFloat32(resizedImage, 112);
    final output =
        List.filled(192, 0.0).reshape([1, 192]); // ✅ Match model's output

    try {
      _interpreter.run(input.reshape([1, 112, 112, 3]), output);
      print("✅ Embedding generated.");
      print('First 10 values: ${output[0].sublist(0, 10)}');
    } catch (e) {
      print('❌ Error running inference: $e');
      return [];
    }

    return List<double>.from(output[0]);
  }

  Float32List imageToByteListFloat32(img.Image image, int inputSize) {
    final buffer = Float32List(inputSize * inputSize * 3);
    int pixelIndex = 0;
    const mean = 127.5;
    const std = 127.5;

    for (int y = 0; y < inputSize; y++) {
      for (int x = 0; x < inputSize; x++) {
        final pixel = image.getPixel(x, y);
        buffer[pixelIndex++] = (pixel.r - mean) / std;
        buffer[pixelIndex++] = (pixel.g - mean) / std;
        buffer[pixelIndex++] = (pixel.b - mean) / std;
      }
    }

    return buffer;
  }

  void dispose() {
    _interpreter.close();
  }
}
