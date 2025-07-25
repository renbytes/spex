# Subscription Attribution

User signup flow

## Overview

This project was automatically generated using the `specds` tool. It contains a complete, tested data science pipeline with modern Python tooling and best practices.

## Project Structure

```
20250721-040034__user-signup-flow/
├── ├── job.py
├── functions.py
├── data_validation.py
├── visualizations.py
├── config.py
├── pyproject.toml
├── environment.yml
├── data/
│   ├── raw/                 # Input data files
│   ├── processed/           # Cleaned and transformed data
│   └── external/            # Reference data
├── outputs/
│   ├── reports/             # Generated reports (HTML, PDF)
│   ├── visualizations/      # Charts and plots
│   └── models/              # Saved models or analysis results
├── notebooks/               # Jupyter notebooks for exploration
├── tests/                   # Unit and integration tests
├── logs/                    # Application logs
└── scripts/                 # Utility scripts
```

## Getting Started

### 1. Set up the conda environment

```bash
# Create and activate conda environment with Java&#x2F;Spark
conda env create -f environment.yml
conda activate pyspark-analysis-env

# Install project in development mode
make install-dev
```

### 2. Check Installation

After setup, verify that Spark is correctly installed and configured:

```bash
make check-spark
```

### 2. Run the analysis

```bash
# Run with a local Spark master
make run-local

# Or run with auto-detected configuration
make run
```

### 3. Development tools

```bash
Bash
# Start PySpark interactive shell
make spark-shell

# Start Jupyter Lab with a Spark kernel
make notebook

# Run Spark-specific tests
make test-spark
```


## Modern Python Features

This project uses modern Python development practices:

- **📦 pyproject.toml**: Modern Python project configuration
- **🐍 conda environments**: Reproducible data science environments  
- **🧪 pytest**: Comprehensive testing framework
- **🎨 black**: Automatic code formatting
- **🔍 mypy**: Static type checking
- **🪝 pre-commit**: Git hooks for code quality
- **📓 Jupyter**: Interactive development and exploration

## Data Sources

- **app_events**: Raw user engagement events, including ad impressions and clicks.
- **signups**: Subscription signup events, including organic and potentially attributed signups.
- **products**: Product metadata mapping product_id to plan names.


## Metrics Calculated

- **total_ad_impressions**: A simple count of events from the engagements table where event_name is &#x27;ad_impression&#x27;.
- **total_ad_clicks**: A simple count of events from the engagements table where event_name is &#x27;ad_click&#x27;.
- **total_signups**: A simple count of all rows in the signups table.
- **attributed_signups**: The core attribution logic. For each signup, find the most recent &#x27;ad_click&#x27; event from the same user that occurred *before* the signup_timestamp. If such a click exists, the signup is attributed. Count the distinct attributed user_ids.
- **click_to_signup_rate**: The percentage of total ad clicks that resulted in an attributed signup. Calculated as (attributed_signups &#x2F; total_ad_clicks) * 100.
- **attributed_signups_by_plan**: Join the attributed signups with the products table on product_id. Then, count the number of attributed signups for each human-readable product plan (e.g., &#x27;Annual Streaming&#x27;, &#x27;Monthly Streaming&#x27;).


## Development Workflow

```bash
# Format and lint code
make format lint

# Run tests
make test

# Quick development checks
make quick-test

# Clean up generated files
make clean
```

## Generated on

2025-07-21 04:00:34 UTC

## Next Steps

1. **📁 Add your data**: Place data files in `data/raw/`
2. **⚙️ Configure**: Update paths in configuration files if needed
3. **🏃 Run analysis**: Execute `make run` to generate insights
4. **📊 Check results**: Review outputs in `outputs/` directory
5. **🎨 Customize**: Modify visualizations and reports as needed
6. **🧪 Test**: Add your own tests in the `tests/` directory

## Troubleshooting

- **Environment issues**: Try `make clean-all && make setup`
- **Missing dependencies**: Run `make update-deps`
- **Test failures**: Check `make status` for environment info

---

*Generated by [specds](https://github.com/renbytes/specds) - The spec-driven data science pipeline generator*