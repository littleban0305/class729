# 729 LINE 關鍵字回覆（免費本地方案）

這份文件紀錄的是「免費可跑的 LINE 關鍵字回覆方案」，目前採用的是：

- LINE Messaging API：接收使用者訊息
- 本地 Node / Express：處理關鍵字邏輯
- ngrok：把本地伺服器暴露到外部，供 LINE Webhook 呼叫
- Firebase Firestore：從系統實際資料讀取課表、聯絡簿、分數、簽到等資料

> 這個方案是「不花錢」的實際做法；不依賴 Firebase Cloud Functions 上線，因為 Cloud Functions 需要 Blaze 方案才可部署。

## 方案概念

- LINE Official Account：負責接收訊息與回覆
- 本地伺服器：`functions/server.js`
- ngrok Tunnel：`https://xxx.ngrok-free.dev/webhook`
- Firestore：讀取 `classes/{classId}` 與 `classes/{classId}/private/state` 的資料
- Flutter App：把資料同步到 Firebase，讓 LINE 可以直接讀取

## 1. 先建立 LINE 官方帳號

1. 進入 LINE Developers Console
2. 建立 Provider
3. 建立 Messaging API Channel
4. 取得：
   - Channel Secret
   - Channel Access Token
5. 設定 Webhook URL 為 ngrok 的公開網址，例如：

```text
https://passivism-palm-undecided.ngrok-free.dev/webhook
```

## 2. 設定本地 Node 專案

先進入 `functions` 資料夾：

```bash
cd functions
npm install
```

建立環境變數：

```bash
$env:LINE_CHANNEL_ACCESS_TOKEN="..."
$env:LINE_CHANNEL_SECRET="..."
```

或在 `.env` 裡寫入（若你自行補上 dotenv 解析）。

## 3. 啟動本地 webhook

```bash
cd functions
npm start
```

啟動後，伺服器會在：

```text
http://localhost:3000
```

再把本地伺服器對外開通：

```bash
ngrok http http://localhost:3000 --host-header=rewrite
```

取得公開網址後，設定到 LINE Developers Console 的 Webhook URL。

## 4. 這個專案現在會讀取什麼資料

後端現在會把 LINE 關鍵字轉成真實資料查詢，讀取的是 Firebase Firestore 中的班級資料：

- `scheduleEntries`：課表
- `diaryEntries`：聯絡簿
- `attendanceRecords`：簽到紀錄
- `studentRecords`：被記紀錄
- `seats`：座位與分數
- `cleanlinessRecords`：整潔分數

例如：

- 查看課表 → 讀 `scheduleEntries`
- 查看聯絡簿 → 讀 `diaryEntries`
- 查看分數 → 讀 `seats` / `cleanlinessRecords`
- 查看今日簽到時間 → 讀 `attendanceRecords`
- 查看被記 → 讀 `studentRecords`
- 被記 30 吵鬧 → 寫入 `studentRecords`、扣除該生 1 分，並同步回軟體

## 5. 目前支援的關鍵字

- 指令清單
- 查看聯絡簿
- 查看課表
- 查看分數
- 查看今日簽到時間
- 查看被記
- 被記 + 座號 + 原因（例如：`被記 30 吵鬧`）
- 你好

## 6. 你現在最需要做的事

1. 在 LINE Developers Console 設定 Webhook URL
2. 啟動 `functions/server.js`
3. 啟用 ngrok
4. 讓 `729` 軟體把班級資料同步到 Firestore
5. 測試 LINE 傳訊息

## 7. 注意事項

- 本方案是免費做法，不需要花錢開 Blaze。
- JWT / LINE secret 不應直接寫死在 Flutter App，應放在後端。
- 若你想查不同班級資料，可用 `班級 729` 這種格式，或設定 `LINE_DEFAULT_CLASS_ID` 環境變數。

## 8. 目前實際檔案

- `functions/server.js`：正式的 LINE webhook 與資料查詢後端
- `functions/package.json`：Node 套件與啟動腳本
- `lib/services/cloud_sync_service.dart`：Flutter App 同步資料到 Firestore

如果你要下一步，我可以直接接著幫你做：

- 把 LINE 真的接到 ngrok 公開網址
- 補上 Firebase service account 連線方式
- 擴充更多關鍵字（作業、缺席、公告、座位）
- 把「今天天氣/考試/提醒」一起接進回覆邏輯
