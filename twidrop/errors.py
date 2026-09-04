"""TwiDrop が投げる例外。"""


class TwiDropError(Exception):
    """すべての TwiDrop 例外の基底クラス。"""


class InvalidTweetURLError(TwiDropError):
    """ツイート URL として解釈できなかった。"""


class TweetNotFoundError(TwiDropError):
    """ツイートが削除済み・非公開・存在しないなどで取得できなかった。"""


class TweetFetchError(TwiDropError):
    """ネットワークや API 応答の問題で取得に失敗した。"""


class MediaDownloadError(TwiDropError):
    """メディアファイルのダウンロードに失敗した。"""
