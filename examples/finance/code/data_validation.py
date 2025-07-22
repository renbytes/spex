import pandas as pd
import pandera as pa
from pandera.typing import DataFrame, Series, Index

class PriceSchema(pa.DataFrameModel):
    """Pandera schema for validating the prepared price data."""
    price: Series[float] = pa.Field(
        ge=0, nullable=False, description="Bitcoin closing price in USD."
    )
    index: Index[pd.DatetimeTZDtype] = pa.Field(
        nullable=False, unique=True, description="Daily timestamp for the data."
    )

    class Config:
        strict = True
        coerce = True


def validate_data(df: pd.DataFrame) -> DataFrame[PriceSchema]:
    """Validates the input DataFrame against the PriceSchema.

    Args:
        df: The DataFrame to validate.

    Returns:
        The validated DataFrame if successful.
    
    Raises:
        pa.errors.SchemaError: If validation fails.
    """
    # Note: Pandera struggles with timezone-naive datetimes from `dt.tz_localize(None)`
    # We will work with a timezone-naive index for validation purposes.
    df_to_validate = df.copy()
    if df_to_validate.index.tz is not None:
        df_to_validate.index = df_to_validate.index.tz_localize(None)

    # Recreate schema for timezone-naive index
    class PriceSchemaNaive(pa.DataFrameModel):
        price: Series[float] = pa.Field(ge=0, nullable=False)
        index: Index[pd.Timestamp] = pa.Field(nullable=False, unique=True)
        class Config:
            strict = True
            coerce = True
            
    try:
        validated_df = PriceSchemaNaive.validate(df_to_validate)
        # Return original dataframe on success
        return df
    except pa.errors.SchemaError as e:
        print(f"Data validation failed: {e}")
        raise


def detect_price_outliers(df: pd.DataFrame, column: str, threshold: float = 1.5) -> pd.DataFrame:
    """Detects outliers in a specific column using the IQR method.

    Args:
        df: The DataFrame to check for outliers.
        column: The name of the column to check.
        threshold: The IQR multiplier to use for defining outliers.

    Returns:
        A DataFrame containing the rows identified as outliers.
    """
    q1 = df[column].quantile(0.25)
    q3 = df[column].quantile(0.75)
    iqr = q3 - q1
    lower_bound = q1 - (iqr * threshold)
    upper_bound = q3 + (iqr * threshold)

    outliers = df[(df[column] < lower_bound) | (df[column] > upper_bound)]
    return outliers