# Visualization functions optimized for big data.
# These functions will be run after the main job and will load the final, aggregated results
# (which are small) to create plots.

import logging
import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns

from config import Settings

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)


def plot_signups_by_plan(df: pd.DataFrame) -> None:
    """
    Generates and saves a bar chart of attributed signups by plan.

    Args:
        df: A Pandas DataFrame containing the aggregated metrics.
    """
    plan_data = df[df['metric_level'] == 'By Plan'].copy()
    plan_data.sort_values('attributed_signups_by_plan', ascending=False, inplace=True)

    if plan_data.empty:
        logger.warning("No data available to plot signups by plan.")
        return

    plt.figure(figsize=(12, 7))
    sns.barplot(
        x='attributed_signups_by_plan',
        y='plan_name',
        data=plan_data,
        palette='viridis'
    )
    plt.title('Attributed Signups by Product Plan', fontsize=16)
    plt.xlabel('Number of Attributed Signups', fontsize=12)
    plt.ylabel('Plan Name', fontsize=12)
    plt.tight_layout()
    
    output_path = "output/attributed_signups_by_plan.png"
    plt.savefig(output_path)
    logger.info(f"Saved signups by plan chart to {output_path}")
    plt.close()


def display_global_kpis(df: pd.DataFrame) -> None:
    """
    Displays the global KPIs in a clean, readable format.

    Args:
        df: A Pandas DataFrame containing the aggregated metrics.
    """
    global_data = df[df['metric_level'] == 'Global Total'].iloc[0]

    if global_data.empty:
        logger.warning("No global KPI data available.")
        return
        
    print("\n" + "="*50)
    print("           GLOBAL ATTRUBUTION KPIs")
    print("="*50)
    print(f"Total Ad Impressions:     {int(global_data['total_ad_impressions']):,}")
    print(f"Total Ad Clicks:          {int(global_data['total_ad_clicks']):,}")
    print(f"Total Signups:            {int(global_data['total_signups']):,}")
    print(f"Attributed Signups:       {int(global_data['attributed_signups']):,}")
    print(f"Click-to-Signup Rate:     {global_data['click_to_signup_rate']:.2f}%")
    print("="*50 + "\n")


def main() -> None:
    """
    Main function to load results and generate visualizations.
    """
    settings = Settings()
    try:
        logger.info(f"Loading aggregated results from {settings.output_path}...")
        # Spark writes CSVs to a directory, find the actual csv file
        import glob
        csv_files = glob.glob(f"{settings.output_path}/*.csv")
        if not csv_files:
            raise FileNotFoundError("No CSV file found in the output directory.")
        
        results_df = pd.read_csv(csv_files[0])
        logger.info("Successfully loaded results.")
        
        display_global_kpis(results_df)
        plot_signups_by_plan(results_df)

    except FileNotFoundError:
        logger.error(f"Error: Output file not found at {settings.output_path}.")
        logger.error("Please run the main Spark job (`job.py`) first.")
    except Exception as e:
        logger.error(f"An error occurred during visualization: {e}", exc_info=True)


if __name__ == "__main__":
    main()