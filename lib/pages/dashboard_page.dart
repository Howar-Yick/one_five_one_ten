// lib/pages/dashboard_page.dart
import 'package:flutter/material.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('概览'),
      ),
      body: const Center(
        child: Text('这里将是您的资产总览仪表盘'),
      ),
    );
  }
}