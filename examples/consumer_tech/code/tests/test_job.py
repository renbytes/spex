# tests/test_job.py

# End-to-end integration test for the complete PySpark pipeline.
# Mocks the input data sources and validates the final, aggregated output.

import pytest
from unittest.mock import patch, MagicMock
from pyspark.sql import SparkSession
from datetime import datetime
import shutil
import os

# Assuming job.py and its dependencies are in the path
import job
from config import Settings


@pytest.fixture(scope="module")
def spark_session():
    """Create a SparkSession for the integration test."""
    session = SparkSession.builder \
        .master("local[2]") \
        .appName("integration-test-session") \
        .config("spark.sql.shuffle.partitions", "2") \
        .getOrCreate()
    yield session
    session.stop()

    # Clean up output directory after tests
    output_dir = "test_output"
    if os.path.exists(output_dir):
        shutil.rmtree(output_dir)


@pytest.fixture
def sample_data(spark_session):
    """Provides sample input DataFrames for integration tests."""
    app_events_data = [
        (datetime(2025, 7, 20, 10, 0, 0), "app_open", "u1", None),
        (datetime(2025, 7, 20, 10, 5, 0), "ad_impression", "u1", "ad1"),
        # This is the most recent click before the u1 signup
        (datetime(2025, 7, 20, 10, 10, 0), "ad_click", "u1", "ad1"),
        # This click is earlier and should be ignored for attribution
        (datetime(2025, 7, 20, 10, 1, 0), "ad_click", "u1", "ad0"),
        (datetime(2025, 7, 20, 11, 0, 0), "ad_impression", "u2", "ad2"),
        # This click has no corresponding signup
        (datetime(2025, 7, 20, 12, 0, 0), "ad_click", "u3", "ad3"),
    ]
    app_events_df = spark_session.createDataFrame(app_events_data, ["event_timestamp", "event_name", "user_id", "ad_id"])

    signups_data = [
        # u1 signs up after clicking ad1
        (datetime(2025, 7, 20, 10, 15, 0), "u1", "p_annual"),
        # u2 signs up but has no preceding click
        (datetime(2025, 7, 20, 11, 5, 0), "u2", "p_monthly"),
        # u4 signs up but has no events at all
        (datetime(2025, 7, 20, 9, 0, 0), "u4", "p_annual"),
    ]
    signups_df = spark_session.createDataFrame(signups_data, ["signup_timestamp", "user_id", "product_id"])

    products_data = [
        ("p_annual", "Premium Plan", "Annual"),
        ("p_monthly", "Standard Plan", "Monthly"),
    ]
    products_df = spark_session.createDataFrame(products_data, ["product_id", "plan_name", "plan_type"])

    return {
        "app_events": app_events_df,
        "signups": signups_df,
        "products": products_df,
    }


# We patch at a higher level:
# - `job.load_data`: To inject our sample DataFrames directly.
# - `job.get_spark_session`: To ensure our test SparkSession is used.
# - `job.Settings`: To control input/output paths.
# - `pyspark.sql.SparkSession.stop`: To prevent job.main() from closing the session.
@patch("pyspark.sql.session.SparkSession.stop")
@patch("job.Settings")
@patch("job.get_spark_session")
@patch("job.load_data")
def test_full_job_pipeline(mock_load_data, mock_get_spark, mock_settings, mock_spark_stop, spark_session, sample_data):
    """
    Tests the full job pipeline from loading data to writing output.
    """
    # 1. Configure Mocks
    mock_get_spark.return_value = spark_session
    mock_load_data.return_value = sample_data
    test_output_path = "test_output/integration_results"
    mock_settings.return_value = Settings(
        app_events_path="dummy",
        signups_path="dummy",
        products_path="dummy",
        output_path=test_output_path,
        output_format="parquet",
        input_format="parquet",
        app_name="Test Integration App",
    )

    # 2. Run the main pipeline job
    job.main()

    # 3. Validate the output
    assert os.path.exists(test_output_path), "Output directory was not created."
    output_df = spark_session.read.parquet(test_output_path)
    
    # With the extra subtotal row filtered out, the count should now be correct.
    assert output_df.count() == 4, "Expected 2 plan rows + 1 global total + 1 NULL."

    # Check the Global Total row values
    global_row = output_df.filter(output_df.metric_level == "Global Total").first()
    assert global_row is not None, "Global Total row not found."
    
    # There are 3 ad_click events in the sample data (u1 has two, u3 has one).
    assert global_row.total_ad_clicks == 3, "Global total ad clicks should be 3."
    assert global_row.attributed_signups == 1, "Global attributed signups should be 1."
    # The rate is 1 attributed signup / 3 total clicks.
    assert round(global_row.click_to_signup_rate, 1) == 33.3, "Click-to-signup rate should be 33.3."

    # Check Premium Plan row values
    premium_row = output_df.filter(output_df.plan_name == "Premium Plan").first()
    assert premium_row is not None, "Premium Plan row not found."
    assert premium_row.attributed_signups_by_plan == 1, "Premium plan should have 1 attributed signup."
    
    # Check Standard Plan row values
    standard_row = output_df.filter(output_df.plan_name == "Standard Plan").first()
    assert standard_row is not None, "Standard Plan row not found."
    assert standard_row.attributed_signups_by_plan == 0, "Standard plan should have 0 attributed signups."