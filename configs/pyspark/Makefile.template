# Makefile for PySpark data science project using conda and pyproject.toml

.PHONY: help setup install install-dev test test-spark lint format run run-local run-cluster clean notebook spark-shell check-spark visualize

CONDA_ENV_NAME = pyspark-analysis-env
PYTHON = python
SPARK_LOCAL_IP = 127.0.0.1

help:
	@echo "🚀 Available commands:"
	@echo ""
	@echo "📦 Environment Management:"
	@echo "  setup         - Create conda environment with Java and Spark"
	@echo "  install       - Install project in current environment"
	@echo "  install-dev   - Install with development dependencies"
	@echo ""
	@echo "🧪 Development:"
	@echo "  test          - Run all tests with coverage"
	@echo "  test-spark    - Run Spark-specific tests"
	@echo "  lint          - Run all linting checks"
	@echo "  format        - Format code with black"
	@echo ""
	@echo "🏃 Execution:"
	@echo "  run           - Run analysis with auto-detected Spark mode"
	@echo "  run-local     - Run with local Spark master"
	@echo "  run-cluster   - Run with cluster configuration"
	@echo "  visualize     - Generate visualizations from the analysis output"
	@echo "  check-spark   - Verify Spark installation and configuration"
	@echo ""
	@echo "🛠️  Development Tools:"
	@echo "  notebook      - Start Jupyter Lab with Spark kernel"
	@echo "  spark-shell   - Start PySpark interactive shell"
	@echo ""
	@echo "🧹 Maintenance:"
	@echo "  clean         - Clean up generated files and Spark artifacts"

setup:
	@echo "🔧 Setting up conda environment with Java and Spark..."
	conda env create -f environment.yml
	@echo ""
	@echo "✅ Environment created successfully!"
	@echo "🔄 Activate with: conda activate $(CONDA_ENV_NAME)"
	@echo "📦 Then run: make install && make check-spark"

install:
	@echo "📦 Installing project..."
	pip install -e .

install-dev:
	@echo "📦 Installing project with development dependencies..."
	pip install -e ".[dev,aws,ml]"

test:
	@echo "🧪 Running all tests..."
	pytest tests/ -v --cov=. --cov-report=html --cov-report=term-missing

test-spark:
	@echo "⚡ Running Spark-specific tests..."
	pytest tests/ -v -m "spark" --cov=. --cov-report=term-missing

lint:
	@echo "🔍 Running linting checks..."
	@echo "Running flake8..."
	flake8 .
	@echo "Running mypy..."
	mypy .
	@echo "Checking black formatting..."
	black --check .

format:
	@echo "🎨 Formatting code..."
	black .
	@echo "✅ Code formatted!"

check-spark:
	@echo "🔍 Checking Spark installation..."
	@$(PYTHON) -c "import findspark; findspark.init(); import pyspark; print(f'✅ PySpark {pyspark.__version__} ready')"
	@$(PYTHON) -c "from pyspark.sql import SparkSession; spark = SparkSession.builder.appName('test').master('local[1]').getOrCreate(); print(f'✅ Spark Context: {spark.sparkContext.version}'); spark.stop()"

run:
	@echo "🏃 Running PySpark analysis (auto-detecting configuration)..."
	$(PYTHON) job.py

run-local:
	@echo "🏃 Running PySpark analysis with local master..."
	SPARK_LOCAL_IP=$(SPARK_LOCAL_IP) PYSPARK_SUBMIT_ARGS="--master local[*] pyspark-shell" $(PYTHON) job.py

run-cluster:
	@echo "🏃 Running PySpark analysis with cluster configuration..."
	@echo "🔧 Make sure to set SPARK_MASTER_URL environment variable"
	@if [ -z "$$SPARK_MASTER_URL" ]; then \
		echo "❌ SPARK_MASTER_URL not set. Example: export SPARK_MASTER_URL=spark://master:7077"; \
		exit 1; \
	fi
	PYSPARK_SUBMIT_ARGS="--master $$SPARK_MASTER_URL pyspark-shell" $(PYTHON) job.py

visualize:
	@echo "🎨 Generating visualizations..."
	@if [ -f "visualizations.py" ]; then \
		$(PYTHON) visualizations.py; \
		echo "✅ Visualizations saved to the 'outputs/visualizations' directory."; \
	else \
		echo "❌ No visualization script found (visualizations.py)"; \
	fi

notebook:
	@echo "📓 Starting Jupyter Lab with PySpark kernel..."
	@echo "🌐 Will open at: http://localhost:8888"
	@echo "⚡ Spark UI will be available at: http://localhost:4040"
	PYSPARK_DRIVER_PYTHON=jupyter PYSPARK_DRIVER_PYTHON_OPTS="lab --no-browser --port=8888" pyspark

spark-shell:
	@echo "🐚 Starting PySpark interactive shell..."
	@echo "💡 Try: spark.range(10).show()"
	pyspark

clean:
	@echo "🧹 Cleaning up..."
	find . -type f -name "*.pyc" -delete
	find . -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
	find . -type d -name "*.egg-info" -exec rm -rf {} + 2>/dev/null || true
	rm -rf build/ dist/ .pytest_cache/ .coverage htmlcov/
	rm -rf spark-warehouse/ metastore_db/ derby.log
	rm -rf outputs/reports/* outputs/visualizations/* outputs/models/*
	find . -name ".DS_Store" -delete 2>/dev/null || true
	@echo "✅ Cleanup complete!"

# Development shortcuts
dev-setup: setup install-dev
	@echo "🎉 Development environment fully set up!"
	@make check-spark

# Spark debugging
spark-logs:
	@echo "📋 Recent Spark application logs:"
	@if [ -d "logs" ]; then \
		find logs -name "*.log" -type f -exec tail -n 20 {} \; 2>/dev/null || echo "No log files found"; \
	else \
		echo "No logs directory found"; \
	fi

# Environment status
status:
	@echo "📊 Environment Status:"
	@echo "Current conda env: $${CONDA_DEFAULT_ENV:-'(none)'}"
	@echo "Python version: $(shell python --version 2>/dev/null || echo 'Not found')"
	@echo "Java version: $(shell java -version 2>&1 | head -n1 || echo 'Not found')"
	@echo ""
	@if conda env list | grep -q "$(CONDA_ENV_NAME)"; then \
		echo "✅ Conda environment '$(CONDA_ENV_NAME)' exists"; \
	else \
		echo "❌ Conda environment '$(CONDA_ENV_NAME)' not found"; \
		echo "   Run 'make setup' to create it"; \
	fi
	@echo ""
	@make check-spark 2>/dev/null || echo "❌ Spark not properly configured"