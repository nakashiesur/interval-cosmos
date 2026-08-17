# ver.2.0.4 検証結果

## 追加修正
- Supabase匿名認証とオンラインプロフィールを接続
- 初回プロフィールに学籍番号を追加
- `student_number` をUNIQUE化し重複登録を防止
- 学籍番号はランキングへ出力しない
- `cloud.js` のprofiles取得・保存を `student_number` 対応
- rankingsテーブルを既存v2.0.3 cloud.jsの `period` 方式と統一
- `submit_interval_cosmos_score` RPCをDB側に作成
- Service Workerキャッシュを `interval-cosmos-v2-0-4` に更新

## 検査
- `node --check app.js` PASS
- `node --check cloud.js` PASS
- `node --check sw.js` PASS
- `node tests/smoke-test.js` PASS
- `node tests/playback-test.js` PASS
- 合計41項目 PASS

## DBセキュリティ
- profiles: 本人のみSELECT/INSERT/UPDATE
- rankings: authenticatedユーザーはSELECTのみ
- スコア更新: SECURITY DEFINERのRPC経由
- student_numberはrankingsへコピーしない
- anon roleにはprofiles/rankingsの権限を付与しない
