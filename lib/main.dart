import 'package:flutter/material.dart';
import 'main_page_screen.dart';
import 'settings.dart';

Future main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Settings().init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Garage Opener',
      theme: ThemeData(
        visualDensity: VisualDensity.compact,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.lightBlueAccent),
        useMaterial3: true,
      ),
      home: const MainPage(),
    );
  }
}
