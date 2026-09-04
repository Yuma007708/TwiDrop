import httpx
import pytest
from fastapi.testclient import TestClient

from twidrop.errors import TweetFetchError, TweetNotFoundError
from twidrop.server import create_app


@pytest.fixture
def app_client(tmp_path, monkeypatch, video_payload):
    """ネットワークを叩かない TestClient。

    ツイート取得は合成 payload を返し、メディア取得はダミーバイト列にする。
    """

    async def fake_fetch(tweet_id, **kwargs):
        return video_payload

    monkeypatch.setattr(
        "twidrop.service.fetch_tweet_payload_async", fake_fetch, raising=True
    )

    real_client = httpx.Client
    transport = httpx.MockTransport(lambda request: httpx.Response(200, content=b"media"))

    def patched_client(*args, **kwargs):
        kwargs["transport"] = transport
        return real_client(*args, **kwargs)

    monkeypatch.setattr("twidrop.downloader.httpx.Client", patched_client)

    with TestClient(create_app(tmp_path)) as client:
        client.output_dir = tmp_path
        yield client


def test_health(app_client, tmp_path):
    response = app_client.get("/api/health")

    assert response.status_code == 200
    assert response.json()["status"] == "ok"
    assert response.json()["output_dir"] == str(tmp_path.resolve())


def test_index_serves_html(app_client):
    response = app_client.get("/")

    assert response.status_code == 200
    assert "TwiDrop" in response.text


def test_preview_returns_tweet(app_client):
    response = app_client.post(
        "/api/tweet", json={"url": "https://x.com/test_user/status/1234567890123456789"}
    )

    assert response.status_code == 200
    body = response.json()
    assert body["author_screen_name"] == "test_user"
    assert body["has_video"] is True
    assert body["media"][0]["url"].endswith("high.mp4?tag=13")


def test_preview_rejects_invalid_url(app_client):
    response = app_client.post("/api/tweet", json={"url": "https://example.com/x"})

    assert response.status_code == 400
    assert "対応していない" in response.json()["detail"]


def test_preview_missing_url_is_422(app_client):
    assert app_client.post("/api/tweet", json={}).status_code == 422


def test_save_writes_files_and_returns_links(app_client, tmp_path):
    response = app_client.post(
        "/api/save", json={"url": "https://x.com/test_user/status/1234567890123456789"}
    )

    assert response.status_code == 200
    body = response.json()
    names = [f["name"] for f in body["files"]]
    assert names == [
        "tweet.md",
        "tweet.json",
        "test_user_1234567890123456789_1.mp4",
    ]
    assert body["skipped"] == []
    for entry in body["files"]:
        assert entry["url"].startswith("/files/test_user_1234567890123456789/")
    assert (tmp_path / "test_user_1234567890123456789" / "tweet.json").exists()


def test_save_without_media(app_client, tmp_path):
    response = app_client.post(
        "/api/save",
        json={"url": "https://x.com/test_user/status/1234567890123456789", "with_media": False},
    )

    assert [f["name"] for f in response.json()["files"]] == ["tweet.md", "tweet.json"]


def test_saved_list_is_empty_then_populated(app_client):
    assert app_client.get("/api/saved").json()["items"] == []

    app_client.post(
        "/api/save", json={"url": "https://x.com/test_user/status/1234567890123456789"}
    )

    items = app_client.get("/api/saved").json()["items"]
    assert len(items) == 1
    assert items[0]["name"] == "test_user_1234567890123456789"
    assert len(items[0]["files"]) == 3


def test_saved_files_are_downloadable(app_client):
    saved = app_client.post(
        "/api/save", json={"url": "https://x.com/test_user/status/1234567890123456789"}
    ).json()
    target = next(f for f in saved["files"] if f["name"].endswith(".mp4"))

    response = app_client.get(target["url"])

    assert response.status_code == 200
    assert response.content == b"media"


def test_files_mount_blocks_path_traversal(app_client):
    response = app_client.get("/files/../../etc/passwd")

    assert response.status_code == 404


def test_not_found_tweet_returns_404(app_client, monkeypatch):
    async def missing(tweet_id, **kwargs):
        raise TweetNotFoundError("削除済みのツイートです")

    monkeypatch.setattr("twidrop.service.fetch_tweet_payload_async", missing)

    response = app_client.post("/api/tweet", json={"url": "https://x.com/a/status/1"})

    assert response.status_code == 404
    assert response.json()["detail"] == "削除済みのツイートです"


def test_upstream_failure_returns_502(app_client, monkeypatch):
    async def failing(tweet_id, **kwargs):
        raise TweetFetchError("レート制限に達しました。")

    monkeypatch.setattr("twidrop.service.fetch_tweet_payload_async", failing)

    response = app_client.post("/api/tweet", json={"url": "https://x.com/a/status/1"})

    assert response.status_code == 502
