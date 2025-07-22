# Core PySpark business logic.
# Start with a high-level comment block outlining your step-by-step plan.
# Implement the plan using a series of transformation-only functions.
# The final function should return a single DataFrame ready for the final aggregation action.
# All functions MUST return a DataFrame and MUST NOT trigger any Spark actions.
# Every function must have comprehensive docstrings and type hints.

from typing import List

from pyspark.sql import DataFrame, Window
import pyspark.sql.functions as F


# ======================================================================================
#                              HIGH-LEVEL EXECUTION PLAN
# ======================================================================================
# The goal is to calculate various subscription attribution metrics, including global
# totals and metrics grouped by product plan, using a SINGLE unified aggregation step.
# This respects the lazy evaluation and single-action principles of Spark.
#
# The plan leverages advanced Spark features (`cube`) to achieve mixed-granularity
# aggregation in one pass.
#
# Step 1: PREPARE EVENTS DATA (_prepare_events)
#   - Input: Raw `app_events` DataFrame.
#   - Action: Create binary indicator columns `is_impression` (1/0) and `is_click` (1/0).
#   - Output: A DataFrame with one row per event, containing user_id and indicator flags.
#
# Step 2: PREPARE SIGNUPS DATA (_prepare_signups)
#   - Input: `signups` and `products` DataFrames.
#   - Action: Broadcast join `signups` with the small `products` table to enrich signups
#     with `plan_name` and `plan_type`. Create an `is_signup` (1) indicator.
#   - Output: A DataFrame with one row per signup, enriched with product details.
#
# Step 3: MAP ATTRIBUTION FLAGS (_map_attribution_flags)
#   - This is the core attribution logic, performed as a transformation.
#   - Input: The prepared signups DataFrame (from Step 2) and the raw events DataFrame.
#   - Action:
#     a. Filter events to get only 'ad_click' events.
#     b. Join signups with clicks on `user_id` where click_timestamp < signup_timestamp.
#     c. Use a Window function partitioned by `user_id` and `signup_timestamp` and ordered
#        by `event_timestamp` descending to find the MOST RECENT click before each signup.
#     d. Left-join this attributed link information back to the main signups DataFrame.
#     e. Create an `is_attributed_signup` (1/0) flag based on a successful join.
#   - Output: The signups DataFrame with an added `is_attributed_signup` column.
#
# Step 4: UNIFY DATA FOR AGGREGATION (_unify_data_for_aggregation)
#   - Input: The prepared events (Step 1) and prepared+attributed signups (Step 3).
#   - Action:
#     a. Standardize the schemas of both DataFrames, adding null placeholders for columns
#        that don't exist in the other (e.g., `plan_name` for events).
#     b. Union the two DataFrames into a single, tall DataFrame. Each row now represents
#        either an event or a signup, with all necessary indicator flags.
#   - Output: A single, unified DataFrame ready for aggregation.
#
# Step 5: PERFORM UNIFIED AGGREGATION AND FINALIZE METRICS (_run_unified_aggregation, _add_post_aggregation_metrics)
#   - Input: The unified DataFrame from Step 4.
#   - Action:
#     a. Use `cube("plan_name", "plan_type")` to group data. `cube` generates aggregates for all
#        combinations of specified columns, PLUS a grand total row (where grouping cols are null).
#        This is the key to getting both global and per-plan metrics in one call.
#     b. In a single `.agg()` call, sum all the indicator flags (`is_impression`, `is_click`,
#        `is_signup`, `is_attributed_signup`) to get the counts.
#     c. In a subsequent transformation, calculate derived metrics like `click_to_signup_rate`
#        and clean up the output DataFrame for presentation.
# ======================================================================================


def _prepare_events(df: DataFrame) -> DataFrame:
    """
    Prepares the app_events data by creating binary indicator columns.

    Args:
        df: The input app_events DataFrame.

    Returns:
        A transformed DataFrame with indicator flags for impressions and clicks.
    """
    return df.select(
        "user_id",
        "ad_id",
        F.col("event_timestamp"),
        F.when(F.col("event_name") == "ad_impression", 1).otherwise(0).alias("is_impression"),
        F.when(F.col("event_name") == "ad_click", 1).otherwise(0).alias("is_click"),
    )


def _prepare_signups(signups_df: DataFrame, products_df: DataFrame) -> DataFrame:
    """
    Enriches signup data with product information.

    Args:
        signups_df: The input signups DataFrame.
        products_df: The input products DataFrame.

    Returns:
        A transformed DataFrame of signups joined with product details.
    """
    return signups_df.join(
        F.broadcast(products_df), on="product_id", how="left"
    ).withColumn("is_signup", F.lit(1))


