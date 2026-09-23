import 'dart:convert';

import 'package:http/http.dart' as http;

class LineKeywordService {
  LineKeywordService({
    required this.backendUrl,
    this.apiKey,
  });

  final String backendUrl;
  final String? apiKey;

  /// 可直接從 Flutter 呼叫的簡單封裝。
  ///
  /// 後端端點預期是：POST /line/keyword
  /// Body 範例：
  /// {
  ///   "message": "課表",
  ///   "userId": "U1234567890"
  /// }
  Future<Map<String, dynamic>> sendKeywordReply({
    required String message,
    String? userId,
  }) async {
    final safeMessage = message.trim();
    if (safeMessage.isEmpty) {
      return {
        'ok': false,
        'reply': '請輸入關鍵字，例如：課表、報名、價格、聯絡我們',
      };
    }

    final uri = Uri.parse(backendUrl.trim());
    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json; charset=utf-8',
        if (apiKey != null && apiKey!.trim().isNotEmpty) 'x-api-key': apiKey!.trim(),
      },
      body: jsonEncode({
        'message': safeMessage,
        'userId': userId ?? 'flutter-app',
      }),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          return decoded;
        }
        return {'ok': true, 'reply': response.body};
      } catch (_) {
        return {'ok': true, 'reply': response.body};
      }
    }

    return {
      'ok': false,
      'reply': '目前無法連線到關鍵字回覆服務，請稍後再試。',
      'statusCode': response.statusCode,
    };
  }

  /// 如果後端沒有設定時，App 也能本地預設顯示回應，避免整個功能直接失敗。
  String getLocalFallbackReply(String message) {
    final normalized = message.trim();
    if (normalized.isEmpty) {
      return '請輸入關鍵字，例如：課表、報名、價格、聯絡我們';
    }

    final lower = normalized.toLowerCase();
    if (lower.contains('課表') || lower.contains('schedule')) {
      return '課表資訊請在教學平台查看，或聯絡教師取得最新版本。';
    }
    if (lower.contains('報名') || lower.contains('signup') || lower.contains('register')) {
      return '報名請至班級公告欄，或點選「報名連結」進行登記。';
    }
    if (lower.contains('價格') || lower.contains('price') || lower.contains('費用')) {
      return '費用請由教室或家長群公告，若需要詳細資訊請聯絡老師。';
    }
    if (lower.contains('客服') || lower.contains('help') || lower.contains('聯絡')) {
      return '請聯絡班級老師，或使用聯絡簿功能。';
    }
    return '您好，請輸入：課表、報名、價格、聯絡我們，系統將提供對應資訊。';
  }
}
