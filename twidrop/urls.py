"""ツイート URL の解析。"""

from __future__ import annotations

import re
from urllib.parse import urlparse

from .errors import InvalidTweetURLError

#: ツイート URL として受け付けるホスト名。
ALLOWED_HOSTS = frozenset(
    {
        "twitter.com",
        "x.com",
        "mobile.twitter.com",
        "mobile.x.com",
        "www.twitter.com",
        "www.x.com",
        # よく使われるフロントエンド。ID の形式は本家と同じ。
        "fxtwitter.com",
        "vxtwitter.com",
        "fixupx.com",
        "nitter.net",
    }
)

_STATUS_PATH = re.compile(r"^/(?:i/web/)?(?:[A-Za-z0-9_]{1,15}/)?status(?:es)?/(\d{1,25})")
_BARE_ID = re.compile(r"^\d{1,25}$")


def extract_tweet_id(source: str) -> str:
    """ツイート URL（または ID そのもの）からツイート ID を取り出す。

    ``https://x.com/NASA/status/1362551461910114310?s=20`` のような
    クエリ付き URL、モバイル版ドメイン、``twitter.com`` / ``x.com``
    のどちらにも対応する。

    Raises:
        InvalidTweetURLError: ツイート URL として解釈できない場合。
    """
    text = (source or "").strip()
    if not text:
        raise InvalidTweetURLError("URL が空です。")

    if _BARE_ID.match(text):
        return text

    candidate = text if "://" in text else f"https://{text}"
    parsed = urlparse(candidate)
    host = (parsed.hostname or "").lower()
    if host not in ALLOWED_HOSTS:
        raise InvalidTweetURLError(
            f"対応していないドメインです: {host or text!r}（twitter.com / x.com の URL を指定してください）"
        )

    match = _STATUS_PATH.match(parsed.path)
    if not match:
        raise InvalidTweetURLError(
            f"ツイート URL ではありません: {text!r}（.../status/<数字> の形式が必要です）"
        )
    return match.group(1)


def canonical_url(tweet_id: str, screen_name: str | None = None) -> str:
    """ツイート ID から x.com の正規 URL を組み立てる。"""
    return f"https://x.com/{screen_name or 'i/web'}/status/{tweet_id}"
