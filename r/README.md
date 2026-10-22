# ouanalytics <a href="https://ismayc.github.io/ouanalytics/"><img src="man/figures/logo.png" align="right" height="139" alt="ouanalytics hex sticker: a basketball on a see-saw" /></a>

The calculations behind the NBA over/under pool page: each team's status
against its win total, each player's points, the change since yesterday,
the wins a team still needs, and playoff seeding with the official NBA
tie-break procedure. Not for CRAN.

Every function is pure: nothing reads a file, calls the network, or looks at
`Sys.Date()`. Every date and constant comes in as an argument. The page build
in [ismayc.github.io](https://github.com/ismayc/ismayc.github.io) reads the saved
data and calls `compute_pool()` and `compute_playoff_seeding()`.

Documentation: <https://ismayc.github.io/ouanalytics/>

## Install

    remotes::install_github("ismayc/ouanalytics@v0.1.0", subdir = "r")

The page build pins a release tag like this one, so a push to the repository
cannot change a build that has been working.

## Test

From the repo root:

    Rscript r/tools/check.R

This installs the package, runs the tests, and fails unless every line is
covered. CI runs the same check, plus `R CMD check`.

## Cross-check with the Python package

`../python/` recomputes every table in polars and compares it with the R result.
The golden cases it tests against (`../golden/`) come from R:

    R CMD INSTALL r
    Rscript r/tools/make-golden.R

Re-run `make-golden.R` after any change to the R calculations, then run the
Python tests (see `../python/README.md`). CI re-runs it and fails if `golden/`
would change. A difference between the two languages means one of them is wrong.

## Layout

| File | Contents |
|---|---|
| `R/standings_logic.R` | Over/under status, points, changes, wins needed |
| `R/seeding.R` | NBA tie-break procedure and playoff seeding |
| `R/pool.R` | `compute_pool()`: the whole pool calculation in order |
| `R/export.R` | CSV export of a case, for the Python cross-check |
| `tests/testthat/` | Tests (fixtures in `helper-*.R`) |
| `tools/check.R` | Tests plus the 100% coverage gate |
| `tools/make-golden.R` | Writes the golden cases (`../golden/`) |
| `data-raw/make-datasets.R` | Builds `pool_example` and `seeding_example` |
| `data-raw/nba_teams.csv` | The 30 teams, with conference and division |
| `_pkgdown.yml`, `pkgdown/`, `vignettes/articles/` | The documentation site (see below) |

## Documentation site

The site is built with pkgdown by CI and published to GitHub Pages at
<https://ismayc.github.io/ouanalytics/> on every push to `master`. To preview it:

    uv run --with fonttools --with pillow python branding/make_branding.py    # only if the logo changed
    Rscript -e 'roxygen2::roxygenise("r")'
    Rscript -e 'pkgdown::build_site("r")'
