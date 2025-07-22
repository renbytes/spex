### 1. Set up the conda environment

```bash
# Create and activate conda environment with Java/Spark
conda env create -f environment.yml
conda activate pyspark-analysis-env

# Install project in development mode
make install-dev
```