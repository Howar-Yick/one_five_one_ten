import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:one_five_one_ten/services/database_service.dart';
import 'package:one_five_one_ten/services/onedrive_service.dart';
import 'package:one_five_one_ten/services/sync_service.dart';

// 认证状态 Provider
final onedriveAuthStateProvider = FutureProvider<OneDriveAuthState>((ref) async {
  return OneDriveService().getAuthState();
});

// 自动同步开关 Provider
final autoSyncProvider = FutureProvider<bool>((ref) async {
  return SyncService.instance.isEnabled();
});

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authAsync = ref.watch(onedriveAuthStateProvider);
    final autoSyncEnabled = ref.watch(autoSyncProvider).value ?? true;

    return Scaffold(
      appBar: AppBar(
        title: const Text('我的设置'),
      ),
      body: ListView(
        children: [
          // ========== 云同步 ==========
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: authAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('加载登录状态出错：$e'),
              data: (auth) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('云同步 (OneDrive)', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 8),
                    if (!auth.signedIn) ...[
                      const Text('使用设备码登录你的 Microsoft 账户以启用云端同步。'),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: () async {
                          final ok = await OneDriveService().signInWithDeviceCode(context);
                          if (ok) {
                            ref.invalidate(onedriveAuthStateProvider);
                            // 登录成功后，立即启用并触发一次同步
                            await SyncService.instance.setEnabled(true, triggerSync: true);
                            ref.invalidate(autoSyncProvider);
                          }
                        },
                        child: const Text('登录 Microsoft 账户'),
                      ),
                    ] else ...[
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.cloud_done_outlined),
                        title: const Text('已登录 OneDrive'),
                        subtitle: Text(auth.username ?? '已连接'),
                        trailing: IconButton(
                          icon: const Icon(Icons.logout),
                          tooltip: '登出',
                          onPressed: () async {
                            await OneDriveService().signOut();
                            await SyncService.instance.setEnabled(false); // 登出时禁用自动同步
                            ref.invalidate(onedriveAuthStateProvider);
                            ref.invalidate(autoSyncProvider);
                          },
                        ),
                      ),
                      const SizedBox(height: 8),
                      SwitchListTile(
                        title: const Text('自动云端同步'),
                        subtitle: const Text('数据变更后自动上传，应用启动时自动下载'),
                        value: autoSyncEnabled,
                        onChanged: (val) async {
                           await SyncService.instance.setEnabled(val);
                           ref.invalidate(autoSyncProvider);
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.sync),
                        title: const Text('立即同步'),
                        subtitle: const Text('手动触发一次拉取和推送'),
                        onTap: () async {
                          await SyncService.instance.start();
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('同步已触发')));
                        },
                      ),
                    ],
                  ],
                );
              },
            ),
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
            onTap: () => _restoreData(context, ref),
          ),
        ],
      ),
    );
  }

  // ======= 云端上传/下载（手动按钮，已被SyncService替代，但保留本地逻辑） =======
  // Future<void> _uploadToCloud... (我们使用 SyncService._pushIfDirty 代替)
  // Future<void> _downloadFromCloud... (我们使用 SyncService._pullIfRemoteNewer 代替)

  // ======= 本地：备份到文件 =======
  Future<void> _backupData(BuildContext context) async {
    final isar = DatabaseService().isar;
    final messenger = ScaffoldMessenger.of(context);

    final savePath = await FilePicker.platform.saveFile(
      dialogTitle: '请选择备份保存位置',
      fileName: 'one_five_one_ten_backup_${DateTime.now().toIso8601String().split('T').first}.isar',
    );
    if (savePath == null) {
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

  // ======= 本地：从文件恢复 =======
  Future<void> _restoreData(BuildContext context, WidgetRef ref) async {
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
      // 在恢复前，停止所有同步服务
      await SyncService.instance.stop();
      await isar.close();
      File(backupPath).copySync(dbPath);
      messenger.showSnackBar(const SnackBar(content: Text('恢复成功！请手动重启 App 以加载新数据。')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('恢复失败：$e')));
    } finally {
      // 重新启动数据库和服务
      await DatabaseService().init();
      ref.invalidate(onedriveAuthStateProvider);
      ref.invalidate(autoSyncProvider);
    }
  }
}