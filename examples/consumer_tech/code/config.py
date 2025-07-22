# General configuration management for file paths and parameters.
# Use pydantic-settings for type-safe configuration.

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """
    Application configuration settings.
    Uses environment variables with a 'SPARK_APP_' prefix.
    e.g., export SPARK_APP_APP_NAME="MyCoolApp"
    """
    model_config = SettingsConfigDict(env_prefix='SPARK_APP_')

    # Job parameters
    app_name: str = "SubscriptionAttribution"

    # Input data paths
    app_events_path: str = "data/app_events.parquet"
    signups_path: str = "data/signups.parquet"
    products_path: str = "data/products.parquet"
    
    # Input data format
    input_format: str = "parquet"

    # Output data path
    output_path: str = "output/attribution_metrics"
    output_format: str = "csv"