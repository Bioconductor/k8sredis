## Find package dependencies
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
    browser()
    .libPaths(c(lib, .libPaths()))
    ## Step1: Install
    BiocManager::install(pkg)
    Sys.info()[["nodename"]]

    ## Step2: Tar it up
    ##    BiocManager::install(pkg, INSTALL_opts = "-build")
    devtools::build(pkg, binary=TRUE, path = bin)
}

run_install <-
    function(workers, lib_path, bin_path, deps, inst)
{
    library(RedisParam)
    p <- RedisParam(workers = workers,
                    jobname = "install",
                    is.worker = FALSE)

    ## drop these on the first iteration
    do <- inst[,"Package"][inst[,"Priority"] %in% "base"]
    deps <- deps[!names(deps) %in% do]

    while (length(deps)) {
        deps <- trim(deps, do)
        do <- names(deps)[lengths(deps) == 0L]
        ## do the work here
        message("here")
        res <- bplapply(
            do[2,3], kube_install, BPPARAM = p,
            lib = lib_path,
            bin = bin_path
        )
        break
        message(length(deps), " " , length(do))
        deps <- deps[!names(deps) %in% do]
    }
}


## Step 1: Create host directories if they don't exist already
dir.create("/host/library", recursive = TRUE)
dir.create("/host/binaries", recursive = TRUE)

## Test
deps <- pkg_depedencies()
inst <- installed.packages()

library <- "/host/library/"
binanies <- "/host/binaries/"

run_install(workers = 5,
            lib_path = library,
            bin_path = binaries,
            deps = deps,
            inst = inst)
