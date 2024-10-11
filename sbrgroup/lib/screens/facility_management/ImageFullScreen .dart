import 'package:flutter/material.dart';
import 'dart:typed_data';

class FullImageScreen extends StatelessWidget {
  final Uint8List imageData; // Blob data (image bytes)

  FullImageScreen({required this.imageData});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color.fromRGBO(6, 73, 105, 1),
        title: const Text(
          'Full Image',
          style: TextStyle(
            fontSize: 18,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(
          color: Colors.white,
        ),
      ),
      body: Center(
        child: InteractiveViewer(
          child: Image.memory(
            imageData, // Display the image from bytes
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return const Text('Error loading image');
            },
          ),
        ),
      ),
    );
  }
}
