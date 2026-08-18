# INTERVAL COSMOS v2.0.5 開発検証記録

## Phase 1 — DB基盤

Supabase上でv2.0.5用DBを新規構築し、以下を実機確認済み。

- コアテーブル: 18 / 18
- コースマスタ: 11 / 11
- 主要RPC: 8 / 8
- 旧v2.0.4テーブル `profiles` / `rankings`: 0
- RLSをv2.0.5構造に合わせて有効化
- `players` と `player_devices` を分離し、1プレイヤーに複数端末を紐付ける構造へ変更

## Phase 2 — 学生アカウント

実ブラウザから新規学生登録を実施し、以下を確認済み。

- 学籍番号の文字列保存
- プレイヤー名保存
- 所属コース保存
- アバター保存
- ランキング公開設定の初期値 `ask`
- `player_devices` に初回端末が1件紐付く
- `public_profiles` が自動生成される

テスト時のDB確認結果:

- course: 作曲コース
- avatar_id: `wave`
- ranking_visibility: `ask`
- linked_devices: `1`
- public_profile: `OK`

## Phase 2 — 6桁PIN端末追加

6桁PINによる複数端末接続フローを実ブラウザで完遂。

仕様:

- 6桁PIN
- 有効期限5分
- PIN入力だけでは接続されない
- 既存端末側で最終承認が必要
- 承認後も旧端末・新端末の両方を継続利用可能

実機テスト:

1. 既存ブラウザでPIN発行
2. 別ブラウザからPIN入力
3. 既存ブラウザで接続要求を承認
4. 新ブラウザ側で同じプレイヤー名・プロフィールが表示されることを確認
5. DB上で同一プレイヤーの `linked_devices = 2` を確認

結果: PASS

Phase 2は完全クローズ。

## Phase 2.5 — Cookie / サイトデータ消失からの自己復旧

実機テスト中にCookie・サイトデータを削除し、ログイン済み端末が1台も残っていない場合、既存の6桁PINだけでは学生自身で復旧できないことが判明。

対策として自己復旧基盤を追加。

仕様:

- 新規学生登録時に本人が復旧コードを設定
- 既存学生はSETTINGSから復旧コードを設定・変更可能
- 復旧コードは8〜20文字の英数字で、英字と数字を両方含む
- 大文字小文字は区別しない
- 学籍番号そのものは復旧コードに使用不可
- DBには復旧コードの平文を保存せずbcryptハッシュのみ保存
- 5回連続失敗で15分ロック
- ログイン済み端末が残っている場合は従来の6桁PINを使用
- ログイン済み端末がない場合は「学籍番号＋復旧コード」で既存playerへ新しいAuthを接続
- 復旧時に学習履歴・ランキング・COSMOS PT・実績・フレームは作り直さず既存playerをそのまま使用

実装ファイル:

- `sql/account-recovery-v2.0.5.sql`
- `phase2-recovery-v205-fixed.js`
- `phase2-recovery-v205.css`
- `docs/V2.0.5_ACCOUNT_RECOVERY.md`
- `tests/recovery-v205-test.js`

### SETTINGSフリーズ hotfix

初回実装ではPhase 2.5と既存モジュールがSETTINGS内のバージョン表示を互いに更新し、MutationObserverが連続発火してフリーズする不具合が再発。

修正:

- Phase 2.5からSETTINGSバージョン表示の書き換え処理を削除
- Account recovery行は未挿入時だけ追加
- 復旧状態確認は1回だけ実行
- 固定版 `phase2-recovery-v205-fixed.js` へ差し替え

実ブラウザでSETTINGSが正常に開閉・操作できることを確認済み。

### 自己復旧 実ブラウザ確認

2026-08-18、学生アカウントで復旧コードを設定後、別ブラウザから以下の一連の流れを実施。

1. `すでにアカウントがある` を選択
2. ログイン済み端末がない場合の自己復旧導線を選択
3. 学籍番号＋本人設定の復旧コードを入力
4. 既存の同一playerへ接続成功
5. モードセレクトまで正常遷移
6. MY COSMOSを開き、既存のCOSMOS PT・BRONZE FRAME等が引き継がれていることを確認

結果: PASS

Phase 2.5は完全クローズ。

## Phase 3 — ランキング第2世代

`v2.0.5-alpha2` として開発ブランチへ実装。

実装内容:

