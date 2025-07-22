# Data quality and validation functions optimized for Spark.
# These should also be transformations that return a DataFrame, adding quality-check columns.

from pyspark.sql import DataFrame, Column
from pyspark.sql.types import (
    StructType, StructField, StringType, TimestampType
)
import pyspark.sql.functions as F
from typing import Dict, List


def get_schema_definitions() -> Dict[str, StructType]:
    """
    Returns schema definitions for all input datasets.

    Returns:
        A dictionary mapping dataset names to their expected schemas.
    """
    return {
        "app_events": StructType([
            StructField("event_timestamp", TimestampType(), False),
            StructField("event_name", StringType(), False),
            StructField("user_id", StringType(), False),
            StructField("ad_id", StringType(), True),
        ]),
        "signups": StructType([
            StructField("signup_timestamp", TimestampType(), False),
            StructField("user_id", StringType(), False),
            StructField("product_id", StringType(), False),
        ]),
        "products": StructType([
            StructField("product_id", StringType(), False),
            StructField("plan_name", StringType(), False),
            StructField("plan_type", StringType(), False),
        ]),
    }


def validate_data(df: DataFrame, schema: StructType) -> DataFrame:
    """
    Validates a DataFrame against an expected schema and adds a quality errors column.

    This function checks for:
    1. Null values in non-nullable columns.
    2. Correct data types (by attempting a cast).

    Args:
        df: The input DataFrame to validate.
        schema: The expected StructType schema.

    Returns:
        The input DataFrame with an added 'data_quality_errors' array column.
    """
    error_checks: List[Column] = []

    for field in schema.fields:
        col_name = field.name
        expected_type = field.dataType
        
        # Check for nulls in non-nullable columns
        if not field.nullable:
            error_checks.append(
                F.when(
                    F.col(col_name).isNull(),
                    F.lit(f"'{col_name}' is NULL")
                )
            )
        
        # Check data type
        # Note: Spark's readers often infer types. This check ensures they can be cast
        # to the required type, which catches format inconsistencies (e.g., bad timestamps).
        if str(df.schema[col_name].dataType) != str(expected_type):
             error_checks.append(
                F.when(
                    F.col(col_name).cast(expected_type).isNull() & F.col(col_name).isNotNull(),
                    F.lit(f"'{col_name}' cannot be cast to {expected_type}")
                )
            )

    # Combine all error checks into a single array column, filtering out nulls
    return df.withColumn(
        "data_quality_errors",
        F.array_except(F.array(*error_checks), F.array(F.lit(None)))
    )