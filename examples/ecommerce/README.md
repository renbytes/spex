# E-commerce Top Selling Products Analysis

This example demonstrates how to use `specds` to generate a SQL-based analytics pipeline for identifying top-selling products in an e-commerce system.

## Objective

The goal is to analyze sales transaction data to identify the top 10 best-selling products by total quantity sold. This analysis joins sales orders with product metadata to provide human-readable product names in the final output.

## Prerequisites

1. The `specds` CLI must be installed and available in your system's PATH.
2. This example uses these sample data files:
   - `examples/ecommerce/sales_orders.csv` - Transactional sales data
   - `examples/ecommerce/products.csv` - Product metadata and names
3. You must have a `spec.toml` file that defines the analysis and points to the data files.

## Sample Data Overview

**Sales Orders (`sales_orders.csv`):**
- Contains order ID, product ID, quantity, and order date
- Represents individual product sales transactions

**Products (`products.csv`):**
- Maps product IDs to human-readable product names
- Provides metadata for sales analysis

## Instructions

This example uses SQL generation for dbt-style analytics workflows.

1. **Organize Your Files:** Place the two `.csv` files and the `spec.toml` file in the `examples/ecommerce/` directory.

2. **Run the Generator:** From your terminal, execute the `generate` command, pointing it to your specification file using the `--spec` flag.

```bash
specds generate --spec examples/ecommerce/spec.toml
```

## Output

After running the command, `specds` will create a new directory inside `generated_jobs/` containing a complete dbt-style SQL project:

```
generated_jobs/
└── sql/
    └── top-10-selling-products/
        └── 20250720-193000__identifies-the-top-10-best-selling-products-by-to/
            ├── models/
            │   ├── job.sql
            │   └── schema.yml
            ├── tests/
            │   └── custom_test.sql
            └── README.md
```

## Expected Results

The analysis will produce a ranked list of the top 10 products by total quantity sold, including:
- Product ID
- Product name
- Total quantity sold
- Ranking by sales volume

This type of analysis is commonly used for:
- Inventory planning and management
- Marketing focus and promotion decisions
- Product performance reporting
- Sales trend analysis