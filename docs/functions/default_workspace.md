# `default_workspace()`

Resolves, but does not create, the default workspace.

```r
Sys.setenv(RWA_WORKSPACE = "/controlled/path")
workspace <- default_workspace()
```

When `RWA_WORKSPACE` is unset, the default is `rwa-workspace` below the current
working directory. Library integrations should generally pass explicit paths.
