import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'login_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LifeFlow',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: Color(0xFFE53935),
        colorScheme: ColorScheme.fromSeed(
          seedColor: Color(0xFFE53935),
          primary: Color(0xFFE53935),
        ),
        useMaterial3: true,
      ),
      home: LoginPage(),
    );
  }
}
