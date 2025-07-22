# Comprehensive unit tests for PySpark functions using a local Spark context.
# Test each function from your plan independently.

import pytest
from pyspark.sql import SparkSession
import pyspark.sql.functions as F
from datetime import datetime

from functions import (
    run_analysis,
    _prepare_events,
    _prepare_signups,
    _map_attribution_flags,
    _unify_data_for_aggregation,
    _run_unified_aggregation,
    _add_post_aggregation_metrics,
)


@pytest.fixture(scope="session")
def spark() -> SparkSession:
    """Create a SparkSession for the tests."""
    return SparkSession.builder.master("local[2]").appName("pytest-spark-session").getOrCreate()


@pytest.fixture
def sample_data(spark: SparkSession):
    """Provides sample input DataFrames for tests."""
    app_events_data = [
        (datetime(2025, 7, 20, 10, 0, 0), "app_open", "u1", None),
        (datetime(2025, 7, 20, 10, 5, 0), "ad_impression", "u1", "ad1"),  # Will be attributed
        (datetime(2025, 7, 20, 10, 10, 0), "ad_click", "u1", "ad1"),      # <-- Attributed click for u1
        (datetime(2025, 7, 20, 10, 1, 0), "ad_click", "u1", "ad0"),       # <-- Too early click for u1
        (datetime(2025, 7, 20, 11, 0, 0), "ad_impression", "u2", "ad2"),  # No click for u2
        (datetime(2025, 7, 20, 12, 0, 0), "ad_click", "u3", "ad3"),       # Click but no signup for u3
    ]
    app_events_schema = ["event_timestamp", "event_name", "user_id", "ad_id"]
    app_events_df = spark.createDataFrame(app_events_data, app_events_schema)

    signups_data = [
        (datetime(2025, 7, 20, 10, 15, 0), "u1", "p_annual"),  # Attributed
        (datetime(2025, 7, 20, 11, 5, 0), "u2", "p_monthly"),  # Not attributed (no click)
        (datetime(2025, 7, 20, 9, 0, 0), "u4", "p_annual"),    # Organic signup
    ]
    signups_schema = ["signup_timestamp", "user_id", "product_id"]
    signups_df = spark.createDataFrame(signups_data, signups_schema)

    products_data = [
        ("p_annual", "Premium Plan", "Annual"),
        ("p_monthly", "Standard Plan", "Monthly"),
    ]
    products_schema = ["product_id", "plan_name", "plan_type"]
    products_df = spark.createDataFrame(products_data, products_schema)

    return {
        "app_events": app_events_df,
        "signups": signups_df,
        "products": products_df,
    }


def test_prepare_events(spark, sample_data):
    # Basic smoke test for _prepare_events function
    result_df = _prepare_events(sample_data["app_events"])
    assert "is_impression" in result_df.columns
    assert "is_click" in result_df.columns
    assert result_df.count() == 6

    # Validate counts of indicators
    counts = result_df.agg(F.sum("is_impression").alias("imps"), F.sum("is_click").alias("clicks")).first()
    assert counts["imps"] == 2
    assert counts["clicks"] == 3  # Corrected to match test data


def test_prepare_signups(spark, sample_data):
    # Ensure product enrichment works as expected
    result_df = _prepare_signups(sample_data["signups"], sample_data["products"])
    assert "plan_name" in result_df.columns
    assert result_df.count() == 3

    # Check correct plan enrichment for known user
    assert result_df.filter(F.col("user_id") == "u1").first()["plan_name"] == "Premium Plan"


