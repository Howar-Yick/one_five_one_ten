// 文件: lib/pages/settings_page.dart
// (这是完整的、已添加主题切换功能的文件)

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:one_five_one_ten/services/database_service.dart';
import 'package:one_five_one_ten/providers/global_providers.dart';
import 'package:one_five_one_ten/services/supabase_sync_service.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMsg;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    setState(() { _isLoading = true; _errorMsg = null; });
    try {
      final syncService = ref.read(syncServiceProvider);
      await syncService.login(
        _emailController.text.trim(), 
        _passwordController.text.trim()
      );
    } catch (e) {
      _errorMsg = "登录失败: ${e.toString()}";
    } finally {
      if(mounted) setState(() { _isLoading = false; });
    }
  }
  
  Future<void> _handleRegister() async {
    setState(() { _isLoading = true; _errorMsg = null; });
    try {
      final syncService = ref.read(syncServiceProvider);
      await syncService.signUp(
        _emailController.text.trim(), 
        _passwordController.text.trim()
      );
    } catch (e) {
      _errorMsg = "注册失败: ${e.toString()}";
    } finally {
      if(mounted) setState(() { _isLoading = false; });
    }
  }

  Future<void> _handleLogout() async {
      setState(() { _isLoading = true; });
      try {
        await ref.read(syncServiceProvider).logout();
      } catch (e) {
         _errorMsg = "登出失败: ${e.toString()}";
      }
      if(mounted) setState(() { _isLoading = false; });
  }

  @override
  Widget build(BuildContext context) {
    final syncService = ref.watch(syncServiceProvider);
    final priceSyncState = ref.watch(priceSyncControllerProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('我的设置'),
        actions: [
          if (priceSyncState == PriceSyncState.loading)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: '同步所有资产价格',
              onPressed: () {
                ref.read(priceSyncControllerProvider.notifier).syncAllPrices();
              },
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        children: [
          // ========== 云同步 ==========
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('云同步 (Supabase)', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                if (_isLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (syncService.isLoggedIn)
                  _buildLoggedInSection(syncService)
                else
                  _buildLoggedOutSection(),
                
                if (_errorMsg != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(_errorMsg!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  ),
              ],
            ),
          ),

          // ★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★
          // ★★★      新增: 主题切换 UI      ★★★
          // ★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★
          const Divider(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
            child: Text('应用主题', style: Theme.of(context).textTheme.titleLarge),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(
                  value: ThemeMode.light,
                  label: Text('浅色'),
                  icon: Icon(Icons.light_mode_outlined),
                ),
                ButtonSegment(
                  value: ThemeMode.dark,
                  label: Text('深色'),
                  icon: Icon(Icons.dark_mode_outlined),
                ),
                ButtonSegment(
                  value: ThemeMode.system,
                  label: Text('跟随系统'),
                  icon: Icon(Icons.settings_system_daydream_outlined),
                ),
              ],
              selected: {ref.watch(themeProvider)},
              onSelectionChanged: (newSelection) {
                ref.read(themeProvider.notifier).setTheme(newSelection.first);
              },
              style: ButtonStyle(
                visualDensity: VisualDensity.adaptivePlatformDensity,
              ),
            ),
          ),
          const SizedBox(height: 16),
          // ★★★ 新增结束 ★★★

          // ========== 数据操作 ==========
          const Divider(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
            child: Text('数据操作', style: Theme.of(context).textTheme.titleLarge),
          ),
          ListTile(
            leading: const Icon(Icons.cloud_sync_outlined),
            title: const Text('同步所有资产价格'),
            subtitle: const Text('从网络获取最新的收盘价和基金净值'),
            onTap: (priceSyncState == PriceSyncState.loading) 
              ? null 
              : () {
                  ref.read(priceSyncControllerProvider.notifier).syncAllPrices();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('已开始同步...'), duration: Duration(seconds: 2))
                  );
                },
          ),
          
          const Divider(height: 32),

          // ========== 本地备份 ==========
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Text('本地备份', style: Theme.of(context).textTheme.titleLarge),
          ),
          ListTile(
            leading: const Icon(Icons.backup_outlined),
            title: const Text('备份到本地'),
            subtitle: const Text('将所有数据导出到一个本地文件中'),
            onTap: () => _backupData(context),
          ),
          ListTile(
            leading: const Icon(Icons.restore_page_outlined),
            title: const Text('从本地恢复'),
            subtitle: const Text('从备份文件中导入数据（将覆盖当前数据）'),
            onTap: () => _restoreData(context),
          ),
        ],
      ),
    );
  }

  Widget _buildLoggedInSection(SupabaseSyncService syncService) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.cloud_done),
          title: const Text('已登录'),
          subtitle: Text(syncService.currentUser!.email ?? 'N/A'),
        ),
        SizedBox(
          width: double.infinity,
          child: FilledButton.tonal(
            onPressed: _isLoading ? null : _handleLogout,
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.errorContainer
            ),
            child: Text(
              '退出登录', 
              style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer)
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildLoggedOutSection() {
    return Column(
      children: [
        TextFormField(
          controller: _emailController,
          decoration: const InputDecoration(
            labelText: '电子邮件',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.email),
          ),
          keyboardType: TextInputType.emailAddress,
          enabled: !_isLoading,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _passwordController,
          decoration: const InputDecoration(
            labelText: '密码 (至少6位)',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.lock),
          ),
          obscureText: true,
          enabled: !_isLoading,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _isLoading ? null : _handleLogin,
                child: const Text('登录'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton(
                onPressed: _isLoading ? null : _handleRegister,
                child: const Text('注册'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _backupData(BuildContext context) async {
    final isar = DatabaseService().isar;
    final messenger = ScaffoldMessenger.of(context);

    final savePath = await FilePicker.platform.saveFile(
      dialogTitle: '请选择备份保存位置',
      fileName: 'one_five_one_ten_backup_${DateTime.now().toIso8601String().split('T').first}.isar',
    );
    if (savePath == null) {
      if (!context.mounted) return;
      messenger.showSnackBar(const SnackBar(content: Text('已取消备份')));
      return;
    }

    try {
      await isar.copyToFile(savePath);
      messenger.showSnackBar(SnackBar(content: Text('备份成功：$savePath')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('备份失败：$e')));
    }
  }

  Future<void> _restoreData(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: const Text('警告：恢复数据'),
        content: const Text('此操作将用备份文件覆盖当前所有数据，且无法撤销。恢复后建议手动重启应用。是否继续？'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dCtx).pop(false), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.of(dCtx).pop(true), child: const Text('继续恢复', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirmed != true) return;

    final picked = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['isar']);
    if (picked == null || picked.files.single.path == null) {
      messenger.showSnackBar(const SnackBar(content: Text('已取消恢复')));
      return;
    }

    final backupPath = picked.files.single.path!;
    final isar = DatabaseService().isar;
    final dbPath = isar.path!;

    try {
      ref.read(syncServiceProvider).stopSync();
      await isar.close();
      File(backupPath).copySync(dbPath);
      messenger.showSnackBar(const SnackBar(content: Text('恢复成功！请手动重启 App 以加载新数据。')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('恢复失败：$e')));
    } finally {
      await DatabaseService().init();
      ref.invalidate(syncServiceProvider);
    }
  }
}