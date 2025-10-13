// 文件: lib/main.dart
// (这是最终的、基于你现有完整代码的修复版本)

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

import 'package:one_five_one_ten/providers/global_providers.dart';


Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // (*** 1. 关键修改：创建一个 ProviderContainer 以便在 runApp 之前调用 Provider ***)
  final container = ProviderContainer();
  // 在应用启动前，异步加载已保存的主题设置
  await container.read(themeProvider.notifier).init();


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

        final int? localAccountId = asset.accountLocalId ??
            (asset.accountSupabaseId != null
                ? accountSupabaseIdToLocalId[asset.accountSupabaseId!]
                : null);

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

  // (*** 2. 关键修改：使用 UncontrolledProviderScope 来传递已完成初始化的 Provider 容器 ***)
  runApp(UncontrolledProviderScope(
    container: container,
    child: const MyApp(),
  ));
}

final supabase = Supabase.instance.client;

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 你的调用方式是正确的，监听 themeProvider 即可获取 ThemeMode 状态
    final themeMode = ref.watch(themeProvider);

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
      themeMode: themeMode, 
      home: const MainNavPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}