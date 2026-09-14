.PHONY: document test check build as-cran manual verify clean

document:
	Rscript -e 'roxygen2::roxygenise()'

test:
	Rscript -e 'devtools::test()'

check:
	Rscript -e 'devtools::check(error_on = "warning")'

build:
	R CMD build .

as-cran: build
	R CMD check --as-cran riskweightedassets_1.0.0.tar.gz

manual:
	R CMD Rd2pdf --no-preview --force --output=riskweightedassets-reference.pdf .

verify:
	Rscript tools/verify-source-tree.R

clean:
	Rscript tools/clean-build.R
