// 文件: lib/main.dart
// (这是完整的、已应用主题切换逻辑的文件)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:one_five_one_ten/pages/main_nav_page.dart'; 
import 'package:one_five_one_ten/services/database_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:one_five_one_ten/allocation/allocation_service.dart';
import 'package:one_five_one_ten/allocation/feature_flags.dart';
import 'package:one_five_one_ten/services/calculator_service.dart';
import 'package:one_five_one_ten/services/exchangerate_service.dart';
import 'package:one_five_one_ten/models/asset.dart';
import 'package:one_five_one_ten/models/account.dart';
import 'package:isar/isar.dart';

// ★ 新增导入
import 'package:one_five_one_ten/providers/global_providers.dart';


Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://gmnuyxqxgtnpaolzgujd.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImdtbnV5eHF4Z3RucGFvbHpndWpkIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTgwOTIxODIsImV4cCI6MjA3MzY2ODE4Mn0.8dYrJAaWyU0dyvFZlS52GZQlimUi-oVaxrrKUzkxZ3U',
  );

  await DatabaseService().init();

  if (kFeatureAllocation) {
    AllocationRegistry.register(() async {
      final isar = DatabaseService().isar;
      final calcService = CalculatorService();
      final fx = ExchangeRateService();

      final allAssets = await isar.assets.where().findAll();
      
      final allAccounts = await isar.accounts.where().findAll();
      final accountSupabaseIdToLocalId = {
        for (var acc in allAccounts)
          if (acc.supabaseId != null) acc.supabaseId!: acc.id
      };
      
      final List<PositionLike> items = [];

      for (final asset in allAssets) {
        Map<String, dynamic> performance;
        double assetLocalValue = 0.0;

        if (asset.subType == AssetSubType.wealthManagement) {
          performance = await calcService.calculateValueAssetPerformance(asset);
          assetLocalValue = (performance['currentValue'] ?? 0.0) as double;
        } 
        else if (asset.trackingMethod == AssetTrackingMethod.shareBased) {
          performance = await calcService.calculateShareAssetPerformance(asset);
          assetLocalValue = (performance['marketValue'] ?? 0.0) as double;
        } else {
          performance = await calcService.calculateValueAssetPerformance(asset);
          assetLocalValue = (performance['currentValue'] ?? 0.0) as double;
        }

        final double rate = await fx.getRate(asset.currency, 'CNY');
        final double marketValueCNY = assetLocalValue * rate;

        final int? localAccountId = accountSupabaseIdToLocalId[asset.accountSupabaseId];

        if (marketValueCNY > 0.01 && localAccountId != null) {
          items.add(PositionLike(
            id: asset.id,
            accountId: localAccountId,
            code: asset.code,
            name: asset.name,
            marketValue: marketValueCNY,
            subType: asset.subType.name,
          ));
        }
      }
      
      return items;
    });
  }

  runApp(const ProviderScope(child: MyApp()));
}

final supabase = Supabase.instance.client;

// ★★★ 修复点: 转换为 ConsumerWidget 以监听 Provider ★★★
class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 监听主题变化
    final themeMode = ref.watch(themeProvider);

    return MaterialApp(
      title: '壹伍壹拾',
      // 浅色主题配置
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple, brightness: Brightness.light),
        useMaterial3: true,
      ),
      // 深色主题配置
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple, brightness: Brightness.dark),
        useMaterial3: true,
      ),
      // 应用当前的主题模式
      themeMode: themeMode, 
      home: const MainNavPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}