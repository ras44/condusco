# condusco

## Overview

condusco lets you run a function iteratively, passing it the rows of a dataframe or the results of a query.

We call the functions condusco runs pipelines, and define a pipeline as a function that accepts a list of parameters and run a series of customized commands based on the values of the parameters.

The most common use case for condusco are data pipelines.  For data pipelines that primarily run SQL queries, we can template queries with a library (ie. [whisker](https://github.com/edwindj/whisker)), so that parametrized values are separated from the query logic.  We can then render the query with the appropriate values:

```
parameters <- source("params.R")

#define a pipeline
pipeline <- function(parameters){
 query <- "SELECT * FROM {{dataset}}.{{table_prefix}}_results LIMIT {{limit_size}}"
 query_with_params <- whisker.render(query, parameters)
 run_query(query_with_params)
}

# run the pipeline with the parameters in 'params.R'
pipeline(parameters)
```


condusco provides the following extensions in functionality to the above design pattern:
 - the user can provide a data-frame that contains multiple rows of parameters to be iteratively passed to the pipeline
 - the user can provide a query and each row of results is iteratively passed to the pipeline
 - any JSON-string parameter will be converted to an object before being passed to the pipeline
 

## Functions

|function|description|
|:--------------|:--------------|
|run_pipeline(pipeline, parameters)| iteratively pass each row of parameters to a pipeline, converting any JSON parameters to objects|
|run_pipeline_gbq(pipeline, query, project)|calls run_pipeline with the results of query executed via bigrquery|
|run_pipeline_dbi(pipline, query, con)|calls run_pipeline with the results of query executed via DBI|


## Installation

```{r, eval = FALSE}
install.packages("condusco")
```

## Features

*   Name-based substitution of local parameters into pipelines, iterating through rows of parameters:
    
    ```{r}
    run_pipeline(
      #the pipeline
      function(parameters){
        query <- "SELECT * FROM {{table_prefix}}_results;"
        print(whisker.render(query,parameters))
      },
      #the parameters
      data.frame(
        table_prefix = c('batman', 'robin')
      )
    )
    ```



*   Name-based substitution of query-results into pipelines, iterating through rows of parameters dataframe:
    
    ```{r}
    con <- dbConnect(RSQLite::SQLite(), ":memory:")

    pipeline <- function(parameters){

      query <-"
        SELECT count(*) as n_hits 
        FROM user_hits 
        WHERE date(date_time) BETWEEN date('{{{date_low}}}') AND date('{{{date_high}}}')
      ;"

      whisker.render(query,parameters)

    }

    run_pipeline_dbi(pipeline,
      "SELECT date('now', '-5 days') as date_low, date('now') as date_high",
      con
    )

    dbDisconnect(con)
    ```


*   Dynamic query generation based on JSON strings:
    
    ```{r}
    con <- dbConnect(RSQLite::SQLite(), ":memory:")
    mtcars
    dbWriteTable(con, "mtcars", mtcars)

    #for each cylinder count, count the number of top 5 hps it has
    pipeline <- function(swap){

      query <- "SELECT
        {{#list}}
          SUM(CASE WHEN hp='{{val}}' THEN 1 ELSE 0 END )as n_hp_{{val}},
        {{/list}}
        cyl
        FROM mtcars
        GROUP BY cyl
      ;"

      print(whisker.render(query,swap))

      print(
        dbGetQuery(
          con,
          whisker.render(query,swap)
        )
      )
    }


    #pass the top 5 most common hps as val parameters
    run_pipeline_dbi(
      pipeline,
      '
      SELECT "[" || GROUP_CONCAT("{ ""val"": """ || hp ||  """ }") || "]" AS list
      FROM (
        SELECT 
          CAST(hp as INTEGER) as HP,
          count(hp) as cnt
        FROM mtcars 
        GROUP BY hp
        ORDER BY cnt DESC
        LIMIT 5
      )
      ',
      con
    )


    dbDisconnect(con)
    ```



# Google BigQuery Examples

This is not available as a vignette because it requires user authentication

```{r }
library(whisker)
library(bigrquery)
library(condusco)

#Set GBQ project
project <- ''

#Set the following options for GBQ authentication on a cloud instance
options("httr_oauth_cache" = "~/.httr-oauth")
options(httr_oob_default=TRUE)

#Run the below query to authenticate and write credentials to .httr-oauth file
query_exec("SELECT 'foo' as bar",project=project);

```



## Dynamically generated queries via JSON
If list is defined, convert the JSON string to an object and iterate through name1,name2 pairs. 
This illustrates how to dynamically generate a query based on the JSON constructed by another query.
In this example, we create a trivial JSON object manually.  We'll use a dynamically generated JSON object in the next example.
```{r}
pipeline <- function(params){

  query <- "SELECT {{{value}}} as dollars_won,
    {{#list}}
    '{{name1}}' as {{name2}},
    {{/list}}
    {{{field}}} as field
  FROM {{table_name}}
  LIMIT {{limit_size}}
  ;"

  res <- query_exec(whisker.render(query,params),
                    project=project,
                    use_legacy_sql = FALSE
  );
  
  print(res)
}

project

run_pipeline_gbq(pipeline, "
    SELECT 1000 as value,
    'word' as field,
    '[{\"name1\":\"foo\", \"name2\":\"bar\"},{\"name1\":\"foo2\", \"name2\":\"bar2\"}]' as list,
    'publicdata:samples.shakespeare' AS table_name,
    5 AS limit_size
", project)

```



## Feature Generation Query
Create features for each of the repos describing how many commits the top 10 commiters made to that repo.
```{r}
pipeline <- function(params){

  query <- "
    SELECT
      {{#list}}
        SUM(CASE WHEN author.name ='{{name}}' THEN 1 ELSE 0 END) as n_{{name_clean}},
      {{/list}}
      repo_name
    FROM `bigquery-public-data.github_repos.sample_commits`
    GROUP BY repo_name
  ;"

  res <- query_exec(
    whisker.render(query,params),
    project=project,
    use_legacy_sql = FALSE
  );
  
  print(res)
}

run_pipeline_gbq(pipeline, "
  SELECT CONCAT('[',
  STRING_AGG(
    CONCAT('{\"name\":\"',name,'\",'
      ,'\"name_clean\":\"', REGEXP_REPLACE(name, r'[^[:alpha:]]', ''),'\"}'
    )
  ),
  ']') as list
  FROM (
    SELECT author.name,
      COUNT(commit) n_commits
    FROM `bigquery-public-data.github_repos.sample_commits`
    GROUP BY 1
    ORDER BY 2 DESC
    LIMIT 10
  )
",
project,
use_legacy_sql = FALSE
)

```


