import unittest
from unittest.mock import patch, MagicMock, call
import os
import pandas as pd
import job

class TestJobPipeline(unittest.TestCase):

    @patch('job.get_settings')
    @patch('job.os.makedirs')
    @patch('job.load_and_prepare_data')
    @patch('job.validate_data')
    @patch('job.detect_price_outliers')
    @patch('job.calculate_moving_average')
    @patch('job.train_and_forecast_sarima')
    @patch('job.combine_all_data')
    @patch('job.plot_price_and_moving_average')
    @patch('job.plot_forecast')
    @patch('job.plot_time_series_decomposition')
    @patch('job.plot_diagnostics')
    @patch('job.get_summary_statistics')
    @patch('job.generate_html_report')
    def test_main_pipeline_flow(self, mock_generate_report, mock_get_stats, 
                                mock_plot_diag, mock_plot_decomp, mock_plot_forecast, mock_plot_price_ma,
                                mock_combine, mock_forecast, mock_ma, mock_detect_outliers,
                                mock_validate, mock_load, mock_makedirs, mock_get_settings):
        """Test the end-to-end flow of the main job function."""
        
        # --- Mock Configuration ---
        mock_settings = MagicMock()
        mock_settings.output_dir = "/fake/output"
        mock_settings.viz_dir = "/fake/output/visualizations"
        mock_settings.input_data_path = "/fake/input/data.csv"
        mock_settings.ma_window = 90
        mock_settings.forecast_horizon = 365
        mock_settings.sarima_order = (1, 1, 1)
        mock_settings.sarima_seasonal_order = (1, 1, 1, 12)
        mock_get_settings.return_value = mock_settings

        # --- Mock DataFrames ---
        mock_raw_df = pd.DataFrame({'price': [1, 2, 3]})
        mock_ma_df = pd.DataFrame({'price': [1, 2, 3], 'moving_average_90': [1, 1.5, 2]})
        mock_forecast_df = pd.DataFrame({'forecast': [4, 5]})
        mock_final_df = pd.DataFrame({'price': [1, 2, 3], 'forecast': [None, None, None, 4, 5]})
        
        # --- Mock Function Returns ---
        mock_load.return_value = mock_raw_df
        mock_validate.return_value = mock_raw_df
        mock_detect_outliers.return_value = pd.DataFrame() # No outliers
        mock_ma.return_value = mock_ma_df
        mock_forecast.return_value = mock_forecast_df
        mock_combine.return_value = mock_final_df
        mock_get_stats.return_value = {'last_actual_price': '$3.00', 'final_forecast_price': '$5.00'}
        mock_plot_forecast.return_value = MagicMock() # Plotly figure

        # --- Run the job ---
        job.main()

        # --- Assertions ---
        mock_get_settings.assert_called_once()
        mock_makedirs.assert_has_calls([
            call("/fake/output", exist_ok=True),
            call("/fake/output/visualizations", exist_ok=True)
        ])
        
        # Data processing calls
        mock_load.assert_called_once_with("/fake/input/data.csv")
        mock_validate.assert_called_once_with(mock_raw_df)
        mock_detect_outliers.assert_called_once()
        
        # Analysis calls
        mock_ma.assert_called_once_with(mock_raw_df, window=90)
        mock_forecast.assert_called_once()
        mock_combine.assert_called_once_with(mock_ma_df, mock_forecast_df)
        
        # Visualization calls
        mock_plot_price_ma.assert_called_once()
        mock_plot_forecast.assert_called_once_with(mock_final_df)
        mock_plot_decomp.assert_called_once()
        mock_plot_diag.assert_called_once()
        
        # Reporting calls
        mock_get_stats.assert_called_once_with(mock_final_df, mock_forecast_df)
        mock_generate_report.assert_called_once()
        
        # Check if final dataframe was saved
        mock_final_df.to_csv.assert_called_once_with(os.path.join(mock_settings.output_dir, "final_forecast_data.csv"))

if __name__ == '__main__':
    unittest.main()