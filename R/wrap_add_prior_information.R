#' Add prior information to a data wrapper
#'
#' Note that the given data wrapper requires a trajectory and expression values
#' to have been added already.
#'
#' @param task A data wrapper to extend upon.
#' @param start_cells The start cells
#' @param end_cells The end cells
#' @param grouping_assignment The grouping of cells, a dataframe with cell_id and group_id
#' @param grouping_network The network between groups, a dataframe with from and to
#' @param marker_feature_ids The features (genes) important for the trajectory
#' @param n_branches Number of branches
#' @param n_end_states Number of end states
#' @param time The time for every cell
#'
#' @export
#'
#' @importFrom testthat expect_true
#' @importFrom purrr discard list_modify
add_prior_information <- function(
  task,
  start_cells = NULL,
  end_cells = NULL,
  grouping_assignment = NULL,
  grouping_network = NULL,
  marker_feature_ids = NULL,
  n_branches = NULL,
  n_end_states = NULL,
  time = NULL
) {
  prior_information <- lst(
    # start_milestones,
    start_cells,
    # end_milestones,
    end_cells,
    grouping_assignment,
    grouping_network,
    marker_feature_ids,
    n_branches,
    time,
    n_end_states
  ) %>% discard(is.null)

  # check input
  # if(!is.null(start_milestones)) {
  #   testthat::expect_true(is_wrapper_with_trajectory(task))
  #   testthat::expect_true(all(start_milestones %in% task$milestone_ids))
  # }
  # if(!is.null(end_milestones)) {
  #   testthat::expect_true(is_wrapper_with_trajectory(task))
  #   testthat::expect_true(all(end_milestones %in% task$milestone_ids))
  # }
  if(!is.null(start_cells)) {
    testthat::expect_true(all(start_cells %in% task$cell_ids))
  }
  if(!is.null(end_cells)) {
    testthat::expect_true(all(start_cells %in% task$cell_ids))
  }
  if(!is.null(grouping_assignment)) {
    testthat::expect_true(is.data.frame(grouping_assignment))
    testthat::expect_setequal(colnames(grouping_assignment), c("cell_id", "group_id"))
    testthat::expect_setequal(grouping_assignment$cell_ids, task$cell_ids)
  }
  if(!is.null(grouping_network)) {
    testthat::expect_true(!is.null(grouping_assignment))
    testthat::expect_setequal(colnames(grouping_network), c("from", "to"))
    testthat::expect_setequal(grouping_network$from, grouping_assignment$group_id)
    testthat::expect_setequal(grouping_network$to, grouping_assignment$group_id)
  }
  if(!is.null(marker_feature_ids)) {
    testthat::expect_true(is_wrapper_with_expression(task))
    testthat::expect_true(all(marker_feature_ids %in% colnames(task$counts)))
  }

  if (is_wrapper_with_trajectory(task) && is_wrapper_with_expression(task)) {
    message("Calculating prior information using trajectory")

    # compute prior information and add it to the wrapper
    calculated_prior_information <-
      with(task, generate_prior_information(
        cell_ids = cell_ids,
        milestone_ids = milestone_ids,
        milestone_network = milestone_network,
        milestone_percentages = milestone_percentages,
        progressions = progressions,
        divergence_regions = divergence_regions,
        counts = counts,
        feature_info = feature_info,
        cell_info = cell_info
      ))

    # update calculated prior information with given prior information (giving precendence to the latter)
    prior_information <- list_modify(calculated_prior_information, !!!prior_information)
  }

  task %>% extend_with(
    "dynwrap::with_prior",
    prior_information = prior_information
  )
}


#' Test whether an object is a task and contains prior information
#'
#' @param object The object to be tested.
#'
#' @export
is_wrapper_with_prior_information <- function(object) {
  is_wrapper_with_trajectory(object) && "dynwrap::with_prior" %in% class(object)
}

