import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns
import plotly.graph_objects as go
from statsmodels.tsa.seasonal import seasonal_decompose
from statsmodels.tsa.statespace.sarimax import SARIMAX
from typing import Optional

sns.set_theme(style="whitegrid")

def plot_price_and_moving_average(df: pd.DataFrame, save_path: Optional[str] = None):
    """Plots the historical price and its moving average.

    Args:
        df: DataFrame containing 'price' and a 'moving_average_X' column.
        save_path: Optional path to save the figure.
    """
    ma_col = [col for col in df.columns if 'moving_average' in col][0]
    
    plt.figure(figsize=(15, 7))
    sns.lineplot(data=df, x=df.index, y='price', label='Daily Price', color='royalblue')
    sns.lineplot(data=df, x=df.index, y=ma_col, label=ma_col.replace('_', ' ').title(), color='orange')
    
    plt.title('Bitcoin Price and Moving Average', fontsize=16)
    plt.xlabel('Date')
    plt.ylabel('Price (USD)')
    plt.legend()
    plt.tight_layout()

    if save_path:
        plt.savefig(save_path, dpi=300)
    plt.close()

def plot_forecast(df: pd.DataFrame) -> go.Figure:
    """Creates an interactive Plotly chart of the price forecast.

    Args:
        df: DataFrame containing historical and forecasted data.

    Returns:
        A Plotly Figure object.
    """
    fig = go.Figure()

    # Historical Price
    fig.add_trace(go.Scatter(
        x=df.index,
        y=df['price'],
        mode='lines',
        name='Historical Price',
        line=dict(color='royalblue')
    ))

    # Forecasted Price
    fig.add_trace(go.Scatter(
        x=df.index,
        y=df['forecast'],
        mode='lines',
        name='Forecasted Price',
        line=dict(color='darkorange', dash='dot')
    ))

    # Confidence Interval
    fig.add_trace(go.Scatter(
        x=df.index,
        y=df['forecast_upper'],
        mode='lines',
        line=dict(width=0),
        fillcolor='rgba(255, 165, 0, 0.2)',
        showlegend=False
    ))
    fig.add_trace(go.Scatter(
        x=df.index,
        y=df['forecast_lower'],
        mode='lines',
        line=dict(width=0),
        fill='tonexty',
        fillcolor='rgba(255, 165, 0, 0.2)',
        name='95% Confidence Interval'
    ))

    fig.update_layout(
        title='Bitcoin Price Forecast vs. Historical Data',
        xaxis_title='Date',
        yaxis_title='Price (USD)',
        legend=dict(x=0.01, y=0.99),
        hovermode='x unified'
    )
    return fig

def plot_time_series_decomposition(series: pd.Series, model: str, period: int, save_path: Optional[str] = None):
    """Plots the decomposition of a time series.

    Args:
        series: The time series to decompose.
        model: The model type ('additive' or 'multiplicative').
        period: The seasonal period.
        save_path: Optional path to save the figure.
    """
    decomposition = seasonal_decompose(series, model=model, period=period)
    
    fig, (ax1, ax2, ax3, ax4) = plt.subplots(4, 1, figsize=(15, 12), sharex=True)
    
    decomposition.observed.plot(ax=ax1, legend=False)
    ax1.set_ylabel('Observed')
    decomposition.trend.plot(ax=ax2, legend=False)
    ax2.set_ylabel('Trend')
    decomposition.seasonal.plot(ax=ax3, legend=False)
    ax3.set_ylabel('Seasonal')
    decomposition.resid.plot(ax=ax4, legend=False)
    ax4.set_ylabel('Residual')
    
    fig.suptitle('Time Series Decomposition', fontsize=18)
    plt.tight_layout(rect=[0, 0, 1, 0.97])

    if save_path:
        plt.savefig(save_path, dpi=300)
    plt.close()

def plot_diagnostics(series, order, seasonal_order, save_path: Optional[str] = None):
    """
    Fits a SARIMA model and plots its diagnostics.
    """
    model = SARIMAX(series, order=order, seasonal_order=seasonal_order)
    results = model.fit(disp=False)
    
    fig = results.plot_diagnostics(figsize=(15, 12))
    plt.tight_layout()

    if save_path:
        plt.savefig(save_path, dpi=300)
    plt.close()