import 'dart:io';
import 'package:flutter/material.dart';

class PreviewScreen extends StatelessWidget {
  final String imagePath;

  const PreviewScreen({super.key, required this.imagePath});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Preview Photo')),
      body: Center(
        child: Image.file(File(imagePath)),
      ),
      bottomNavigationBar: BottomAppBar(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            TextButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Retake'),
            ),
            ElevatedButton.icon(
              onPressed: () {
                // Here we will later navigate to labeling or submit
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Proceeding to labeling...')),
                );
              },
              icon: const Icon(Icons.check),
              label: const Text('Continue'),
            ),
          ],
        ),
      ),
    );
  }
}

