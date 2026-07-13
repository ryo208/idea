# ColorLens セットアップ手順

iPhoneカメラで中央の色を判別して、色名・カラーコードを表示&読み上げるアプリ。

## 必要なもの

- Mac + Xcode(15以降推奨)
- iPhone実機(カメラを使うためシミュレーターでは動作確認できない)

## 手順

1. Xcodeで **File → New → Project → iOS → App** を選択
   - Product Name: `ColorLens`
   - Interface: SwiftUI / Language: Swift
2. プロジェクトに自動生成された `ColorLensApp.swift` と `ContentView.swift` を、このフォルダのファイルで置き換える
3. `CameraManager.swift` と `ColorClassifier.swift` をプロジェクトに追加する
4. ターゲット設定の **Info** タブでカメラ利用の許可文言を追加する
   - Key: `Privacy - Camera Usage Description`(`NSCameraUsageDescription`)
   - Value: `色を判別するためにカメラを使用します`
5. iPhoneを接続して実機で実行する

## 使い方

- 調べたい物に照準(中央の円)を向けると、下のパネルに色名とカラーコードが出る
- 🔊 ボタンで色名を読み上げ
- 🔦 ボタンでライト点灯(至近距離で測ると環境光の影響が減って精度が上がる)

## 今後の改良候補

- 判別した色の履歴保存
- 色名の語彙を増やす(JIS慣用色名269色との最近傍マッチング)
- 白い紙を使ったホワイトバランス補正(キャリブレーション)
- Phase 2: TCS34725センサーデバイスからのBLE受信
