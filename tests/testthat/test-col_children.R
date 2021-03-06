# tests for col_children fxn in taxize
context("col_children")

temp1 <- col_children(name="Apis")
temp2 <- col_children(name="Puma")
temp3 <- col_children(name="Helianthus")
temp4 <- col_children(name="Animalia")
temp5 <- col_children(name="Plantae")
temp11 <- col_children(name="Accipiter striatus")
temp12 <- col_children(name=c("Apis","Accipiter striatus","Collomia","Buteo"))
temp13 <- col_children(id=c(2346405,2344165,2346405), checklist = '2012')

test_that("col_children returns the correct class", {
	expect_is(temp1[[1]][1,3], "character")
	expect_that(temp1, is_a("list"))
	expect_that(temp2, is_a("list"))
	expect_that(temp3, is_a("list"))
	expect_that(temp4, is_a("list"))
	expect_that(temp5, is_a("list"))
	expect_that(temp11, is_a("list"))
	expect_that(temp12, is_a("list"))
	expect_that(temp1[[1]], is_a("data.frame"))
	expect_that(temp1[[1]], is_a("data.frame"))
	expect_that(temp1[[1]], is_a("data.frame"))
	expect_that(temp1[[1]], is_a("data.frame"))
	expect_that(temp1[[1]], is_a("data.frame"))
})

test_that("col_children returns the correct dimensions", {
	expect_equal(NCOL(temp1[[1]]), 3)
	expect_equal(NCOL(temp2[[1]]), 3)
	expect_equal(NCOL(temp3[[1]]), 3)
	expect_equal(NCOL(temp4[[1]]), 3)
	expect_equal(NCOL(temp5[[1]]), 3)

	expect_equal(length(temp11), 1)
	expect_equal(length(temp12), 4)
})

test_that("missing/wrong data given returns result", {
  expect_equal(nrow(col_children(name="")[[1]]), 0)
  expect_equal(nrow(col_children(name="asdfasdfdf")[[1]]), 0)
  expect_is(col_children(), "list")
})
