import os
from pydantic_settings import BaseSettings
from typing import Tuple

class Settings(BaseSettings):
    """
    Configuration settings for the data pipeline, loaded from environment
    variables or a .env file.
    """
    # File Paths
    base_dir: str = os.path.dirname(os.path.abspath(__file__))
    input_data_path: str = os.path.join(base_dir, "data", "stock_prices.csv")
    output_dir: str = os.path.join(base_dir, "output")
    viz_dir: str = os.path.join(output_dir, "visualizations")

    # Analysis Parameters
    ma_window: int = 90
    forecast_horizon: int = 365

    # SARIMA Model Parameters
    # Note: These are example parameters. In a real project, they would be
    # determined through rigorous analysis (e.g., ACF/PACF plots, grid search).
    # Using a simple ARIMA(1,1,1) as a starting point.
    sarima_order: Tuple[int, int, int] = (1, 1, 1)
    # Seasonal order (P,D,Q,s). s=7 for weekly seasonality. Set to 0 if no clear seasonality.
    # Using a yearly seasonality (s=365) is computationally very expensive.
    # We will use a simpler model here for demonstration.
    sarima_seasonal_order: Tuple[int, int, int, int] = (1, 1, 1, 12) # Example monthly seasonality

    class Config:
        env_file = ".env"
        env_file_encoding = 'utf-8'

# Singleton instance of settings
_settings = None

def get_settings() -> Settings:
    """Returns a singleton instance of the Settings."""
    global _settings
    if _settings is None:
        _settings = Settings()
    return _settings