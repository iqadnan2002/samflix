import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'screens/main_navigation.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Load the hidden API key vault
  await dotenv.load(fileName: ".env");
  
  MediaKit.ensureInitialized();
  await FlutterDownloader.initialize(debug: false, ignoreSsl: true);
  runApp(const SamflixApp());
}

class SamflixApp extends StatelessWidget {
  const SamflixApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SAMFLIX',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true).copyWith(scaffoldBackgroundColor: const Color(0xFF0F0F0F)),
      home: const MainNavigation(),
    );
  }
}