- RESULTに「今回 / 自己ベスト / 月間順位相当 / 殿堂順位相当」を追加
- 自己ベスト未更新時はランク演出を表示しない
- 自己ベスト更新時のみ順位演出
- `ask` 設定では順位演出後に公開確認を表示
- 「このランキングを公開する / 非公開のまま続ける」を実装
- SETTINGSに `毎回確認 / 常に公開 / 常に非公開` を追加
- ランキングにコースバッジ / 称号 / フレームを追加表示
- 正答率 / 最大コンボ / スコア / アバター / プレイヤー名を継続表示
- ランキング行から公開プロフィールカードを開ける導線を追加
- 公開プロフィールカードにコース / アバター / 称号 / フレーム / 公開ベスト / 正答率 / 最大コンボ / 代表実績を表示
- 学籍番号は公開プロフィールに含めない
- RESULTで `R = RETRY`, `Esc = MODE SELECT` を追加

### alpha2.1 hotfix

実ブラウザでSETTINGSを開いた際、Phase 3の公開設定UIと `MutationObserver` が相互に再描画を発生させ、画面がフリーズする不具合を確認。

修正内容:

- SETTINGS / RESULT / RANKING の拡張描画を、内容変更時のみDOM更新する方式へ変更
- `MutationObserver` による無限再描画を防止
- Phase 3 JS/CSSへ `alpha2.1` のキャッシュバスターを付与

### 実ブラウザ確認

`ranking_visibility = ask` の学生アカウントでSTANDARD / TEXTをプレイし、以下を確認済み。

1. 自己ベスト更新後に `RANKING PRIVACY` の公開確認が表示される
2. 「非公開のまま続ける」を選択できる
3. RESULTに `PRIVATE` が表示される
4. RESULTに `月間 1位相当` が表示される
5. RESULTに `殿堂 1位相当` が表示される
6. RESULTに「今回 / 自己ベスト / 月間順位 / 殿堂順位」の4カードが表示される
7. SETTINGSフリーズ修正後もゲーム継続可能

`ranking_visibility = always_public` に変更後、以下を実ブラウザ確認済み。

1. 自己ベスト更新記録が公開ランキングへ掲載される
2. ランキング行から `test` の公開プロフィールカードを開ける
3. 公開プロフィールカードに `作曲コース` が表示される
4. アバターが表示される
5. 公開ベスト `195` が表示される
6. TEXT公開記録 `195`、正答率 `100%`、MAXコンボ `2` が表示される
7. 学籍番号は公開プロフィールカードに表示されない

自己ベスト `195` に対して `80` の記録を出し、以下を確認済み。

- 自己ベストは `195` を維持
- ランクイン演出は再表示されない
- ONLINE RECORD は既存公開ベストを維持

`ranking_visibility = always_private` へ変更し、現行実装では公開済みランキングが非公開化されることも確認。

結果: Phase 3 PASS

### v2.0.5後の改善項目

GitHub Issue #1で追跡する。

- 自己ベスト順位の表記を明確化
- `常に非公開` で過去の公開済みベストを消さない仕様へ変更
- 学習履歴 → FOCUS練習遷移時の一瞬のSELECT MODE表示を除去
- サンプル不足時に WEAK POINT と断定しない

## Phase 4 — 学習履歴・苦手分析

`v2.0.5-alpha3` として本人向け学習ダッシュボードを実装。

### 実ブラウザ確認

学生アカウント `test` で学習履歴画面を開き、以下を確認済み。

- PLAY SESSIONS: `3`
- ACCURACY: `100%`（4/4）
- BEST SCORE: `195`
- MAX COMBO: `2`
- 14 DAY ACTIVITY に 8/17 の3プレイが表示される
- MODE ANALYSIS に TEXT 3 PLAY / 正答率100% / BEST 195 / MAX 2 が表示される
- INTERVAL ANALYSIS に13音程の回答数・正答率が表示される
- RECENT SESSIONS に 100 / 195 / 80 の3セッションが時刻付きで表示される
- 「この苦手を練習」→ 回答方法 TEXT / KEYS の選択画面を確認
- TEXT / KEYS のボタンを同サイズ・同格の表現へ修正
- SETTINGSを背後に残したままFOCUSへ遷移する不具合をhotfixで修正
- 選択した音程のみのFOCUS SELECTへ遷移する導線を実装

機能上のPhase 4はPASS。遷移途中にSELECT MODEが一瞬見える点のみ、Issue #1へUIブラッシュアップとして持ち越す。

## Phase 5 — MY COSMOS / 実績・称号・フレーム・デイリー

重い基盤実装を `v2.0.5-dev` へ先行コミット。

実装済み:

