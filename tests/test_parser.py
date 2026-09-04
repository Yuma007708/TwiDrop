from datetime import timezone

from twidrop.parser import clean_text, parse_media, parse_tweet


def test_parse_video_tweet_picks_highest_bitrate_mp4(video_payload):
    tweet = parse_tweet(video_payload)

    assert tweet.id == "1234567890123456789"
    assert tweet.author_screen_name == "test_user"
    assert tweet.author_name == "テスト太郎"
    assert tweet.like_count == 42
    assert tweet.reply_count == 7
    assert tweet.created_at is not None
    assert tweet.created_at.tzinfo == timezone.utc
    assert tweet.has_video is True

    assert len(tweet.media) == 1
    media = tweet.media[0]
    assert media.kind == "video"
    assert media.url.endswith("1280x720/high.mp4?tag=13")
    assert media.bitrate == 2176000
    assert media.duration_ms == 30000
    assert media.extension == ".mp4"


def test_media_tco_link_is_stripped_from_text(video_payload):
    assert parse_tweet(video_payload).text == "テスト投稿です"


def test_hls_only_video_is_skipped(video_payload):
    variants = video_payload["mediaDetails"][0]["video_info"]["variants"]
    video_payload["mediaDetails"][0]["video_info"]["variants"] = [
        v for v in variants if v["content_type"] == "application/x-mpegURL"
    ]
    assert parse_media(video_payload) == []


def test_parse_photo_tweet_uses_original_size(photo_payload):
    tweet = parse_tweet(photo_payload)

    assert tweet.has_video is False
    assert [m.kind for m in tweet.media] == ["photo", "photo"]
    assert tweet.media[0].url == "https://pbs.twimg.com/media/AAA.jpg?format=jpg&name=orig"
    assert tweet.media[0].thumbnail_url == "https://pbs.twimg.com/media/AAA.jpg"
    assert tweet.media[0].extension == ".jpg"
    assert tweet.media[1].extension == ".png"
    # HTML エスケープが戻り、末尾のメディアリンクが落ちている。
    assert tweet.text == "写真つき & テキスト"


def test_parse_text_only_tweet(text_payload):
    tweet = parse_tweet(text_payload)

    assert tweet.media == []
    assert tweet.has_video is False
    assert tweet.text == "ただのテキスト"
    assert tweet.url == "https://x.com/plain/status/111"
    assert tweet.slug == "plain_111"


def test_clean_text_keeps_links_when_no_media():
    text = "参考 https://t.co/abcd"
    assert clean_text(text, strip_media_link=False) == text
    assert clean_text(text, strip_media_link=True) == "参考"


def test_invalid_created_at_is_none(text_payload):
    text_payload["created_at"] = "not-a-date"
    assert parse_tweet(text_payload).created_at is None


def test_to_markdown_contains_media_and_metadata(video_payload):
    markdown = parse_tweet(video_payload).to_markdown()

    assert "@test_user (テスト太郎)" in markdown
    assert "テスト投稿です" in markdown
    assert "いいね: 42" in markdown
    assert "high.mp4" in markdown
