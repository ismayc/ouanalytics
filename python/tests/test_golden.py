"""The acceptance tests: Python recomputes every golden case and matches R."""

from __future__ import annotations

import pytest

from ouanalytics_py.cli import main
from ouanalytics_py.compare import compare_case
from ouanalytics_py.validate import validate_case

from conftest import ALL_CASES, GOLDEN, POOL_CASES, SEEDING_CASES


@pytest.mark.parametrize("case", ALL_CASES)
def test_case_matches_r(case):
    results = compare_case(GOLDEN / case)
    failures = [line for r in results if not r.ok for line in r.lines()]
    assert results, "no tables compared"
    assert not failures, "\n".join(failures)


@pytest.mark.parametrize("case", ALL_CASES)
def test_case_passes_validation(case):
    failures = [line for r in validate_case(GOLDEN / case) if not r.ok for line in r.lines()]
    assert not failures, "\n".join(failures)


def test_cli_all_cases_exit_zero(capsys):
    assert main([str(GOLDEN / c) for c in ALL_CASES]) == 0
    out = capsys.readouterr().out
    assert "FAIL" not in out
    assert out.strip().endswith("all cases match")
    # a pool case prints 11 tables and 5 validations; a seeding case 1 and 4
    assert out.count(": ok") == len(POOL_CASES) * (11 + 5) + len(SEEDING_CASES) * (1 + 4)
