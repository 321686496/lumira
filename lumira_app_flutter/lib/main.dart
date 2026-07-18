import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '如画 Lumira',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 测试 Logo 加载
              Image.asset('assets/images/logo.png', width: 100),
              const SizedBox(height: 20),
              // 测试模板封面加载
              Image.asset('assets/images/templates/cafe_portrait.jpg', width: 200),
            ],
          ),
        ),
      ),
    );
  }
}
