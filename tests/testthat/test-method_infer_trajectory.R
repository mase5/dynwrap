context("Testing infer_trajectory")

source(paste0(ifelse(file.exists("nothelper-methods.R"), "", "tests/testthat/"), "nothelper-methods.R"))

# create dataset
id <- "a"
cell_ids <- c("truth", "universally", "acknowledged", "that", "a", "single")
cell_info <- data_frame(
  cell_id = cell_ids,
  info1 = c("man", "in", "possession", "of", "a", "good"),
  info2 = c("fortune", "must", "be", "in", "want", "of"),
  info3 = 1:6
)
extras1 <- list("a wife.")
extras2 <- c("However", "little", "known")

num_features <- round(runif(1, 100, 120))
feature_names <- paste0("feature_", seq_len(num_features))

expression <- matrix(runif(num_features * length(cell_ids), 8, 12), nrow = length(cell_ids), dimnames = list(cell_ids, feature_names))
counts <- 2^expression - 1
feature_info <- data_frame(feature_id = feature_names, mean = colMeans(expression), var = apply(expression, 2, var))

dataset <-
  wrap_expression(
    id = id,
    expression,
    counts,
    cell_info,
    feature_info,
    extras1 = extras1,
    extras2 = extras2
  ) %>%
  add_prior_information(start_id = cell_ids[[1]])

# make sure dynmethods is not installed
if ("dynmethods" %in% rownames(utils::installed.packages())) remove.packages("dynmethods")

test_that("Testing infer_trajectory with control methods", {
  method <- ti_comp1()

  model <- infer_trajectory(dataset, method)
  expect_s3_class(model, "dynwrap::with_trajectory")

  # test priors
  model <- infer_trajectory(dataset, method, give_priors = c("start_id"))
  expect_s3_class(model, "dynwrap::with_trajectory")

  expect_error(infer_trajectory(dataset, method, give_priors = c("to be or not to be")))

  # run with multiple datasets and one method
  models <- infer_trajectories(list(dataset, dataset), method)
  expect_true(is_tibble(models))
  expect_equal(nrow(models), 2)
  expect_setequal(c("dataset_ix", "method_ix", "model", "method_name", "method_id", "dataset_id", "summary"), names(models))

  models <- infer_trajectories(list_as_tibble(list(dataset, dataset)), ti_comp1())
  expect_true(is_tibble(models))
  expect_equal(nrow(models), 2)

  # run with multiple methods
  models <- infer_trajectories(dataset, list(ti_comp1(), ti_comp1()))
  expect_true(is_tibble(models))
  expect_equal(nrow(models), 2)

  models <- infer_trajectories(dataset, list_as_tibble(list(ti_comp1(), ti_comp1())))
  expect_true(is_tibble(models))
  expect_equal(nrow(models), 2)

  # models <- infer_trajectories(dataset, c("comp1", "comp1"))
  # expect_true(is_tibble(models))
  # expect_equal(nrow(models), 2)

  expect_error(infer_trajectories(dataset, c(1,2,3)))
  expect_error(infer_trajectories(c(1,2,3), c(1,2,3)))

  # run with multiple datasets and multiple methods
  models <- infer_trajectories(
    dataset = list(dataset, dataset, dataset),
    method = list(ti_comp1(), ti_comp1())
  )

  expect_true(is_tibble(models))
  expect_equal(nrow(models), 6)

  # run with multiple datasets and multiple methods with specified parameters
  models <- infer_trajectories(
    dataset = list(dataset, dataset),
    method = list_as_tibble(list(ti_comp1(), ti_comp1())),
    parameters = list(list(dimred = "mds"), list(dimred = "pca"))
  )

  expect_true(is_tibble(models))
  expect_equal(nrow(models), 4)

  # capture the output
  models <- infer_trajectories(
    dataset = dataset,
    method = ti_comp1(),
    parameters = list(),
    return_verbose = TRUE
  )
  expect_equal(models$summary[[1]]$stdout, "")
  expect_equal(models$summary[[1]]$stderr, "")
})


# test_that("Testing get_ti_methods", {
#   methods <- get_ti_methods(c("comp1"))
#   expect_equal(nrow(methods), 1)
#   expect_error(get_ti_methods("I_AM_A_ROBOT"))
#   expect_is(get_ti_methods(as_tibble = FALSE), "list")
# })
