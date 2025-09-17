// lib/main.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:one_five_one_ten/pages/main_nav_page.dart'; 
import 'package:one_five_one_ten/services/database_service.dart';

// 1. 导入 Supabase Flutter SDK
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 2. 初始化 Supabase
  // ！！！请确保替换为您在 Supabase 仪表盘中获取到的真实凭证！！！
  await Supabase.initialize(
    url: 'https://gmnuyxqxgtnpaolzgujd.supabase.co',      // 替换为您的 Project URL
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImdtbnV5eHF4Z3RucGFvbHpndWpkIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTgwOTIxODIsImV4cCI6MjA3MzY2ODE4Mn0.8dYrJAaWyU0dyvFZlS52GZQlimUi-oVaxrrKUzkxZ3U', // 替换为您的 anon key
  );

  // 3. 初始化本地数据库 (保持不变)
  await DatabaseService().init();

  // 4. 运行 App (保持不变)
  runApp(const ProviderScope(child: MyApp()));
}

// 5. (可选但推荐) 创建一个全局辅助变量来方便地访问 Supabase 客户端
final supabase = Supabase.instance.client;

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '壹伍壹拾',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple, brightness: Brightness.light),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple, brightness: Brightness.dark),
        useMaterial3: true,
      ),
      themeMode: ThemeMode.system, 
      home: const MainNavPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}