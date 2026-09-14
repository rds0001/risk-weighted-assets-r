"""Export the canonical NumPy PCG64/Ziggurat standard-normal path.

This development-only bridge freezes the stochastic reference path used by
the Python 1.0.0 implementation.  It is not included in the CRAN package.
"""

import json

import numpy as np


SEED = 20260831
PATHS = 5000

rng = np.random.default_rng(SEED)
print(
    json.dumps(
        {
            "generator": "numpy.random.default_rng/PCG64",
            "normal_sampler": "NumPy standard_normal (Ziggurat)",
            "numpy_version": np.__version__,
            "seed": SEED,
            "paths": PATHS,
            "values": rng.normal(0.0, 1.0, PATHS).tolist(),
        },
        separators=(",", ":"),
    )
)
