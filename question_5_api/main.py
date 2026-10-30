"""Run from the repository root: uvicorn question_5_api.main:app --reload."""
from contextlib import asynccontextmanager
from typing import Literal

from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, ConfigDict, field_validator

from .data import load_data


class CohortQuery(BaseModel):
    model_config = ConfigDict(extra="forbid")
    severity: list[Literal["MILD", "MODERATE", "SEVERE"]] | None = None
    treatment_arm: str | None = None

    @field_validator("severity", mode="before")
    @classmethod
    def normalize_severity(cls, value):
        if isinstance(value, list):
            return [x.strip().upper() if isinstance(x, str) else x for x in value]
        return value

    @field_validator("treatment_arm")
    @classmethod
    def nonblank_arm(cls, value):
        if value is not None and not value.strip():
            raise ValueError("treatment_arm cannot be blank")
        return value.strip() if value is not None else None


class CohortResult(BaseModel):
    count: int
    subject_ids: list[str]


class RiskResult(BaseModel):
    subject_id: str
    risk_score: int
    risk_category: Literal["Low", "Medium", "High"]


def create_app(data_path=None):
    @asynccontextmanager
    async def lifespan(application):
        application.state.ae = load_data(data_path)
        yield

    application = FastAPI(title="Clinical Trial Data API", lifespan=lifespan)

    @application.get("/")
    def welcome():
        return {"message": "Clinical Trial Data API is running"}

    @application.post("/ae-query", response_model=CohortResult)
    def ae_query(query: CohortQuery):
        df = application.state.ae
        if query.severity is not None:
            df = df[df["AESEV"].isin(query.severity)]
        if query.treatment_arm is not None:
            df = df[df["ACTARM"].str.casefold().eq(query.treatment_arm.casefold())]
        return {"count": len(df), "subject_ids": sorted(df["USUBJID"].unique().tolist())}

    @application.get("/subject-risk/{subject_id}", response_model=RiskResult)
    def subject_risk(subject_id: str):
        df = application.state.ae
        events = df[df["USUBJID"].eq(subject_id)]
        if events.empty:
            raise HTTPException(404, "Subject not found in the AE dataset")
        score = int(events["AESEV"].map({"MILD": 1, "MODERATE": 3, "SEVERE": 5}).sum())
        category = "Low" if score < 5 else "Medium" if score < 15 else "High"
        return {"subject_id": subject_id, "risk_score": score, "risk_category": category}

    return application


app = create_app()
