// 文件: lib/pages/main_nav_page.dart
import 'package:flutter/material.dart';
// 1. 导入 Riverpod
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:one_five_one_ten/pages/accounts_page.dart';
import 'package:one_five_one_ten/pages/dashboard_page.dart';
import 'package:one_five_one_ten/pages/settings_page.dart';
// 2. 导入我们的 providers
import 'package:one_five_one_ten/providers/global_providers.dart';
// ★ 新增：配置规划器入口页
import 'package:one_five_one_ten/pages/allocation_planner_page.dart';

// 3. (移除) 不再需要旧的 sync_service
// import 'package:one_five_one_ten/services/sync_service.dart';

// 4. 将 StatefulWidget 更改为 ConsumerStatefulWidget
class MainNavPage extends ConsumerStatefulWidget {
  const MainNavPage({super.key});

  @override
  ConsumerState<MainNavPage> createState() => _MainNavPageState(); // 5. 更改 State 类型
}

// 6. 将 State 更改为 ConsumerState
class _MainNavPageState extends ConsumerState<MainNavPage> {
  int _selectedIndex = 0;

  // ★ 顺序：概览 -> 账户 -> 配置 -> 我的
  static const List<Widget> _pages = <Widget>[
    DashboardPage(),
    AccountsPage(),
    AllocationPlannerPage(), // ★ 新增：配置
    SettingsPage(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  void initState() {
    super.initState();
    // 7. (修改) 使用新的 SupabaseSyncService 检查登录状态
    // 我们使用 WidgetsBinding.instance.addPostFrameCallback 确保 ref 在此阶段可用
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 8. 读取我们新的 provider 并调用检查
      ref.read(syncServiceProvider).checkLoginAndStartSync();
    });
    // 9. (移除) 旧的启动器
    // SyncService.instance.start();
  }

  @override
  void dispose() {
    // 10. (移除) 旧的 dispose 逻辑
    // SyncService.instance.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages.elementAt(_selectedIndex),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            activeIcon: Icon(Icons.dashboard),
            label: '概览',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_balance_wallet_outlined),
            activeIcon: Icon(Icons.account_balance_wallet),
            label: '账户',
          ),
          // ★ 新增的第三个 Tab：配置
          BottomNavigationBarItem(
            icon: Icon(Icons.tune_outlined),
            activeIcon: Icon(Icons.tune),
            label: '配置',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined),
            activeIcon: Icon(Icons.settings),
            label: '我的',
          ),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed, // 四个项目时保持固定样式
      ),
    );
  }
}
