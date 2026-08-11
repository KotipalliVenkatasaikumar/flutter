import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:ajna/theme/app_colors.dart';

class FullImageScreen extends StatelessWidget {
  final Uint8List imageData; // Blob data (image bytes)

  FullImageScreen({required this.imageData});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.onPrimary,
        elevation: 0,
        // Brand hero gradient — matches CustomAppBar and the home header.
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: AppColors.heroGradient,
              stops: AppColors.heroStops,
            ),
          ),
        ),
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
