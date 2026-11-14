# 729 班級軟體：給 Copilot 的專案說明

## 專案概要
- Flutter App（Windows 桌面為主，也支援 Android／Web），給 729 班使用。
- 兩種模式：**大屏模式**（掛在教室給全班看、觸控操作）與**教師後台**（老師在電腦前管理）。
- 資料：`AppState`（ChangeNotifier）存在 SharedPreferences，並透過 Firebase Firestore 同步（公開資料給大屏、私密資料給老師）。
- LINE 官方帳號後端在 `functions/server.js`（Express + webhook）。
- 介面文字一律用**繁體中文、臺灣用語**；程式註解也用繁體中文。

## 檔案地圖
| 檔案 | 內容 |
| --- | --- |
| `lib/main.dart` | 主題 `AppTokens`／`_buildAppTheme`、教師後台外框、大屏首頁 `BigScreenHomePage`、座位格 `BigScreenSeatGrid`、同學卡片 `_StudentCard`、蓋章頁 `StampPage`、選號 `LotteryPage`＋`PickMode`、聯絡簿書本 `showDiaryBook`、時間管理 `TimeManagementPage`、頂端列 `BigScreenTopBar`／`AutoHideBar` 等（檔案很大，之後要拆） |
| `lib/device_gate.dart` | 裝置角色選擇、大屏外殼 `BigScreenDeviceShell`（用 `import 'main.dart' show ...`，新增共用元件要記得加進 show 清單） |
| `lib/teacher_pages.dart` | 總覽 `OverviewPage`、簽到 `AttendancePage`、蓋章紀錄 `RegistrationRecordsPage`、班級照片等 |
| `lib/app_state.dart` | 所有資料與存檔、雲端同步、匯入匯出 |
| `lib/models.dart` | `SeatData`、`ScheduleEntry`、`DiaryEntry`、`TimePeriod` 等 |
| `lib/records_models.dart` | `StudentRecord`、`AttendanceRecord` 等紀錄 |
| `lib/services/cloud_sync_service.dart` | Firestore 讀寫；新增要給大屏看的欄位時，記得加進 `_publicData` |
| `lib/app_window_controls.dart` | 右上角最小化／最大化／關閉 |
| `assets/icon/*.png` | Lucide 風格圖示（黑線透明底），用 `AppIcon(AppIcons.xxx)` 顯示並自動上色 |

### 資料注意事項
- `ScheduleEntry.weekday`、`ScheduleEntry.lesson` 都是**從 0 開始**，顯示「第幾節」時要 +1。
- `SeatData.row` 是第幾個直排（左→右），`slot` 是那排的第幾個（前→後）；講台在上方。
- 新增要存檔的資料時，要同時處理：載入、`_save`、`exportData`、`_applyImportedData`、`_applyPublicData`／`applyPublicCloudData`、雲端 `_publicData`（參考 `timePeriods` 的寫法）。

## 視覺風格（一定要遵守）
- 配色（Happy Hues）：背景 `#fffffe`、主要文字／框線 `#272343`（`AppTokens.ink`）、次要文字 `#5A5F75`、主按鈕黃 `#ffd803`（上面用深藍字，不用白字）、大屏背景淺青 `#e3f6f5`、面板青 `#bae8e8`。
- 男生座位淺藍 `#DCEBFF`、女生淺粉 `#FFE1EC`（`AppTokens.seatBoy/seatGirl`），不要改。
- **超細框線 1px**：可以點的東西用黑色（`scheme.outline`），容器用灰色（`scheme.outlineVariant`）。
- 圓角：大面板 36、卡片 24、控制項 10；座位格是格子大小 × 0.32。
- **禁止**：漸層、陰影、毛玻璃（BackdropFilter）。全部是平面單色。
- 字級只用：56（時鐘）／32（大數字）／20（標題）／15（內文）／13（說明）；字體 `Class729Rounded`。
- 一個畫面只有一個黃色主按鈕，其他用外框按鈕。
- 圖示一律用 `AppIcon(AppIcons.xxx, size: AppIcons.topBarSize)`。
- 大屏頁面要包在 `BigScreenPageFrame`（淺青背景＋白色大圓角面板，文字放大 1.15 倍）裡；彈出視窗用 `showBottomCard`（下方圓角小卡、點外面關閉）或 `showPageDialog`。
- 教師後台跟大屏首頁同一套外觀：頂端白色圓角長條（`BigScreenTopBar`，有文字標籤、不自動收合）＋淺青背景＋白色圓角面板。
- 動畫要有手感但短（約 0.2～0.9 秒），彈跳曲線不要套在透明度上（會超過 1 報錯）。

## 目前功能狀態
- **大屏首頁**：左邊座位表（講台、男藍女粉、點了看同學卡片）；右邊時鐘、現在的課或特殊顯示、「開始上課」（會最小化視窗）、四顆圓形按鈕：選號機、課表、聯絡簿、蓋章。頂端列 1 秒沒碰就收起，只露一條。
- **選號機**：可選人數；特殊抽法 `PickMode`：大十字 9 人、九宮格 8 人、大峽谷 10 人（中心點本人不算，超出邊界繞到對面）。首頁版本在座位表上跳動畫，抽完保持選取，有「取消選取」按鈕。
- **蓋章系統（beta）**：`seat.score` 目前同時代表結算章和兌換章（兌換功能還沒做）。蓋章紀錄存成 `StudentRecord`，type 為 `蓋章`／`扣章`、note 是理由。`StampPage` 可以多選同學一起蓋，一個理由一章；本週扣滿 5 章會顯示「反省單」標籤。老師在後台刪除紀錄時章數會自動退回。完整規則在專案文件「729 蓋章政策」。
- **時間管理**：上課時段直接讀課表；`TimePeriod` 只放非上課的特殊顯示，可勾「蓋過上課」；課與課之間自動顯示「下課」。
- **聯絡簿**：書本造型，封面翻開動畫，左右箭頭翻頁換日期，右頁最後一行直接輸入新增。

## 待辦與已知問題
1. 安全性：LINE webhook 沒驗證簽章、任何人都能透過 LINE 記人；Firestore 規則等於全開；`auth_service.dart` 裡有寫死的教師密碼（要改成 Firebase Email 登入）；`server.js` 應改用 Reply API 以免吃免費額度。
2. 清理：`ReminderPage` 簡報編輯器、`_ReminderTestPage`、`BigScreenRegistrationPage`、`SideBar`、`DesktopFrame` 已不再使用，可以刪除；`main.dart` 要依頁面拆檔。
3. 蓋章系統下一步：幹部 PIN 碼與每週上限、排行榜、奉獻進度條（建議放在大屏頂端列中間）、兌換功能、申訴便條紙。
4. Windows 上的 `accessibility_bridge ... AXTree` 錯誤訊息是 Flutter 已知問題，不影響功能。

## 工作方式
- 每次修改後請執行 `flutter analyze`，有錯誤先修好再交付。
- 改動盡量小而集中，不要順手重寫無關的部分；沿用現有元件與 `AppTokens`。
- 回答與說明用繁體中文，給初學者也看得懂的步驟。
