# ouanalytics-py

<img src="branding/logo.png" align="right" height="139" alt="ouanalytics-py hex sticker: a basketball on a see-saw">

A second, independent implementation of the R package `ouanalytics`
(`../r/`), written in Python with polars. It recomputes every table
that R writes for a golden case and reports any difference, so the two
implementations check each other. The R source is the specification.

Modules (`src/ouanalytics_py/`):

- `standings.py`: the pool calculations (`standings_logic.R`, `pool.R`), one
  function per R function, plus `compute_pool()`.
- `seeding.py`: the NBA tie-break procedure (`seeding.R`).
- `io.py`: reads a case folder (`inputs/*.csv`, `outputs/*.csv`); writes nothing.
- `compare.py`: recomputes a case and compares it with R's outputs.
- `validate.py`: data checks that need no R (listed in its docstring).
- `cli.py`: the `ouanalytics-check` command.

## Install

```sh
cd ouanalytics-py
uv sync            # creates .venv with polars, pytest, and pytest-cov
```

Requires Python 3.11 or later and polars 2.0 or later.

## Test

```sh
uv run pytest
```

Coverage is enforced at 100% of lines and branches (`pyproject.toml`). The
golden tests (`tests/test_golden.py`) recompute each case in `../golden/`
and must match R. `tests/test_failures.py` breaks copies of the cases (a
changed number, a dropped column, a duplicated pick, a broken seed order) and
checks that the command fails with a useful message.

## Check cases from the command line

```sh
uv run ouanalytics-check ../golden/*
```

For each case folder, it prints one line per table (`ok`, or the first 5
differing rows with the Python and R values) and one `validate:` line per
data check. It exits 1 on any difference or violation, and 0 when everything
matches. A folder is a pool case when `inputs/` holds `game_results_raw`,
`scores`, `projections`, `picks`, `standings`, and `params`, and a seeding
case when it holds `meta`, `standings`, and `scores_tidy`.

Comparison rules: the same column names in the same order, the same row
count, numbers equal within 1e-9 (relative and absolute), NA equal to NA, and
exact equality for everything else. Seeding rows must match in order. Pool
tables are compared after sorting both sides by every column.

## Rounding and division: what is guarded, and what is not

- `round()`: R 4.x rounds to the nearer of the two 2-decimal neighbors and
  breaks exact ties to even (`round(3.125, 2)` is 3.12). `standings.r_round`
  reproduces this and matched R bit for bit on 178,976 test values (October 22,
  2026, R 4.6.1). Polars' own `round` differed from R on 374 of those test
  values, but **not on any value this pipeline produces**: polars 2.0 `round(2)`
  gives R's result for all 3,485 possible win-loss records and all 13,530
  wins-needed ratios. `r_round` is kept as exactness insurance.
- Division by a scalar: polars 2.0 computes `col / 100` as `col * 0.01`, so
  `1429 / 100` gives 14.290000000000001 where R gives 14.29. `standings._fdiv`
  divides by a column instead, which is exact. It changed the value on 1,058
  of the 10,001 possible lines, and `ceiling(line / 100 * 82)` on none of them.

A one-bit difference is inside the 1e-9 comparison tolerance, so the golden
comparison cannot see it, and the unit tests in `tests/test_standings.py` guard
both helpers directly.

The `rounding` golden case (`../golden/rounding/`) guards a different mistake:
**half-up rounding**, as a spreadsheet or Python's `Decimal` does by default. 1
win in 32 games is exactly 3.125 percent; R rounds it to 3.12 and half-up gives
3.13. With a line of 3.13, R calls the team UNDER and half-up calls it PUSH, a
difference of kind, not of a bit. A half-up `r_round` passes the October 21,
fixture, and seeding cases and fails this one on 7 tables (checked October 22,
2026). It does not catch polars' own `round`, which already agrees with R here.