- 実績カタログ（基礎・正答率・コンボ・モード・13音程・連続日数・ランキング）
- 高難度実績は未解放時 `???`
- メイン称号1個＋称号コレクション
- NORMAL → BRONZE → SILVER → GOLD → PLATINUM → COSMIC のポイント成長
- AURORA / SUPERNOVA / EVENT HORIZON の複合条件フレーム
- JST日付ごとに共通3枠のデイリーミッション
- デイリー報酬はCOSMOS PTのみで、ゲームスコア加算なし
- 代表実績を最大3つ設定し、公開プロフィールへ反映可能
- `evaluate_my_progress()` による再計算可能・複数端末安全な解放判定
- `MY COSMOS` UI、称号/フレーム装備、実績一覧、デイリー進捗、解放演出

関連ファイル:

- `sql/progression-v2.0.5.sql`
- `phase5-progression-v205.js`
- `phase5-v205.css`
- `docs/V2.0.5_PHASE5_PROGRESSION.md`
- `tests/progression-v205-test.js`

Phase 1の実際のセットアップSQLと列名を照合し、Phase 5が利用するカタログ/進捗テーブルの構造一致を確認済み。

### 実ブラウザ確認 — 初回表示

2026-08-18、Phase 5 SQLをSupabase SQL Editorで実行し `Success. No rows returned` を確認。

その後 `v2.0.5-dev` 最新版を起動し、学生アカウント `test` で `MY COSMOS` を開いて以下を確認。

- MY COSMOS画面が正常表示される
- 既存プレイ履歴から `FIRST SIGNAL` が遡及解除される
- COSMOS PT = `10`
- メイン称号 = `FIRST SIGNAL`
- フレーム = `NORMAL`
- 次段階 `BRONZE` まで `10 / 100 PT` と表示される
- 2026-08-18のDAILY MISSIONSが3枠生成される
  - `10 CLEAR SIGNALS` 0/10
  - `HYPER SPARK` 0/1
  - `DUAL ROUTE` 0/2
- NORMAL / BRONZE / SILVER / GOLD / PLATINUM / COSMIC / AURORA / hidden frames が表示される
- 未解放の高難度フレームは `???` として条件を隠して表示される

初回表示: PASS

### 実ブラウザ確認 — 動的進行

HYPER DRIVE / KEYSを1セッションプレイし、16問中14問正解、最大コンボ5、スコア2430を記録。

以下を確認。

- 自己ベスト更新後の既存ランキング演出が正常表示される
- `HYPER IGNITION` 実績解除演出が表示される（+25 PT）
- 最大コンボ5到達により `COMBO 5` が解除される（+15 PT）
- DAILY `10 CLEAR SIGNALS` が 10/10 COMPLETE（+10 PT）
- DAILY `HYPER SPARK` が 1/1 COMPLETE（+15 PT）
- DAILY `DUAL ROUTE` が 1/2 へ進行
- COSMOS PT が 10 → 75 へ再計算される
- MY COSMOS再表示時に75 / 100 PTとしてBRONZEへの進捗が表示される

計算確認: `10 + 25 + 15 + 10 + 15 = 75 PT`

その後別モードをプレイし、以下を確認。

- COSMOS PTが130まで増加
- BRONZE FRAMEが自動解放
- BRONZE FRAMEが自動装備
- 次のSILVERまで `130 / 300 PT` と表示

フレーム成長: PASS

### カットイン競合

ランキングカットインと実績/デイリー/フレーム解除カットインが一時的に重なって表示される現象を実機で確認。

対策としてPhase 5解除演出を、ランキング演出および公開確認が終了するまで待機するキュー方式へ修正済み。実機での競合再テストは次回実施。

次の確認:

- EAR LINK等でランキング演出→解除演出が重ならず順番に出ること
- 代表実績の選択と公開プロフィール反映

### 自動回帰テスト

`.github/workflows/v205-tests.yml` を追加。以後 `v2.0.5-dev` push時に以下を自動実行する。

- extension JS syntax check
- smoke test
- playback regression
- account regression
- recovery regression
- ranking regression
- progression regression

## 開発版起動メモ

- v2.0.4由来のService Workerキャッシュが残っていると旧 `profiles` を参照する場合がある。
- キャッシュクリア後、v2.0.5の `PLAYER ACCESS` が正常表示されることを確認済み。
- `START_HERE.command` は実行権限付きに修正済み。
- 今後の開発版ローカル起動ポートは `8875` を使用し、旧キャッシュとの衝突を避ける。