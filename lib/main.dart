import 'package:currency_converter/home_page.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Simple Currency Converter',
      home: const HomePage(),
      theme: ThemeData(
        textSelectionTheme: const TextSelectionThemeData(
          selectionHandleColor: Color(0xFFb79525),
          selectionColor: Color(0xFFb79525),
        ),
      ),
    );
  }
}
