import json

import httpx
import pytest

from twidrop.downloader import (
    download_media,
    media_filename,
    safe_name,
    save_tweet,
)
from twidrop.errors import MediaDownloadError
from twidrop.models import Media
from twidrop.parser import parse_tweet

VIDEO_BYTES = b"fake-mp4-bytes" * 100


def _client(handler) -> httpx.Client:
    return httpx.Client(transport=httpx.MockTransport(handler))


def _ok(request: httpx.Request) -> httpx.Response:
    return httpx.Response(200, content=VIDEO_BYTES)


@pytest.mark.parametrize(
    ("value", "expected"),
    [
        ("NASA_123", "NASA_123"),
        ("../../etc/passwd", "etc_passwd"),
        ("ユーザー_1", "1"),
        ("a/b\\c", "a_b_c"),
        ("", "tweet"),
    ],
)
def test_safe_name(value, expected):
    assert safe_name(value) == expected


def test_media_filename_uses_slug_index_and_extension(video_payload):
    tweet = parse_tweet(video_payload)
    assert (
        media_filename(tweet, tweet.media[0], 1) == "test_user_1234567890123456789_1.mp4"
    )


def test_download_media_writes_file(tmp_path, video_payload):
    media = parse_tweet(video_payload).media[0]
    target = tmp_path / "video.mp4"

    with _client(_ok) as client:
        assert download_media(media, target, client=client) == target
    assert target.read_bytes() == VIDEO_BYTES
    # 一時ファイルは残らない。
    assert list(tmp_path.glob("*.part")) == []


def test_download_media_skips_existing_file(tmp_path, video_payload):
    media = parse_tweet(video_payload).media[0]
    target = tmp_path / "video.mp4"
    target.write_bytes(b"existing")

    def fail(request):  # pragma: no cover - 呼ばれないことが期待値
        raise AssertionError("既存ファイルがあるのに再取得された")

    with _client(fail) as client:
        download_media(media, target, client=client)
    assert target.read_bytes() == b"existing"


def test_download_media_overwrite(tmp_path, video_payload):
    media = parse_tweet(video_payload).media[0]
    target = tmp_path / "video.mp4"
    target.write_bytes(b"existing")

    with _client(_ok) as client:
        download_media(media, target, client=client, overwrite=True)
    assert target.read_bytes() == VIDEO_BYTES


def test_download_media_rejects_unknown_host(tmp_path):
    media = Media(kind="video", url="https://evil.example.com/payload.mp4")

    with pytest.raises(MediaDownloadError, match="許可されていない"):
        download_media(media, tmp_path / "x.mp4")
    assert not (tmp_path / "x.mp4").exists()


def test_download_media_http_error_leaves_no_partial_file(tmp_path, video_payload):
    media = parse_tweet(video_payload).media[0]
    target = tmp_path / "video.mp4"

    with _client(lambda request: httpx.Response(403)) as client:
        with pytest.raises(MediaDownloadError, match="403"):
            download_media(media, target, client=client)
    assert not target.exists()


def test_save_tweet_writes_text_json_and_media(tmp_path, video_payload):
    tweet = parse_tweet(video_payload)

    with _client(_ok) as client:
        result = save_tweet(tweet, tmp_path, client=client)

    assert result.directory == tmp_path / "test_user_1234567890123456789"
    assert result.text_file.read_text(encoding="utf-8").startswith("# @test_user")
    saved = json.loads(result.json_file.read_text(encoding="utf-8"))
    assert saved["id"] == "1234567890123456789"
    assert saved["media"][0]["kind"] == "video"
    assert [p.name for p in result.media_files] == ["test_user_1234567890123456789_1.mp4"]
    assert result.skipped == []
    assert len(result.files) == 3


def test_save_tweet_without_media(tmp_path, video_payload):
    tweet = parse_tweet(video_payload)

    result = save_tweet(tweet, tmp_path, with_media=False)

    assert result.media_files == []
    assert result.json_file.exists()


def test_save_tweet_records_failed_media_but_keeps_text(tmp_path, photo_payload):
    tweet = parse_tweet(photo_payload)

    def one_fails(request: httpx.Request) -> httpx.Response:
        return httpx.Response(500 if "BBB" in str(request.url) else 200, content=b"img")

    with _client(one_fails) as client:
        result = save_tweet(tweet, tmp_path, client=client)

    assert len(result.media_files) == 1
    assert len(result.skipped) == 1
    assert "BBB" in result.skipped[0]
    assert result.text_file.exists()
