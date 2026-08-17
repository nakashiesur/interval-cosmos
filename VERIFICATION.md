# ver.2.0.3 検証結果

以下の構文検査・回帰テスト・Playback専用テストを実行しています。

```bash
node --check app.js
node --check cloud.js
node --check sw.js
node tests/smoke-test.js
node tests/playback-test.js
```

## v2.0.3追加項目

- SETTINGSに `MELODIC / HARMONIC / BOTH` が存在する
- 各Playback方式の日本語説明が表示される
- BOTH時のみ再生順セレクターが表示される
- BOTHの初期順序が `HARMONIC → MELODIC`
- `MELODIC → HARMONIC` へ変更可能
- 再生順設定が実際のAudioEngineの呼び出し順へ反映される
- MELODIC単独再生の挙動は維持
- HARMONIC単独再生の挙動は維持
- SETTING歯車アイコンに通常サイズ用クラスを適用
- 起動画面・SETTINGSのバージョンが `ver.2.0.3`
- Service Workerキャッシュ名が `interval-cosmos-v2-0-3`

## 既存機能の回帰確認

- 中島ゼミロゴ
- Final Edition表記なし
- PRACTICE MODE最上段・初心者マーク
- STANDARD / HYPER DRIVE / EAR LINK
- 7段13個の回答ボタン
- 回答ラベルの問題ごとの日本語／記号ランダム切替
- 全問上行形
- 長押し終了
- CORE 7
- 初心者向け音程ガイド
- RESULTのローカル得点表示
- MISSED INTERVALS分析
- オンラインランキングUI
- 旧 `Answer labels / Reduced motion / Direction` 設定が本体stateへ復活していない

結果：全自動テスト PASS
