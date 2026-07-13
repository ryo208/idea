# DOLUCK GCS — ドローン地上管制UI

ドローンを飛行させて、地上の追尾アンテナからのテレメトリ・コマンドをPCに表示する、
SpaceXのミッションコントロール風UI。

## 構成

```
[ドローン] --MAVLink/無線--> [追尾アンテナ + 受信機] --USB/UDP--> [PC]
                                                                  ├ bridge.py (MAVLink→WebSocket変換)
                                                                  └ index.html (ブラウザUI) ← ws://localhost:8765
```

- **index.html** — UI本体。1ファイル完結・依存なし。ブラウザで開くだけで動く
- **bridge.py** — 実機接続用。MAVLinkテレメトリをJSONに変換してWebSocketで配信し、UIからのコマンドをMAVLinkに変換する

## まず見る(デモモード)

`index.html` をブラウザで開くだけ。実機リンクがないときは内蔵フライトシミュレーションに
自動フォールバックし、カウントダウン(T−10s)→離陸→ウェイポイント巡回2周→RTL→着陸のデモ
ミッションが流れる。右上バッジが `SIM` 表示になる。

コマンドボタン(HOLD / RESUME / RTL / LAND、着陸後は ARM / LAUNCH)はシミュレーションにも効く。

## 実機接続(LIVEモード)

```bash
pip install pymavlink websockets

# テレメトリ無線(SiK 915/433MHz等)がUSBシリアルの場合
python bridge.py --mav /dev/ttyUSB0 --baud 57600

# SITLやWiFiテレメトリ(UDP)の場合
python bridge.py --mav udp:0.0.0.0:14550
```

ブリッジ起動後に `index.html` を開くと自動で `ws://127.0.0.1:8765` に接続し、
バッジが `LIVE` (緑)になる。追尾アンテナのAZ/ELはブリッジ側でホーム位置からの
方位角・仰角として計算している(実アンテナのローテーター制御に流用可)。

## UIの見どころ

| パネル | 内容 |
|---|---|
| ヘッダー | ミッションフェーズ(PAD→ASCENT→CRUISE→RTL→LANDING)、T+クロック、リンク状態 |
| FLIGHT DATA | 高度・対地速度・昇降率・方位・地上局からの距離 |
| GROUND TRACK | 地上局中心の航跡マップ。レンジリング100m、アンテナビーム、ウェイポイント |
| チャート | 高度・対地速度の直近120秒ストリップチャート(ホバーで値表示) |
| ゲージ | SpaceX中継風のアーク型速度・高度ゲージ |
| ATTITUDE | 姿勢儀(人工水平儀)+ロール/ピッチ/ヨー |
| TRACKING ANTENNA | 天球ポーラープロット(中心=天頂)、AZ/EL、RSSI、リンク品質 |
| COMMAND | ARM / LAUNCH / HOLD / RESUME / RTL / LAND(状態に応じて活性化) |
| EVENT LOG | T±タイムスタンプ付きイベント(LIFTOFF、WAYPOINT ACQUIRED、TOUCHDOWN…) |

## デザインメモ(v2: SpaceX中継スタイル)

- **フルスクリーン機上カメラ風ビュー**: 星空(高度で濃くなる)・地平線グロー・速度でスクロールするパースグリッド・雲・ドローン機体シルエット(航法灯: 左赤/右緑、白ストロボ点滅、プロペラ円盤)。ロール/ピッチで映像全体が傾く
- **D-DINフォント埋め込み**(SpaceXが使用する書体。OFL-1.1ライセンス、woff2をdata URIで内蔵)
- **下部バー**: SpaceX中継シグネチャの円形ゲージ(速度/高度)+ 大型T+クロック + ミッションタイムライン(LIFTOFF→CRUISE→LAP 1→LAP 2→RTL→TOUCHDOWN、進捗と連動)
- **演出**: 主要イベントで画面中央コールアウト(LIFTOFF等)、離陸時の画面シェイク(prefers-reduced-motion対応)、SOUNDトグルでカウントダウンビープ+離陸ノイズ(WebAudio生成、デフォルトOFF)
- 半透明ガラスパネル + ヘアライン境界のオーバーレイUI
- 系列色 シアン `#2F9EC2`・アンバー `#B08A3E` — ダーク面でCVD分離・コントラスト検証済み

## 今後の改良候補

- [ ] アンテナローテーター(az/elサーボ)への追尾指令出力
- [ ] 飛行ログの記録・リプレイ
- [ ] 動画ストリーム(FPV)パネルの追加
- [ ] 複数機の同時トラッキング