#' Extract the prior information from the milestone network
#'
#' For example, what are the start cells, the end cells, to which milestone does each cell belong to.
#'
#' @inheritParams wrap_data
#' @inheritParams add_trajectory
#' @inheritParams add_expression
#' @param marker_logfc Marker genes require at least a X-fold log difference between groups of cells.
#' @param marker_minpct Only test genes that are detected in a minimum fraction of cells between groups of cells.
#'
#' @export
generate_prior_information <- function(
  cell_ids,
  milestone_ids,
  milestone_network,
  milestone_percentages,
  progressions,
  divergence_regions,
  counts,
  feature_info = NULL,
  cell_info = NULL,
  marker_logfc = 1,
  marker_minpct = 0.4
) {
  requireNamespace("Seurat")

  ## START AND END CELLS ##
  # convert milestone network to an igraph object
  is_directed <- any(milestone_network$directed)
  gr <- igraph::graph_from_data_frame(
    milestone_network,
    directed = is_directed,
    vertices = milestone_ids
  )

  # determine starting and ending milestones
  start_milestones <-
    if (is_directed) {
      names(which(igraph::degree(gr, mode = "in") == 0))
    } else {
      names(which(igraph::degree(gr) <= 1))
    }

  # determine starting and ending milestones
  end_milestones <-
    if (is_directed) {
      names(which(igraph::degree(gr, mode = "out") == 0))
    } else {
      start_milestones
    }

  # define helper function for determining the closest cells
  determine_closest_cells <- function(mids) {
    pseudocell <- paste0("MILESTONECELL_", mids)
    traj <-
      wrap_data(
        id = "tmp",
        cell_ids = c(cell_ids, pseudocell)
      ) %>%
      add_trajectory(
        milestone_ids = milestone_ids,
        milestone_network = milestone_network,
        divergence_regions = divergence_regions,
        milestone_percentages = bind_rows(
          milestone_percentages,
          data_frame(cell_id = pseudocell, milestone_id = mids, percentage = 1)
        )
      )

    geo <- compute_tented_geodesic_distances(traj, waypoint_cells = pseudocell)[,cell_ids,drop = FALSE]

    unique(unlist(apply(geo, 1, function(x) {
      sample(names(which(x == min(x))), 1)
    })))
  }

  # determine start cells
  if (length(start_milestones) > 0) {
    start_cells <- determine_closest_cells(start_milestones)
  } else {
    start_cells <- unique(progressions$cell_id)
  }

  # determine end cells
  if (length(end_milestones) > 0) {
    end_cells <- determine_closest_cells(end_milestones)
  } else {
    end_cells <- c()
  }

  ## CELL GROUPING ##
  grouping_assignment <-
    milestone_percentages %>%
    group_by(cell_id) %>%
    summarise(group_id = milestone_id[which.max(percentage)])
  grouping_network <- milestone_network %>% select(from, to)

  ## MARKER GENES ##
  if (!is.null(feature_info) && "housekeeping" %in% colnames(feature_info)) {
    marker_feature_ids <- feature_info %>%
      filter(!housekeeping) %>%
      pull(feature_id)
  } else {
    ident <- grouping_assignment %>%
      slice(match(rownames(counts), cell_id)) %>%
      pull(group_id) %>%
      factor() %>%
      setNames(rownames(counts))

    seurat <- Seurat::CreateSeuratObject(t(counts[names(ident), ]))

    seurat@ident <- ident

    changing <- Seurat::FindAllMarkers(
      seurat,
      logfc.treshold = marker_logfc,
      min.pct = marker_minpct
    )

    marker_feature_ids <- changing %>%
      filter(abs(avg_logFC) >= 1) %>%
      .$gene %>%
      unique()
  }

  ## NUMBER OF BRANCHES ##
  n_branches <- nrow(milestone_network)

  ## NUMBER OF NUMBER OF END STATES ##
  n_end_states <- length(end_milestones)

  ## TIME AND TIME COURSE ##
  time <-
    if (!is.null(cell_info) && "simulationtime" %in% colnames(cell_info)) {
      setNames(cell_info$simulationtime, cell_info$cell_id)
    } else {
      NULL
    }

  timecourse <-
    if (!is.null(cell_info) && "timepoint" %in% colnames(cell_info)) {
      setNames(cell_info$timepoint, cell_info$cell_id)
    } else {
      NULL
    }

  # return output
  lst(
    start_milestones,
    start_cells,
    end_milestones,
    end_cells,
    grouping_assignment,
    grouping_network,
    marker_feature_ids,
    n_branches,
    time,
    timecourse,
    n_end_states
  )
}