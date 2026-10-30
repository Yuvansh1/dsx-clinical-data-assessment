"""Exercise the API against the actual R export and save reproducible results."""
import json
from pathlib import Path

from fastapi.testclient import TestClient

from question_5_api.data import load_data
from question_5_api.main import app


def main():
    data = load_data()
    subject = str(data.USUBJID.iloc[0])
    arm = str(data.ACTARM.iloc[0])
    with TestClient(app) as client:
        welcome = client.get("/")
        assert welcome.status_code == 200
        cohort = client.post("/ae-query", json={}).json()
        assert cohort["count"] == len(data)
        assert len(cohort["subject_ids"]) == data.USUBJID.nunique()
        filtered = client.post("/ae-query", json={"severity": ["MILD", "MODERATE"],
                                                  "treatment_arm": arm}).json()
        expected = data[data.AESEV.isin(["MILD", "MODERATE"]) & data.ACTARM.eq(arm)]
        assert filtered["count"] == len(expected)
        assert filtered["subject_ids"] == sorted(expected.USUBJID.unique())
        risk = client.get(f"/subject-risk/{subject}").json()
        expected_score = data.loc[data.USUBJID.eq(subject), "AESEV"].map(
            {"MILD": 1, "MODERATE": 3, "SEVERE": 5}).sum()
        assert risk["risk_score"] == int(expected_score)
        assert client.get("/subject-risk/DOES-NOT-EXIST").status_code == 404
    result = {"welcome": welcome.json(), "all_record_count": cohort["count"],
              "all_subject_count": len(cohort["subject_ids"]), "filter_arm": arm,
              "filtered_record_count": filtered["count"], "subject_risk": risk}
    Path("outputs/api_smoke_results.json").write_text(json.dumps(result, indent=2), encoding="utf-8")
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
