from __future__ import annotations

import base64
import json
from typing import Any

from openai import OpenAI
from pydantic import BaseModel, Field

from config import settings


class VibeCourtCase(BaseModel):
    calendar_text: str | None = None
    calendar_image_base64: str | None = None
    calendar_image_mime_type: str = "image/jpeg"
    recently_played_text: str | None = None
    room_image_base64: str | None = None
    room_image_mime_type: str = "image/jpeg"


class VibeCourtCasePreview(BaseModel):
    evidence_types: list[str]
    calendar_excerpt: str | None = None
    calendar_photo_attached: bool
    recently_played_excerpt: str | None = None
    room_photo_attached: bool


class ChargeItem(BaseModel):
    title: str
    detail: str
    severity: int = Field(ge=1, le=10)


class ScoreCard(BaseModel):
    chaos: int = Field(ge=0, le=100)
    taste: int = Field(ge=0, le=100)
    discipline: int = Field(ge=0, le=100)
    main_character: int = Field(ge=0, le=100)


class VibeCourtResult(BaseModel):
    case_title: str
    one_liner: str
    summary: str
    charges: list[ChargeItem]
    evidence: list[str]
    verdict: str
    sentence: str
    scores: ScoreCard
    recommendation: str


def build_case_preview(case: VibeCourtCase) -> VibeCourtCasePreview:
    evidence_types: list[str] = []
    if case.calendar_text:
        evidence_types.append("calendar")
    if case.calendar_image_base64:
        evidence_types.append("calendar_photo")
    if case.recently_played_text:
        evidence_types.append("recently_played")
    if case.room_image_base64:
        evidence_types.append("room_photo")

    return VibeCourtCasePreview(
        evidence_types=evidence_types,
        calendar_excerpt=_excerpt(case.calendar_text),
        calendar_photo_attached=bool(case.calendar_image_base64),
        recently_played_excerpt=_excerpt(case.recently_played_text),
        room_photo_attached=bool(case.room_image_base64),
    )


def analyze_case(case: VibeCourtCase) -> VibeCourtResult:
    if not settings.openai_api_key:
        raise RuntimeError("OPENAI_API_KEY is not set.")

    if not any(
        [
            case.calendar_text,
            case.calendar_image_base64,
            case.recently_played_text,
            case.room_image_base64,
        ]
    ):
        raise ValueError("No evidence supplied.")

    client = OpenAI(api_key=settings.openai_api_key)
    content: list[dict[str, Any]] = [
        {
            "type": "text",
            "text": _build_user_prompt(case),
        }
    ]

    if case.room_image_base64:
        mime_type = case.room_image_mime_type or "image/jpeg"
        normalized = _normalize_base64(case.room_image_base64)
        content.append(
            {
                "type": "image_url",
                "image_url": {
                    "url": f"data:{mime_type};base64,{normalized}",
                },
            }
        )

    if case.calendar_image_base64:
        mime_type = case.calendar_image_mime_type or "image/jpeg"
        normalized = _normalize_base64(case.calendar_image_base64)
        content.append(
            {
                "type": "image_url",
                "image_url": {
                    "url": f"data:{mime_type};base64,{normalized}",
                },
            }
        )

    response = client.chat.completions.create(
        model=settings.openai_model,
        temperature=0.9,
        response_format={"type": "json_object"},
        messages=[
            {
                "role": "system",
                "content": (
                    "You are Vibe Court, a witty but fair judge. "
                    "Analyze only the provided evidence. Be funny, specific, and premium-feeling. "
                    "Do not be cruel, hateful, sexual, or invasive. "
                    "Return valid JSON only."
                ),
            },
            {
                "role": "user",
                "content": content,
            },
        ],
    )
    raw = response.choices[0].message.content or "{}"
    data = json.loads(raw)
    return VibeCourtResult.model_validate(_coerce_result(data))


