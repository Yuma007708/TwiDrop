import Foundation

/// テスト用の応答データ。
///
/// 実在ツイートの内容は使わず、API と同じ構造の合成データを組み立てている。
enum SampleResponses {
    static func videoTweet() -> Data { Data(videoTweetJSON.utf8) }
    static func photoTweet() -> Data { Data(photoTweetJSON.utf8) }
    static func textTweet() -> Data { Data(textTweetJSON.utf8) }
    static func tombstone() -> Data { Data(tombstoneJSON.utf8) }
    static func html() -> Data { Data("<!DOCTYPE html><html></html>".utf8) }

    static let videoTweetJSON = """
    {
      "__typename": "Tweet",
      "id_str": "1234567890123456789",
      "text": "テスト投稿です https://t.co/abcd1234",
      "lang": "ja",
      "created_at": "2024-05-01T12:34:56.000Z",
      "favorite_count": 42,
      "conversation_count": 7,
      "possibly_sensitive": false,
      "user": {
        "name": "テスト太郎",
        "screen_name": "test_user",
        "profile_image_url_https": "https://pbs.twimg.com/profile_images/1/avatar_normal.jpg"
      },
      "mediaDetails": [
        {
          "type": "video",
          "media_url_https": "https://pbs.twimg.com/amplify_video_thumb/1/img/thumb.jpg",
          "original_info": { "width": 1280, "height": 720 },
          "video_info": {
            "duration_millis": 75000,
            "variants": [
              {
                "content_type": "application/x-mpegURL",
                "url": "https://video.twimg.com/amplify_video/1/pl/playlist.m3u8"
              },
              {
                "bitrate": 288000,
                "content_type": "video/mp4",
                "url": "https://video.twimg.com/amplify_video/1/vid/480x270/low.mp4?tag=13"
              },
              {
                "bitrate": 2176000,
                "content_type": "video/mp4",
                "url": "https://video.twimg.com/amplify_video/1/vid/1280x720/high.mp4?tag=13"
              }
            ]
          }
        }
      ]
    }
    """

    static let photoTweetJSON = """
    {
      "__typename": "Tweet",
      "id_str": "999",
      "text": "写真つき &amp; テキスト https://t.co/zzzz",
      "created_at": "2024-01-02T03:04:05.000Z",
      "user": { "name": "Photo Bot", "screen_name": "photo_bot" },
      "mediaDetails": [
        {
          "type": "photo",
          "media_url_https": "https://pbs.twimg.com/media/AAA.jpg",
          "original_info": { "width": 1600, "height": 900 }
        },
        {
          "type": "photo",
          "media_url_https": "https://pbs.twimg.com/media/BBB.png",
          "original_info": { "width": 800, "height": 800 }
        }
      ]
    }
    """

    static let textTweetJSON = """
    {
      "__typename": "Tweet",
      "id_str": "111",
      "text": "ただのテキスト",
      "created_at": "2020-12-31T23:59:59.000Z",
      "user": { "name": "Plain", "screen_name": "plain" },
      "mediaDetails": []
    }
    """

    static let tombstoneJSON = """
    {
      "__typename": "TweetTombstone",
      "tombstone": { "text": { "text": "この投稿は削除されました" } }
    }
    """
}
