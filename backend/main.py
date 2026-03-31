from __future__ import annotations

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field, model_validator

from config import settings
from services.vibe_court import (
    VibeCourtCase,
    VibeCourtCasePreview,
    VibeCourtResult,
    analyze_case,
    build_case_preview,
)

app = FastAPI(title="Vibe Court API", version="0.2.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=[o.strip() for o in settings.cors_origins.split(",") if o.strip()],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


class AnalyzeRequest(BaseModel):
    calendar_text: str | None = Field(default=None, max_length=12000)
    calendar_image_base64: str | None = Field(default=None, max_length=10_000_000)
    calendar_image_mime_type: str = Field(default="image/jpeg", max_length=100)
    recently_played_text: str | None = Field(default=None, max_length=12000)
    room_image_base64: str | None = Field(default=None, max_length=10_000_000)
    room_image_mime_type: str = Field(default="image/jpeg", max_length=100)

    @model_validator(mode="after")
    def validate_any_input(self) -> "AnalyzeRequest":
        if not any(
            [
                self.calendar_text and self.calendar_text.strip(),
                self.calendar_image_base64 and self.calendar_image_base64.strip(),
                self.recently_played_text and self.recently_played_text.strip(),
                self.room_image_base64 and self.room_image_base64.strip(),
            ]
        ):
            raise ValueError("At least one evidence input is required.")
        return self


class AnalyzeResponse(BaseModel):
    ok: bool
    preview: VibeCourtCasePreview
    result: VibeCourtResult | None = None
    error: str | None = None


@app.get("/api/health")
def health():
    return {"status": "ok", "product": "vibe-court"}


@app.post("/api/analyze", response_model=AnalyzeResponse)
def analyze(req: AnalyzeRequest):
    case = VibeCourtCase(
        calendar_text=(req.calendar_text or "").strip() or None,
        calendar_image_base64=(req.calendar_image_base64 or "").strip() or None,
        calendar_image_mime_type=req.calendar_image_mime_type,
        recently_played_text=(req.recently_played_text or "").strip() or None,
        room_image_base64=(req.room_image_base64 or "").strip() or None,
        room_image_mime_type=req.room_image_mime_type,
    )
    preview = build_case_preview(case)

    try:
        result = analyze_case(case)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e)) from e
    except RuntimeError as e:
        raise HTTPException(status_code=500, detail=str(e)) from e
    except Exception as e:
        raise HTTPException(status_code=502, detail=f"Analysis failed: {e!s}") from e

    return AnalyzeResponse(ok=True, preview=preview, result=result, error=None)
