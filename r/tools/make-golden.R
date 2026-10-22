# Write the golden cases both packages test against: fixed inputs and the tables
# this R package computes from them. Run from the repo root:
#   R CMD INSTALL r && Rscript r/tools/make-golden.R
# Re-run after any change to the R calculations, then run the Python tests
# (python/README.md). CI re-runs this and fails if golden/ would change, so a
# change to the R code cannot land without its golden files.
#
# Cases:
#   oct21      real data through October 21, 2026, with player names replaced by
#              P1, P2, ... The INPUTS are frozen (they came from the page build);
#              only the outputs are recomputed here.
#   fixture    the small pool the R tests use (it has game scores).
#   seeding_N  six random leagues with few games, so many teams tie.

suppressMessages({
  library(ouanalytics)
  library(dplyr)
  library(tibble)
})

golden <- "golden"
stopifnot(dir.exists(file.path(golden, "oct21", "inputs")))
unlink(file.path(golden, c("fixture", paste0("seeding_", 1:6))), recursive = TRUE)

# --- oct21: recompute the outputs from the committed inputs -----------------
inp <- file.path(golden, "oct21", "inputs")
rd <- function(f) read.csv(file.path(inp, f), check.names = FALSE, stringsAsFactors = FALSE)
game_results_raw <- as_tibble(rd("game_results_raw.csv")) |>
  mutate(dateGame = as.Date(dateGame), numberGameTeamSeason = as.integer(numberGameTeamSeason))
stopifnot(nrow(rd("scores.csv")) == 0)  # this case has no game scores
scores <- tibble(game_id = character(), game_date = as.Date(character()),
                 away_team = character(), home_team = character(),
                 slug_away_team = character(), slug_home_team = character(),
                 away_score = numeric(), home_score = numeric())
projections <- as_tibble(rd("projections.csv"))
picks <- as_tibble(rd("picks.csv"))
standings <- as_tibble(rd("standings.csv"))
p <- rd("params.csv")
pv <- function(n) p$value[p$name == n]
params <- list(yesterday = as.Date(pv("yesterday")), today = as.Date(pv("today")),
               season_start = as.Date(pv("season_start")),
               num_games = as.numeric(pv("num_games")))
pool <- compute_pool(game_results_raw, scores, projections, picks, standings,
                     params$yesterday, params$today, params$season_start,
                     params$num_games)
export_pool_case(file.path(golden, "oct21"), game_results_raw, scores,
                 projections, picks, standings, params, pool)

# --- fixture: the small pool the R tests use --------------------------------
source("r/tests/testthat/helper-fixtures.R", local = TRUE)
fx_standings <- tibble(team_name = c("Alpha", "Bravo", "Los Angeles Clippers"),
                       wins = c(1, 0, 1), losses = c(1, 1, 0))
fx_params <- list(yesterday = d2, today = d2 + 1, season_start = d1,
                  num_games = 82)
fx_pool <- compute_pool(game_results_raw, scores, projections, picks,
                        fx_standings, fx_params$yesterday, fx_params$today,
                        fx_params$season_start, fx_params$num_games)
export_pool_case(file.path(golden, "fixture"), game_results_raw, scores,
                 projections, picks, fx_standings, fx_params, fx_pool)

# --- seeding_1 to seeding_6: random leagues ---------------------------------
# The 30 NBA teams, with their conference and division (frozen table).
meta <- read.csv("r/data-raw/nba_teams.csv", stringsAsFactors = FALSE)

random_league <- function(seed, games_per_team) {
  set.seed(seed)
  n_games <- games_per_team * nrow(meta) / 2
  g <- tibble(a = sample(meta$abbreviation, n_games, replace = TRUE),
              b = sample(meta$abbreviation, n_games, replace = TRUE)) |>
    filter(a != b) |>
    mutate(sa = sample(90:130, n(), replace = TRUE),
           sb = sample(90:130, n(), replace = TRUE)) |>
    filter(sa != sb)
  scores_tidy <- bind_rows(
    g |> transmute(team_slug = a, opponent_slug = b, score = sa, opponent_score = sb),
    g |> transmute(team_slug = b, opponent_slug = a, score = sb, opponent_score = sa)
  )
  rec <- scores_tidy |>
    group_by(team_slug) |>
    summarize(wins = sum(score > opponent_score),
              losses = sum(score < opponent_score), .groups = "drop")
  st <- meta |>
    transmute(team_name = team, conference, division, abbreviation) |>
    left_join(rec, by = c("abbreviation" = "team_slug")) |>
    mutate(wins = coalesce(wins, 0L), losses = coalesce(losses, 0L),
           `Winning Pct` = if_else(wins + losses > 0,
                                   round(wins / (wins + losses), 3), 0),
           `Games Back` = "-") |>
    select(team_name, conference, division, wins, losses, `Winning Pct`,
           `Games Back`, abbreviation)
  list(standings = st, scores_tidy = scores_tidy)
}

leagues <- list(list(1, 3), list(2, 3), list(3, 6), list(4, 6), list(5, 12),
                list(6, 20))
for (i in seq_along(leagues)) {
  lg <- random_league(leagues[[i]][[1]], leagues[[i]][[2]])
  seeded <- compute_playoff_seeding(lg$standings, lg$scores_tidy, meta)
  export_seeding_case(file.path(golden, sprintf("seeding_%d", i)), meta,
                      lg$standings, lg$scores_tidy, seeded)
}

cat("Wrote golden cases to", golden, "\n")
print(list.files(golden))
