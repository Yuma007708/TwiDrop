"""ツイートとメディアを表すデータモデル。"""

from __future__ import annotations

from dataclasses import asdict, dataclass, field
from datetime import datetime
from typing import Any, Literal

MediaKind = Literal["photo", "video", "animated_gif"]


@dataclass(frozen=True)
class Media:
    """ツイートに添付された 1 件のメディア。"""

    kind: MediaKind
    #: 実際にダウンロードする URL（画像は原寸、動画は最高画質の mp4）。
    url: str
    #: サムネイル / ポスター画像。画像メディアでは ``url`` と同じになることがある。
    thumbnail_url: str | None = None
    width: int | None = None
    height: int | None = None
    duration_ms: int | None = None
    bitrate: int | None = None

    @property
    def extension(self) -> str:
        """保存時の拡張子（``.mp4`` など、ドット付き）。"""
        path = self.url.split("?", 1)[0]
        _, _, tail = path.rpartition("/")
        if "." in tail:
            return "." + tail.rsplit(".", 1)[1].lower()
        return ".mp4" if self.kind != "photo" else ".jpg"

    def to_dict(self) -> dict[str, Any]:
        return asdict(self)


@dataclass(frozen=True)
class Tweet:
    """1 件のツイート。"""

    id: str
    text: str
    author_name: str
    author_screen_name: str
    created_at: datetime | None = None
    url: str = ""
    like_count: int | None = None
    reply_count: int | None = None
    lang: str | None = None
    author_avatar_url: str | None = None
    possibly_sensitive: bool = False
    media: list[Media] = field(default_factory=list)

    @property
    def has_video(self) -> bool:
        return any(m.kind in ("video", "animated_gif") for m in self.media)

    @property
    def slug(self) -> str:
        """保存ディレクトリ名に使う識別子。"""
        return f"{self.author_screen_name}_{self.id}"

    def to_dict(self) -> dict[str, Any]:
        data = asdict(self)
        data["created_at"] = self.created_at.isoformat() if self.created_at else None
        return data

    def to_markdown(self) -> str:
        """ツイート本文を人が読める Markdown に整形する。"""
        when = self.created_at.strftime("%Y-%m-%d %H:%M:%S %Z").strip() if self.created_at else "不明"
        lines = [
            f"# @{self.author_screen_name} ({self.author_name})",
            "",
            f"- 投稿日時: {when}",
            f"- URL: {self.url}",
        ]
        if self.like_count is not None:
            lines.append(f"- いいね: {self.like_count}")
        if self.reply_count is not None:
            lines.append(f"- 返信: {self.reply_count}")
        lines += ["", "---", "", self.text, ""]
        if self.media:
            lines += ["", "## 添付メディア", ""]
            for index, item in enumerate(self.media, start=1):
                lines.append(f"{index}. [{item.kind}] {item.url}")
            lines.append("")
        return "\n".join(lines)
