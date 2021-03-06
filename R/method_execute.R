.method_execute <- function(
  dataset,
  method,
  parameters,
  give_priors,
  seed,
  verbose,
  return_verbose,
  debug
) {
  # start the timer
  timings <- list(execution_start = Sys.time())

  # test whether the dataset contains expression
  testthat::expect_true(is_data_wrapper(dataset))
  testthat::expect_true(is_wrapper_with_expression(dataset))

  # check method
  testthat::expect_true(is_ti_method(method))

  # extract args from dataset
  inputs <- .method_extract_args(dataset, method$inputs, give_priors)

  # extract parameters from method
  params <- get_default_parameters(method)
  params[names(parameters)] <- parameters
  parameters <- params
  rm(params)

  # initialise stdout/stderr files
  sink_meta <- .method_init_sinks(verbose = verbose, return_verbose = return_verbose)

  # print helpful message
  if (verbose) {
    cat(
      "Executing '", method$id, "' on '", dataset$id, "'\n",
      "With parameters: ", deparse(parameters), "\n",
      "And inputs: ", paste0(names(inputs), collapse = ", "), "\n",
      sep = ""
    )
  }

  # run preproc
  preproc_meta <-
    if (method$run_info$backend == "function") {
      .method_execution_preproc_function(method = method)
    } else {
      .method_execution_preproc_container(method = method, inputs = inputs, parameters = parameters, verbose = verbose || return_verbose, seed = seed, debug = debug)
    }

  # initialise output variables
  model <- NULL
  timings$method_beforepreproc <- Sys.time()

  error <- tryCatch({
    # execute method and return model
    model <-
      if (method$run_info$backend == "function") {
        .method_execution_execute_function(method = method, inputs = inputs, parameters = parameters, verbose = verbose || return_verbose, seed = seed, preproc_meta = preproc_meta)
      } else {
        .method_execution_execute_container(method = method, preproc_meta = preproc_meta)
      }

    # add model timings and timings stop
    timings <- c(timings, model$timings)
    timings$method_afterpostproc <- Sys.time()

    # remove timings from model
    model$timings <- NULL
    class(model) <- setdiff(class(model), "dynwrap::with_timings")

    NA_character_
  }, error = function(e) {
    e$message
  })

  # run postproc
  if (method$run_info$backend == "function") {
    .method_execution_postproc_function(preproc_meta = preproc_meta)
  } else {
    .method_execution_postproc_container(preproc_meta = preproc_meta)
  }

  # retrieve stdout/stderr
  stds <- .method_close_sinks(sink_meta)

  # stop timings
  timings$execution_stop <- Sys.time()

  # if method doesn't return these timings, row with the oars we have
  if (!"method_afterpreproc" %in% names(timings)) timings$method_afterpreproc <- timings$method_beforepreproc
  if (!"method_aftermethod" %in% names(timings)) timings$method_aftermethod <- timings$method_afterpostproc

  # make sure timings are numeric
  timings <- map_dbl(timings, as.numeric)

  # calculate timing differences
  timings_diff <- diff(timings[c("execution_start", "method_beforepreproc", "method_afterpreproc", "method_aftermethod", "method_afterpostproc", "execution_stop")]) %>%
    set_names(c("time_sessionsetup", "time_preprocessing", "time_method", "time_postprocessing", "time_sessioncleanup"))

  # create a summary tibble
  summary <- tibble(
    method_name = method$name,
    method_id = method$id,
    dataset_id = dataset$id,
    stdout = stds$stdout,
    stderr = stds$stderr,
    error = error,
    prior_df = list(method$inputs %>% rename(prior_id = input_id) %>% mutate(given = prior_id %in% names(inputs)))
  ) %>%
    bind_cols(as.data.frame(as.list(timings_diff)))

  lst(model, summary)
}

.method_init_sinks <- function(verbose, return_verbose) {
  if (!verbose || return_verbose) {
    stdout_file <- tempfile()
    sink(stdout_file, type = "output", split = verbose, append = TRUE)

    # manual states that messages can only be sinked with an open connection
    stderr_file <- tempfile()
    stderr_con <- file(stderr_file, open = "wt")

    # can't split the message connection :(
    sink(stderr_con, type = "message", split = FALSE, append = TRUE)
  } else {
    stdout_file <- stderr_file <- stderr_con <- NULL
  }

  lst(
    stdout_file,
    stderr_file,
    stderr_con,
    verbose,
    return_verbose
  )
}
.method_close_sinks <- function(sink_meta) {
  if (!sink_meta$verbose || sink_meta$return_verbose) {
    sink(type = "output")
    sink(type = "message")
    close(sink_meta$stderr_con)
  }

  if (sink_meta$return_verbose) {
    stdout <- read_file(sink_meta$stdout_file)
    stderr <- read_file(sink_meta$stderr_file)
    if (sink_meta$verbose && length(stderr) > 0) {
      cat("Messages (not in order):\n")
      cat(paste(stderr, collapse = "\n"))
    }
  } else {
    stdout <- ""
    stderr <- ""
  }

  lst(stdout, stderr)
}

