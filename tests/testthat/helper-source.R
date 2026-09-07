# Sources project functions for tests (works from tests/testthat or project root)
root <- normalizePath(testthat::test_path("..", ".."), winslash = "/")
for (f in list.files(file.path(root, "R"), full.names = TRUE)) source(f)
