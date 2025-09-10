import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:one_five_one_ten/pages/accounts_page.dart';
import 'package:one_five_one_ten/services/database_service.dart';

// main 函数修改为异步
Future<void> main() async {
  // 确保 Flutter 小部件绑定已初始化
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化数据库服务
  await DatabaseService().init();

  // 使用 ProviderScope 包裹根组件，以启用 Riverpod
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '壹伍壹拾',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      darkTheme: ThemeData.dark(useMaterial3: true),
      themeMode: ThemeMode.system, // 跟随系统主题
      home: const AccountsPage(), // 将首页设置为我们的账户页面
    );
  }
}