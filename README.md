# Medicare Provider Analytics and Anomaly Detection

Portfolio analytics project for CMS Medicare Physician and Other Practitioners data across 2013 to 2024.

## What Has Been Completed

- Multi-year ingestion and integration for all CMS files from 2013 to 2024.
- Unified PostgreSQL star schema implemented and validated.
- ETL pipeline updated for year-aware loading with row count validation.
- SQL analytics queries implemented and aligned with schema.
- Reusable reporting views implemented.
- SQL-first EDA notebook implemented using direct PostgreSQL queries.
- Provider-level feature engineering notebook implemented.
- Isolation Forest anomaly detection notebook implemented with score exports.
- Power BI delivery completed:
	- Imported PostgreSQL tables.
	- Built data model.
	- Created DAX measures.
	- Built Executive Dashboard.
	- Built Spending Analysis page.
	- Built Geographic Analysis page.
	- Built Provider Analysis page.
	- Built Procedure Analysis page.
	- Built Anomaly Detection page.

## Project Structure

- Data/raw/: CMS source CSV files.
- Data/interim/: Intermediate processing outputs.
- Data/processed/: Modeling and analytics outputs.
- sql/: Schema, views, and analytics SQL.
- src/: ETL and Python pipeline code.
- notebooks/: EDA, feature engineering, and anomaly detection workflows.
- reports/powerbi/: Power BI report assets.

## Technology Stack

- PostgreSQL 16 in Docker
- Python 3.11+
- Pandas, NumPy, scikit-learn
- SQLAlchemy and psycopg2
- Jupyter Notebook
- Power BI Desktop

## Database and Runtime Configuration

- PostgreSQL host: localhost
- PostgreSQL port: 5433
- Database: medicare_provider_analytics
- User: medicare_user
- Password: medicare_password

## How To Run The Project

### 1) Start PostgreSQL

Run from project root:

docker compose up -d

Notes:
- On container startup, sql/schema.sql and sql/views.sql are mounted and used for initialization.

### 2) Create Python environment and install dependencies

Windows PowerShell:

python -m venv .venv
.venv\Scripts\Activate.ps1
pip install -r requirements.txt

### 3) Run ETL for 2013 to 2024

python .\src\etl_pipeline.py

This loads all yearly files, derives data_year from filename, and writes to the unified fact and dimension tables.

### 4) Apply or refresh SQL views and analytics scripts

Run views:

Get-Content .\sql\views.sql -Raw | docker compose exec -T postgres psql -U medicare_user -d medicare_provider_analytics

Run analysis queries:

Get-Content .\sql\analysis_queries.sql -Raw | docker compose exec -T postgres psql -U medicare_user -d medicare_provider_analytics

### 5) Run notebooks

Launch Jupyter:

jupyter notebook

Recommended order:
- notebooks/eda_postgresql.ipynb
- notebooks/feature_engineering.ipynb
- notebooks/data_exploration.ipynb

### 6) Generated outputs

Feature engineering output:
- Data/processed/provider_modeling_dataset.csv

Anomaly detection outputs:
- Data/processed/provider_anomaly_scores.csv
- Data/processed/high_risk_providers.csv

## Power BI Implementation Summary

Completed Power BI workflow:
- PostgreSQL tables imported from the warehouse.
- Star model relationships configured.
- DAX measures created for spend, utilization, growth, and anomaly KPIs.
- Six report pages delivered:
	- Executive Dashboard
	- Spending Analysis
	- Geographic Analysis
	- Provider Analysis
	- Procedure Analysis
	- Anomaly Detection

Suggested refresh flow:
1. Run ETL.
2. Re-run views and analysis SQL.
3. Refresh Power BI dataset.

## Data Integration Notes

- All source files currently loaded follow the same 28-column raw structure.
- The warehouse uses one consistent schema for all years.
- No per-year table branching is required.

## Current Status

Project is in a working end-to-end state:
- Data ingestion complete.
- Warehouse and analytics SQL complete.
- Notebook analysis complete.
- Anomaly scoring complete.
- Power BI reporting complete.
