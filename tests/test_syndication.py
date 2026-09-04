import httpx
import pytest

from twidrop.errors import TweetFetchError, TweetNotFoundError
from twidrop.syndication import (
    build_request_url,
    fetch_tweet_payload,
    make_token,
)


def _client(handler) -> httpx.Client:
    return httpx.Client(transport=httpx.MockTransport(handler))


def test_token_is_deterministic_and_url_safe():
    token = make_token("1362551461910114310")

    assert token == make_token("1362551461910114310")
    assert token.isalnum()
    assert "0" not in token and "." not in token


def test_different_ids_give_different_tokens():
    assert make_token("20") != make_token("21")


def test_build_request_url_contains_id_lang_and_token():
    url = build_request_url("20", lang="ja")

    assert "id=20" in url
    assert "lang=ja" in url
    assert f"token={make_token('20')}" in url


def test_fetch_returns_payload(video_payload):
    with _client(lambda request: httpx.Response(200, json=video_payload)) as client:
        assert fetch_tweet_payload("1234567890123456789", client=client) == video_payload


def test_tombstone_raises_not_found():
    tombstone = {
        "__typename": "TweetTombstone",
        "tombstone": {"text": {"text": "この投稿は削除されました"}},
    }
    with _client(lambda request: httpx.Response(200, json=tombstone)) as client:
        with pytest.raises(TweetNotFoundError, match="削除"):
            fetch_tweet_payload("20", client=client)


def test_html_response_raises_not_found():
    handler = lambda request: httpx.Response(200, text="<!DOCTYPE html><html></html>")
    with _client(handler) as client:
        with pytest.raises(TweetNotFoundError):
            fetch_tweet_payload("20", client=client)


def test_404_raises_not_found():
    with _client(lambda request: httpx.Response(404)) as client:
        with pytest.raises(TweetNotFoundError):
            fetch_tweet_payload("20", client=client)


def test_rate_limit_raises_fetch_error():
    with _client(lambda request: httpx.Response(429)) as client:
        with pytest.raises(TweetFetchError, match="レート制限"):
            fetch_tweet_payload("20", client=client)


def test_server_error_raises_fetch_error():
    with _client(lambda request: httpx.Response(503)) as client:
        with pytest.raises(TweetFetchError, match="503"):
            fetch_tweet_payload("20", client=client)


def test_network_failure_raises_fetch_error():
    def handler(request):
        raise httpx.ConnectError("boom", request=request)

    with _client(handler) as client:
        with pytest.raises(TweetFetchError):
            fetch_tweet_payload("20", client=client)
