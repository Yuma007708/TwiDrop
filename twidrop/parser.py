"""syndication API の JSON を :mod:`twidrop.models` のオブジェクトに変換する。"""

from __future__ import annotations

import html
import re
from datetime import datetime
from typing import Any, Iterable

from .models import Media, Tweet
from .urls import canonical_url

_TCO_TAIL = re.compile(r"\s*https://t\.co/\w+\s*$")


def _parse_datetime(raw: str | None) -> datetime | None:
    if not raw:
        return None
    try:
        return datetime.fromisoformat(raw.replace("Z", "+00:00"))
    except ValueError:
        return None


def clean_text(raw: str | None, *, strip_media_link: bool = True) -> str:
    """HTML エスケープを戻し、末尾のメディア用 t.co リンクを取り除く。"""
    text = html.unescape(raw or "")
    if strip_media_link:
        text = _TCO_TAIL.sub("", text)
    return text.strip()


def _original_photo_url(url: str) -> str:
    """pbs.twimg.com の画像 URL を原寸（``name=orig``）に書き換える。"""
    base = url.split("?", 1)[0]
    if base.endswith((".jpg", ".png", ".webp", ".gif")):
        return f"{base}?format={base.rsplit('.', 1)[1]}&name=orig"
    return f"{base}?name=orig"


def _best_video_variant(variants: Iterable[dict[str, Any]]) -> dict[str, Any] | None:
    """mp4 のうち最もビットレートの高いものを選ぶ（HLS は除外）。"""
    mp4s = [
        v
        for v in variants
        if str(v.get("content_type") or v.get("type") or "").startswith("video/mp4")
        and (v.get("url") or v.get("src"))
    ]
    if not mp4s:
        return None
    return max(mp4s, key=lambda v: int(v.get("bitrate") or 0))


def parse_media(payload: dict[str, Any]) -> list[Media]:
    """``mediaDetails`` から :class:`Media` のリストを作る。"""
    items: list[Media] = []
    for detail in payload.get("mediaDetails") or []:
        kind = detail.get("type")
        thumbnail = detail.get("media_url_https")
        original = (detail.get("original_info") or {})
        width = original.get("width")
        height = original.get("height")

        if kind == "photo":
            if not thumbnail:
                continue
            items.append(
                Media(
                    kind="photo",
                    url=_original_photo_url(thumbnail),
                    thumbnail_url=thumbnail,
                    width=width,
                    height=height,
                )
            )
            continue

        if kind in ("video", "animated_gif"):
            info = detail.get("video_info") or {}
            variant = _best_video_variant(info.get("variants") or [])
            if not variant:
                continue
            items.append(
                Media(
                    kind=kind,
                    url=variant.get("url") or variant.get("src"),
                    thumbnail_url=thumbnail,
                    width=width,
                    height=height,
                    duration_ms=info.get("duration_millis"),
                    bitrate=variant.get("bitrate"),
                )
            )
    return items


def parse_tweet(payload: dict[str, Any]) -> Tweet:
    """API のレスポンス全体を :class:`Tweet` に変換する。"""
    user = payload.get("user") or {}
    screen_name = user.get("screen_name") or "unknown"
    tweet_id = str(payload.get("id_str") or payload.get("id") or "")
    media = parse_media(payload)

    return Tweet(
        id=tweet_id,
        text=clean_text(payload.get("text"), strip_media_link=bool(media)),
        author_name=user.get("name") or screen_name,
        author_screen_name=screen_name,
        created_at=_parse_datetime(payload.get("created_at")),
        url=canonical_url(tweet_id, screen_name),
        like_count=payload.get("favorite_count"),
        reply_count=payload.get("conversation_count"),
        lang=payload.get("lang"),
        author_avatar_url=user.get("profile_image_url_https"),
        possibly_sensitive=bool(payload.get("possibly_sensitive")),
        media=media,
    )
