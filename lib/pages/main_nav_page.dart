// lib/pages/main_nav_page.dart
import 'package:flutter/material.dart';
import 'package:one_five_one_ten/pages/accounts_page.dart';
import 'package:one_five_one_ten/pages/dashboard_page.dart';
import 'package:one_five_one_ten/pages/settings_page.dart';

class MainNavPage extends StatefulWidget {
  const MainNavPage({super.key});

  @override
  State<MainNavPage> createState() => _MainNavPageState();
}

class _MainNavPageState extends State<MainNavPage> {
  int _selectedIndex = 0; // 当前选中的页面索引

  // 将我们的三个主页面放入一个列表
  static const List<Widget> _pages = <Widget>[
    DashboardPage(),
    AccountsPage(),
    SettingsPage(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 主体内容根据索引显示不同的页面
      body: _pages.elementAt(_selectedIndex),
      // 底部导航栏
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
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined),
            activeIcon: Icon(Icons.settings),
            label: '我的',
          ),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}