def _map_attribution_flags(
    signups_with_products_df: DataFrame, events_df: DataFrame
) -> DataFrame:
    """
    Identifies attributed signups using a time-based join and window function.

    Args:
        signups_with_products_df: DataFrame of signups enriched with product data.
        events_df: The raw app_events DataFrame.

    Returns:
        The signups DataFrame with an added 'is_attributed_signup' (1/0) column.
    """
    clicks_df = events_df.filter(F.col("event_name") == "ad_click").select(
        F.col("user_id").alias("click_user_id"),
        F.col("event_timestamp").alias("click_timestamp"),
        F.col("ad_id").alias("click_ad_id"),
    )

    joined_df = signups_with_products_df.join(
        clicks_df,
        on=[
            signups_with_products_df["user_id"] == clicks_df["click_user_id"],
            signups_with_products_df["signup_timestamp"] > clicks_df["click_timestamp"],
        ],
        how="left",
    )

    window_spec = Window.partitionBy("user_id", "signup_timestamp").orderBy(
        F.col("click_timestamp").desc()
    )

    ranked_clicks_df = joined_df.withColumn("rank", F.row_number().over(window_spec))

    attributed_signups = ranked_clicks_df.withColumn(
        "is_attributed_signup",
        F.when((F.col("rank") == 1) & (F.col("click_user_id").isNotNull()), 1).otherwise(0),
    ).drop("click_user_id", "click_timestamp", "click_ad_id", "rank")

    signup_grain_cols = signups_with_products_df.columns

    dedup_window = Window.partitionBy(*signup_grain_cols).orderBy(
        F.col("is_attributed_signup").desc()
    )

    return attributed_signups.withColumn("dedup_rank", F.row_number().over(dedup_window)) \
                             .filter(F.col("dedup_rank") == 1) \
                             .drop("dedup_rank")


def _unify_data_for_aggregation(
    events_with_indicators_df: DataFrame, signups_with_attribution_df: DataFrame
) -> DataFrame:
    """
    Unions event and signup data into a single DataFrame for unified aggregation.

    Args:
        events_with_indicators_df: DataFrame of events with indicator columns.
        signups_with_attribution_df: DataFrame of signups with attribution flags.

    Returns:
        A single unified DataFrame.
    """
    events_unified = events_with_indicators_df.select(
        "user_id",
        "is_impression",
        "is_click",
        F.lit(0).alias("is_signup"),
        F.lit(0).alias("is_attributed_signup"),
        F.lit(None).cast("string").alias("plan_name"),
        F.lit(None).cast("string").alias("plan_type"),
    )

    signups_unified = signups_with_attribution_df.select(
        "user_id",
        F.lit(0).alias("is_impression"),
        F.lit(0).alias("is_click"),
        "is_signup",
        "is_attributed_signup",
        "plan_name",
        "plan_type",
    )

    return events_unified.unionByName(signups_unified)


def _run_unified_aggregation(unified_df: DataFrame) -> DataFrame:
    """
    Performs a single, unified aggregation using CUBE to get metrics at multiple
    granularity levels (global and per-plan).

    Args:
        unified_df: The combined events and signups DataFrame.

    Returns:
        An aggregated DataFrame with raw metric counts and grouping_id.
    """
    return unified_df.cube("plan_name", "plan_type").agg(
        F.sum("is_impression").alias("total_ad_impressions"),
        F.sum("is_click").alias("total_ad_clicks"),
        F.sum("is_signup").alias("total_signups"),
        F.sum("is_attributed_signup").alias("attributed_signups"),
        F.grouping_id().alias("grouping_id")
    )


def _add_post_aggregation_metrics(agg_df: DataFrame, unified_df: DataFrame) -> DataFrame:
    """
    Calculates derived metrics and cleans up the aggregated DataFrame.

    Args:
        agg_df: The DataFrame resulting from the unified aggregation.

    Returns:
        A final, clean DataFrame with all required metrics.
    """
    # Compute per-plan rows (from cube)
    by_plan_rows = (
        agg_df.filter(F.col("grouping_id") == 0)
        .withColumn("metric_level", F.lit("By Plan"))
        .withColumn("attributed_signups_by_plan", F.col("attributed_signups"))
        .withColumn(
            "click_to_signup_rate",
            F.when(F.col("total_ad_clicks") > 0, (F.col("attributed_signups") / F.col("total_ad_clicks")) * 100).otherwise(0.0),
        )
    )

    # Compute true global totals on original unified data (no cube)
    global_totals = (
        unified_df.agg(
            F.sum("is_impression").alias("total_ad_impressions"),
            F.sum("is_click").alias("total_ad_clicks"),
            F.sum("is_signup").alias("total_signups"),
            F.sum("is_attributed_signup").alias("attributed_signups"),
        )
        .withColumn("plan_name", F.lit("Global Total"))
        .withColumn("plan_type", F.lit("Global Total"))
        .withColumn("metric_level", F.lit("Global Total"))
        .withColumn("attributed_signups_by_plan", F.lit(None))
        .withColumn(
            "click_to_signup_rate",
            F.when(F.col("total_ad_clicks") > 0, (F.col("attributed_signups") / F.col("total_ad_clicks")) * 100).otherwise(0.0),
        )
    )

    return by_plan_rows.select(global_totals.columns).unionByName(global_totals)


def run_analysis(
    app_events_df: DataFrame, signups_df: DataFrame, products_df: DataFrame
) -> DataFrame:
    """
    Orchestrates the entire subscription attribution analysis pipeline.

    Args:
        app_events_df: Raw DataFrame of application events.
        signups_df: Raw DataFrame of user signups.
        products_df: DataFrame of product metadata.

    Returns:
        A DataFrame containing the final calculated metrics.
    """
    events_with_indicators_df = _prepare_events(app_events_df)
    signups_with_products_df = _prepare_signups(signups_df, products_df)
    signups_with_attribution_df = _map_attribution_flags(
        signups_with_products_df, app_events_df
    )
    unified_df = _unify_data_for_aggregation(
        events_with_indicators_df, signups_with_attribution_df
    )
    aggregated_df = _run_unified_aggregation(unified_df)
    final_metrics_df = _add_post_aggregation_metrics(aggregated_df, unified_df)
    return final_metrics_df