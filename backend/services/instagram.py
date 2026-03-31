"""공개 프로필 메타데이터 수집 (instaloader). 실패 시 None."""

from __future__ import annotations

from dataclasses import dataclass

import instaloader


@dataclass
class InstagramPublicSnapshot:
    username: str
    full_name: str
    biography: str
    followers: int
    followees: int
    is_private: bool
    is_verified: bool
    external_url: str | None
    post_count: int
    recent_captions: list[str]


def fetch_public_profile(username: str, max_posts: int = 12) -> InstagramPublicSnapshot | None:
    username = username.strip().lstrip("@")
    if not username:
        return None

    loader = instaloader.Instaloader(
        download_pictures=False,
        download_videos=False,
        download_video_thumbnails=False,
        download_geotags=False,
        download_comments=False,
        save_metadata=False,
        compress_json=False,
    )

    try:
        profile = instaloader.Profile.from_username(loader.context, username)
    except Exception:
        return None

    if profile.is_private:
        return InstagramPublicSnapshot(
            username=profile.username,
            full_name=profile.full_name or "",
            biography=profile.biography or "",
            followers=profile.followers,
            followees=profile.followees,
            is_private=True,
            is_verified=profile.is_verified,
            external_url=profile.external_url,
            post_count=profile.mediacount,
            recent_captions=[],
        )

    captions: list[str] = []
    try:
        for i, post in enumerate(profile.get_posts()):
            if i >= max_posts:
                break
            cap = post.caption or ""
            if cap.strip():
                captions.append(cap.strip())
    except Exception:
        pass

    return InstagramPublicSnapshot(
        username=profile.username,
        full_name=profile.full_name or "",
        biography=profile.biography or "",
        followers=profile.followers,
        followees=profile.followees,
        is_private=False,
        is_verified=profile.is_verified,
        external_url=profile.external_url,
        post_count=profile.mediacount,
        recent_captions=captions,
    )
