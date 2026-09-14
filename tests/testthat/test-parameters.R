test_that("parameter store is strict and dimension aware", {
  new_store <- rwa_internal("new_parameter_store")
  get_value <- rwa_internal("parameter_get")
  has_value <- rwa_internal("parameter_has")
  frame <- data.frame(
    parameter_key = c("A", "A"), dimension_1 = c("X", "Y"),
    dimension_2 = c("", "Z"), parameter_value = c(1.5, 2.5)
  )
  params <- new_store(frame)
  expect_equal(get_value(params, "A", "X"), 1.5)
  expect_true(has_value(params, "A", "Y", "Z"))
  expect_error(get_value(params, "MISSING"), class = "rwa_parameter_error")
  expect_error(new_store(rbind(frame, frame[1, ])), class = "rwa_parameter_error")
})

test_that("bundled regulatory configuration expands without defaults", {
  params <- rwa_internal("default_parameter_store")()
  expect_equal(rwa_internal("parameter_get")(params, "SA_CCF", "CLASS_1"), 1)
  expect_gte(length(params$values), 400)
})

