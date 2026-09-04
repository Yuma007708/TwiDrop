"""TwiDrop のコマンドラインインターフェース。"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

from . import __version__
from .errors import TwiDropError
from .service import DEFAULT_OUTPUT_DIR, get_tweet, save_from_url


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="twidrop",
        description="ツイート URL から本文・画像・動画を保存します。",
    )
    parser.add_argument("urls", nargs="*", help="ツイートの URL（複数指定可）")
    parser.add_argument(
        "-o",
        "--output",
        default=str(DEFAULT_OUTPUT_DIR),
        help=f"保存先ディレクトリ（既定: {DEFAULT_OUTPUT_DIR}）",
    )
    parser.add_argument(
        "--no-media", action="store_true", help="本文だけ保存し、画像・動画は取得しない"
    )
    parser.add_argument(
        "--overwrite", action="store_true", help="既に存在するメディアも再ダウンロードする"
    )
    parser.add_argument(
        "--info", action="store_true", help="保存せずに取得内容を表示するだけにする"
    )
    parser.add_argument(
        "--serve", action="store_true", help="Web UI をローカルで起動する"
    )
    parser.add_argument("--host", default="127.0.0.1", help="--serve 時のホスト")
    parser.add_argument("--port", type=int, default=8000, help="--serve 時のポート")
    parser.add_argument("--version", action="version", version=f"TwiDrop {__version__}")
    return parser


def _print_tweet(tweet) -> None:
    print(f"@{tweet.author_screen_name} ({tweet.author_name})")
    if tweet.created_at:
        print(f"  投稿日時: {tweet.created_at}")
    print(f"  本文: {tweet.text}")
    for media in tweet.media:
        size = f" {media.width}x{media.height}" if media.width else ""
        print(f"  [{media.kind}]{size} {media.url}")
    if not tweet.media:
        print("  メディアなし")


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)

    if args.serve:
        from .server import run

        run(host=args.host, port=args.port, output_dir=Path(args.output))
        return 0

    if not args.urls:
        build_parser().print_help()
        return 2

    exit_code = 0
    for url in args.urls:
        try:
            if args.info:
                _print_tweet(get_tweet(url))
                continue

            result = save_from_url(
                url,
                args.output,
                with_media=not args.no_media,
                overwrite=args.overwrite,
            )
            print(f"保存しました: {result.directory}")
            for path in result.files:
                print(f"  - {path.name}")
            for note in result.skipped:
                print(f"  ! スキップ: {note}", file=sys.stderr)
        except TwiDropError as exc:
            print(f"エラー ({url}): {exc}", file=sys.stderr)
            exit_code = 1
    return exit_code


if __name__ == "__main__":
    raise SystemExit(main())
