# Schema Comparison: 2013-2024 CMS Provider Service Files

## Scope

Compared the raw CSV headers for all provider service files in `Data/raw/`:

- MUP_PHY_R25_P04_V20_D13_Prov_Svc.csv
- MUP_PHY_R25_P04_V20_D14_Prov_Svc.csv
- MUP_PHY_R25_P04_V20_D15_Prov_Svc.csv
- MUP_PHY_R25_P04_V20_D16_Prov_Svc.csv
- MUP_PHY_R25_P04_V20_D17_Prov_Svc.csv
- MUP_PHY_R25_P04_V20_D18_Prov_Svc.csv
- MUP_PHY_R25_P04_V20_D19_Prov_Svc.csv
- MUP_PHY_R25_P05_V20_D20_Prov_Svc.csv
- MUP_PHY_R25_P05_V20_D21_Prov_Svc.csv
- MUP_PHY_R25_P05_V20_D22_Prov_Svc.csv
- MUP_PHY_R25_P05_V20_D23_Prov_Svc.csv
- MUP_PHY_R26_P05_V10_D24_Prov_Svc.csv

## Result

- All 12 files share the same 28-column header layout.
- No schema drift was detected between 2013 and 2024.
- No extra columns, missing columns, or reordered columns were found in the raw provider service extracts.

## Unified Schema Decision

A single star schema is sufficient for all years:

- `dim_provider`
- `dim_geography`
- `dim_service`
- `fact_provider_service`

The ETL derives `data_year` from the filename and loads each file into the same fact table grain of provider + geography + service + year.
