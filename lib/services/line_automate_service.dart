import 'dart:async';
import 'dart:developer' as developer;

import 'package:puppeteer/puppeteer.dart';

/// LINE 官方帳號後台的瀏覽器自動化服務。
///
/// 使用前請在 pubspec.yaml 的 dependencies 加入：
///
///   puppeteer: ^3.26.0
///
/// 這個服務不依賴專案內其他 model、state 或頁面，因此可以單獨呼叫。
class LineAutomateService {
  LineAutomateService._();

  /// 全域唯一的服務實例。
  static final LineAutomateService instance = LineAutomateService._();

  /// 對外提供方便的 Singleton 取得方式。
  factory LineAutomateService() => instance;

  static const Duration _browserLaunchTimeout = Duration(seconds: 45);
  static const Duration _navigationTimeout = Duration(seconds: 60);
  static const Duration _loginTimeout = Duration(minutes: 5);
  static const Duration _pollInterval = Duration(milliseconds: 500);
  static const Duration _inputTimeout = Duration(seconds: 30);

  /// 開啟可見瀏覽器，等待人工完成 LINE 登入與 2FA，並發送私訊。
  ///
  /// 首次使用時會開啟可見的 Chromium 視窗，讓使用者可以手動完成
  /// LINE 後台登入、QR Code 或 2FA。偵測到頁面離開登入頁後，才會
  /// 繼續尋找聊天室輸入框並送出訊息。
  ///
  /// 任何瀏覽器、網路、登入、定位或發送錯誤都會被攔截，並回傳 false。
  Future<bool> sendPrivateMessage({
    required String parentChatUrl,
    required String message,
  }) async {
    Browser? browser;

    if (!_isValidHttpUrl(parentChatUrl)) {
      _log('無效的聊天室網址：$parentChatUrl');
      return false;
    }
    if (message.trim().isEmpty) {
      _log('訊息不可為空白。');
      return false;
    }

    try {
      _log('正在啟動可見 Chromium，請手動完成 LINE 登入與 2FA。');
      browser = await puppeteer.launch(
        headless: false,
        timeout: _browserLaunchTimeout,
      );

      final page = await browser.newPage();
      page.defaultNavigationTimeout = _navigationTimeout;
      page.defaultTimeout = _inputTimeout;

      _log('正在前往家長聊天室網址。');
      await page.goto(parentChatUrl, wait: Until.networkIdle);

      await _waitForLoginToComplete(page);

      _log('登入狀態已確認，正在尋找聊天室輸入框。');
      final messageBox = Locator.race([
        page.locator('[contenteditable="true"]'),
        page.locator('textarea'),
        page.locator('[role="textbox"]'),
        page.locator('input[placeholder*="訊息"]'),
        page.locator('input[placeholder*="メッセージ"]'),
      ]).setTimeout(_inputTimeout);

      await messageBox.fill(message);
      _log('訊息已填入，正在按下 Enter 送出。');
      await page.keyboard.press(Key.enter);

      _log('LINE 私訊已送出。');
      return true;
    } on TimeoutException catch (error, stackTrace) {
      _log('操作逾時，未能完成 LINE 私訊：$error', stackTrace);
      return false;
    } catch (error, stackTrace) {
      _log('LINE 私訊操作失敗：$error', stackTrace);
      return false;
    } finally {
      if (browser != null) {
        try {
          await browser.close();
          _log('瀏覽器已關閉。');
        } catch (error, stackTrace) {
          _log('關閉瀏覽器時發生錯誤：$error', stackTrace);
        }
      }
    }
  }

  /// 等待手動登入成功。
  ///
  /// 判斷條件是目前網址不再包含常見的登入路徑。LINE 後台可能使用
  /// 不同網域或登入路徑，因此這裡不綁定單一固定網址。
  Future<void> _waitForLoginToComplete(Page page) async {
    final deadline = DateTime.now().add(_loginTimeout);
    var lastUrl = page.url ?? '';

    if (!_looksLikeLoginUrl(lastUrl)) {
      _log('目前頁面看起來已經登入，繼續執行。');
      return;
    }

    _log('請在開啟的瀏覽器中完成 LINE 登入與 2FA，等待時間上限為 5 分鐘。');
    while (DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(_pollInterval);
      final currentUrl = page.url ?? '';

      if (currentUrl != lastUrl) {
        lastUrl = currentUrl;
        _log('偵測到頁面跳轉：$currentUrl');
      }
      if (!_looksLikeLoginUrl(currentUrl)) {
        _log('已偵測到登入頁跳轉完成。');
        return;
      }
    }

    throw TimeoutException('等待 LINE 登入與 2FA 超過 5 分鐘。');
  }

  bool _isValidHttpUrl(String value) {
    final uri = Uri.tryParse(value);
    return uri != null && (uri.scheme == 'http' || uri.scheme == 'https');
  }

  bool _looksLikeLoginUrl(String url) {
    final lowerUrl = url.toLowerCase();
    return lowerUrl.contains('/login') ||
        lowerUrl.contains('/signin') ||
        lowerUrl.contains('login') ||
        lowerUrl.contains('signin') ||
        lowerUrl.contains('auth');
  }

  void _log(String message, [StackTrace? stackTrace]) {
    developer.log(
      message,
      name: 'LineAutomateService',
      stackTrace: stackTrace,
    );
  }
}
