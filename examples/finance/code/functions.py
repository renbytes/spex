#
# Plan for Bitcoin Price Forecasting Pipeline:
#
# 1.  **Configuration & Setup:**
#     - Use `pydantic-settings` in `config.py` to manage all parameters (paths, model orders, window sizes).
#     - The main `job.py` script will orchestrate the pipeline, ensuring output directories exist.
#
# 2.  **Data Ingestion & Preparation (`load_and_prepare_data`):**
#     - Load the raw CSV data using pandas.
#     - Perform essential cleaning:
#       - Parse 'snapped_at' into a timezone-aware datetime object.
#       - Set the datetime column as the DataFrame index.
#       - Select and rename relevant columns ('price') for clarity.
#       - Ensure the data is sorted chronologically.
#       - Resample to a daily frequency ('D') and forward-fill any missing daily prices to ensure a continuous time series for the model.
#
# 3.  **Data Quality Assurance (`data_validation.py`):**
#     - Define a `pandera` schema to enforce data types (e.g., float for price) and non-null constraints on critical columns.
#     - Implement an outlier detection function (e.g., using the IQR method) to identify and flag anomalous price points, which will be reported but not removed by default.
#
# 4.  **Core Analysis & Feature Engineering:**
#     - **Moving Average (`calculate_moving_average`):**
#       - Implement a function to calculate the rolling moving average on the 'price' column.
#       - The window size (e.g., 90 days) will be configurable.
#       - This function will add the 'moving_average' column to the DataFrame.
#     - **Time Series Modeling (`train_and_forecast_sarima`):**
#       - This is the core forecasting function.
#       - It will take the price time series and SARIMA model parameters (order and seasonal_order) from the configuration.
#       - It will use `statsmodels.tsa.statespace.sarimax.SARIMAX` to build the model.
#       - The model will be fitted to the entire historical price series.
#       - The fitted model's `get_forecast()` method will be used to predict future values for the specified horizon (365 days).
#       - The function will return a DataFrame containing the forecasted values, along with the lower and upper bounds of the 95% confidence interval.
#
# 5.  **Result Aggregation (`combine_all_data`):**
#     - Create a utility function to merge the historical data (with moving average) and the forecast data into a single, comprehensive DataFrame. This unified view is essential for plotting and reporting.
#
# 6.  **Insights & Summarization (`get_summary_statistics`):**
#     - A function to extract key metrics for the report's executive summary, such as the last recorded actual price and the final forecasted price at the end of the horizon.
#
# 7.  **Visualization & Reporting (`visualizations.py`, `reports.py`):**
#     - The pipeline will generate several plots:
#       - Historical price vs. 90-day moving average (Matplotlib).
#       - Interactive forecast plot showing history, forecast, and confidence interval (Plotly).
#       - Time series decomposition plot to visualize trend, seasonality, and residuals (Matplotlib).
#       - SARIMA model diagnostic plots (ACF, PACF, etc.) to assess model fit (Matplotlib).
#     - A professional HTML report will be generated using Jinja2, embedding the key metrics and visualizations to provide a shareable summary of the findings.
#
# 8.  **Interactive Dashboard (`dashboard.py`):**
#     - A Streamlit application will consume the final combined data artifact.
#     - It will provide an interactive platform for users to explore the forecast, view key metrics, and inspect the data, making the results more accessible.
#
import pandas as pd
from statsmodels.tsa.statespace.sarimax import SARIMAX
from typing import Tuple, Dict, Any

def load_and_prepare_data(file_path: str) -> pd.DataFrame:
    """Loads, cleans, and prepares the Bitcoin price data.

    Args:
        file_path: The path to the input CSV file.

    Returns:
        A cleaned and prepared pandas DataFrame with a datetime index.
    """
    df = pd.read_csv(file_path)
    df['snapped_at'] = pd.to_datetime(df['snapped_at']).dt.tz_localize(None)
    df = df.set_index('snapped_at')
    df = df[['price']]
    df = df.sort_index()
    # Resample to daily frequency and forward-fill missing values
    df = df.resample('D').ffill().dropna()
    return df

def calculate_moving_average(df: pd.DataFrame, window: int) -> pd.DataFrame:
    """Calculates the moving average for the price column.

    Args:
        df: The input DataFrame with a 'price' column.
        window: The window size for the moving average calculation.

    Returns:
        The DataFrame with an added 'moving_average' column.
    """
    df_copy = df.copy()
    df_copy[f'moving_average_{window}'] = df_copy['price'].rolling(window=window).mean()
    return df_copy

def train_and_forecast_sarima(
    series: pd.Series,
    order: Tuple[int, int, int],
    seasonal_order: Tuple[int, int, int, int],
    forecast_steps: int
) -> pd.DataFrame:
    """Trains a SARIMA model and generates a forecast.

    Args:
        series: The time series data to model (e.g., price).
        order: The (p, d, q) order of the model.
        seasonal_order: The (P, D, Q, s) seasonal order of the model.
        forecast_steps: The number of steps ahead to forecast.

    Returns:
        A DataFrame containing the forecast, lower CI, and upper CI.
    """
    model = SARIMAX(series, order=order, seasonal_order=seasonal_order)
    results = model.fit(disp=False)
    
    forecast = results.get_forecast(steps=forecast_steps)
    forecast_df = forecast.summary_frame(alpha=0.05)[['mean', 'mean_ci_lower', 'mean_ci_upper']]
    forecast_df.columns = ['forecast', 'forecast_lower', 'forecast_upper']
    
    return forecast_df

def combine_all_data(
    historical_df: pd.DataFrame, forecast_df: pd.DataFrame
) -> pd.DataFrame:
    """Combines historical and forecast data into a single DataFrame.

    Args:
        historical_df: DataFrame with historical data (price, MA).
        forecast_df: DataFrame with forecasted values.

    Returns:
        A unified DataFrame containing all data.
    """
    return pd.concat([historical_df, forecast_df], axis=1)

def get_summary_statistics(
    final_df: pd.DataFrame, forecast_df: pd.DataFrame
) -> Dict[str, Any]:
    """Extracts key summary statistics for the report.

    Args:
        final_df: The combined DataFrame of historical and forecast data.
        forecast_df: The DataFrame with forecasted values.

    Returns:
        A dictionary of summary metrics.
    """
    last_actual_price = final_df['price'].dropna().iloc[-1]
    final_forecast_price = forecast_df['forecast'].iloc[-1]
    
    stats = {
        "last_actual_price": f"${last_actual_price:,.2f}",
        "final_forecast_price": f"${final_forecast_price:,.2f}",
    }
    return stats