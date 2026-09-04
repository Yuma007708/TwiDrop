# TwiDrop

ツイートの URL から**本文・画像・動画**を保存するアプリです。
API キーや X アカウントのログインは不要です（埋め込みツイートが使う公開エンドポイントを利用）。

- 📱 **[iOS アプリ](ios/)** — SwiftUI 製。共有シートから保存、写真アプリへの書き出しに対応
- 🖥 **CLI / Web UI** — 同じ処理を Python から使えるコンパニオン実装

動画は自動で**最高画質の mp4** を、画像は**原寸**を選びます。

## iOS アプリ

```bash
brew install xcodegen
cd ios
xcodegen generate
open TwiDrop.xcodeproj
```

- URL を貼り付けて**プレビュー**（本文・作者・動画はその場で再生）
- **端末に保存** — `tweet.json` / `tweet.md` と動画・画像のファイル
- **写真アプリに追加** — 保存した動画・画像をカメラロールへ
- **共有シートから保存** — X アプリで「共有 → TwiDrop に保存」
- **保存済み一覧** — 詳細表示、共有シートで書き出し、スワイプで削除

セットアップ手順と構成は **[ios/README.md](ios/README.md)** を参照してください。

```bash
swift test --package-path ios/TwiDropKit    # 45 tests
```

## CLI / Web UI（Python）

Mac やサーバ上でまとめて保存したいときに使えます。

```bash
pip install -r requirements.txt

python -m twidrop --serve                   # Web UI → http://127.0.0.1:8000
python -m twidrop https://x.com/NASA/status/1362551461910114310
python -m twidrop --info URL                # 保存せず内容だけ表示
python -m twidrop --no-media URL            # 本文だけ保存
```

保存結果:

```
downloads/
└── NASA_1362551461910114310/
    ├── tweet.md                        # 人が読む用の本文
    ├── tweet.json                      # メタデータ一式
    └── NASA_1362551461910114310_1.mp4  # 動画（最高画質）
```

`pip install -e .` すると `twidrop` コマンドとしても実行できます。

### 対応する URL

- `https://x.com/<user>/status/<id>`
- `https://twitter.com/<user>/status/<id>`（`mobile.` / `www.` 付きも可）
- `https://x.com/i/web/status/<id>`
- ツイート ID だけ（例: `1362551461910114310`）

### Python から使う

```python
from twidrop import service

tweet = service.get_tweet("https://x.com/NASA/status/1362551461910114310")
print(tweet.text, tweet.has_video)

result = service.save_from_url("https://x.com/NASA/status/1362551461910114310")
print(result.directory, [p.name for p in result.files])
```

### JSON API

Web UI は次の API の上に載っているので、他のツールからも呼び出せます。

| メソッド | パス | 説明 |
| --- | --- | --- |
| `POST` | `/api/tweet` | `{"url": ...}` を渡して内容を取得（保存しない） |
| `POST` | `/api/save` | `{"url": ..., "with_media": true}` で取得して保存 |
| `GET` | `/api/saved` | 保存済みツイートの一覧 |
| `GET` | `/files/<dir>/<file>` | 保存済みファイルのダウンロード |
| `GET` | `/api/health` | 稼働確認 |

```bash
pip install -r requirements-dev.txt
pytest                                      # 66 tests
```

## 構成

どちらの実装も同じ流れです。UI から切り離したロジック層を持つので、単体でテストできます。

| 処理 | Swift (`ios/TwiDropKit/`) | Python (`twidrop/`) |
| --- | --- | --- |
| URL からツイート ID を取り出す | `TweetURL.swift` | `urls.py` |
| エンドポイント用の token を生成 | `SyndicationToken.swift` | `syndication.py` |
| ツイート JSON を取得 | `SyndicationClient.swift` | `syndication.py` |
| JSON をモデルへ変換 | `TweetParser.swift` | `parser.py` |
| メディアを取得 | `MediaDownloader.swift` | `downloader.py` |
| 保存・一覧・削除 | `TweetArchive.swift` | `downloader.py` |

`SyndicationTokenTests` は、Swift と Python の token 生成結果が一致することも確認しています。

## 制限と注意

- 取得できるのは**公開ツイートのみ**です。鍵アカウント、削除済み、年齢制限付きの投稿は取得できません。
- 非公式の公開エンドポイントを利用しているため、X 側の仕様変更で動かなくなる可能性があります。
- 短時間に大量のリクエストを送るとレート制限がかかります。
- 保存したコンテンツの権利は投稿者に帰属します。私的利用の範囲で使い、再配布や商用利用は行わないでください。
