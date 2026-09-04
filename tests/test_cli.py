import pytest

from twidrop.cli import main
from twidrop.errors import TweetNotFoundError
from twidrop.parser import parse_tweet


@pytest.fixture
def stub_fetch(monkeypatch, video_payload):
    monkeypatch.setattr(
        "twidrop.service.fetch_tweet_payload", lambda tweet_id, **kw: video_payload
    )
    return video_payload


def test_info_prints_tweet_without_saving(stub_fetch, capsys, tmp_path):
    code = main(["--info", "https://x.com/test_user/status/1234567890123456789"])
    out = capsys.readouterr().out

    assert code == 0
    assert "@test_user (テスト太郎)" in out
    assert "high.mp4" in out
    assert list(tmp_path.iterdir()) == []


def test_save_writes_files(stub_fetch, monkeypatch, tmp_path, capsys):
    monkeypatch.setattr(
        "twidrop.downloader.download_media",
        lambda media, destination, **kw: (destination.write_bytes(b"x"), destination)[1],
    )

    code = main(["-o", str(tmp_path), "https://x.com/test_user/status/1234567890123456789"])
    out = capsys.readouterr().out

    assert code == 0
    assert "保存しました" in out
    directory = tmp_path / "test_user_1234567890123456789"
    assert (directory / "tweet.md").exists()
    assert (directory / "test_user_1234567890123456789_1.mp4").exists()


def test_no_media_flag(stub_fetch, tmp_path):
    main(["-o", str(tmp_path), "--no-media", "https://x.com/test_user/status/1234567890123456789"])

    directory = tmp_path / "test_user_1234567890123456789"
    assert sorted(p.name for p in directory.iterdir()) == ["tweet.json", "tweet.md"]


def test_invalid_url_reports_error(capsys):
    code = main(["--info", "https://example.com/nope"])

    assert code == 1
    assert "エラー" in capsys.readouterr().err


def test_missing_tweet_reports_error(monkeypatch, capsys):
    def missing(tweet_id, **kwargs):
        raise TweetNotFoundError("削除済みです")

    monkeypatch.setattr("twidrop.service.fetch_tweet_payload", missing)

    code = main(["--info", "https://x.com/a/status/1"])

    assert code == 1
    assert "削除済みです" in capsys.readouterr().err


def test_no_arguments_shows_help(capsys):
    assert main([]) == 2
    assert "usage" in capsys.readouterr().out.lower()
