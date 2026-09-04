"""URL を渡すだけで取得〜保存まで行う高レベル API。"""

from __future__ import annotations

from pathlib import Path

import httpx

from .downloader import SaveResult, save_tweet
from .models import Tweet
from .parser import parse_tweet
from .syndication import fetch_tweet_payload, fetch_tweet_payload_async
from .urls import extract_tweet_id

DEFAULT_OUTPUT_DIR = Path("downloads")


def get_tweet(url: str, *, lang: str = "ja", client: httpx.Client | None = None) -> Tweet:
    """ツイート URL から :class:`~twidrop.models.Tweet` を取得する（保存はしない）。"""
    tweet_id = extract_tweet_id(url)
    payload = fetch_tweet_payload(tweet_id, lang=lang, client=client)
    return parse_tweet(payload)


async def get_tweet_async(
    url: str, *, lang: str = "ja", client: httpx.AsyncClient | None = None
) -> Tweet:
    """:func:`get_tweet` の非同期版。"""
    tweet_id = extract_tweet_id(url)
    payload = await fetch_tweet_payload_async(tweet_id, lang=lang, client=client)
    return parse_tweet(payload)


def save_from_url(
    url: str,
    output_dir: Path | str = DEFAULT_OUTPUT_DIR,
    *,
    with_media: bool = True,
    overwrite: bool = False,
    lang: str = "ja",
) -> SaveResult:
    """ツイート URL を受け取り、本文とメディアを保存して結果を返す。"""
    with httpx.Client(timeout=60.0, follow_redirects=True) as client:
        tweet = get_tweet(url, lang=lang, client=client)
        return save_tweet(
            tweet,
            output_dir,
            with_media=with_media,
            overwrite=overwrite,
            client=client,
        )
