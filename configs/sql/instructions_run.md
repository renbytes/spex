### 1. Configure ourdbt profile

This project requires a `profiles.yml` file to connect to ourdata warehouse. By default, dbt looks for this file in `~/.dbt/`.

### 2. Run the analysis

```bash
# Install dependencies
dbt deps

# Run dbt models
dbt run

# Test data quality
dbt test
```

### 3. View Documentation

```bash
# Generate documentation website
dbt docs generate

# Serve the documentation locally
dbt docs serve
```