// ignore_for_file: use_build_context_synchronously

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:ota_update/ota_update.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// 版本資訊模型
class AppVersionInfo {
  const AppVersionInfo({
    required this.latestVersion,
    required this.downloadUrl,
  });

  final String latestVersion;
  final String downloadUrl;

  factory AppVersionInfo.fromJson(Map<String, dynamic> json) {
    final latestVersion = (json['latest_version'] ?? json['version'] ?? '').toString().trim();
    final downloadUrl = (json['download_url'] ?? json['apk_url'] ?? '').toString().trim();

    if (latestVersion.isEmpty) {
      throw const FormatException('version.json 缺少 latest_version 欄位');
    }
    if (downloadUrl.isEmpty) {
      throw const FormatException('version.json 缺少 download_url 欄位');
    }

    return AppVersionInfo(
      latestVersion: latestVersion,
      downloadUrl: downloadUrl,
    );
  }

  static AppVersionInfo fromPlatformJson(Map<String, dynamic> json) {
    final latestVersion = (json['latest_version'] ?? '').toString().trim();
    final downloadUrl = (json['download_url'] ?? '').toString().trim();

    if (latestVersion.isEmpty) {
      throw const FormatException('version.json 缺少 latest_version 欄位');
    }
    if (downloadUrl.isEmpty) {
      throw const FormatException('version.json 缺少 download_url 欄位');
    }

    return AppVersionInfo(
      latestVersion: latestVersion,
      downloadUrl: downloadUrl,
    );
  }
}

/// 獨立更新服務：不依賴你原本業務程式碼
class AppUpdateService {
  const AppUpdateService();

  /// 讀取網路版 version.json
  ///
  /// 範例格式：
  /// {
  ///   "latest_version": "1.2.3",
  ///   "download_url": "https://example.com/app-release.apk"
  /// }
  Future<AppVersionInfo> fetchLatestVersion(String versionUrl) async {
    if (!Platform.isAndroid && !Platform.isWindows) {
      throw UnsupportedError('目前版本更新檢查僅支援 Android 與 Windows 平台。');
    }

    final response = await http.get(Uri.parse(versionUrl));

    if (response.statusCode != 200) {
      throw HttpException(
        '抓取版本資訊失敗，HTTP 狀態碼：${response.statusCode}',
        500,
      );
    }

    final body = response.body;
    if (body.trim().isEmpty) {
      throw const FormatException('version.json 內容為空');
    }

    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('version.json 格式錯誤，頂層必須是 JSON object');
    }

    final platformKey = _currentPlatformKey();
    final platformJson =
        decoded[platformKey] is Map<String, dynamic> ? decoded[platformKey] as Map<String, dynamic> : decoded;

