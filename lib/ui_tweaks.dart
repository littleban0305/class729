// 手動微調專用檔案：頭像的大小與位置都在這裡改。
// 改完存檔後，請完整熱重啟 App，單純 hot reload 不會更新這些 const 設定。
// 新增圖片檔後需重新建置 App，Flutter 才會將新檔案打包進 assets。

/// 頭像的位置與大小（以詳細資料卡片的左上角為原點）
/// left：負越多越往左；top：負越多越往上；width/height：頭像寬高
class AvatarTweak {
  final double left;
  final double top;
  final double width;
  final double height;

  const AvatarTweak({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });
}

/// 所有同學共用的預設位置
const AvatarTweak defaultAvatarTweak = AvatarTweak(
  left: -5,
  top: -90,
  width: 110,
  height: 110,
);

/// 個別同學想另外調整時寫在這裡（沒寫的就用上面的預設）
/// left/top 控制位置，width/height 可分別調整圖片寬度和高度。
const Map<String, AvatarTweak> avatarTweaks = {
  // '2': AvatarTweak(left: -20, top: -100, width: 130, height: 150),
  // '5': AvatarTweak(left: -20, top: -100, width: 130, height: 130),
  '2': AvatarTweak(left: -5, top: -90, width: 110, height: 110),
  '5': AvatarTweak(left: -20, top: -157, width: 200, height: 200),
  '4': AvatarTweak(left: -5, top: -123, width: 170, height: 170),
  '1': AvatarTweak(left: -5, top: -140, width: 170, height: 170),
  '6': AvatarTweak(left: -0, top: -120, width: 170, height: 170),
};
