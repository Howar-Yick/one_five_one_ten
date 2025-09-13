// lib/services/onedrive_service.dart
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class OneDriveAuthState {
  final bool signedIn;
  final String? username;
  const OneDriveAuthState(this.signedIn, this.username);
}

class OneDriveService {
  // TODO: 用你的应用的 Client ID 替换（Azure Portal 上的 Application (client) ID）
  static const String _clientId = '09dc69e1-9dd1-419e-920e-7ed97fe26980';

  // common=多租户+MSA；如只想个人账户可改成 'consumers'
  static const String _tenant = 'consumers';
  static const String _authority = 'https://login.microsoftonline.com/$_tenant';
  static const String _scope = 'offline_access Files.ReadWrite.AppFolder openid profile';

  // Graph
  static const String _graph = 'https://graph.microsoft.com/v1.0';

  // 存储键
  static const _kAccessToken = 'od_access_token';
  static const _kRefreshToken = 'od_refresh_token';
  static const _kExpiresAt   = 'od_expires_at';
  static const _kUsername    = 'od_username';

  // 设备码登录
  Future<bool> signInWithDeviceCode(BuildContext context) async {
    final codeRes = await http.post(
      Uri.parse('$_authority/oauth2/v2.0/devicecode'),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {'client_id': _clientId, 'scope': _scope},
    );
if (codeRes.statusCode != 200) {
  try {
    final m = json.decode(codeRes.body) as Map<String, dynamic>;
    final err = m['error'];
    final desc = m['error_description'];
    _toast(context, '获取设备码失败：$err\n$desc');
  } catch (_) {
    _toast(context, '获取设备码失败：${codeRes.statusCode} ${codeRes.body}');
  }
  return false;
}
    final data = json.decode(codeRes.body) as Map<String, dynamic>;
    final deviceCode = data['device_code'] as String;
    final userCode = data['user_code'] as String;
    final verifyUrl = (data['verification_uri_complete'] ?? data['verification_uri']) as String;
    int interval = (data['interval'] as num?)?.toInt() ?? 5;

    bool? proceed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dCtx) => AlertDialog(
        title: const Text('Microsoft 登录'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('在浏览器打开以下链接，并输入下方代码完成授权：'),
            const SizedBox(height: 8),
            SelectableText(verifyUrl, style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 8),
            SelectableText(userCode, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      await launchUrl(Uri.parse(verifyUrl), mode: LaunchMode.externalApplication);
                    },
                    child: const Text('打开验证网页'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text('完成网页中的登录后，点击“已完成授权”。', style: TextStyle(fontSize: 12)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dCtx).pop(false), child: const Text('取消')),
          ElevatedButton(onPressed: () => Navigator.of(dCtx).pop(true), child: const Text('已完成授权')),
        ],
      ),
    );

    if (proceed != true) return false;

    // 轮询 token
    while (true) {
      await Future.delayed(Duration(seconds: interval));
      final tokenRes = await http.post(
        Uri.parse('$_authority/oauth2/v2.0/token'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'grant_type': 'urn:ietf:params:oauth:grant-type:device_code',
          'client_id': _clientId,
          'device_code': deviceCode,
        },
      );

      final body = json.decode(tokenRes.body) as Map<String, dynamic>;
      if (tokenRes.statusCode == 200 && body['access_token'] != null) {
        final accessToken = body['access_token'] as String;
        final refreshToken = body['refresh_token'] as String?;
        final expiresIn = (body['expires_in'] as num?)?.toInt() ?? 3600;

        // 取用户名
        String? username;
        try {
          final me = await http.get(
            Uri.parse('$_graph/me'),
            headers: {'Authorization': 'Bearer $accessToken'},
          );
          if (me.statusCode == 200) {
            final meJson = json.decode(me.body) as Map<String, dynamic>;
            username = (meJson['userPrincipalName'] ?? meJson['mail'] ?? meJson['displayName'])?.toString();
          }
        } catch (_) {}

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_kAccessToken, accessToken);
        if (refreshToken != null) await prefs.setString(_kRefreshToken, refreshToken);
        await prefs.setInt(_kExpiresAt, DateTime.now().add(Duration(seconds: expiresIn - 30)).millisecondsSinceEpoch);
        if (username != null) await prefs.setString(_kUsername, username);

        _toast(context, '登录成功');
        return true;
      } else {
        final err = (body['error'] ?? '').toString();
        if (err == 'authorization_pending') {
          continue; // 用户还没完成
        } else if (err == 'slow_down') {
          interval += 2;
        } else {
          _toast(context, '登录失败：$err');
          return false;
        }
      }
    }
  }

  Future<void> signOut() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kAccessToken);
    await prefs.remove(_kRefreshToken);
    await prefs.remove(_kExpiresAt);
    await prefs.remove(_kUsername);
  }

  Future<OneDriveAuthState> getAuthState() async {
    final prefs = await SharedPreferences.getInstance();
    final access = prefs.getString(_kAccessToken);
    final refresh = prefs.getString(_kRefreshToken);
    final name = prefs.getString(_kUsername);
    if (access == null && refresh == null) return const OneDriveAuthState(false, null);
    return OneDriveAuthState(true, name);
  }

  Future<String?> _validAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    var access = prefs.getString(_kAccessToken);
    final refresh = prefs.getString(_kRefreshToken);
    final expiresAtMs = prefs.getInt(_kExpiresAt) ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;

    if (access != null && now < expiresAtMs) return access;
    if (refresh == null) return null;

    // 刷新
    final res = await http.post(
      Uri.parse('$_authority/oauth2/v2.0/token'),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'grant_type': 'refresh_token',
        'client_id': _clientId,
        'refresh_token': refresh,
        'scope': _scope,
      },
    );
    if (res.statusCode != 200) return null;

    final body = json.decode(res.body) as Map<String, dynamic>;
    access = body['access_token'] as String?;
    final newRefresh = body['refresh_token'] as String?;
    final expiresIn = (body['expires_in'] as num?)?.toInt() ?? 3600;

    if (access == null) return null;
    await prefs.setString(_kAccessToken, access);
    if (newRefresh != null) await prefs.setString(_kRefreshToken, newRefresh);
    await prefs.setInt(_kExpiresAt, DateTime.now().add(Duration(seconds: expiresIn - 30)).millisecondsSinceEpoch);
    return access;
  }

  // 确保 App 根目录（approot）下存在 one_five_one_ten 文件夹
  Future<void> _ensureAppFolder(String accessToken) async {
    final createRes = await http.post(
      Uri.parse('$_graph/me/drive/special/approot/children'),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
      body: json.encode({
        'name': 'one_five_one_ten',
        'folder': {},
        '@microsoft.graph.conflictBehavior': 'replace',
      }),
    );
    // 409/400 说明已存在或已创建，不必特殊处理
    if (createRes.statusCode == 201 || createRes.statusCode == 409 || createRes.statusCode == 400) return;
  }

  // 上传备份（覆盖同名文件）
  Future<bool> uploadBackup(Uint8List bytes, String fileName) async {
    final token = await _validAccessToken();
    if (token == null) return false;

    await _ensureAppFolder(token);
    final uri = Uri.parse('$_graph/me/drive/special/approot:/one_five_one_ten/$fileName:/content');
    final res = await http.put(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/octet-stream',
      },
      body: bytes,
    );
    return res.statusCode == 200 || res.statusCode == 201;
  }

  // 下载最新备份（按修改时间倒序取第一个）
  Future<(String fileName, Uint8List bytes)?> downloadLatestBackup() async {
    final token = await _validAccessToken();
    if (token == null) return null;

    final listUri = Uri.parse(
      '$_graph/me/drive/special/approot:/one_five_one_ten:/children?\$orderby=lastModifiedDateTime desc&\$top=1',
    );
    final listRes = await http.get(listUri, headers: {'Authorization': 'Bearer $token'});
    if (listRes.statusCode != 200) return null;

    final listJson = json.decode(listRes.body) as Map<String, dynamic>;
    final items = (listJson['value'] as List?) ?? [];
    if (items.isEmpty) return null;

    final first = items.first as Map<String, dynamic>;
    final id = first['id'] as String;
    final name = first['name'] as String;

    final dlRes = await http.get(
      Uri.parse('$_graph/me/drive/items/$id/content'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (dlRes.statusCode != 200) return null;

    return (name, Uint8List.fromList(dlRes.bodyBytes));
  }

  void _toast(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}
