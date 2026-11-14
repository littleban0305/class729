// Windows 自動更新：從 GitHub Releases（littleban0305/class729-updater）抓最新版 729.zip，
// 下載後交給一個小 bat 等 app 關掉、解壓蓋過舊檔、再重新打開。
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

/// 放更新檔的公開 repo（Releases 裡要有 729.zip）
const kUpdateRepo = 'littleban0305/class729-updater';

/// 畫面上方顯示的更新狀態（null = 不顯示）
final windowsUpdateStatus = ValueNotifier<String?>(null);

bool _running = false;

/// 版本比較：1.0.1+3 → [1, 0, 1, 3]
List<int> _parse(String v) {
  final clean = v.trim().replaceFirst(RegExp(r'^[vV]'), '');
  final main = clean.split('+');
  final nums = main.first.split('.').map((e) => int.tryParse(e) ?? 0).toList();
  while (nums.length < 3) {
    nums.add(0);
  }
  nums.add(main.length > 1 ? int.tryParse(main[1]) ?? 0 : 0);
  return nums;
}

bool isNewer(String latest, String current) {
  final a = _parse(latest), b = _parse(current);
  for (var i = 0; i < a.length && i < b.length; i++) {
    if (a[i] != b[i]) return a[i] > b[i];
  }
  return false;
}

/// 檢查並自動更新。回傳給「檢查更新」按鈕顯示的訊息。
Future<String> checkWindowsUpdate({bool manual = false}) async {
  if (kIsWeb || !Platform.isWindows) return '只有 Windows 版支援自動更新';
  if (kDebugMode && !manual) return '除錯模式不自動更新';
  if (_running) return '正在更新中';
  _running = true;
  try {
    final info = await PackageInfo.fromPlatform();
    final current = '${info.version}+${info.buildNumber}';
    final res = await http
        .get(Uri.parse('https://api.github.com/repos/$kUpdateRepo/releases/latest'),
            headers: {'Accept': 'application/vnd.github+json'})
        .timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) return '檢查更新失敗（HTTP ${res.statusCode}）';
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    final tag = (json['tag_name'] ?? '').toString();
    if (!isNewer(tag, current)) return '已經是最新版（$current）';
    final assets = (json['assets'] as List? ?? []).whereType<Map>();
    final asset = assets.firstWhere(
      (a) => (a['name'] ?? '').toString().toLowerCase().endsWith('.zip'),
      orElse: () => const {},
    );
    final url = (asset['browser_download_url'] ?? '').toString();
    if (url.isEmpty) return '最新版 $tag 沒有附上 zip 檔';

    windowsUpdateStatus.value = '發現新版本 $tag，正在下載…';
    final tmp = await Directory.systemTemp.createTemp('729_update_');
    final zip = File('${tmp.path}\\729.zip');
    final dl = await http.Client().send(http.Request('GET', Uri.parse(url)));
    if (dl.statusCode != 200) {
      windowsUpdateStatus.value = null;
      return '下載失敗（HTTP ${dl.statusCode}）';
    }
    final total = dl.contentLength ?? 0;
    var got = 0;
    final sink = zip.openWrite();
    await for (final chunk in dl.stream) {
      sink.add(chunk);
      got += chunk.length;
      if (total > 0) {
        windowsUpdateStatus.value = '正在下載新版本 $tag…${(got * 100 / total).floor()}%';
      }
    }
    await sink.close();

    windowsUpdateStatus.value = '下載完成，即將重新啟動並更新…';
    await Future<void>.delayed(const Duration(seconds: 2));
    final exe = Platform.resolvedExecutable;
    final appDir = File(exe).parent.path;
    final bat = File('${tmp.path}\\update.bat');
    await bat.writeAsString([
      '@echo off',
      'chcp 65001 >nul',
      ':wait',
      'tasklist /FI "PID eq $pid" 2>nul | find "$pid" >nul',
      'if not errorlevel 1 (',
      '  timeout /t 1 /nobreak >nul',
      '  goto wait',
      ')',
      'powershell -NoProfile -ExecutionPolicy Bypass -Command "Expand-Archive -LiteralPath \'${zip.path}\' -DestinationPath \'$appDir\' -Force"',
      'start "" "$exe"',
      '',
    ].join('\r\n'));
    await Process.start('cmd', ['/c', bat.path], mode: ProcessStartMode.detached, runInShell: false);
    exit(0);
  } catch (e) {
    windowsUpdateStatus.value = null;
    return '檢查更新失敗：$e';
  } finally {
    _running = false;
  }
}
