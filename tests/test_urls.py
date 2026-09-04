import pytest

from twidrop.errors import InvalidTweetURLError
from twidrop.urls import canonical_url, extract_tweet_id


@pytest.mark.parametrize(
    ("source", "expected"),
    [
        ("https://x.com/NASA/status/1362551461910114310", "1362551461910114310"),
        ("https://twitter.com/jack/status/20", "20"),
        ("https://twitter.com/jack/status/20?s=20&t=abc", "20"),
        ("https://mobile.twitter.com/i/web/status/123456", "123456"),
        ("http://www.x.com/user/statuses/777", "777"),
        ("x.com/user/status/888", "888"),
        ("  https://x.com/user/status/999/photo/1  ", "999"),
        ("https://fxtwitter.com/user/status/555", "555"),
        ("1362551461910114310", "1362551461910114310"),
    ],
)
def test_extract_tweet_id(source, expected):
    assert extract_tweet_id(source) == expected


@pytest.mark.parametrize(
    "source",
    [
        "",
        "   ",
        "https://example.com/user/status/1",
        "https://x.com/NASA",
        "https://x.com/NASA/status/abc",
        "ただの文字列",
    ],
)
def test_extract_tweet_id_rejects_bad_input(source):
    with pytest.raises(InvalidTweetURLError):
        extract_tweet_id(source)


def test_canonical_url():
    assert canonical_url("20", "jack") == "https://x.com/jack/status/20"
    assert canonical_url("20") == "https://x.com/i/web/status/20"
