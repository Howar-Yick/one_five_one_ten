// lib/pages/settings_page.dart
import 'package:flutter/material.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('我的设置'),
      ),
      body: const Center(
        child: Text('这里将放置App的设置选项'),
      ),
    );
  }
}