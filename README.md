# 729 班級軟體 V1

Flutter + Dart 桌面 App，設計給 VS Code 開發與 GitHub 管理。

## 目前功能

### 原有功能（保留）
- 首頁就是「提醒」
- 提醒可新增、編輯、刪除
- 提醒支援日期、開始時間、結束時間
- 提醒可以新增多個連結按鈕
- 每個按鈕可自訂「顯示文字」與 URL
- 左側 Navbar 可縮小，只顯示圖示
- Navbar 品牌只顯示 729
- 座位表
- 聯絡簿
- 課表
- 選號
- 桌面視窗最小化／最大化／關閉
- SharedPreferences 本機儲存
- JSON 匯出／匯入
- 沒有登入系統

### 老師需求新增
- 簽到：學生可在大屏點擊簽到，保存實際到校時間
- 遲到：可設定遲到門檻，簽到後自動標記是否遲到
- 老師紀錄：秩序不佳、晚進教室、缺交作業，可加備註
- 整潔：班長／外掃管理可選學生、區域、優秀／一般／待改進、評分與備註
- 每週整潔統計：自動整理目前週期的優秀與待改進前 3 名
- 班級照片：教師端可加入照片與活動名稱，依日期保存；大屏不公開照片
- 大屏模式：只提供提醒與簽到，不提供後台管理介面

> 目前資料仍採「本機離線優先」。手機與電腦的雲端即時同步、LINE 官方帳號、畢業影片自動生成先不塞進 V1，等核心功能穩定後再做。

## 在 VS Code 開發

1. 安裝 Flutter SDK 與 Dart/Flutter VS Code 擴充套件。
2. 用 VS Code 開啟整個資料夾。
3. 在終端機執行：

```powershell
flutter pub get
flutter analyze
flutter run -d windows
```

第一次如果缺少 Windows 平台檔案，可執行：

```powershell
flutter create --platforms=windows .
```

## GitHub

```powershell
git init
git add .
git commit -m "Update 729 class app"
git branch -M main
git remote add origin <你的 GitHub repository URL>
git push -u origin main
```

`.gitignore` 已排除 Flutter 建置產物與 IDE 暫存檔。
