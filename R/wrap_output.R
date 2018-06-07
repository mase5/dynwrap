#' Wrap the output of a TI method
#'
#' Will extract outputs from a given folder given an output format:
#'  * rds: One `output.rds` file containing all the output. Output can be present as `.$pseudotime` or as `.$linear_trajectory$pseudotime` . Parameters specific for an output should be given in `.$linear_trajectory$params`
#'  * text: Csv and/or json files, including subdirectories. Output can be present as `./pseudotime.csv` or as `./linear_trajectory/pseudotime.csv`. Parameters specific for an output should be given in `./linear_trajectory/params.json`.
#'  * feather: Feather files
#'  * dynwrap: Directly a dynwrap wrapper as an rds file in `output.rds`
#'
#' @param model The model to start from, as generated by `wrap_data`
#' @param output_ids The ids of the outputs generated by the methods
#' @param dir_output The directory containing the output files
#' @param output_format The output format, can be rds, text or dynwrap
#'
#' @export
wrap_output <- function(model, output_ids, dir_output, output_format = c("text", "rds", "feather", "dynwrap")) {
  output_format <- match.arg(output_format)
  if(output_format == "rds") {
    wrap_rds(model, output_ids, dir_output)
  } else if (output_format == "text") {
    wrap_text(model, output_ids, dir_output)
  } else if (output_format == "feather") {
    wrap_feather(model, output_ids, dir_output)
  } else if (output_format == "dynwrap") {
    read_rds(file.path(dir_output, "output.rds"))
  }
}

#' @rdname wrap_output
wrap_rds <- function(model, output_ids, dir_output) {
  output <- read_rds(file.path(dir_output, "output.rds"))

  for (output_id in output_ids) {
    processor <- get_output_processor(output_id)

    # get output from output[[output_id]]
    inner_output_ids <- intersect(processor$params, names(output[[output_id]]))
    output_oi <- output[[output_id]][inner_output_ids]

    # get output from output, but don't select parts which are already in the output_oi
    outer_output_ids <- setdiff(intersect(processor$params, names(output)), names(output_oi))
    output_oi <- c(
      output_oi,
      output[outer_output_ids]
    )

    # also add extra params
    if(!is.null(output[[output_id]]) && !is.null(output[[output_id]]$params)) {
      output_oi <- c(
        output_oi,
        as.list(output[[output_oi]]$params)
      )
    }

    # always give model as first argument
    output_oi <- c(
      list(model),
      output_oi
    )

    # check required outputs
    # if (!all(processor$required_params %in% names(output_oi))) {
    #   stop("Some outputs were not found but are required: ", setdiff(processor$required_params, names(output_oi)))
    # }

    model <- invoke(processor$processor, output_oi)
  }
  model
}

#' @rdname wrap_output
wrap_text <- function(model, output_ids, dir_output) {
  outer_files <- list.files(dir_output, full.names = TRUE)

  for (output_id in output_ids) {
    output_oi <- list()

    processor <- get_output_processor(output_id)

    inner_files <- list.files(file.path(dir_output, output_id), all.files = TRUE)

    files <- c(inner_files, outer_files)

    for(param in processor$params) {
      matching <- stringr::str_subset(files, glue::glue(".*\\/{param}\\..*"))
      if(length(matching)) {
        output_oi[[param]] <- read_infer(first(matching), param)
      }
    }

    # also add extra params, both from the output_id folder as well as from the main folder
    if(file.exists(file.path(dir_output, output_id, "params.json"))) {
      output_oi <- c(
        output_oi,
        jsonlite::read_json(file.path(dir_output, output_id, "params.json"))
      )
    }


    # always give model as first argument
    output_oi <- c(
      list(model),
      output_oi
    )

    # check required outputs
    # if (!all(processor$required_params %in% names(output_oi))) {
    #   stop("Some outputs were not found but are required: ", setdiff(processor$required_params, names(output_oi)))
    # }

    model <- invoke(processor$processor, output_oi)
  }
  model
}





#' @rdname wrap_output
wrap_hdf5 <- function(model, output_ids, dir_output) {
  output <- read_rds(file.path(dir_output, "output.rds"))

  for (output_id in output_ids) {
    processor <- get_output_processor(output_id)

    # get output from output[[output_id]]
    inner_output_ids <- intersect(processor$params, names(output[[output_id]]))
    output_oi <- output[[output_id]][inner_output_ids]

    # get output from output, but don't select parts which are already in the output_oi
    outer_output_ids <- setdiff(intersect(processor$params, names(output)), names(output_oi))
    output_oi <- c(
      output_oi,
      output[outer_output_ids]
    )

    # also add extra params
    if(!is.null(output[[output_id]]) && !is.null(output[[output_id]]$params)) {
      output_oi <- c(
        output_oi,
        as.list(output[[output_oi]]$params)
      )
    }

    # always give model as first argument
    output_oi <- c(
      list(model),
      output_oi
    )

    # check required outputs
    # if (!all(processor$required_params %in% names(output_oi))) {
    #   stop("Some outputs were not found but are required: ", setdiff(processor$required_params, names(output_oi)))
    # }

    model <- invoke(processor$processor, output_oi)
  }
  model
}




#' @rdname wrap_output
wrap_feather <- function(model, output_ids, dir_output) {
  outer_files <- list.files(dir_output, full.names = TRUE)

  for (output_id in output_ids) {
    output_oi <- list()

    processor <- get_output_processor(output_id)

    inner_files <- list.files(file.path(dir_output, output_id), all.files = TRUE)

    files <- c(inner_files, outer_files)

    for(param in processor$params) {
      matching <- stringr::str_subset(files, glue::glue(".*\\/{param}.feather"))
      if(length(matching)) {
        output_oi[[param]] <- feather::read_feather(first(matching))
      }
    }

    # also add extra params, both from the output_id folder as well as from the main folder
    if(file.exists(file.path(dir_output, output_id, "params.json"))) {
      output_oi <- c(
        output_oi,
        jsonlite::read_json(file.path(dir_output, output_id, "params.json"))
      )
    }

    # always give model as first argument
    output_oi <- c(
      list(model),
      output_oi
    )

    model <- invoke(processor$processor, output_oi)
  }
  model
}


read_infer <- function(file, param) {
  if(endsWith(file, ".csv")) {

    col_types <- switch(
      param,
      milestone_network = cols(
        from = col_character(),
        to = col_character(),
        length = col_double(),
        directed = col_logical()
      ),
      dimred = cols(
        cell_id = col_character(),
        .default = col_double()
      ),
      dimred_milestones = cols(
        milestone_id = col_character(),
        .default = col_double()
      ),
      cols()
    )

    read_csv(file, col_types = col_types)
  } else if (endsWith(file, ".json")) {
    jsonlite::read_json(file, TRUE)
  }
}


get_output_processor <- function(output_id) {
  processor <- get(paste0("add_", output_id), "package:dynwrap")

  required_params <- names(as.list(formals(processor)) %>% map_chr(class) %>% keep(~. == "name"))
  required_params <- setdiff(required_params, c("data_wrapper", "traj", "model", "pred", "..."))
  optional_params <- names(as.list(formals(processor)) %>% map_chr(class) %>% keep(~. != "name"))

  lst(
    processor,
    required_params,
    optional_params,
    params = c(required_params, optional_params)
  )
}