// lib/main.dart
// (*** 已为你集成 ChatGPT 方案 ***)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:one_five_one_ten/pages/main_nav_page.dart'; 
import 'package:one_five_one_ten/services/database_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// (*** 1. 导入新模块和所需的服务 ***)
import 'package:one_five_one_ten/allocation/allocation_service.dart';
import 'package:one_five_one_ten/allocation/feature_flags.dart';
import 'package:one_five_one_ten/services/calculator_service.dart';
import 'package:one_five_one_ten/services/exchangerate_service.dart';
import 'package:one_five_one_ten/models/asset.dart';
import 'package:isar/isar.dart';
// (*** 导入结束 ***)


Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://gmnuyxqxgtnpaolzgujd.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImdtbnV5eHF4Z3RucGFvbHpndWpkIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTgwOTIxODIsImV4cCI6MjA3MzY2ODE4Mn0.8dYrJAaWyU0dyvFZlS52GZQlimUi-oVaxrrKUzkxZ3U',
  );

  await DatabaseService().init();

  // (*** 2. 在这里注册数据源 ***)
  if (kFeatureAllocation) {
    AllocationRegistry.register(() async {
      // 1. 获取所有服务和数据库实例
      final isar = DatabaseService().isar;
      final calcService = CalculatorService();
      final fx = ExchangeRateService();

      // 2. 获取所有资产
      final allAssets = await isar.assets.where().findAll();
      
      final List<PositionLike> items = [];

      // 3. 遍历所有资产，计算其 CNY 市值
      for (final asset in allAssets) {
        Map<String, dynamic> performance;
        double assetLocalValue = 0.0;

        // (复用我们之前修复好的 CalculatorService 逻辑)
        if (asset.subType == AssetSubType.wealthManagement) {
          performance = await calcService.calculateValueAssetPerformance(asset);
          assetLocalValue = (performance['currentValue'] ?? 0.0) as double;
        } 
        else if (asset.trackingMethod == AssetTrackingMethod.shareBased) {
          performance = await calcService.calculateShareAssetPerformance(asset);
          assetLocalValue = (performance['marketValue'] ?? 0.0) as double;
        } else {
          // (包括 "其他" 类型的价值法资产, 以及我们修复过的脏数据)
          performance = await calcService.calculateValueAssetPerformance(asset);
          assetLocalValue = (performance['currentValue'] ?? 0.0) as double;
        }

        // 4. 转换成 CNY
        final double rate = await fx.getRate(asset.currency, 'CNY');
        final double marketValueCNY = assetLocalValue * rate;

        // 5. 如果有市值，才计入配置
        if (marketValueCNY > 0.01) {
          items.add(PositionLike(
            code: asset.code,
            name: asset.name,
            marketValue: marketValueCNY,
            subType: asset.subType.name, // 传递 subType 帮助归桶
          ));
        }
      }
      
      return items;
    });
  }
  // (*** 适配器逻辑结束 ***)

  runApp(const ProviderScope(child: MyApp()));
}

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