    return AppVersionInfo.fromPlatformJson(platformJson);
  }

  String _currentPlatformKey() {
    if (Platform.isAndroid) return 'android';
    if (Platform.isWindows) return 'windows';
    return 'android';
  }

  /// 判斷是否有新版
  bool isNewVersionAvailable(String currentVersion, String latestVersion) {
    return _compareVersion(currentVersion, latestVersion) < 0;
  }

  /// 直接檢查更新
  ///
  /// 你可以在 app 啟動時（例如 splash / home 的 initState）呼叫：
  /// AppUpdateService().checkForUpdate(
  ///   context,
  ///   versionUrl: 'https://your-domain.com/version.json',
  /// );
  Future<void> checkForUpdate(
    BuildContext context, {
    required String versionUrl,
  }) async {
    if (!Platform.isAndroid && !Platform.isWindows) {
      return;
    }

    final uiContext = context;

    try {
      final info = await fetchLatestVersion(versionUrl);
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version.trim();

      if (!uiContext.mounted) return;

      if (!isNewVersionAvailable(currentVersion, info.latestVersion)) {
        return;
      }

      final shouldUpdate = await showDialog<bool>(
        context: uiContext,
        barrierDismissible: false,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('發現新版本'),
            content: Text(
              '目前版本：$currentVersion\n'
              '最新版本：${info.latestVersion}\n\n'
              '是否立即更新？',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('稍後'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('立即更新'),
              ),
            ],
          );
        },
      );

      if (shouldUpdate != true) {
        return;
      }

      await _downloadAndInstallApk(uiContext, info.downloadUrl);
    } catch (e) {
      debugPrint('AppUpdateService.checkForUpdate error: $e');
      if (uiContext.mounted) {
        ScaffoldMessenger.of(uiContext).showSnackBar(
          SnackBar(
            content: Text('檢查更新失敗：$e'),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  /// 下載 APK 並觸發 Android 安裝
  Future<void> _downloadAndInstallApk(BuildContext context, String apkUrl) async {
    if (!Platform.isAndroid) {
      debugPrint('Android OTA 更新僅在 Android 平台啟用，當前平台：${Platform.operatingSystem}');
      return;
    }

    final uiContext = context;

    try {
      if (!uiContext.mounted) return;

      ScaffoldMessenger.of(uiContext).showSnackBar(
        const SnackBar(
          content: Text('開始下載更新，安裝前請確認允許安裝未知來源 APK。'),
        ),
      );

      final stream = OtaUpdate().execute(
        apkUrl,
        destinationFilename: 'app_update.apk',
      );

      await for (final event in stream) {
        switch (event.status) {
          case OtaStatus.DOWNLOADING:
            debugPrint('下載中：${event.value ?? 0}%');
            break;
          case OtaStatus.INSTALLING:
            debugPrint('開始安裝');
            if (uiContext.mounted) {
              ScaffoldMessenger.of(uiContext).showSnackBar(
                const SnackBar(content: Text('正在安裝更新，請稍候...')),
              );
            }
            break;
          case OtaStatus.INSTALLATION_DONE:
            debugPrint('安裝完成');
            if (uiContext.mounted) {
              ScaffoldMessenger.of(uiContext).showSnackBar(
                const SnackBar(content: Text('更新已安裝完成。')),
              );
            }
            break;
          case OtaStatus.DOWNLOAD_ERROR:
          case OtaStatus.INTERNAL_ERROR:
          case OtaStatus.PERMISSION_NOT_GRANTED_ERROR:
          case OtaStatus.CHECKSUM_ERROR:
            debugPrint('更新下載/安裝失敗：${event.value ?? 'unknown error'}');
            if (uiContext.mounted) {
              ScaffoldMessenger.of(uiContext).showSnackBar(
                const SnackBar(content: Text('更新失敗，請稍後再試。')),
              );
            }
            break;
          case OtaStatus.ALREADY_RUNNING_ERROR:
          case OtaStatus.CANCELED:
          case OtaStatus.INSTALLATION_ERROR:
            debugPrint('更新流程中斷：${event.status}');
            if (uiContext.mounted) {
              ScaffoldMessenger.of(uiContext).showSnackBar(
                const SnackBar(content: Text('更新流程已中斷。')),
              );
            }
            break;
        }
      }
    } catch (e) {
      debugPrint('downloadAndInstall error: $e');
      if (uiContext.mounted) {
        ScaffoldMessenger.of(uiContext).showSnackBar(
          SnackBar(content: Text('下載更新失敗：$e')),
        );
      }
    }
  }

  /// 比較版本號：1.0.0 < 1.0.1 < 1.2.0 < 2.0.0
  int _compareVersion(String currentVersion, String latestVersion) {
    final current = _normalizeVersion(currentVersion);
    final latest = _normalizeVersion(latestVersion);

    final maxLength = current.length > latest.length ? current.length : latest.length;

    for (int i = 0; i < maxLength; i++) {
      final currentValue = i < current.length ? current[i] : 0;
      final latestValue = i < latest.length ? latest[i] : 0;

      if (currentValue < latestValue) {
        return -1;
      }
      if (currentValue > latestValue) {
        return 1;
      }
    }

    return 0;
  }

  List<int> _normalizeVersion(String version) {
    final cleaned = version.replaceAll(RegExp(r'[^0-9.]'), '').trim();

    if (cleaned.isEmpty) {
      return const [0];
    }

    final parts = cleaned.split('.');
    final normalized = <int>[];

    for (final part in parts) {
      if (part.isEmpty) {
        continue;
      }
      normalized.add(int.tryParse(part) ?? 0);
    }

    return normalized.isEmpty ? const [0] : normalized;
  }
}

class HttpException implements Exception {
  const HttpException(this.message, this.statusCode);

  final String message;
  final int statusCode;

  @override
  String toString() => 'HttpException: $message (status: $statusCode)';
}
