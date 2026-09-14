# Architecture

## Design principles

The package separates immutable resources, validation, temporal selection,
calculation and persistence. All regulatory values are data, all result rows
carry version context, and the public API never mutates package resources.
Python is not used at runtime.

## Component map

1. `config.R`, `parameters.R` and package YAML load versioned rules and expose
   strict three-dimensional parameter lookup.
2. `contracts.R` normalises dates, validates keys, references, intervals and
   bounded values, then selects the official bitemporal snapshot.
3. `formulas.R` contains side-effect-free numerical primitives.
4. `engine_*.R` calculate credit, CCR/CVA, securitisation, market,
   operational, capital, IRRBB and ICAAP modules.
5. `pipeline.R` orchestrates applied and fully-loaded runs, controls, lineage
   and headline metrics.
6. `excel_io.R` is the only canonical spreadsheet boundary.
7. `synthetic.R`, `resources.R` and `workspace.R` materialise immutable
   synthetic resources into caller-controlled locations.
8. `api.R` exposes the stable integration surface and translates unexpected
   errors into the package condition hierarchy.

## Calculation flow

```text
R list or 16 XLSX inputs
          |
          v
schema + reference + range validation
          |
          v
official bitemporal snapshot and designation overlay
          |
          +-----------------------+
          |                       |
          v                       v
applied rule set           fully-loaded rule set
          |                       |
          +-----------+-----------+
                      v
  34 result tables + metrics + 12 controls + lineage
                      |
             optional XLSX/JSON output
```

## Determinism

In-memory run IDs are derived from table contents, implementation fingerprint
and package version unless supplied by the caller. Dataset runs use input-file,
code and version hashes. The canonical IRRBB reference uses a frozen NumPy
PCG64/Ziggurat path so that R and Python golden results agree; non-reference
seeds use an isolated R stream and do not alter `.Random.seed`.

## Side effects

`calculate_tables()`, list functions and `default_workspace()` are read-only.
The three write-capable public functions require an explicit destination:
`create_workspace()`, `generate_synthetic_dataset()` and
`calculate_dataset()`. Examples and tests write only below `tempdir()`.

## Dependency boundary

Runtime dependencies are CRAN packages only: `digest`, `jsonlite`, `openxlsx`
and `yaml`, plus base R. Development tooling and the historical Python source
are not required by installed users and are excluded from the source tarball.
