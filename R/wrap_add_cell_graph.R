#' Constructs a trajectory using a graph between cells, by mapping cells onto a set of backbone cells.
#'
#' This function will generate the milestone_network and progressions.
#'
#' @param model The model to extend
#' @param cell_graph The edges between cells. Format: Data frame(from = character, to = character, length(optional) = numeric, directed(optional) = logical)
#' @param to_keep A named vector containing booleans containing
#'   whether or not a cell is part of the backbone. Or, alternatively a character vector containing the backbone cells
#' @param milestone_prefix A prefix to add to the id of the cell ids when they are used as milestones, in order to avoid any naming conflicts,
#' @param ... extra information to be stored in the wrapper.
#'
#' @export
#'
#' @return The trajectory model
#'
#' @importFrom testthat expect_is expect_true expect_equal
add_cell_graph <- function(
  model,
  cell_graph,
  to_keep,
  milestone_prefix = "milestone_",
  ...
) {
  requireNamespace("igraph")

  # check data wrapper
  testthat::expect_true(is_data_wrapper(model))

  # optionally add length and directed if not specified
  if (!"length" %in% colnames(cell_graph)) {
    cell_graph$length <- 1
  }
  if (!"directed" %in% colnames(cell_graph)) {
    cell_graph$directed <- FALSE
  }

  # check to_keep
  if (is.character(to_keep)) {
    cell_ids <- unique(c(cell_graph$from, cell_graph$to))
    to_keep <- (cell_ids %in% to_keep) %>% set_names(cell_ids)
  } else {
    cell_ids <- names(to_keep)
  }
  testthat::expect_is(to_keep, "logical")
  testthat::expect_true(all(cell_ids %in% model$cell_ids))
  testthat::expect_equal(sort(unique(c(cell_graph$from, cell_graph$to))), sort(names(to_keep)))

  # check cell_graph
  check_milestone_network(cell_ids, cell_graph)

  # check is_directed
  is_directed <- any(cell_graph$directed)

  # make igraph object
  ids <- names(to_keep)
  gr <- igraph::graph_from_data_frame(cell_graph %>% rename(weight = length), directed = is_directed, vertices = ids)

  # STEP 1: for each cell, find closest milestone
  v_keeps <- names(to_keep)[to_keep]
  dists <- igraph::distances(gr, to = v_keeps)
  closest_trajpoint <- v_keeps[apply(dists, 1, which.min)]

  # STEP 2: simplify backbone
  gr <- gr %>%
    igraph::induced.subgraph(v_keeps)

  milestone_ids <- igraph::V(gr)$name

  # STEP 3: Calculate progressions of cell_ids
  # determine which nodes were on each path
  milestone_network_proto <-
    igraph::as_data_frame(gr) %>%
    as_tibble() %>%
    rowwise() %>%
    mutate(
      path = igraph::shortest_paths(gr, from, to, mode = "out")$vpath %>% map(names)
    ) %>%
    ungroup()

  # for each node, find an edge which contains the node and
  # calculate its progression along that edge
  progressions <-
    milestone_network_proto %>%
    rowwise() %>%
    do(with(., data_frame(from, to, weight, node = path))) %>%
    ungroup %>%
    group_by(node) %>%
    slice(1) %>%
    mutate(
      percentage = ifelse(weight == 0, 0, igraph::distances(gr, from, node) / weight)
    ) %>%
    ungroup() %>%
    right_join(
      data_frame(cell_id = ids, node = closest_trajpoint),
      by = "node"
    ) %>%
    select(cell_id, from, to, percentage)

  # create output
  milestone_network <- milestone_network_proto %>%
    select(from, to, length = weight) %>%
    mutate(directed = is_directed)

  # rename milestones so the milestones don't have the
  # same names as the nodes
  renamefun <- function(x) {
    paste0(milestone_prefix, x) %>%
      set_names(names(x))
  }

  milestone_network <- milestone_network %>%
    mutate_at(c("from", "to"), renamefun)
  milestone_ids <- milestone_ids %>%
    renamefun
  progressions <- progressions %>%
    mutate_at(c("from", "to"), renamefun)

  # return output
  add_trajectory(
    model = model,
    milestone_ids = milestone_ids,
    milestone_network = milestone_network,
    divergence_regions = NULL,
    progressions = progressions,
    ...
  ) %>%
    simplify_trajectory()
}
