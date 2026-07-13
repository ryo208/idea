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

## デザインメモ

- ダーク単一テーマ(ミッションコントロールの世界観に意図的にコミット)
- 面 `#0B0F14` / 系列色 シアン `#2F9EC2`・アンバー `#B08A3E` — CVD分離・コントラスト検証済み
- 数値はすべて等幅フォント + tabular-nums

## 今後の改良候補

- [ ] アンテナローテーター(az/elサーボ)への追尾指令出力
- [ ] 飛行ログの記録・リプレイ
- [ ] 動画ストリーム(FPV)パネルの追加
- [ ] 複数機の同時トラッキング
