// lib/pages/settings_page.dart
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:one_five_one_ten/services/database_service.dart';
import 'package:one_five_one_ten/services/onedrive_service.dart';

final onedriveAuthStateProvider = FutureProvider<OneDriveAuthState>((ref) async {
  return OneDriveService().getAuthState();
});

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authAsync = ref.watch(onedriveAuthStateProvider);

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
                          if (ok) ref.invalidate(onedriveAuthStateProvider);
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
                            ref.invalidate(onedriveAuthStateProvider);
                          },
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => _uploadToCloud(context),
                              child: const Text('上传到云端'),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => _downloadFromCloud(context),
                              child: const Text('从云端恢复'),
                            ),
                          ),
                        ],
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
            onTap: () => _restoreData(context),
          ),
        ],
      ),
    );
  }

  // ======= 云端：上传到 OneDrive =======
  Future<void> _uploadToCloud(BuildContext context) async {
    final isar = DatabaseService().isar;
    final messenger = ScaffoldMessenger.of(context);

    try {
      // 先导出到临时文件，再读成 bytes
      final tmp = File('${Directory.systemTemp.path}/one_five_one_ten_upload_${DateTime.now().millisecondsSinceEpoch}.isar');
      await isar.copyToFile(tmp.path);
      final bytes = await tmp.readAsBytes();
      await tmp.delete();

      final fileName = 'backup_${DateTime.now().toIso8601String().split("T").first}.isar';
      final ok = await OneDriveService().uploadBackup(Uint8List.fromList(bytes), fileName);
      if (ok) {
        messenger.showSnackBar(SnackBar(content: Text('上传成功：$fileName')));
      } else {
        messenger.showSnackBar(const SnackBar(content: Text('上传失败，请检查登录与网络')));
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('上传失败：$e')));
    }
  }

  // ======= 云端：从 OneDrive 下载并恢复 =======
  Future<void> _downloadFromCloud(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final result = await OneDriveService().downloadLatestBackup();
      if (result == null) {
        messenger.showSnackBar(const SnackBar(content: Text('云端未找到备份')));
        return;
      }

      final (fileName, bytes) = result;

      final isar = DatabaseService().isar;
      final dbPath = isar.path!;
      await isar.close();
      final file = File(dbPath);
      await file.writeAsBytes(bytes, flush: true);

      // 重新初始化，避免空引用
      await DatabaseService().init();

      messenger.showSnackBar(SnackBar(content: Text('恢复成功：$fileName（如未看到变化，手动重启应用）')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('恢复失败：$e')));
    }
  }

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
      await isar.close();
      File(backupPath).copySync(dbPath);
      messenger.showSnackBar(const SnackBar(content: Text('恢复成功！请手动重启 App 以加载新数据。')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('恢复失败：$e')));
    } finally {
      await DatabaseService().init();
    }
  }
}
