# Makefile for Python data science project using conda and pyproject.toml

.PHONY: help setup install install-dev test lint format run clean notebook dashboard report pre-commit update-deps

CONDA_ENV_NAME = data-analysis-env
PYTHON = python

help:
	@echo "🚀 Available commands:"
	@echo ""
	@echo "📦 Environment Management:"
	@echo "  setup         - Create conda environment and install dependencies"
	@echo "  install       - Install project in current environment"
	@echo "  install-dev   - Install with development dependencies"
	@echo "  update-deps   - Update all dependencies to latest versions"
	@echo ""
	@echo "🧪 Development:"
	@echo "  test          - Run all tests with coverage"
	@echo "  test-fast     - Run tests without slow markers"
	@echo "  lint          - Run all linting checks"
	@echo "  format        - Format code with black"
	@echo "  pre-commit    - Set up pre-commit hooks"
	@echo ""
	@echo "🏃 Execution:"
	@echo "  run           - Run the main analysis"
	@echo "  report        - Generate the analysis report"
	@echo "  notebook      - Start Jupyter Lab server"
	@echo "  dashboard     - Start interactive dashboard"
	@echo ""
	@echo "🧹 Maintenance:"
	@echo "  clean         - Clean up generated files and caches"
	@echo "  clean-all     - Clean everything including conda environment"

setup:
	@echo "🔧 Setting up conda environment..."
	conda env create -f environment.yml
	@echo ""
	@echo "✅ Environment created successfully!"
	@echo "🔄 Activate with: conda activate $(CONDA_ENV_NAME)"
	@echo "📦 Then run: make install"

install:
	@echo "📦 Installing project..."
	pip install -e .

install-dev:
	@echo "📦 Installing project with development dependencies..."
	pip install -e ".[dev,interactive,export]"

update-deps:
	@echo "🔄 Updating conda environment..."
	conda env update -f environment.yml --prune
	pip install -e ".[dev,interactive,export]" --upgrade

test:
	@echo "🧪 Running tests with coverage..."
	pytest tests/ -v --cov=. --cov-report=html --cov-report=term-missing

test-fast:
	@echo "⚡ Running fast tests..."
	pytest tests/ -v -m "not slow"

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

pre-commit:
	@echo "🪝 Setting up pre-commit hooks..."
	pre-commit install
	pre-commit run --all-files

run:
	@echo "🏃 Running analysis..."
	$(PYTHON) job.py

report:
	@echo "📄 Generating analysis report..."
	@if [ -f "reports.py" ]; then \
		$(PYTHON) reports.py; \
		echo "✅ Report generated successfully in the 'outputs/reports' directory."; \
	else \
		echo "❌ No reports script found (reports.py)"; \
	fi

notebook:
	@echo "📓 Starting Jupyter Lab..."
	@echo "🌐 Will open at: http://localhost:8888"
	jupyter lab --no-browser --port=8888

dashboard:
	@echo "📊 Starting interactive dashboard..."
	@if [ -f "dashboard.py" ]; then \
		echo "🎯 Streamlit dashboard detected"; \
		streamlit run dashboard.py; \
	elif [ -f "app.py" ]; then \
		echo "🎯 Dash app detected"; \
		$(PYTHON) app.py; \
	else \
		echo "❌ No dashboard file found (dashboard.py or app.py)"; \
	fi

clean:
	@echo "🧹 Cleaning up..."
	find . -type f -name "*.pyc" -delete
	find . -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
	find . -type d -name "*.egg-info" -exec rm -rf {} + 2>/dev/null || true
	rm -rf build/ dist/ .pytest_cache/ .coverage htmlcov/
	rm -rf outputs/reports/* outputs/visualizations/* outputs/models/*
	find . -name ".DS_Store" -delete 2>/dev/null || true
	@echo "✅ Cleanup complete!"

clean-all: clean
	@echo "🗑️  Removing conda environment..."
	conda env remove -n $(CONDA_ENV_NAME) -y 2>/dev/null || true
	@echo "✅ Full cleanup complete!"

# Development shortcuts
dev-setup: setup install-dev pre-commit
	@echo "🎉 Development environment fully set up!"

quick-test: format lint test-fast
	@echo "⚡ Quick development checks complete!"

# Environment status
status:
	@echo "📊 Environment Status:"
	@echo "Current conda env: $${CONDA_DEFAULT_ENV:-'(none)'}"
	@echo "Python version: $(shell python --version 2>/dev/null || echo 'Not found')"
	@echo "Pip packages: $(shell pip list 2>/dev/null | wc -l || echo 'Error') installed"
	@echo ""
	@if conda env list | grep -q "$(CONDA_ENV_NAME)"; then \
		echo "✅ Conda environment '$(CONDA_ENV_NAME)' exists"; \
	else \
		echo "❌ Conda environment '$(CONDA_ENV_NAME)' not found"; \
		echo "   Run 'make setup' to create it"; \
	fi