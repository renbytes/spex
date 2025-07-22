import streamlit as st
import pandas as pd
import os
from config import get_settings
from visualizations import plot_forecast
from functions import get_summary_statistics

st.set_page_config(layout="wide", page_title="Bitcoin Price Forecast Dashboard")

@st.cache_data
def load_data(data_path):
    """Loads the final combined data for the dashboard."""
    if os.path.exists(data_path):
        return pd.read_csv(data_path, index_col=0, parse_dates=True)
    return None

def main():
    """Main function to render the Streamlit dashboard."""
    st.title("📈 Bitcoin Price Forecast Dashboard")
    st.markdown("""
    This dashboard provides an interactive view of the Bitcoin daily price forecast. 
    The forecast is generated using a SARIMA model based on historical price data.
    """)

    settings = get_settings()
    data_path = os.path.join(settings.output_dir, "final_forecast_data.csv")
    
    data = load_data(data_path)

    if data is None:
        st.error(f"Forecast data not found at {data_path}. Please run the main pipeline first by executing `python job.py`.")
        return

    # Extract summary stats
    historical_data = data[['price']].dropna()
    forecast_data = data[['forecast', 'forecast_lower', 'forecast_upper']].dropna()
    summary_stats = get_summary_statistics(data, forecast_data)
    ma_col = [col for col in data.columns if 'moving_average' in col][0]

    # --- Metrics Row ---
    st.header("Key Metrics")
    col1, col2, col3 = st.columns(3)
    with col1:
        st.metric(label="Last Recorded Actual Price", value=summary_stats["last_actual_price"])
    with col2:
        st.metric(label=f"Forecast Price (in {settings.forecast_horizon} days)", value=summary_stats["final_forecast_price"])
    with col3:
        last_ma = data[ma_col].dropna().iloc[-1]
        st.metric(label=f"Last {settings.ma_window}-Day Moving Average", value=f"${last_ma:,.2f}")

    # --- Interactive Forecast Chart ---
    st.header("Interactive Forecast Chart")
    st.markdown("Use the tools to pan, zoom, and inspect the data points.")
    
    forecast_fig = plot_forecast(data)
    st.plotly_chart(forecast_fig, use_container_width=True)

    # --- Data Explorer ---
    st.header("Data Explorer")
    show_data = st.checkbox("Show raw and forecasted data table")
    if show_data:
        st.dataframe(data.style.format({
            "price": "${:,.2f}",
            ma_col: "${:,.2f}",
            "forecast": "${:,.2f}",
            "forecast_lower": "${:,.2f}",
            "forecast_upper": "${:,.2f}",
        }, na_rep=""))

    # --- Download Button ---
    st.download_button(
        label="Download Forecast Data as CSV",
        data=data.to_csv().encode('utf-8'),
        file_name='bitcoin_forecast_data.csv',
        mime='text/csv',
    )
    
    # --- Sidebar for methodology ---
    st.sidebar.header("Methodology")
    st.sidebar.info(f"""
    - **Model**: SARIMA {settings.sarima_order}{settings.sarima_seasonal_order}
    - **Forecast Horizon**: {settings.forecast_horizon} days
    - **Moving Average Window**: {settings.ma_window} days
    - **Input Data**: Historical daily prices from `{os.path.basename(settings.input_data_path)}`
    """)

if __name__ == "__main__":
    main()