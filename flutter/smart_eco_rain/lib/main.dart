import 'package:flutter/material.dart';
import 'login_screen.dart';
import 'home_screen.dart'; 

void main() => runApp(const SmartEcoRainApp());

class SmartEcoRainApp extends StatelessWidget {
  const SmartEcoRainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SmartEcoRain',
      theme: ThemeData(
        brightness: Brightness.light,
        fontFamily: 'SFPro',
        primarySwatch: Colors.teal,
        scaffoldBackgroundColor: const Color(0xFFF7FAFE),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: Colors.black,
        ),
      ),
      themeMode: ThemeMode.light,
      home: LoginScreen(), 
      debugShowCheckedModeBanner: false,
      routes: {
        '/home': (context) => HomeScreen(username: ''), 
      },
    );
  }
}
