pkg_depedencies <-
    function()
{
    db <- available.packages(repos = BiocManager::repositories())
    soft <- available.packages(
        repos = BiocManager::repositories()["BioCsoft"]
    )
    deps0 <- tools::package_dependencies(rownames(soft), db, recursive=TRUE)
    ## return deps
    tools::package_dependencies(
               union(names(deps0), unlist(deps0, use.names = FALSE)),
               db,
               recursive=TRUE
           )
}

## munge deps
trim <- function(deps, drop) {
    lvls <- names(deps)
    df <- data.frame(
        pkg = factor(rep(names(deps), lengths(deps)), levels = lvls),
        dep = unlist(deps, use.names = FALSE)
    )
    df <- df[!df$dep %in% drop,, drop = FALSE]
    split(df$dep, df$pkg)
}

kube_install <-
    function(pkg, lib, bin)
{
    tryCatch({
        .libPaths(c(lib, .libPaths()))
        ## Step1: Install
        cwd <- setwd(bin)
        on.exit(setwd(cwd))
        BiocManager::install(pkg, INSTALL_opts = "--build", update=FALSE, quiet=TRUE)
        Sys.info()[["nodename"]]
    }, error = function(e) {
        conditionMessage(e)
    })
}

run_install <-
    function(workers, lib_path, bin_path, deps, inst)
{
    library(RedisParam)
    ## drop these on the first iteration
    do <- inst[,"Package"][inst[,"Priority"] %in% "base"]
    deps <- deps[!names(deps) %in% do]

    while (length(deps)) {
        deps <- trim(deps, do)
        do <- names(deps)[lengths(deps) == 0L]
        p <- RedisParam(workers = workers, jobname = "demo",
                        is.worker = FALSE, tasks=length(do),
                        progressbar = TRUE)
        
        ## do the work here
        res <- bplapply(
            head(do), kube_install, BPPARAM = p,
            lib = lib_path,
            bin = bin_path
        )
        break
        message(length(deps), " " , length(do))
        deps <- deps[!names(deps) %in% do]
    }

    res
}


## Step 1: Create host directories if they don't exist already
dir.create("/host/library", recursive = TRUE)
dir.create("/host/binaries", recursive = TRUE)

## To reload quickly
deps_rds <- "pkg_dependencies.rds"
if (!file.exists(deps_rds)) {
    deps <- pkg_depedencies()
    saveRDS(deps, deps_rds)
}
deps <- readRDS(deps_rds)

inst <- installed.packages()

run_install(workers = 8,
            lib_path = "/host/library/",
            bin_path = "/host/binaries/",
            deps = deps,
            inst = inst)

## Create PACKAGES.gz and 
tools::write_PACAKGES("/host/binaries", addFiles=TRUE)

## overwrite PACAKGES.gz in the bucket.
## provide secret to gcloud for gsutil to transfer packages
AnVIL::gsutil_rsync("/host/binaries/", "gs://anvil-rstudio-bioconductor-test/0.99/3.11/src/contrib/", dry=FALSE)
