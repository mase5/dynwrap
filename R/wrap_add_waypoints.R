#' Add or create waypoints to a trajectory
#'
#' @inheritParams select_waypoints
#' @importFrom testthat expect_true
#'
#' @export
add_waypoints <- function(
  trajectory,
  n_waypoints = 100,
  resolution = sum(trajectory$milestone_network$length)/n_waypoints
) {
  testthat::expect_true(is_wrapper_with_trajectory(trajectory))

  waypoints <- with(trajectory, select_waypoints(
    trajectory,
    n_waypoints,
    resolution
  ))

  # create output structure
  trajectory %>% extend_with(
    "dynwrap::with_waypoints",
    waypoints = waypoints
  )
}

#' Test whether an trajectory is a data_wrapper and waypoints
#'
#' @param trajectory The trajectory to be tested.
#'
#' @export
is_wrapper_with_waypoints <- function(trajectory) {
  is_wrapper_with_trajectory(trajectory) && "dynwrap::with_waypoints" %in% class(trajectory)
}

#' Select the waypoints
#'
#' Waypoints are spread equally over the whole trajectory
#'
#' @param trajectory Wrapper with trajectory
#' @param n_waypoints The number of waypoints
#' @param resolution The resolution of the waypoints, measured in the same units as the lengths of the milestone network edges, will be automatically computed using n_waypoints
#'
#' @export
select_waypoints <- function(
  trajectory,
  n_waypoints = 100,
  resolution = sum(trajectory$milestone_network$length)/n_waypoints
) {
  # create milestone waypoints
  waypoint_milestone_percentages_milestones <- tibble(
    milestone_id = trajectory$milestone_ids,
    waypoint_id = paste0("W", milestone_id),
    percentage = 1
  )

  # create uniform progressions
  # waypoints which lie on a milestone will get a special name, so that they are the same between milestone network edges
  waypoint_progressions <- trajectory$milestone_network %>%
    mutate(percentage = map(length, ~c(seq(0, ., min(resolution, .))/., 1))) %>%
    select(-length, -directed) %>%
    unnest(percentage) %>%
    group_by(from, to, percentage) %>% # remove duplicate waypoints
    filter(row_number() == 1) %>%
    ungroup() %>%
    mutate(waypoint_id = case_when(
      percentage == 0 ~ paste0("MILESTONE_W", from),
      percentage == 1 ~ paste0("MILESTONE_W", to),
      TRUE ~ paste0("W", row_number())
    )
  )

  # create waypoint percentages from progressions
  waypoint_milestone_percentages <- waypoint_progressions %>%
    group_by(waypoint_id) %>%
    filter(row_number() == 1) %>%
    rename(cell_id = waypoint_id) %>%
    convert_progressions_to_milestone_percentages(
      "this argument is unnecessary, I can put everything I want in here!",
      trajectory$milestone_ids,
      trajectory$milestone_network,
      .
    ) %>%
    rename(waypoint_id = cell_id)

  # calculate distance
  waypoint_geodesic_distances <- compute_tented_geodesic_distances(trajectory, waypoint_milestone_percentages = waypoint_milestone_percentages)

  # also create network between waypoints
  waypoint_network <- waypoint_progressions %>%
    group_by(from, to) %>%
    mutate(from_waypoint = waypoint_id, to_waypoint = lead(waypoint_id, 1)) %>%
    drop_na() %>% ungroup() %>%
    select(from = from_waypoint, to = to_waypoint, from_milestone_id = from, to_milestone_id = to)

  # create waypoints and their properties
  waypoints <- waypoint_milestone_percentages %>%
    group_by(waypoint_id) %>%
    arrange(-percentage) %>%
    filter(row_number() == 1) %>%
    ungroup() %>%
    mutate(milestone_id = ifelse(percentage == 1, milestone_id, NA)) %>%
    select(-percentage)

  lst(
    milestone_percentages = waypoint_milestone_percentages,
    progressions = waypoint_progressions,
    geodesic_distances = waypoint_geodesic_distances,
    waypoint_network,
    waypoints
  )
}
