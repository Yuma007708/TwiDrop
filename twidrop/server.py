"""TwiDrop の Web UI / JSON API（FastAPI）。"""

from __future__ import annotations

import asyncio
import os
from pathlib import Path
from typing import Any

from fastapi import FastAPI, HTTPException
from fastapi.responses import FileResponse
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel, Field

from . import __version__
from .downloader import save_tweet
from .errors import InvalidTweetURLError, TweetNotFoundError, TwiDropError
from .models import Tweet
from .service import DEFAULT_OUTPUT_DIR, get_tweet_async

STATIC_DIR = Path(__file__).parent / "static"


class TweetRequest(BaseModel):
    url: str = Field(..., description="ツイートの URL または ID")


class SaveRequest(TweetRequest):
    with_media: bool = Field(True, description="画像・動画も保存するか")
    overwrite: bool = Field(False, description="既存ファイルを上書きするか")


def _tweet_response(tweet: Tweet) -> dict[str, Any]:
    data = tweet.to_dict()
    data["has_video"] = tweet.has_video
    return data


def _to_http_error(exc: TwiDropError) -> HTTPException:
    if isinstance(exc, InvalidTweetURLError):
        return HTTPException(status_code=400, detail=str(exc))
    if isinstance(exc, TweetNotFoundError):
        return HTTPException(status_code=404, detail=str(exc))
    return HTTPException(status_code=502, detail=str(exc))


def create_app(output_dir: Path | str | None = None) -> FastAPI:
    """FastAPI アプリを生成する。

    保存先は引数 > 環境変数 ``TWIDROP_OUTPUT_DIR`` > ``downloads`` の順で決まる。
    """
    base_dir = Path(
        output_dir or os.environ.get("TWIDROP_OUTPUT_DIR") or DEFAULT_OUTPUT_DIR
    ).resolve()
    base_dir.mkdir(parents=True, exist_ok=True)

    app = FastAPI(title="TwiDrop", version=__version__)
    app.state.output_dir = base_dir

    @app.get("/api/health")
    async def health() -> dict[str, Any]:
        return {"status": "ok", "version": __version__, "output_dir": str(base_dir)}

    @app.post("/api/tweet")
    async def preview(request: TweetRequest) -> dict[str, Any]:
        """保存せずにツイート内容を取得する（プレビュー用）。"""
        try:
            tweet = await get_tweet_async(request.url)
        except TwiDropError as exc:
            raise _to_http_error(exc) from exc
        return _tweet_response(tweet)

    @app.post("/api/save")
    async def save(request: SaveRequest) -> dict[str, Any]:
        """ツイートを取得してサーバ上に保存する。"""
        try:
            tweet = await get_tweet_async(request.url)
            result = await asyncio.to_thread(
                save_tweet,
                tweet,
                base_dir,
                with_media=request.with_media,
                overwrite=request.overwrite,
            )
        except TwiDropError as exc:
            raise _to_http_error(exc) from exc

        return {
            "tweet": _tweet_response(result.tweet),
            "directory": str(result.directory),
            "files": [
                {
                    "name": path.name,
                    "size": path.stat().st_size,
                    "url": f"/files/{result.directory.name}/{path.name}",
                }
                for path in result.files
            ],
            "skipped": result.skipped,
        }

    @app.get("/api/saved")
    async def saved() -> dict[str, Any]:
        """保存済みツイートの一覧を新しい順で返す。"""
        entries = []
        for directory in sorted(
            (p for p in base_dir.iterdir() if p.is_dir()),
            key=lambda p: p.stat().st_mtime,
            reverse=True,
        ):
            files = sorted(p for p in directory.iterdir() if p.is_file())
            entries.append(
                {
                    "name": directory.name,
                    "saved_at": directory.stat().st_mtime,
                    "files": [
                        {
                            "name": f.name,
                            "size": f.stat().st_size,
                            "url": f"/files/{directory.name}/{f.name}",
                        }
                        for f in files
                    ],
                }
            )
        return {"items": entries}

    app.mount("/files", StaticFiles(directory=base_dir), name="files")
    app.mount("/static", StaticFiles(directory=STATIC_DIR), name="static")

    @app.get("/")
    async def index() -> FileResponse:
        return FileResponse(STATIC_DIR / "index.html")

    return app


app = create_app()


def run(host: str = "127.0.0.1", port: int = 8000, output_dir: Path | None = None) -> None:
    """開発用サーバを起動する。"""
    import uvicorn

    uvicorn.run(create_app(output_dir), host=host, port=port)
