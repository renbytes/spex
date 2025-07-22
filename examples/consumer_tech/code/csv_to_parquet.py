### FILE: csv_to_parquet.py

import logging
from pathlib import Path
import pandas as pd

# ==============================================================================
#                                 CONFIGURATION
# ==============================================================================
# Instructions:
# 1. Add the full paths to your input CSV files to the list below.
# 2. Specify the directory where you want the Parquet files to be saved.

# Example for macOS/Linux:
# CSV_FILE_PATHS = [
#     "/Users/your_user/data/source/sales.csv",
#     "/Users/your_user/data/source/inventory.csv",
# ]
# OUTPUT_DIRECTORY = "/Users/your_user/data/output/parquet"

# Example for Windows:
# CSV_FILE_PATHS = [
#     "C:\\Users\\your_user\\data\\source\\sales.csv",
#     "C:\\Users\\your_user\\data\\source\\inventory.csv",
# ]
# OUTPUT_DIRECTORY = "C:\\Users\\your_user\\data\\output\\parquet"

CSV_FILE_PATHS = [
    '/Users/bordumb/workspace/repositories/specds/generated_jobs/pyspark/subscription-attribution/20250721-040034__user-signup-flow/data/app_events.csv',
    '/Users/bordumb/workspace/repositories/specds/generated_jobs/pyspark/subscription-attribution/20250721-040034__user-signup-flow/data/signups.csv',
    '/Users/bordumb/workspace/repositories/specds/generated_jobs/pyspark/subscription-attribution/20250721-040034__user-signup-flow/data/products.csv',
]

OUTPUT_DIRECTORY = "/Users/bordumb/workspace/repositories/specds/generated_jobs/pyspark/subscription-attribution/20250721-040034__user-signup-flow/data"

# ==============================================================================

# Configure basic logging to provide feedback to the user
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(levelname)s - %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
)


def convert_csv_to_parquet(csv_path: Path, output_dir: Path) -> None:
    """
    Reads a single CSV file and writes its contents to a Parquet file.

    The output Parquet file will have the same base name as the input CSV file
    but with a .parquet extension.

    Args:
        csv_path: The path to the input CSV file.
        output_dir: The directory where the output Parquet file will be saved.
    """
    try:
        logging.info(f"Processing '{csv_path.name}'...")

        # Construct the output path, replacing the .csv extension with .parquet
        output_filename = csv_path.stem + ".parquet"
        output_path = output_dir / output_filename

        # Read the CSV file into a pandas DataFrame
        df = pd.read_csv(csv_path)

        # Write the DataFrame to a Parquet file
        # The 'pyarrow' engine is commonly used and efficient.
        df.to_parquet(output_path, engine="pyarrow", index=False)

        logging.info(f"Successfully converted '{csv_path.name}' to '{output_path.name}'")

    except FileNotFoundError:
        logging.error(f"Error: The file '{csv_path}' was not found.")
    except Exception as e:
        logging.error(f"An unexpected error occurred while processing '{csv_path.name}': {e}")


def main():
    """
    Main function to orchestrate the conversion process based on the configuration.
    """
    # Validate configuration
    if not CSV_FILE_PATHS or not OUTPUT_DIRECTORY:
        logging.critical(
            "Configuration error: Please set CSV_FILE_PATHS and OUTPUT_DIRECTORY at the top of the script."
        )
        return

    output_dir = Path(OUTPUT_DIRECTORY)

    # Ensure the output directory exists, creating it if necessary.
    try:
        output_dir.mkdir(parents=True, exist_ok=True)
        logging.info(f"Output directory is '{output_dir}'.")
    except Exception as e:
        logging.critical(f"Failed to create output directory '{output_dir}': {e}")
        return

    # Process each CSV file from the configuration list
    for file_path_str in CSV_FILE_PATHS:
        csv_file_path = Path(file_path_str)
        convert_csv_to_parquet(csv_file_path, output_dir)

    logging.info("Conversion process finished.")


if __name__ == "__main__":
    main()