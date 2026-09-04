"""ツイート本文とメディアをローカルへ保存する。"""

from __future__ import annotations

import json
import re
from dataclasses import dataclass, field
from pathlib import Path
from urllib.parse import urlparse

import httpx

from .errors import MediaDownloadError
from .models import Media, Tweet

#: メディアの取得を許可するホスト。ここに無い URL は取りに行かない。
ALLOWED_MEDIA_HOSTS = frozenset({"pbs.twimg.com", "video.twimg.com"})

_UNSAFE_CHARS = re.compile(r"[^A-Za-z0-9._-]+")

DOWNLOAD_HEADERS = {
    "User-Agent": (
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 "
        "(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36"
    ),
    "Referer": "https://x.com/",
}


@dataclass
class SaveResult:
    """1 件のツイートを保存した結果。"""

    tweet: Tweet
    directory: Path
    text_file: Path
    json_file: Path
    media_files: list[Path] = field(default_factory=list)
    skipped: list[str] = field(default_factory=list)

    @property
    def files(self) -> list[Path]:
        return [self.text_file, self.json_file, *self.media_files]


def safe_name(value: str, *, fallback: str = "tweet") -> str:
    """ファイル名に使える文字だけを残す。"""
    cleaned = _UNSAFE_CHARS.sub("_", value).strip("._")
    return cleaned[:80] or fallback


def _check_media_url(url: str) -> None:
    host = (urlparse(url).hostname or "").lower()
    if host not in ALLOWED_MEDIA_HOSTS:
        raise MediaDownloadError(f"許可されていないメディアホストです: {host or url!r}")


def media_filename(tweet: Tweet, media: Media, index: int) -> str:
    """``NASA_1362551461910114310_1.mp4`` のような名前を組み立てる。"""
    return f"{safe_name(tweet.slug)}_{index}{media.extension}"


def download_media(
    media: Media,
    destination: Path,
    *,
    client: httpx.Client | None = None,
    overwrite: bool = False,
    timeout: float = 60.0,
) -> Path:
    """メディア 1 件をストリーミングで保存する。

    既にファイルがあり ``overwrite`` が False なら再取得しない。
    """
    _check_media_url(media.url)
    if destination.exists() and not overwrite:
        return destination

    destination.parent.mkdir(parents=True, exist_ok=True)
    temporary = destination.with_suffix(destination.suffix + ".part")
    owned = client is None
    http = client or httpx.Client(timeout=timeout, follow_redirects=True)
    try:
        with http.stream("GET", media.url, headers=DOWNLOAD_HEADERS) as response:
            if response.status_code >= 400:
                raise MediaDownloadError(
                    f"メディアの取得に失敗しました（HTTP {response.status_code}）: {media.url}"
                )
            with temporary.open("wb") as handle:
                for chunk in response.iter_bytes(chunk_size=1 << 16):
                    handle.write(chunk)
    except httpx.HTTPError as exc:
        temporary.unlink(missing_ok=True)
        raise MediaDownloadError(f"メディアの取得に失敗しました: {exc}") from exc
    finally:
        if owned:
            http.close()

    temporary.replace(destination)
    return destination


def save_tweet(
    tweet: Tweet,
    output_dir: Path | str = "downloads",
    *,
    with_media: bool = True,
    overwrite: bool = False,
    client: httpx.Client | None = None,
) -> SaveResult:
    """ツイート本文（Markdown / JSON）と添付メディアを保存する。

    保存先は ``<output_dir>/<screen_name>_<tweet_id>/`` 以下。
    """
    directory = Path(output_dir) / safe_name(tweet.slug)
    directory.mkdir(parents=True, exist_ok=True)

    text_file = directory / "tweet.md"
    text_file.write_text(tweet.to_markdown(), encoding="utf-8")

    json_file = directory / "tweet.json"
    json_file.write_text(
        json.dumps(tweet.to_dict(), ensure_ascii=False, indent=2), encoding="utf-8"
    )

    result = SaveResult(tweet=tweet, directory=directory, text_file=text_file, json_file=json_file)
    if not with_media:
        return result

    owned = client is None
    http = client or httpx.Client(timeout=60.0, follow_redirects=True)
    try:
        for index, media in enumerate(tweet.media, start=1):
            target = directory / media_filename(tweet, media, index)
            try:
                result.media_files.append(
                    download_media(media, target, client=http, overwrite=overwrite)
                )
            except MediaDownloadError as exc:
                # 1 件失敗しても残りは保存する。
                result.skipped.append(f"{media.url}: {exc}")
    finally:
        if owned:
            http.close()
    return result