def _build_user_prompt(case: VibeCourtCase) -> str:
    parts = [
        "Create a courtroom-style roast and analysis for this person.",
        "The output must feel sharp, premium, and screenshot-worthy.",
        "Ground every joke in the evidence, then end with one genuinely useful recommendation.",
        "Return JSON with these keys exactly:",
        (
            "case_title, one_liner, summary, charges, evidence, verdict, sentence, "
            "scores, recommendation"
        ),
        "charges must be an array of objects with title, detail, severity.",
        "evidence must be an array of short bullet-style strings.",
        "scores must be an object with chaos, taste, discipline, main_character as integers 0-100.",
    ]

    if case.calendar_text:
        parts.extend(
            [
                "",
                "[Calendar Evidence]",
                case.calendar_text,
            ]
        )

    if case.calendar_image_base64:
        parts.extend(
            [
                "",
                "[Calendar Screenshot Evidence]",
                "A calendar screenshot is attached. Infer scheduling density, timing habits, and visible patterns.",
            ]
        )

    if case.recently_played_text:
        parts.extend(
            [
                "",
                "[Recently Played Evidence]",
                case.recently_played_text,
            ]
        )

    if case.room_image_base64:
        parts.extend(
            [
                "",
                "[Room Photo Evidence]",
                "A room photo is attached. Inspect decor, organization, mood, and contradictions.",
            ]
        )

    return "\n".join(parts)


def _normalize_base64(value: str) -> str:
    candidate = value.strip()
    if "," in candidate and candidate.lower().startswith("data:"):
        candidate = candidate.split(",", 1)[1]
    try:
        base64.b64decode(candidate, validate=True)
    except Exception as exc:  # pragma: no cover - defensive branch
        raise ValueError("Room image must be valid base64 data.") from exc
    return candidate


def _excerpt(value: str | None, limit: int = 220) -> str | None:
    if not value:
        return None
    trimmed = value.strip()
    if len(trimmed) <= limit:
        return trimmed
    return f"{trimmed[:limit].rstrip()}..."


def _coerce_result(data: dict[str, Any]) -> dict[str, Any]:
    return {
        "case_title": str(data.get("case_title") or "The People v. Your Vibe"),
        "one_liner": str(data.get("one_liner") or "This court has concerns."),
        "summary": str(data.get("summary") or "The submitted evidence paints a vivid picture."),
        "charges": _coerce_charges(data.get("charges")),
        "evidence": _coerce_evidence(data.get("evidence")),
        "verdict": str(data.get("verdict") or "Mildly guilty with style."),
        "sentence": str(data.get("sentence") or "Take one deep breath and reorganize something small."),
        "scores": _coerce_scores(data.get("scores")),
        "recommendation": str(
            data.get("recommendation")
            or "Trim one source of chaos and keep one signature style choice."
        ),
    }


def _coerce_charges(value: Any) -> list[dict[str, Any]]:
    if isinstance(value, list) and value:
        items: list[dict[str, Any]] = []
        for item in value[:4]:
            if isinstance(item, dict):
                items.append(
                    {
                        "title": str(item.get("title") or "Suspicious behavior"),
                        "detail": str(item.get("detail") or "The court requests clarification."),
                        "severity": _clamp_int(item.get("severity"), 5, 1, 10),
                    }
                )
        if items:
            return items
    return [
        {
            "title": "Excessive vibe projection",
            "detail": "The evidence suggests a carefully curated level of chaos.",
            "severity": 6,
        }
    ]


def _coerce_evidence(value: Any) -> list[str]:
    if isinstance(value, list):
        cleaned = [str(item) for item in value if str(item).strip()]
        if cleaned:
            return cleaned[:6]
    return ["The submitted materials consistently point to a dramatic but salvageable situation."]


def _coerce_scores(value: Any) -> dict[str, int]:
    source = value if isinstance(value, dict) else {}
    return {
        "chaos": _clamp_int(source.get("chaos"), 62, 0, 100),
        "taste": _clamp_int(source.get("taste"), 71, 0, 100),
        "discipline": _clamp_int(source.get("discipline"), 44, 0, 100),
        "main_character": _clamp_int(source.get("main_character"), 80, 0, 100),
    }


def _clamp_int(value: Any, fallback: int, lower: int, upper: int) -> int:
    try:
        parsed = int(value)
    except (TypeError, ValueError):
        return fallback
    return max(lower, min(upper, parsed))
