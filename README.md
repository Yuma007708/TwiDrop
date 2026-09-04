# TwiDrop

ツイートの URL から**本文・画像・動画**を iPhone / iPad に保存する SwiftUI アプリです。
API キーや X アカウントのログインは不要です（埋め込みツイートが使う公開エンドポイントを利用）。

## できること

- URL を貼り付けると**自動でプレビュー**（本文・作者・動画はその場で再生）。ボタンは「保存する」1 つだけ
- **クリップボードの URL をワンタップで使う**（中身はタップするまで読みません）
- **端末に保存** — `tweet.json` / `tweet.md` と、動画・画像のファイル
- **写真アプリに追加** — 保存した動画・画像をカメラロールへ
- **共有シートから保存** — X アプリで「共有 → TwiDrop に保存」
- **ライブラリ** — 保存済みをサムネイルのグリッドで一覧。詳細から共有・写真に追加・削除

動画は自動で**最高画質の mp4** を、画像は**原寸**を選びます。

## デザイン

ダーク × アンバーの 1 アクセント。動画が主役なので暗い背景でサムネイルを際立たせ、
入力欄と保存ボタンは親指の届く画面下部に置いています。書体は SF Rounded（`fontDesign(.rounded)`）。
配色と共通部品は `TwiDrop/Theme.swift` にまとめてあります。

## ビルド手順

`.xcodeproj` はマージが壊れやすいのでコミットせず、[XcodeGen](https://github.com/yonaskolb/XcodeGen) の
`project.yml` から生成します。

```bash
brew install xcodegen
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

対応 OS は iOS 17 以降です。

> XcodeGen を使わない場合は、Xcode で App + Share Extension のターゲットを作り、
> `TwiDropKit` をローカルパッケージとして追加したうえで、
> `TwiDrop/` と `ShareExtension/` のファイルを各ターゲットに入れてください。
> `ArchiveLocation.swift` と `Theme.swift` は**両方**のターゲットに含めます。

## 構成

```
.
├── project.yml            # XcodeGen のプロジェクト定義
├── TwiDropKit/            # ロジック層（Swift Package・Foundation のみ）
│   ├── Sources/TwiDropKit/
│   └── Tests/TwiDropKitTests/
├── TwiDrop/               # アプリ本体（SwiftUI）
│   ├── TwiDropApp.swift
│   ├── TweetViewModel.swift
│   ├── Theme.swift              # 配色・共通部品（共有拡張とも共有）
│   ├── ArchiveLocation.swift    # 保存先（共有拡張とも共有）
│   ├── PhotoLibrarySaver.swift
│   └── Views/
│       ├── ContentView.swift        # 2 タブのルート
│       ├── SaveView.swift           # 「保存」タブ
│       ├── TweetCardView.swift      # ツイートカード・メディア表示
│       └── SavedTweetsView.swift    # 「ライブラリ」タブ・詳細
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
swift test --package-path TwiDropKit
```

```
Executed 45 tests, with 0 failures
```

ネットワークには接続せず、実際の API と同じ構造の合成データとスタブで検証します。

## 制限と注意

- 取得できるのは**公開ツイートのみ**です。鍵アカウント、削除済み、年齢制限付きの投稿は取得できません。
- 非公式の公開エンドポイントを利用しているため、X 側の仕様変更で動かなくなる可能性があります。
- 保存したコンテンツの権利は投稿者に帰属します。私的利用の範囲で使い、再配布や商用利用は行わないでください。
