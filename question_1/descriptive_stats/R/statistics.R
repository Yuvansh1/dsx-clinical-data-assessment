validate_numeric <- function(x, na.rm) {
  if (!is.numeric(x) || is.complex(x) || !is.null(dim(x)) || is.object(x)) {
    stop("x must be a plain numeric vector", call. = FALSE)
  }
  if (!is.logical(na.rm) || length(na.rm) != 1L || is.na(na.rm)) {
    stop("na.rm must be TRUE or FALSE", call. = FALSE)
  }
  if (any(is.infinite(x))) stop("x must not contain infinite values", call. = FALSE)
  if (na.rm) x <- x[!is.na(x)]
  x
}

#' Arithmetic mean
#' @param x A plain integer or double vector. Infinite values are rejected.
#' @param na.rm Remove NA and NaN values when TRUE; defaults to FALSE.
#' @return A numeric scalar; NA_real_ for empty input or unremoved missing values.
#' @examples
#' calc_mean(c(1, 2, 3))
#' calc_mean(c(1, NA, 3), na.rm = TRUE)
#' @export
calc_mean <- function(x, na.rm = FALSE) {
  x <- validate_numeric(x, na.rm)
  if (!length(x) || anyNA(x)) return(NA_real_)
  mean(x)
}

#' Median
#' @inheritParams calc_mean
#' @return A numeric scalar; NA_real_ for empty input or unremoved missing values.
#' @examples
#' calc_median(c(1, 2, 8, 9))
#' @export
calc_median <- function(x, na.rm = FALSE) {
  x <- validate_numeric(x, na.rm)
  if (!length(x) || anyNA(x)) return(NA_real_)
  stats::median(x)
}

#' Modes, including ties
#' @inheritParams calc_mean
#' @return Sorted numeric modes. Returns numeric(0) for empty input or when no
#'   value repeats, including a singleton. Returns NA_real_ for unremoved
#'   missing values. All tied values with frequency at least two are returned.
#' @examples
#' calc_mode(c(1, 1, 2, 2, 3))
#' calc_mode(c(1, 2, 3))
#' @export
calc_mode <- function(x, na.rm = FALSE) {
  x <- validate_numeric(x, na.rm)
  if (anyNA(x)) return(NA_real_)
  if (!length(x)) return(numeric())
  values <- sort(unique(x))
  counts <- tabulate(match(x, values))
  if (max(counts) < 2L) return(numeric())
  as.numeric(values[counts == max(counts)])
}

#' First quartile
#' @inheritParams calc_mean
#' @return A numeric scalar using R quantile type 7; NA_real_ for empty input
#'   or unremoved missing values. A singleton returns its own value.
#' @examples
#' calc_q1(1:5)
#' @export
calc_q1 <- function(x, na.rm = FALSE) {
  x <- validate_numeric(x, na.rm)
  if (!length(x) || anyNA(x)) return(NA_real_)
  as.numeric(stats::quantile(x, 0.25, type = 7, names = FALSE))
}

#' Third quartile
#' @inheritParams calc_mean
#' @return A numeric scalar using R quantile type 7; NA_real_ for empty input
#'   or unremoved missing values. A singleton returns its own value.
#' @examples
#' calc_q3(1:5)
#' @export
calc_q3 <- function(x, na.rm = FALSE) {
  x <- validate_numeric(x, na.rm)
  if (!length(x) || anyNA(x)) return(NA_real_)
  as.numeric(stats::quantile(x, 0.75, type = 7, names = FALSE))
}

#' Interquartile range
#' @inheritParams calc_mean
#' @return Q3 minus Q1 using type 7 quantiles; NA_real_ for empty input or
#'   unremoved missing values. A singleton returns zero.
#' @examples
#' calc_iqr(1:5)
#' @export
calc_iqr <- function(x, na.rm = FALSE) {
  calc_q3(x, na.rm) - calc_q1(x, na.rm)
}
