context("data frame swaps")
library(whisker)

test_that(" data.frame '<' swaped into {{{three_escapes}}} via whisker == '<' ", {

  if (!isNamespaceLoaded("whisker")) {
    stop("Package whisker needed for this function to work. Please install it.")
  }

  expect_true(
    run_pipeline(
      #the pipeline
      function(swap){
        query <- "{{{three_escapes}}}"
        whisker.render(query,swap)
      },
      #the swap
      data.frame(
        three_escapes = '<'
      )
    )
    #should equal '<'
    =="<"
  )

})

test_that(" data.frame '<' swaped into {{two_escapes}} via whisker == '&lt;", {

  if (!isNamespaceLoaded("whisker")) {
    stop("Package whisker needed for this function to work. Please install it.")
  }

  expect_true(
    run_pipeline(
      #the pipeline
      function(swap){
        query <- "{{two_escapes}}"
        whisker.render(query,swap)
      },
      #the swap
      data.frame(
        two_escapes = '<'
      )
    )
    #should equal '<'
    =="&lt;"
  )

})


test_that("single element dataframe is converted to a named list", {

  if (!isNamespaceLoaded("whisker")) {
    stop("Package whisker needed for this function to work. Please install it.")
  }

  expect_true(
    run_pipeline(
      #the pipeline
      function(swap){
        query <- "{{two_escapes}}"
        whisker.render(query,swap)
      },
      #the swap
      data.frame(
        two_escapes = 1
      )
    )
    #should equal 1
    =="1"
  )

})
