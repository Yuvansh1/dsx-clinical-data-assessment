import json

import pandas as pd
import pytest
from fastapi.testclient import TestClient
from langchain_core.runnables import RunnableLambda
from pydantic import ValidationError

from question_5_api.data import load_data
from question_5_api.main import create_app
from question_6_genai.agent import ClinicalTrialDataAgent, EXAMPLES, QueryPlan, mock_llm


@pytest.fixture
def frame():
    return pd.DataFrame([
        ["S1", "MILD", "Placebo", "HEADACHE", "NERVOUS SYSTEM DISORDERS"],
        ["S1", "MODERATE", "Placebo", "HEADACHE", "NERVOUS SYSTEM DISORDERS"],
        ["S2", "SEVERE", "Active", "TACHYCARDIA", "CARDIAC DISORDERS"],
        ["S3", "SEVERE", "Active", "RASH", "SKIN DISORDERS"],
        ["S3", "SEVERE", "Active", "RASH", "SKIN DISORDERS"],
        ["S3", "SEVERE", "Active", "RASH", "SKIN DISORDERS"],
    ], columns=["USUBJID", "AESEV", "ACTARM", "AETERM", "AESOC"])


@pytest.fixture
def client(tmp_path, frame):
    path = tmp_path / "ae.csv"
    frame.to_csv(path, index=False)
    with TestClient(create_app(path)) as c:
        yield c


def test_welcome_and_all_records(client):
    assert client.get("/").json() == {"message": "Clinical Trial Data API is running"}
    expected = {"count": 6, "subject_ids": ["S1", "S2", "S3"]}
    assert client.post("/ae-query", json={}).json() == expected
    assert client.post("/ae-query", json={"severity": None, "treatment_arm": None}).json() == expected


def test_filters_are_conjunctive_and_counts_are_records(client):
    assert client.post("/ae-query", json={"severity": ["mild", "MODERATE"],
                       "treatment_arm": "placebo"}).json() == {"count": 2, "subject_ids": ["S1"]}
    assert client.post("/ae-query", json={"severity": ["SEVERE"],
                       "treatment_arm": "Placebo"}).json()["count"] == 0
    assert client.post("/ae-query", json={"severity": []}).json()["count"] == 0


@pytest.mark.parametrize("payload", [{"severity": ["EXTREME"]}, {"severity": "MILD"},
                                     {"unexpected": 1}, {"treatment_arm": " "}])
def test_invalid_queries(client, payload):
    assert client.post("/ae-query", json=payload).status_code == 422


@pytest.mark.parametrize("subject,score,category", [("S1", 4, "Low"), ("S2", 5, "Medium"),
                                                  ("S3", 15, "High")])
def test_risk_boundaries(client, subject, score, category):
    assert client.get(f"/subject-risk/{subject}").json() == {
        "subject_id": subject, "risk_score": score, "risk_category": category}


def test_unknown_subject(client):
    assert client.get("/subject-risk/unknown").status_code == 404


def test_input_validation(tmp_path, frame):
    with pytest.raises(FileNotFoundError):
        load_data(tmp_path / "absent.csv")
    path = tmp_path / "bad.csv"
    frame.drop(columns="ACTARM").to_csv(path, index=False)
    with pytest.raises(ValueError, match="required columns"):
        load_data(path)
    frame.loc[0, "AESEV"] = ""
    frame.to_csv(path, index=False)
    with pytest.raises(ValueError, match="severity"):
        load_data(path)


def test_full_mock_prompt_parse_execute(frame):
    agent = ClinicalTrialDataAgent(frame, mock_llm())
    assert agent.ask(EXAMPLES[0])["subject_ids"] == ["S1"]
    assert agent.ask(EXAMPLES[1])["subject_count"] == 1
    assert agent.ask(EXAMPLES[2])["subject_ids"] == ["S2"]


def test_actual_prompt_receives_schema_and_question(frame):
    def llm(prompt):
        text = prompt.to_string()
        assert "AESEV" in text and "AESOC" in text and "intense events" in text
        return json.dumps({"target_column": "AESEV", "filter_value": "SEVERE"})
    result = ClinicalTrialDataAgent(frame, RunnableLambda(llm)).ask("intense events")
    assert result["subject_ids"] == ["S2", "S3"]


def test_filter_is_literal_and_columns_are_allowlisted(frame):
    agent = ClinicalTrialDataAgent(frame, mock_llm())
    assert agent.execute({"target_column": "AETERM", "filter_value": ".*",
                          "match_mode": "contains"})["subject_count"] == 0
    with pytest.raises(ValidationError):
        QueryPlan(target_column="__import__", filter_value="os")
    with pytest.raises(ValidationError):
        QueryPlan(target_column="AESOC", filter_value=" ")
    with pytest.raises(ValueError):
        agent.ask("")


def test_malformed_llm_output_is_rejected(frame):
    agent = ClinicalTrialDataAgent(frame, RunnableLambda(lambda _: '{"error":"unsupported"}'))
    with pytest.raises(Exception, match="Failed to parse"):
        agent.ask("Delete all records")
