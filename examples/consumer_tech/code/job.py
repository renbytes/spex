# Main PySpark job orchestration script.
# Should include: Spark session management, data loading, calling the main analysis function,
# and triggering the single, final action to write the results.

import logging
import sys

from pyspark.sql import DataFrame, SparkSession

from config import Settings
from functions import run_analysis
from spark_config import get_spark_session
from data_validation import validate_data, get_schema_definitions

# Configure logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)


def load_data(spark: SparkSession, settings: Settings) -> dict[str, DataFrame]:
    """
    Loads all necessary datasets from specified paths.

    Args:
        spark: The SparkSession object.
        settings: The application configuration object.

    Returns:
        A dictionary mapping dataset names to their DataFrames.
    """
    logger.info("Loading input datasets...")
    try:
        datasets = {
            "app_events": spark.read.format(settings.input_format).load(settings.app_events_path),
            "signups": spark.read.format(settings.input_format).load(settings.signups_path),
            "products": spark.read.format(settings.input_format).load(settings.products_path),
        }
        logger.info("Successfully loaded all datasets.")
        return datasets
    except Exception as e:
        logger.error(f"Failed to load data: {e}", exc_info=True)
        sys.exit(1)


def main() -> None:
    """
    The main entry point for the PySpark job.
    """
    logger.info("Starting Subscription Attribution job.")

    # 1. Configuration and Spark Session
    settings = Settings()
    spark = get_spark_session(settings.app_name)

    # 2. Load Data
    input_data = load_data(spark, settings)
    
    # 3. Data Quality Validation (optional but recommended)
    # schemas = get_schema_definitions()
    # validated_data = {}
    # for name, df in input_data.items():
    #     logger.info(f"Validating schema for dataset: {name}")
    #     validated_data[name] = validate_data(df, schemas[name])
    
    # Optional: Filter out bad data or log quality metrics. For this example, we proceed.
    # To see validation errors, you could run:
    # validated_data["app_events"].where("size(data_quality_errors) > 0").show()

    # 4. Run Core Analysis
    # The run_analysis function encapsulates all transformations.
    logger.info("Running core analysis transformations...")
    final_metrics_df = run_analysis(
        app_events_df=input_data["app_events"],
        signups_df=input_data["signups"],
        products_df=input_data["products"],
    )

    # Cache the final DataFrame before writing if it's used multiple times
    final_metrics_df.cache()
    
    # Log a sample of the results
    logger.info("Sample of final aggregated metrics:")
    final_metrics_df.show(truncate=False)

    # 5. Write Output (The single action)
    logger.info(f"Writing final metrics to {settings.output_path}")
    try:
        (
            final_metrics_df.coalesce(1)
            .write.mode("overwrite")
            .format(settings.output_format)
            .option("header", "true")
            .save(settings.output_path)
        )
        logger.info("Job completed successfully.")
    except Exception as e:
        logger.error(f"Failed to write output: {e}", exc_info=True)
        sys.exit(1)
    finally:
        spark.stop()
        logger.info("Spark session stopped.")


if __name__ == "__main__":
    main()