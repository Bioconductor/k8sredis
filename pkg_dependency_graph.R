package_dependencies <- tools::package_dependencies

trim <- function(deps, drop) {
    lvls = names(deps)
    df = data.frame(
        pkg = factor(rep(names(deps), lengths(deps)), levels = lvls),
        dep = unlist(deps, use.names = FALSE)
    )
    df = df[!df$dep %in% drop,, drop = FALSE]
    split(df$dep, df$pkg)
}

db = available.packages(repos = BiocManager::repositories())
soft = available.packages(repos = BiocManager::repositories()["BioCsoft"])
deps0 = package_dependencies(rownames(soft), db, recursive=TRUE)
deps1 = package_dependencies(
    union(names(deps0), unlist(deps0, use.names = FALSE)),
    db,
    recursive=TRUE
)

deps = deps1
inst = installed.packages()

## drop these on the first iteration
do = inst[,"Package"][inst[,"Priority"] %in% "base"]
deps = deps[!names(deps) %in% do]

length(deps)

table(lengths(deps))

library(RedisParam)

p <- RedisParam(workers = 5, jobname = "install_packages", is.worker = FALSE)

while (length(deps)) {
    deps = trim(deps, do)
    do = names(deps)[lengths(deps) == 0L]
    do = do[1:5]
    ## do the work here
    bplapply(do, function(x) BiocManager::install(x), BPPARAM = p)
    ##
    message(length(deps), " " , length(do))
    deps = deps[!names(deps) %in% do]
}
