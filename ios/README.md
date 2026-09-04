# TwiDrop for iOS

ツイートの URL から**本文・画像・動画**を iPhone / iPad に保存する SwiftUI アプリです。
API キーや X アカウントのログインは不要です（埋め込みツイートが使う公開エンドポイントを利用）。

## できること

- URL を貼り付けて**プレビュー**（本文・作者・動画はその場で再生）
- **端末に保存** — `tweet.json` / `tweet.md` と、動画・画像のファイル
- **写真アプリに追加** — 保存した動画・画像をカメラロールへ
- **共有シートから保存** — X アプリで「共有 → TwiDrop に保存」
- **保存済み一覧** — 詳細表示、共有シートで書き出し、スワイプで削除

動画は自動で**最高画質の mp4** を、画像は**原寸**を選びます。

## ビルド手順

`.xcodeproj` はマージが壊れやすいのでコミットせず、[XcodeGen](https://github.com/yonaskolb/XcodeGen) の
`project.yml` から生成します。

```bash
brew install xcodegen
cd ios
xcodegen generate
open TwiDrop.xcodeproj
```

Xcode で開いたら 2 か所だけ設定してください。

1. **署名** — `TwiDrop` と `ShareExtension` の両ターゲットで
   Signing & Capabilities から自分の Team を選ぶ
2. **App Group** — 両ターゲットに同じ App Group を設定する
   （既定値は `group.dev.twidrop.shared`）

App Group は共有拡張で保存したツイートを本体アプリから見るために使います。
未設定でも本体アプリ単体は動きます（保存先がアプリの Documents になります）。

> XcodeGen を使わない場合は、Xcode で App + Share Extension のターゲットを作り、
> `TwiDropKit` をローカルパッケージとして追加したうえで、
> `TwiDrop/` と `ShareExtension/` のファイルを各ターゲットに入れてください。
> `ArchiveLocation.swift` は**両方**のターゲットに含めます。

## 構成

```
ios/
├── project.yml            # XcodeGen のプロジェクト定義
├── TwiDropKit/            # ロジック層（Swift Package・Foundation のみ）
│   ├── Sources/TwiDropKit/
│   └── Tests/TwiDropKitTests/
├── TwiDrop/               # アプリ本体（SwiftUI）
│   ├── TwiDropApp.swift
│   ├── TweetViewModel.swift
│   ├── ArchiveLocation.swift    # 共有拡張とも共有
│   ├── PhotoLibrarySaver.swift
│   └── Views/
└── ShareExtension/        # 共有シート拡張
```

UI とロジックを分けているのがポイントです。`TwiDropKit` は Foundation にしか依存しないので、
Mac や Linux 上でも `swift test` だけでロジックを検証できます。

| ファイル | 役割 |
| --- | --- |
| `TweetURL.swift` | URL からツイート ID を取り出す |
| `SyndicationToken.swift` | エンドポイントが要求する token を生成 |
| `SyndicationClient.swift` | ツイート JSON を取得 |
| `TweetParser.swift` | JSON をモデルへ変換（最高画質 mp4 の選択など） |
| `MediaDownloader.swift` | メディアファイルの取得 |
| `TweetArchive.swift` | 保存・一覧・削除 |

## テスト

```bash
swift test --package-path ios/TwiDropKit
```

```
Executed 45 tests, with 0 failures
```

ネットワークには接続せず、実際の API と同じ構造の合成データとスタブで検証します。
`SyndicationTokenTests` は、同じアルゴリズムのリポジトリ内 Python 実装
（`twidrop/syndication.py`）と出力が一致することも確認しています。

## 制限と注意

- 取得できるのは**公開ツイートのみ**です。鍵アカウント、削除済み、年齢制限付きの投稿は取得できません。
- 非公式の公開エンドポイントを利用しているため、X 側の仕様変更で動かなくなる可能性があります。
- 保存したコンテンツの権利は投稿者に帰属します。私的利用の範囲で使い、再配布や商用利用は行わないでください。
