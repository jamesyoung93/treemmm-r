# Rolling-origin + period-jump temporal cross-validation.
# Mirrors treemmm.core.temporal.splitter in the Python package.
# TODO Phase 3: implement get_splits().

# get_splits produces train/test index pairs for rolling-origin CV.
# Default: 5 folds with each fold's training horizon expanding forward.
# TODO Phase 3.
get_splits <- function(df, time_col, n_folds = 5L) {
  stop("Not yet implemented (Phase 3). See ROADMAP.md.")
}
