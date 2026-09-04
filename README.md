# TwiDrop

ツイートの URL を渡すだけで、**本文・画像・動画**をローカルに保存するツールです。
Web UI とコマンドラインの両方から使えます。

- API キー不要（埋め込みツイートが使う公開エンドポイントを利用）
- 動画は自動で**最高画質の mp4** を選択
- 画像は原寸（`name=orig`）で保存
- 本文は Markdown（`tweet.md`）と JSON（`tweet.json`）の両方で保存

## セットアップ

```bash
pip install -r requirements.txt
```

## Web UI

```bash
python -m twidrop --serve
# → http://127.0.0.1:8000
```

URL を貼り付けて「プレビュー」で内容を確認し、「保存する」でサーバ上に保存します。
保存したファイルは画面上のリンクからブラウザにダウンロードできます。

保存先を変えたいときは `--output` か環境変数 `TWIDROP_OUTPUT_DIR` を使います。

```bash
python -m twidrop --serve --port 9000 --output ~/tweets
```

## コマンドライン

```bash
# 本文・画像・動画をまとめて保存（既定の保存先は ./downloads）
python -m twidrop https://x.com/NASA/status/1362551461910114310

# 複数まとめて / 保存先を指定
python -m twidrop -o ~/tweets URL1 URL2 URL3

# 保存せず内容だけ確認
python -m twidrop --info URL

# 本文だけ保存（メディアは取得しない）
python -m twidrop --no-media URL

# 既存のメディアも再取得
python -m twidrop --overwrite URL
```

`pip install -e .` すると `twidrop` コマンドとしても実行できます。

### 保存されるもの

```
downloads/
└── NASA_1362551461910114310/
    ├── tweet.md                        # 人が読む用の本文
    ├── tweet.json                      # メタデータ一式
    └── NASA_1362551461910114310_1.mp4  # 動画（最高画質）
```

対応する URL の形式:

- `https://x.com/<user>/status/<id>`
- `https://twitter.com/<user>/status/<id>`（`mobile.` / `www.` 付きも可）
- `https://x.com/i/web/status/<id>`
- ツイート ID だけ（例: `1362551461910114310`）

## Python から使う

```python
from twidrop import service

tweet = service.get_tweet("https://x.com/NASA/status/1362551461910114310")
print(tweet.text, tweet.has_video)

result = service.save_from_url("https://x.com/NASA/status/1362551461910114310")
print(result.directory, [p.name for p in result.files])
```

## JSON API

Web UI は次の API の上に載っているので、他のツールからも呼び出せます。

| メソッド | パス | 説明 |
| --- | --- | --- |
| `POST` | `/api/tweet` | `{"url": ...}` を渡して内容を取得（保存しない） |
| `POST` | `/api/save` | `{"url": ..., "with_media": true}` で取得して保存 |
| `GET` | `/api/saved` | 保存済みツイートの一覧 |
| `GET` | `/files/<dir>/<file>` | 保存済みファイルのダウンロード |
| `GET` | `/api/health` | 稼働確認 |

## 構成

| ファイル | 役割 |
| --- | --- |
| `twidrop/urls.py` | URL からツイート ID を取り出す |
| `twidrop/syndication.py` | 公開エンドポイントから JSON を取得 |
| `twidrop/parser.py` | JSON をツイート／メディアのモデルに変換 |
| `twidrop/downloader.py` | 本文とメディアをディスクに保存 |
| `twidrop/service.py` | URL → 取得 → 保存をつなぐ高レベル API |
| `twidrop/server.py` | FastAPI の Web UI / JSON API |
| `twidrop/cli.py` | コマンドライン |

## テスト

```bash
pip install -r requirements-dev.txt
pytest
```

ネットワークには接続せず、実際の API と同じ構造の合成データでテストします。

## 制限と注意

- 取得できるのは**公開ツイートのみ**です。鍵アカウント、削除済み、年齢制限付きの投稿は取得できません。
- 非公式の公開エンドポイントを利用しているため、X 側の仕様変更で動かなくなる可能性があります。
- 短時間に大量のリクエストを送るとレート制限がかかります。
- 保存したコンテンツの権利は投稿者に帰属します。私的利用の範囲で使い、再配布や商用利用は行わないでください。
