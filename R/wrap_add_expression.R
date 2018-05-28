#' Add count and normalised expression values to a data wrapper
#'
#' @param data_wrapper A data wrapper to extend upon
#' @param counts The counts with genes in columns and cells in rows
#' @param expression The normalised expression values with genes in columns and cells in rows
#' @param feature_info Optional meta-information of the features, a data.frame with at least feature_id as column
#' @param ... extra information to be stored in the wrapper
#' @param expression_source The source of expression, can be "counts", "expression", an expression matrix, or another data wrapper which contains expression
#'
#' @export
#'
#' @importFrom testthat expect_equal expect_is
add_expression <- function(
  data_wrapper,
  counts,
  expression,
  feature_info = NULL,
  ...
) {
  testthat::expect_true(is_data_wrapper(data_wrapper))

  cell_ids <- data_wrapper$cell_ids

  testthat::expect_is(counts, "matrix")
  testthat::expect_is(expression, "matrix")
  testthat::expect_equal(rownames(counts), cell_ids)
  testthat::expect_equal(rownames(expression), cell_ids)
  testthat::expect_equal(colnames(expression), colnames(counts))

  if (!is.null(feature_info)) {
    testthat::expect_is(feature_info, "data.frame")
    testthat::expect_equal(colnames(counts), feature_info$feature_id)
    testthat::expect_equal(colnames(expression), feature_info$feature_id)
  }

  # create output structure
  data_wrapper %>% extend_with(
    "dynwrap::with_expression",
    counts = counts,
    expression = expression,
    feature_info = feature_info,
    ...
  )
}

#' @rdname add_expression
#' @export
is_wrapper_with_expression <- function(data_wrapper) {
  is_data_wrapper(data_wrapper) && "dynwrap::with_expression" %in% class(data_wrapper)
}

#' @rdname add_expression
#' @export
get_expression <- function(data_wrapper, expression_source = "expression") {
  if (is.character(expression_source)) {
    if(!expression_source %in% names(data_wrapper)) {stop("Expression source not in traj, did you run add_expression?")}
    expression <- data_wrapper[[expression_source]]
  } else if (is.matrix(expression_source)) {
    expression <- expression_source
  } else if (is_wrapper_with_expression(expression_source)) {
    expression <- get_expression(expression_source)
  } else {
    stop("Invalid expression_source")
  }
  expression
}

#' Create a wrapper object with expression and counts
#'
#' @inheritParams add_expression
#' @inheritParams wrap_data
#'
#' @export
wrap_expression <- function(expression, counts, cell_info = NULL, feature_info = NULL, ..., id="") {
  testthat::expect_equivalent(dim(expression), dim(counts))
  testthat::expect_equivalent(colnames(expression), colnames(counts))
  testthat::expect_equivalent(rownames(expression), rownames(counts))

  wrap_data(id, rownames(expression), cell_info, ...) %>%
    add_expression(counts, expression, feature_info)
}