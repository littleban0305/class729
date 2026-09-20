# 729 雲端同步設定

## 1. 安裝 / 登入 Firebase CLI

在專案根目錄執行：

```powershell
firebase login
```

本專案已附 `.firebaserc`，預設專案為 `class-729-app`。

## 2. 部署 Firestore Security Rules

```powershell
firebase deploy --only firestore:rules
```

目前規則的設計：

- `classes/{classId}`：大屏可讀。
- 教師登入後可以建立／更新公開班級資料。
- 未登入的大屏只能更新 `attendanceToday` 與 `updatedAt`，不能改提醒、座位、課表等其他資料。
- `classes/{classId}/private/state`：完整教師資料，只允許 Firebase Authentication 登入者讀寫。
- 禁止刪除整個班級公開文件。

## 3. Firebase Authentication

Firebase Console 需要確認 Authentication 已啟用 Email/Password provider，因為教師端目前使用 Email + 密碼登入。

## 4. Firestore

Firestore 需要已建立 Default database。若原本是 production mode 也沒有問題，部署本專案的 `firestore.rules` 後即可套用新的權限。

## 5. 測試順序

### 教師端

1. 登入教師帳號。
2. 在「雲端與裝置」輸入班級代碼，例如 `729`。
3. 按「儲存代碼」。
4. 先按「立即上傳到雲端」。
5. 確認 Firestore 出現：
   - `classes/729`
   - `classes/729/private/state`

### 大屏端

1. 啟動另一台裝置／另一份 App。
2. 選擇「大屏 / 簽到裝置」。
3. 輸入同一個班級代碼。
4. 等待大屏載入教師端的提醒、座位、聯絡簿、課表。
5. 學生按自己的名字簽到。
6. 教師端變更提醒或公開資料時，大屏應透過 Firestore listener 自動更新。

### 注意

班級代碼不是安全驗證碼。知道班級代碼的人可以讀取公開班級資料；因此不要把秩序、缺交作業、整潔評分、照片或完整簽到時間放進公開文件。這些資料目前放在 `private/state`。

## 6. 本機分析

```powershell
flutter pub get
flutter analyze
```

如果要做真正的 Firestore rules 測試，可以另外使用 Firebase Local Emulator Suite；正式部署前建議先在 emulator 驗證讀寫權限。
