% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/wrap_add_prior_information.R
\name{add_prior_information}
\alias{add_prior_information}
\title{Add prior information to a data wrapper}
\usage{
add_prior_information(dataset, start_id = NULL, end_id = NULL,
  groups_id = NULL, groups_network = NULL, features_id = NULL,
  groups_n = NULL, start_n = NULL, end_n = NULL,
  timecourse_continuous = NULL, timecourse_discrete = NULL,
  verbose = TRUE)
}
\arguments{
\item{dataset}{A data wrapper to extend upon.}

\item{start_id}{The start cells}

\item{end_id}{The end cells}

\item{groups_id}{The grouping of cells, a dataframe with cell_id and group_id}

\item{groups_network}{The network between groups, a dataframe with from and to}

\item{features_id}{The features (genes) important for the trajectory}

\item{groups_n}{Number of branches}

\item{start_n}{Number of start states}

\item{end_n}{Number of end states}

\item{timecourse_continuous}{The time for every cell}

\item{timecourse_discrete}{The time for every cell in groups}

\item{verbose}{Whether or not to print informative messages}
}
\description{
Note that the given data wrapper requires a trajectory and expression values
to have been added already.
}
