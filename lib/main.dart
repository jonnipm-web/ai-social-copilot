import 'package:flutter/material.dart';

void main() {
  runApp(const MaterialApp(
    home: Scaffold(
      backgroundColor: Color(0xFF6C63FF),
      body: Center(
        child: Text(
          'Flutter funcionando!',
          style: TextStyle(color: Colors.white, fontSize: 24),
        ),
      ),
    ),
  ));
}
