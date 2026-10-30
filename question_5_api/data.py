"""Load the explicit R export; never silently substitute demonstration data."""
import os
from pathlib import Path

import pandas as pd

ROOT = Path(__file__).resolve().parents[1]
REQUIRED = {"USUBJID", "AESEV", "ACTARM", "AETERM", "AESOC"}


def load_data(path=None):
    path = Path(path or os.getenv("CLINICAL_DATA_PATH", ROOT / "data" / "adae.csv"))
    if not path.is_file():
        raise FileNotFoundError(f"Missing {path}. Run Rscript scripts/run_all.R first.")
    df = pd.read_csv(path, dtype="string", keep_default_na=False)
    if missing := REQUIRED - set(df.columns):
        raise ValueError(f"CSV is missing required columns: {sorted(missing)}")
    for column in REQUIRED:
        df[column] = df[column].str.strip()
    if df["USUBJID"].eq("").any():
        raise ValueError("USUBJID must be nonblank on every record")
    df["AESEV"] = df["AESEV"].str.upper()
    bad = set(df["AESEV"]) - {"MILD", "MODERATE", "SEVERE"}
    if bad:
        raise ValueError(f"Missing or unsupported AE severity: {sorted(bad)}")
    return df
