"""Run validation with logs, using either system R or the local Windows runtime."""
import os
from pathlib import Path
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]


def main():
    os.chdir(ROOT)
    out = ROOT / "outputs" / "validation"
    out.mkdir(parents=True, exist_ok=True)
    local_r = ROOT / ".tools/R/bin/R.exe"
    local_rs = ROOT / ".tools/R/bin/Rscript.exe"
    r = str(local_r) if local_r.exists() else shutil.which("R")
    rs = str(local_rs) if local_rs.exists() else shutil.which("Rscript")
    if not r or not rs:
        raise SystemExit("R is required. Install R >= 4.2 and add R/Rscript to PATH.")
    env = os.environ.copy()
    env["R_LIBS_USER"] = str(ROOT / ".Rlibrary")
    env["LANG"] = "C"
    env["LC_ALL"] = "C"
    env["_R_CHECK_FORCE_SUGGESTS_"] = "false"
    def run(name, command, cwd=ROOT):
        print(f"Running {name}", flush=True)
        result = subprocess.run(command, cwd=cwd, env=env, capture_output=True, text=True,
                                encoding="utf-8", errors="replace")
        (out / f"{name}.txt").write_text(result.stdout + result.stderr, encoding="utf-8")
        if result.returncode:
            raise SystemExit(f"{name} failed; see {out / (name + '.txt')}")
    run("r-pipeline", [rs, "scripts/run_all.R"])
    run("r-package-tests", [rs, "scripts/check_package.R"])
    run("r-clinical-tests", [rs, "tests/test_clinical.R"])
    run("r-package-build", [r, "CMD", "build", "--no-build-vignettes", "question_1/descriptive_stats"])
    run("r-package-check", [r, "CMD", "check", "--no-manual", "--no-vignettes",
                             "--no-build-vignettes", "descriptiveStats_1.0.0.tar.gz"])
    # The log directory already exists, including on a fresh checkout without .tools.
    run("python-tests", [sys.executable, "-m", "pytest", "-q",
                         f"--basetemp={out / 'pytest-temp'}",
                         "-o", f"cache_dir={out / 'pytest-cache'}"])
    run("api-smoke", [sys.executable, "-m", "scripts.smoke_api"])
    run("assistant-examples", [sys.executable, "-m", "question_6_genai.agent", "--mode", "mock"])
    print(f"All checks passed. Logs: {out}")


if __name__ == "__main__":
    main()
