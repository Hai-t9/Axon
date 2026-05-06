import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:camera/camera.dart';
import 'screens/camera_screen.dart';

List<CameraDescription> cameras = [];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    cameras = await availableCameras();
  } on CameraException catch (e) {
    debugPrint('Error initializing cameras: \$e');
  }

  runApp(
    const ProviderScope(
      child: AxonApp(),
    ),
  );
}

class AxonApp extends StatelessWidget {
  const AxonApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Axon Camera System',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueGrey),
        useMaterial3: true,
      ),
      home: CameraScreen(cameras: cameras),
      debugShowCheckedModeBanner: false,
    );
  }
}

