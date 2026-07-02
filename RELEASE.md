# Release Guide

LangueDeChat のリリースは [`asc`](https://github.com/rorkai/App-Store-Connect-CLI) (App Store Connect CLI) でローカル完結します。Xcode の Organizer 操作は不要です。

---

## セットアップ(初回のみ)

### 1. asc CLI をインストール

```bash
brew install asc
```

### 2. App Store Connect API キーを準備

1. https://appstoreconnect.apple.com/access/integrations/api でチームキーを生成(Admin 権限)
2. `.p8` ファイルを `~/.appstoreconnect/AuthKey_XXX.p8` に保存(`chmod 600`)
3. Issuer ID / Key ID を控える

※ yomy と同じ Apple Developer チーム (`WHBF4Z49B6`) なので、既存の `~/.appstoreconnect/AuthKey_HTM4VLQ5AJ.p8` をそのまま使えます。

### 3. 認証情報を .env に登録

`.env.example` をコピーして `.env` を作成し、値を埋める:

```bash
cp .env.example .env
# エディタで .env を編集して ASC_KEY_ID / ASC_ISSUER_ID / ASC_PRIVATE_KEY_PATH / ASC_APP_ID を入力
```

`.env` は `.gitignore` 済みなのでコミットされません。LangueDeChat の `ASC_APP_ID` は `6781539310`。

---

## リリース手順

毎回のリリースで実行する流れ。

### 認証情報を読み込む

```bash
set -a; source .env; set +a
```

### Internal Testing(自分や組織メンバーのみ、即配信)

```bash
asc workflow run testflight_internal VERSION:1.0
```

archive → IPA エクスポート → アップロード → 処理完了待ち を 1 コマンドで実行。Internal Tester(App Store Connect の Users and Access に登録されたユーザー)に自動的に届きます。

### External Testing(社外テスター、Beta App Review が必要)

```bash
asc workflow run testflight_external VERSION:1.0 GROUP:"LangueDeChat Tester"
```

archive → IPA エクスポート → アップロード → 指定 Beta Group へ配信 → Beta App Review 提出 を 1 コマンドで実行。

`GROUP` は App Store Connect で作成した External Beta Group の名前 or ID を渡します。

### 同じ Version の再ビルド(再審査不要)

`SUBMIT_BETA:false` で審査提出をスキップ:

```bash
asc workflow run testflight_external VERSION:1.0 GROUP:"LangueDeChat Tester" SUBMIT_BETA:false
```

Beta App Review は **Marketing Version ごとに 1 回**通れば、同 Version の build 番号違いはそのまま配信できます。

---

## ビルド番号の運用

`CFBundleVersion`(= `CURRENT_PROJECT_VERSION`)は、workflow の archive ステップで `git rev-list --count HEAD`(コミット数)を xcodebuild フラグとして注入します。手動更新は不要です。

- ソースの `project.pbxproj` は `CURRENT_PROJECT_VERSION = 1` のまま据え置き(git diff が出ない)
- archive 時だけ `CURRENT_PROJECT_VERSION=<コミット数>` で上書きされる
- app 本体とウィジェット拡張 (`LangueDeChatWidgets`) は同じプロジェクト設定を共有するため、両方に同じビルド番号が入る
- コミットが進む = ビルド番号が増える、なので TestFlight への再アップロードが弾かれない

> yomy は Run Script build phase で同じことをしているが、LangueDeChat は `GENERATE_INFOPLIST_FILE = YES` で `CFBundleVersion` が `$(CURRENT_PROJECT_VERSION)` から自動生成されるため、xcodebuild フラグ注入だけで完結する(pbxproj や `ENABLE_USER_SCRIPT_SANDBOXING` を触る必要がない)。

---

## トラブルシュート

### `Error: --group is required`

`asc publish testflight` には Beta Group が必須。Internal Testing の場合は `asc builds upload`(workflow 内では `testflight_internal` ステップ)を使う。

### `ITMS-90360: Missing Info.plist value`

ウィジェット拡張の `LangueDeChatWidgets-Info.plist` に `CFBundleDisplayName` 等の必須キーがない場合に出る。エラーメッセージで指摘されたキーを補う。

### `アクセス権をリクエスト` 画面が出る(App Store Connect API)

個人アカウントでも初回は組織レベルで API アクセスを有効化する必要がある。ボタンを押せば即時 or メール確認を経て有効化される。

---

## App Store 本申請

別途準備が必要。Beta App Review とは別審査(通常 1〜3 日):

- スクリーンショット(6.9" / 6.7" / iPad 対応サイズ)
- 説明文(4000字)・サブタイトル(30字)・キーワード(100字)・プロモテキスト(170字)
- 年齢レーティング
- App Store Connect の「App プライバシー」設定
- カテゴリ

これらは TestFlight 配信とは独立しているため、TestFlight で使っているビルドをそのまま「リリースに追加」して提出できます。