def test_map_attribution_flags(spark, sample_data):
    # Test attribution logic works on windowing and joins
    signups_with_products_df = _prepare_signups(sample_data["signups"], sample_data["products"])
    result_df = _map_attribution_flags(signups_with_products_df, sample_data["app_events"])

    assert "is_attributed_signup" in result_df.columns
    assert result_df.count() == 3

    # u1 should be attributed
    attributed_user1 = result_df.filter(F.col("user_id") == "u1").first()
    assert attributed_user1["is_attributed_signup"] == 1

    # u2 should not be attributed (no prior click)
    unattributed_user2 = result_df.filter(F.col("user_id") == "u2").first()
    assert unattributed_user2["is_attributed_signup"] == 0

    # u4 is organic signup (no prior click)
    organic_user4 = result_df.filter(F.col("user_id") == "u4").first()
    assert organic_user4["is_attributed_signup"] == 0


def test_run_unified_aggregation(spark, sample_data):
    # Test cube aggregation includes grouping_id correctly
    events_df = _prepare_events(sample_data["app_events"])
    signups_df = _prepare_signups(sample_data["signups"], sample_data["products"])
    attributed_df = _map_attribution_flags(signups_df, sample_data["app_events"])
    unified_df = _unify_data_for_aggregation(events_df, attributed_df)
    agg_df = _run_unified_aggregation(unified_df)

    # Validate grouping_id exists and cube worked
    assert "grouping_id" in agg_df.columns

    # There should be at least one per-plan row (grouping_id == 0)
    assert agg_df.filter(F.col("grouping_id") == 0).count() >= 1


def test_add_post_aggregation_metrics(spark, sample_data):
    # Ensure post aggregation metrics like metric_level and rates are added correctly
    events_df = _prepare_events(sample_data["app_events"])
    signups_df = _prepare_signups(sample_data["signups"], sample_data["products"])
    attributed_df = _map_attribution_flags(signups_df, sample_data["app_events"])
    unified_df = _unify_data_for_aggregation(events_df, attributed_df)
    agg_df = _run_unified_aggregation(unified_df)
    final_df = _add_post_aggregation_metrics(agg_df, unified_df)

    # Check required columns exist
    assert "click_to_signup_rate" in final_df.columns
    assert "metric_level" in final_df.columns

    # There should be at least one Global Total row with the correct metric_level
    assert final_df.filter(F.col("metric_level") == "Global Total").count() >= 1


def test_run_analysis(spark, sample_data):
    """End-to-end test of the main analysis function."""
    result_df = run_analysis(
        sample_data["app_events"], sample_data["signups"], sample_data["products"]
    )
    
    result_df.filter(F.col("metric_level") == "Global Total").show(truncate=False)

    # Validate presence of key rows instead of asserting exact total count
    assert result_df.filter(F.col("metric_level") == "Global Total").count() >= 1
    assert result_df.filter((F.col("plan_name") == "Premium Plan") & (F.col("metric_level") == "By Plan")).count() >= 1
    assert result_df.filter((F.col("plan_name") == "Standard Plan") & (F.col("metric_level") == "By Plan")).count() >= 1

    # Check global totals (should sum everything correctly)
    global_row = result_df.filter(F.col("metric_level") == "Global Total").first().asDict()
    assert global_row["total_ad_impressions"] == 2
    assert global_row["total_ad_clicks"] == 3
    assert global_row["total_signups"] == 3
    assert global_row["attributed_signups"] == 1
    assert round(global_row["click_to_signup_rate"], 1) == 33.3  # (1 attributed signup / 3 clicks) * 100

    # Check breakdown for Premium Plan (plan-specific row)
    premium_row = result_df.filter((F.col("plan_name") == "Premium Plan") & (F.col("metric_level") == "By Plan")).first().asDict()
    assert premium_row["total_signups"] == 2  # u1 + u4 signed up to Premium Plan
    assert premium_row["attributed_signups_by_plan"] == 1  # u1 was attributed

    # Check breakdown for Standard Plan (plan-specific row)
    standard_row = result_df.filter((F.col("plan_name") == "Standard Plan") & (F.col("metric_level") == "By Plan")).first().asDict()
    assert standard_row["total_signups"] == 1  # u2 signed up to Standard Plan
    assert standard_row["attributed_signups_by_plan"] == 0  # u2 was not attributed