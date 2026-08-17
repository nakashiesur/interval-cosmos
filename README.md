# INTERVAL COSMOS ver.2.0.3

大学生向けのインターバル認識・反射トレーニングWebアプリです。スマートフォンを第一優先に設計し、PCでも利用できます。

## ver.2.0.3 の変更点

### Playback
- `MELODIC / HARMONIC / BOTH` の3種類は維持
- `BOTH` 選択時に再生順を選べるようにしました
  - `HARMONIC → MELODIC`（初期値）
  - `MELODIC → HARMONIC`
- 再生順の設定は端末に保存され、実際の音声再生にも反映されます
- SETTINGS内に日本語の説明を追加
  - MELODIC：基準音 → 到達音の順に2音を続けて再生
  - HARMONIC：基準音と到達音の2音を同時に再生
  - BOTH：MELODICとHARMONICを続けて再生
- v2.0.2からアップデートした端末では、BOTHの順序は `HARMONIC → MELODIC` を初期値として補完します

### SETTINGS UI
- SETTINGの歯車アイコンを通常サイズに戻しました
- Playbackの説明文は小さく表示し、英語表記に不慣れな学生でも意味を把握しやすくしています

### コード整理・検証
- 旧設定項目 `Answer labels / Reduced motion / Direction` は本体コードへ再混入していないことを確認
- Service Workerのキャッシュを `v2-0-3` へ更新
- Playback専用の挙動テストを追加

## オンライン公開

本体は静的Webアプリです。Netlify / Vercel / Cloudflare Pages / GitHub Pagesなどへフォルダ一式を配置すれば、学生はURLを開くだけでプレイできます。

オンラインランキングには現在Supabase接続コードを同梱しています。

1. Supabaseプロジェクトを作成
2. `supabase_setup.sql` をSQL Editorで実行
3. `cloud-config.js` にProject URLとPublishable Keyを設定
4. このフォルダ一式をHTTPS対応の静的ホスティングへ公開

Supabase未設定でもゲーム本体は動作し、ランキング送信のみ無効になります。

### iCloud Drive / Google Driveについて
- iCloud DriveとGoogle Driveはファイル保存・共有用途であり、このフォルダを置くだけでWebアプリとして公開する用途には適していません。
- Googleアカウントだけで完結させたい場合は、Google Apps ScriptをWebアプリとして公開し、Google SheetsをランキングDBとして使う構成へ移植できます。
- この場合はSupabaseを使わずにオンラインランキングを実現できますが、Apps Script向けのコード変更が必要です。

## 主なファイル

- `index.html` — エントリーポイント
- `styles.css` — UI / スマホ最適化 / アニメーション
- `app.js` — ゲーム本体・音楽理論・Playback・学習分析
- `cloud.js` — Supabase接続
- `cloud-config.js` — Supabase接続設定
- `supabase_setup.sql` — データベース初期構築
- `nakashima-logo.png` — 起動画面ロゴ
- `manifest.webmanifest` / `sw.js` — PWA関連
- `tests/smoke-test.js` — UI・ロジック回帰テスト
- `tests/playback-test.js` — Playback順序の挙動テスト

## ローカル確認

```bash
python3 -m http.server 8080
```

ブラウザで `http://localhost:8080` を開いてください。

## 自動テスト

```bash
node --check app.js
node --check cloud.js
node --check sw.js
node tests/smoke-test.js
node tests/playback-test.js
```
