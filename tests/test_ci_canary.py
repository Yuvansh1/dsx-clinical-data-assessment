"""Temporary failing test to verify the CI failure-issue job. Remove after the check."""


def test_ci_canary_fails_on_purpose():
    assert False, "Intentional failure to exercise the report-failure CI job"
