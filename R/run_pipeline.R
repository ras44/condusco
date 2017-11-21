#' Runs user-provided pipeline for each row of arguments in parameters, converting any JSON
#' strings to objects
#'
#' @param pipeline User-provided function with one argument, a dataframe
#' @param parameters An dataframe of fields to convert to json
#'
#' @import assertthat jsonlite
#'
#' @examples
#'
#' library(whisker)
#'
#' run_pipeline(
#'   function(params){
#'    query <- "SELECT result FROM {{table_prefix}}_results;"
#'    whisker.render(query,params)
#'  },
#'  data.frame(
#'    table_prefix = c('batman', 'robin')
#'  )
#')
#'
#' @export
run_pipeline <- function(pipeline, parameters){

  assert_that(length(parameters)>0)

  #For each row in parameters, convert each column to json object if it contains json
  apply(parameters, 1, function(row){
    lr <- as.list(row)
    for(n in names(lr)){
      tryCatch({
        lr[[n]] <- fromJSON(get(n,lr), simplifyVector=FALSE)
      },error=function(e){
        lr[[n]] <- toString(get(n,lr))
      }
      )
    }

    pipeline(lr)
  })

}


#' A wrapper for running pipelines with a BigQuery invocation query
#'
#' @param pipeline User-provided function with one argument, one row of query results
#' @param query A query to execute in Google BigQuery
#' @param project The Google BigQuery project to bill
#' @param ... Additional arguments passed to query_exec()
#'
#' @import bigrquery
#'
#' @examples
#'
#'\dontrun{
#' library(whisker)
#'
#' #Set GBQ project
#' project <- ''
#'
#' #Set the following options for GBQ authentication on a cloud instance
#' options("httr_oauth_cache" = "~/.httr-oauth")
#' options(httr_oob_default=TRUE)
#'
#' #Run the below query to authenticate and write credentials to .httr-oauth file
#' query_exec("SELECT 'foo' as bar",project=project);
#'
#' pipeline <- function(params){
#'
#'   query <- "
#'     SELECT
#'       {{#list}}
#'         SUM(CASE WHEN author.name ='{{name}}' THEN 1 ELSE 0 END) as n_{{name_clean}},
#'       {{/list}}
#'       repo_name
#'     FROM `bigquery-public-data.github_repos.sample_commits`
#'     GROUP BY repo_name
#'   ;"
#'
#'   res <- query_exec(
#'     whisker.render(query,params),
#'     project=project,
#'     use_legacy_sql = FALSE
#'   );
#'
#'   print(res)
#' }
#'
#' run_pipeline_gbq(pipeline, "
#'   SELECT CONCAT('[',
#'   STRING_AGG(
#'     CONCAT('{\"name\":\"',name,'\",'
#'       ,'\"name_clean\":\"', REGEXP_REPLACE(name, r'[^[:alpha:]]', ''),'\"}'
#'     )
#'   ),
#'   ']') as list
#'   FROM (
#'     SELECT author.name,
#'       COUNT(commit) n_commits
#'     FROM `bigquery-public-data.github_repos.sample_commits`
#'     GROUP BY 1
#'     ORDER BY 2 DESC
#'     LIMIT 10
#'   )
#' ",
#' project,
#' use_legacy_sql = FALSE
#' )
#'}
#' @export
run_pipeline_gbq <- function(pipeline, query, project, ... ){

  #run the query to generate the intitialization table
  parameters <- query_exec(query, project=project, ...)

  run_pipeline(pipeline, parameters)

}

#' A wrapper for running pipelines with a DBI connection invocation query
#'
#' @param pipeline User-provided function with one argument, one row of query results
#' @param query A query to execute via the DBI connection
#' @param con The DBI connection
#' @param ... Additional arguments passed to dbSendQuery() and dbFetch()
#'
#' @import DBI
#'
#' @examples
#'
#'\dontrun{
#' library(whisker)
#' library(RSQLite)
#'
#' con <- dbConnect(RSQLite::SQLite(), ":memory:")
#'
#' dbWriteTable(con, "mtcars", mtcars)
#'
#' #for each cylinder count, count the number of top 5 hps it has
#' pipeline <- function(params){
#'
#'   query <- "SELECT
#'     {{#list}}
#'     SUM(CASE WHEN hp='{{val}}' THEN 1 ELSE 0 END )as n_hp_{{val}},
#'   {{/list}}
#'     cyl
#'     FROM mtcars
#'     GROUP BY cyl
#'   ;"
#'
#'
#'   dbGetQuery(
#'     con,
#'     whisker.render(query,params)
#'   )
#' }
#'
#'
#' #pass the top 5 most common hps as val params
#' run_pipeline_dbi(
#'   pipeline,
#'   '
#'   SELECT "[" || GROUP_CONCAT("{ ""val"": """ || hp ||  """ }") || "]" AS list
#'   FROM (
#'     SELECT
#'       CAST(hp as INTEGER) as HP,
#'       count(hp) as cnt
#'     FROM mtcars
#'     GROUP BY hp
#'     ORDER BY cnt DESC
#'     LIMIT 5
#'   )
#'   ',
#'   con
#' )
#'
#'
#' dbDisconnect(con)
#'}
#' @export
run_pipeline_dbi <- function(pipeline, query, con, ...){

  rs <- dbSendQuery(con, query, ...)
  parameters <- dbFetch(rs, ...)

  dbClearResult(rs, ...)

  run_pipeline(pipeline, parameters)

}
