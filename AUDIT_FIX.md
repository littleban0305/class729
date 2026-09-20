# 729 Build Fix

修正 Android / Windows 編譯錯誤：

- `device_gate.dart` 使用大屏頁面時需要引用 `main.dart` 中的 `ReminderPage`、`LotteryPage`、`SeatPage`、`DiaryPage`、`SchedulePage`。
- 補上 explicit named import，避免分析器把這些 Widget 當成未定義方法。
- 未修改教師端「只有後台」的導航設計。
- 未修改既有大屏功能與手機版 UI。
