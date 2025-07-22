# Renewable Energy Production Analysis

This example demonstrates how to use `specds` to generate a Python-based analytics pipeline for analyzing renewable energy production data.

## Objective

The goal is to analyze daily energy production from renewable sources (solar and wind) to calculate total production metrics grouped by energy source type. This analysis helps understand energy output patterns and source performance.

## Prerequisites

1. The `specds` CLI must be installed and available in your system's PATH.
2. This example uses this sample data file:
   - `examples/energy/sample_data.csv` - Daily renewable energy production data
3. You must have a `spec.toml` file that defines the analysis and points to the data file.

## Sample Data Overview

**Renewable Production (`sample_data.csv`):**
- `date`: Date of energy production
- `source_type`: Type of renewable energy source (solar, wind, etc.)
- `production_mwh`: Energy production in megawatt-hours

The sample data covers multiple days of solar and wind energy production, allowing for aggregation and comparison analysis.

## Instructions

This example uses Python generation with pandas for data analysis workflows.

1. **Organize Your Files:** Place the `.csv` file and the `spec.toml` file in the `examples/energy/` directory.

2. **Run the Generator:** From your terminal, execute the `generate` command, pointing it to your specification file using the `--spec` flag.

```bash
specds generate --spec examples/energy/spec.toml
```

## Output

After running the command, `specds` will create a new directory inside `generated_jobs/` containing a complete Python analytics project:

```
generated_jobs/
└── python/
    └── energy-production-analysis/
        └── 20250720-193000__analyzes-daily-energy-production-from-renewable-so/
            ├── job.py
            ├── functions.py
            ├── tests/
            │   ├── test_job.py
            │   └── test_functions.py
            └── README.md
```

## Expected Results

The analysis will produce total energy production metrics including:
- Total megawatt-hours produced by source type (solar vs. wind)
- Production summaries and comparisons
- Data validation and quality checks

## Use Cases

This type of analysis is valuable for:
- **Energy Planning:** Understanding renewable source productivity
- **Performance Monitoring:** Tracking solar and wind farm output
- **Resource Allocation:** Optimizing energy portfolio mix
- **Sustainability Reporting:** Measuring renewable energy goals
- **Grid Management:** Planning energy distribution and storage
