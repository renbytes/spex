# Consumer Tech Ad Attribution Analysis

This example demonstrates how to use `specds` to generate a complex, multi-table ad attribution pipeline using PySpark.

## Objective

The goal is to analyze user engagement and signup data to attribute new subscriptions to ad clicks. The analysis will calculate a full funnel of metrics, from initial ad impressions to attributed signups broken down by subscription plan.

## Prerequisites

1. The `specds` CLI must be installed and available in your system's PATH.
2. This example uses these sample data files:
   - `examples/consumer_tech/engagements.csv`
   - `examples/consumer_tech/signups.csv`
   - `examples/consumer_tech/products.csv`
3. You must have a `spec.toml` file that defines the analysis and points to the data files.

## Instructions

For complex analyses involving multiple datasets and metrics, using a spec file is the required approach.

1. **Organize Your Files:** Place the three `.csv` files and the `spec.toml` file in a dedicated directory, for example `examples/consumer_tech/`.

2. **Run the Generator:** From your terminal, execute the `generate` command, pointing it to your specification file using the `--spec` flag.

```bash
specds generate --spec examples/consumer_tech/spec.toml
```

## Output

After running the command, `specds` will create a new, self-organizing directory inside `generated_jobs/`. This directory will contain a complete, ready-to-run PySpark project with the following structure:

```
generated_jobs/
└── pyspark/
    └── ad-attributed-subscription-analysis/
        └── 20250720-193000__analyzes-user-engagement-and-signup-data-to-attribu/
            ├── job.py
            ├── functions.py
            ├── tests/
            │   ├── test_job.py
            │   └── test_functions.py
            └── README.md
```