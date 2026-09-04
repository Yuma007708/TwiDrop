"""x.com の公開 syndication エンドポイントからツイートを取得する。

埋め込みツイート（oEmbed）が使っているのと同じ公開 API を叩くため、
API キーや認証は不要。取得できるのは公開ツイートのみ。
"""

from __future__ import annotations

import math
from typing import Any

import httpx

from .errors import TweetFetchError, TweetNotFoundError

ENDPOINT = "https://cdn.syndication.twimg.com/tweet-result"

#: ブラウザからのアクセスに見せるための最低限のヘッダー。
DEFAULT_HEADERS = {
    "User-Agent": (
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 "
        "(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36"
    ),
    "Accept": "application/json",
}

_BASE36_DIGITS = "0123456789abcdefghijklmnopqrstuvwxyz"


def _to_base36(value: float, precision: int = 20) -> str:
    """浮動小数点数を 36 進数の文字列にする（JS の ``Number#toString(36)`` 相当）。"""
    integral = int(value)
    fraction = value - integral

    head = ""
    if integral == 0:
        head = "0"
    while integral > 0:
        head = _BASE36_DIGITS[integral % 36] + head
        integral //= 36

    tail = []
    for _ in range(precision):
        fraction *= 36
        digit = int(fraction)
        tail.append(_BASE36_DIGITS[digit])
        fraction -= digit
    return f"{head}.{''.join(tail)}"


def make_token(tweet_id: str) -> str:
    """エンドポイントが要求する ``token`` パラメータを組み立てる。

    公式の埋め込みスクリプトと同じ手順で、ツイート ID から決定的に導出する。
    """
    value = (int(tweet_id) / 1e15) * math.pi
    return _to_base36(value).replace("0", "").replace(".", "")


def build_request_url(tweet_id: str, lang: str = "ja") -> str:
    """取得用の URL を組み立てる。"""
    return f"{ENDPOINT}?id={tweet_id}&lang={lang}&token={make_token(tweet_id)}"


def _interpret(payload: Any, tweet_id: str) -> dict[str, Any]:
    """API のレスポンス本体を検証して辞書として返す。"""
    if not isinstance(payload, dict):
        raise TweetFetchError(f"想定外の応答形式です（ツイート ID: {tweet_id}）。")
    typename = payload.get("__typename")
    if typename == "TweetTombstone":
        reason = (
            payload.get("tombstone", {}).get("text", {}).get("text")
            or "削除済み、非公開、または年齢制限付きのツイートです。"
        )
        raise TweetNotFoundError(reason)
    if "id_str" not in payload and "text" not in payload:
        raise TweetNotFoundError(f"ツイートが見つかりませんでした（ID: {tweet_id}）。")
    return payload


def fetch_tweet_payload(
    tweet_id: str,
    *,
    lang: str = "ja",
    client: httpx.Client | None = None,
    timeout: float = 20.0,
) -> dict[str, Any]:
    """ツイートの生 JSON を同期取得する。"""
    url = build_request_url(tweet_id, lang=lang)
    owned = client is None
    http = client or httpx.Client(timeout=timeout, follow_redirects=True)
    try:
        response = http.get(url, headers=DEFAULT_HEADERS)
    except httpx.HTTPError as exc:
        raise TweetFetchError(f"ツイートの取得に失敗しました: {exc}") from exc
    finally:
        if owned:
            http.close()
    return _handle_response(response, tweet_id)


async def fetch_tweet_payload_async(
    tweet_id: str,
    *,
    lang: str = "ja",
    client: httpx.AsyncClient | None = None,
    timeout: float = 20.0,
) -> dict[str, Any]:
    """ツイートの生 JSON を非同期取得する。"""
    url = build_request_url(tweet_id, lang=lang)
    owned = client is None
    http = client or httpx.AsyncClient(timeout=timeout, follow_redirects=True)
    try:
        response = await http.get(url, headers=DEFAULT_HEADERS)
    except httpx.HTTPError as exc:
        raise TweetFetchError(f"ツイートの取得に失敗しました: {exc}") from exc
    finally:
        if owned:
            await http.aclose()
    return _handle_response(response, tweet_id)


def _handle_response(response: httpx.Response, tweet_id: str) -> dict[str, Any]:
    if response.status_code == 404:
        raise TweetNotFoundError(f"ツイートが見つかりませんでした（ID: {tweet_id}）。")
    if response.status_code == 429:
        raise TweetFetchError("レート制限に達しました。しばらく待ってから再試行してください。")
    if response.status_code >= 400:
        raise TweetFetchError(f"取得に失敗しました（HTTP {response.status_code}）。")
    try:
        payload = response.json()
    except ValueError as exc:
        # 非公開・削除済みのときは JSON ではなく HTML が返ることがある。
        raise TweetNotFoundError(
            f"ツイートを取得できませんでした（ID: {tweet_id}）。"
            "削除済み、非公開アカウント、または存在しない ID の可能性があります。"
        ) from exc
    return _interpret(payload, tweet_id)
