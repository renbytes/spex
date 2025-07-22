# Spark configuration management and session optimization.
# Include functions to build a performance-tuned SparkSession.

from pyspark.sql import SparkSession


def get_spark_session(app_name: str = "SubscriptionAttribution") -> SparkSession:
    """
    Creates and returns a performance-tuned SparkSession.

    Args:
        app_name: The name for the Spark application.

    Returns:
        A configured SparkSession object.
    """
    return (
        SparkSession.builder.appName(app_name)
        # Use a more efficient serializer
        .config("spark.serializer", "org.apache.spark.serializer.KryoSerializer")
        # Enable dynamic allocation
        .config("spark.dynamicAllocation.enabled", "true")
        .config("spark.shuffle.service.enabled", "true")
        # Optimize shuffle partitions
        .config("spark.sql.shuffle.partitions", "200")
        # Adaptive Query Execution for performance gains
        .config("spark.sql.adaptive.enabled", "true")
        .config("spark.sql.adaptive.coalescePartitions.enabled", "true")
        .config("spark.sql.adaptive.skewJoin.enabled", "true")
        .getOrCreate()
    )