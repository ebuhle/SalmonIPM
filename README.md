# salmonIPM

This is the development repo for **salmonIPM**, an R package that fits integrated population models to data from anadromous Pacific salmonid populations using a hierarchical Bayesian framework implemented in [Stan](https://mc-stan.org/). Various models are available, representing alternative life histories and data structures as well as independent or hierarchically pooled populations. Users can specify stage-specific covariate effects and hyper-priors using formula syntax.

## Installation

1. Install and configure **rstan** (version 2.26 or higher) by following the instructions in the [RStan Getting Started](https://github.com/stan-dev/rstan/wiki/RStan-Getting-Started) vignette.

2. Install the current version of **salmonIPM** from GitHub using **devtools**. Because the repo is private for the time being, it is necessary to [generate a personal access token](https://github.com/settings/tokens) (PAT) and pass it to `install_github()` as discussed [here](https://stackoverflow.com/questions/21171142/how-to-install-r-package-from-private-repo-using-devtools-install-github).

```r
if(!require("devtools")) install.packages("devtools")
devtools::install_github("ebuhle/salmonIPM", auth_token = "my_PAT")
```

We recommend using multiple cores if available when installing **salmonIPM** to reduce compilation time. You can do this by setting the R environment variable `MAKEFLAGS` to `-jX`, where `X` is the number of cores. This can be done interactively using `Sys.setenv(MAKEFLAGS = "-jX")` or it can be specified in `.Renviron`.