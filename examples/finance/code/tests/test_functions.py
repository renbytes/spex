import unittest
import pandas as pd
import numpy as np
from unittest.mock import patch, MagicMock
from functions import (
    load_and_prepare_data,
    calculate_moving_average,
    train_and_forecast_sarima,
    combine_all_data,
    get_summary_statistics,
)

class TestFunctions(unittest.TestCase):

    def setUp(self):
        """Set up mock data for tests."""
        dates = pd.to_datetime(pd.date_range(start="2022-01-01", periods=100, freq="D"))
        self.mock_df = pd.DataFrame({
            'price': np.linspace(100, 199, 100)
        }, index=dates)

    def test_load_and_prepare_data(self):
        """Test data loading and preparation."""
        csv_data = "snapped_at,price,market_cap,total_volume\n" \
                   "2022-01-01 00:00:00 UTC,100,1000,10\n" \
                   "2022-01-02 00:00:00 UTC,101,1010,11"
        
        with patch('pandas.read_csv', return_value=pd.read_csv(pd.io.common.StringIO(csv_data))):
            df = load_and_prepare_data("dummy_path.csv")
            self.assertIsInstance(df.index, pd.DatetimeIndex)
            self.assertEqual(len(df), 2)
            self.assertIn('price', df.columns)
            self.assertEqual(df.index.name, 'snapped_at')

    def test_calculate_moving_average(self):
        """Test moving average calculation."""
        window = 10
        df_with_ma = calculate_moving_average(self.mock_df, window=window)
        ma_col = f'moving_average_{window}'
        
        self.assertIn(ma_col, df_with_ma.columns)
        self.assertTrue(df_with_ma[ma_col].iloc[:window-1].isna().all())
        self.assertAlmostEqual(df_with_ma[ma_col].iloc[window-1], 104.5)

    @patch('functions.SARIMAX')
    def test_train_and_forecast_sarima(self, mock_sarimax):
        """Test SARIMA model training and forecasting logic."""
        mock_results = MagicMock()
        mock_forecast = MagicMock()
        mock_forecast.summary_frame.return_value = pd.DataFrame({
            'mean': [200, 201],
            'mean_ci_lower': [190, 191],
            'mean_ci_upper': [210, 211]
        })
        mock_results.get_forecast.return_value = mock_forecast
        mock_sarimax.return_value.fit.return_value = mock_results

        series = self.mock_df['price']
        order = (1, 1, 1)
        seasonal_order = (0, 0, 0, 0)
        steps = 2

        forecast_df = train_and_forecast_sarima(series, order, seasonal_order, steps)

        mock_sarimax.assert_called_once_with(series, order=order, seasonal_order=seasonal_order)
        mock_sarimax.return_value.fit.assert_called_once()
        mock_results.get_forecast.assert_called_once_with(steps=steps)
        self.assertEqual(len(forecast_df), 2)
        self.assertIn('forecast', forecast_df.columns)
        self.assertIn('forecast_lower', forecast_df.columns)
        self.assertIn('forecast_upper', forecast_df.columns)

    def test_combine_all_data(self):
        """Test combining historical and forecast data."""
        forecast_dates = pd.date_range(start="2022-04-11", periods=5, freq="D")
        forecast_df = pd.DataFrame({
            'forecast': np.arange(200, 205)
        }, index=forecast_dates)
        
        combined = combine_all_data(self.mock_df, forecast_df)
        self.assertEqual(len(combined), 105)
        self.assertEqual(combined['price'].iloc[-1], self.mock_df['price'].iloc[-1])
        self.assertEqual(combined['forecast'].iloc[-1], forecast_df['forecast'].iloc[-1])

    def test_get_summary_statistics(self):
        """Test summary statistics extraction."""
        final_df = self.mock_df.copy()
        final_df['price'].iloc[-1] = 199.99
        
        forecast_df = pd.DataFrame({'forecast': [300.50, 400.75]})
        
        stats = get_summary_statistics(final_df, forecast_df)
        self.assertEqual(stats['last_actual_price'], '$199.99')
        self.assertEqual(stats['final_forecast_price'], '$400.75')


if __name__ == '__main__':
    unittest.main()