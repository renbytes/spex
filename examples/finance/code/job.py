import logging
import os
import pandas as pd
from config import get_settings
from functions import (
    load_and_prepare_data,
    calculate_moving_average,
    train_and_forecast_sarima,
    combine_all_data,
    get_summary_statistics,
)
from data_validation import validate_data, detect_price_outliers
from visualizations import (
    plot_price_and_moving_average,
    plot_forecast,
    plot_time_series_decomposition,
    plot_diagnostics,
)
from reports import generate_html_report

# Configure logging
logging.basicConfig(
    level=logging.INFO, format="%(asctime)s - %(levelname)s - %(message)s"
)


def main():
    """
    Main orchestration function for the Bitcoin price forecasting pipeline.

    This function coordinates the entire process:
    1. Loads configuration.
    2. Prepares output directories.
    3. Loads and validates input data.
    4. Performs time series analysis (Moving Average, SARIMA forecast).
    5. Generates and saves visualizations.
    6. Creates a comprehensive HTML report.
    """
    logging.info("Starting Bitcoin price forecasting pipeline...")

    # 1. Load configuration
    try:
        settings = get_settings()
        logging.info("Configuration loaded successfully.")
    except Exception as e:
        logging.error(f"Failed to load configuration: {e}")
        return

    # 2. Prepare output directories
    os.makedirs(settings.output_dir, exist_ok=True)
    os.makedirs(settings.viz_dir, exist_ok=True)
    logging.info(f"Output directories ensured at {settings.output_dir}")

    # 3. Load and validate data
    try:
        btc_data = load_and_prepare_data(settings.input_data_path)
        logging.info(f"Loaded {len(btc_data)} data points from {settings.input_data_path}")

        validate_data(btc_data)
        logging.info("Data schema validation successful.")

        outliers = detect_price_outliers(btc_data, 'price')
        if not outliers.empty:
            logging.warning(f"Detected {len(outliers)} potential outliers in price data.")
        else:
            logging.info("No outliers detected in price data.")

    except FileNotFoundError:
        logging.error(f"Input data file not found at {settings.input_data_path}")
        return
    except Exception as e:
        logging.error(f"An error occurred during data loading or validation: {e}")
        return

    # 4. Perform time series analysis
    logging.info("Performing time series analysis...")
    analysis_df = calculate_moving_average(btc_data, window=settings.ma_window)
    logging.info(f"Calculated {settings.ma_window}-day moving average.")

    price_series = btc_data["price"]
    
    # NOTE: SARIMA fitting on large datasets can be time-consuming.
    # For a production system, consider pre-trained models or more efficient algorithms.
    logging.info("Training SARIMA model and forecasting. This may take a few minutes...")
    try:
        forecast_df = train_and_forecast_sarima(
            price_series,
            order=settings.sarima_order,
            seasonal_order=settings.sarima_seasonal_order,
            forecast_steps=settings.forecast_horizon,
        )
        logging.info(f"Forecasted prices for the next {settings.forecast_horizon} days.")
    except Exception as e:
        logging.error(f"Failed to train or forecast with SARIMA model: {e}")
        return

    final_df = combine_all_data(analysis_df, forecast_df)
    final_df.to_csv(os.path.join(settings.output_dir, "final_forecast_data.csv"))
    logging.info("Combined historical and forecast data saved.")

    # 5. Generate and save visualizations
    logging.info("Generating visualizations...")
    price_ma_plot_path = os.path.join(settings.viz_dir, "price_ma_plot.png")
    plot_price_and_moving_average(final_df, save_path=price_ma_plot_path)

    forecast_plot_path = os.path.join(settings.viz_dir, "forecast_plot.html")
    forecast_fig = plot_forecast(final_df)
    forecast_fig.write_html(forecast_plot_path)

    decomposition_plot_path = os.path.join(settings.viz_dir, "decomposition_plot.png")
    plot_time_series_decomposition(
        price_series, model="multiplicative", period=365, save_path=decomposition_plot_path
    )

    # Note: Diagnostics are on the fitted model, not part of the main dataframe
    diagnostics_plot_path = os.path.join(settings.viz_dir, "model_diagnostics.png")
    plot_diagnostics(price_series, 
                     order=settings.sarima_order, 
                     seasonal_order=settings.sarima_seasonal_order, 
                     save_path=diagnostics_plot_path)

    logging.info(f"Visualizations saved to {settings.viz_dir}")

    # 6. Create HTML report
    logging.info("Generating HTML report...")
    summary_stats = get_summary_statistics(final_df, forecast_df)
    report_path = os.path.join(settings.output_dir, "bitcoin_forecast_report.html")

    report_context = {
        "report_title": "Bitcoin Daily Price Forecast Report",
        "last_actual_price": summary_stats["last_actual_price"],
        "final_forecast_price": summary_stats["final_forecast_price"],
        "forecast_horizon": settings.forecast_horizon,
        "ma_window": settings.ma_window,
        "sarima_order": str(settings.sarima_order),
        "sarima_seasonal_order": str(settings.sarima_seasonal_order),
        "price_ma_plot_path": price_ma_plot_path,
        "decomposition_plot_path": decomposition_plot_path,
        "diagnostics_plot_path": diagnostics_plot_path,
        "forecast_plot_path": forecast_plot_path,
    }

    generate_html_report(
        template_name="report_template.html",
        context=report_context,
        output_path=report_path,
    )
    logging.info(f"HTML report generated at {report_path}")

    logging.info("Pipeline execution completed successfully.")
    logging.info("To view the interactive dashboard, run: streamlit run dashboard.py")


if __name__ == "__main__":
    main()