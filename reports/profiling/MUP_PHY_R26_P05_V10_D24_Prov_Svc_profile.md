# Profile Report: MUP_PHY_R26_P05_V10_D24_Prov_Svc

Scope: this report covers only `MUP_PHY_R26_P05_V10_D24_Prov_Svc.csv`.

## Executive Summary

- Row count: 9,781,673
- Column count: 28
- Exact duplicate rows: 0
- Total missing values: 12,668,203
- Pandas warning: `Rndrng_Prvdr_State_FIPS` and `Rndrng_Prvdr_Zip5` showed mixed-type inference during loading, so they should be treated as identifier strings rather than numeric fields.

## Data Types

| Column | pandas dtype | Inferred business type |
| --- | --- | --- |
| Rndrng_NPI | int64 | Provider identifier |
| Rndrng_Prvdr_Last_Org_Name | object | Text |
| Rndrng_Prvdr_First_Name | object | Text |
| Rndrng_Prvdr_MI | object | Text |
| Rndrng_Prvdr_Crdntls | object | Text |
| Rndrng_Prvdr_Ent_Cd | object | Categorical code |
| Rndrng_Prvdr_St1 | object | Address text |
| Rndrng_Prvdr_St2 | object | Address text |
| Rndrng_Prvdr_City | object | Geographic text |
| Rndrng_Prvdr_State_Abrvtn | object | State code |
| Rndrng_Prvdr_State_FIPS | object | State FIPS code |
| Rndrng_Prvdr_Zip5 | object | ZIP code |
| Rndrng_Prvdr_RUCA | float64 | Rural-Urban Commuting Area code |
| Rndrng_Prvdr_RUCA_Desc | object | RUCA description |
| Rndrng_Prvdr_Cntry | object | Country code/text |
| Rndrng_Prvdr_Type | object | Provider type / specialty |
| Rndrng_Prvdr_Mdcr_Prtcptg_Ind | object | Medicare participation indicator |
| HCPCS_Cd | object | HCPCS code |
| HCPCS_Desc | object | HCPCS description |
| HCPCS_Drug_Ind | object | Drug indicator |
| Place_Of_Srvc | object | Place-of-service code |
| Tot_Benes | int64 | Count measure |
| Tot_Srvcs | float64 | Count measure |
| Tot_Bene_Day_Srvcs | int64 | Count measure |
| Avg_Sbmtd_Chrg | float64 | Monetary measure |
| Avg_Mdcr_Alowd_Amt | float64 | Monetary measure |
| Avg_Mdcr_Pymt_Amt | float64 | Monetary measure |
| Avg_Mdcr_Stdzd_Amt | float64 | Monetary measure |

## Missing Values

| Column | Missing count | Missing % |
| --- | ---: | ---: |
| Rndrng_Prvdr_St2 | 7,637,996 | 78.08 |
| Rndrng_Prvdr_MI | 3,465,045 | 35.42 |
| Rndrng_Prvdr_Crdntls | 1,079,707 | 11.04 |
| Rndrng_Prvdr_First_Name | 474,867 | 4.85 |
| Rndrng_Prvdr_RUCA | 5,291 | 0.05 |
| Rndrng_Prvdr_RUCA_Desc | 5,291 | 0.05 |
| Rndrng_Prvdr_State_FIPS | 5 | 0.00 |
| Rndrng_Prvdr_Zip5 | 1 | 0.00 |

## Column Dictionary

| Column | Meaning |
| --- | --- |
| Rndrng_NPI | National Provider Identifier for the rendering provider. |
| Rndrng_Prvdr_Last_Org_Name | Provider last name for individuals, or organization name for organizational providers. |
| Rndrng_Prvdr_First_Name | Provider first name when the provider is an individual. |
| Rndrng_Prvdr_MI | Provider middle initial when available. |
| Rndrng_Prvdr_Crdntls | Provider credential suffix or designation, such as MD, DO, NP, or similar. |
| Rndrng_Prvdr_Ent_Cd | Provider entity type code indicating individual versus organization. |
| Rndrng_Prvdr_St1 | Primary street address line. |
| Rndrng_Prvdr_St2 | Secondary street address line or suite/unit information. |
| Rndrng_Prvdr_City | Provider city. |
| Rndrng_Prvdr_State_Abrvtn | Two-letter state abbreviation. |
| Rndrng_Prvdr_State_FIPS | State Federal Information Processing Standards code. |
| Rndrng_Prvdr_Zip5 | Five-digit ZIP code. |
| Rndrng_Prvdr_RUCA | Rural-Urban Commuting Area code. |
| Rndrng_Prvdr_RUCA_Desc | Human-readable description of the RUCA classification. |
| Rndrng_Prvdr_Cntry | Provider country. |
| Rndrng_Prvdr_Type | Provider type or specialty classification. |
| Rndrng_Prvdr_Mdcr_Prtcptg_Ind | Indicator showing whether the provider participates in Medicare. |
| HCPCS_Cd | Healthcare Common Procedure Coding System code for the service. |
| HCPCS_Desc | Plain-language description of the HCPCS-coded service. |
| HCPCS_Drug_Ind | Indicator showing whether the HCPCS code represents a drug. |
| Place_Of_Srvc | Place-of-service code for where the service was delivered. |
| Tot_Benes | Total number of distinct Medicare beneficiaries served. |
| Tot_Srvcs | Total number of services rendered. |
| Tot_Bene_Day_Srvcs | Total beneficiary day services reported. |
| Avg_Sbmtd_Chrg | Average submitted charge amount. |
| Avg_Mdcr_Alowd_Amt | Average Medicare allowed amount. |
| Avg_Mdcr_Pymt_Amt | Average Medicare payment amount. |
| Avg_Mdcr_Stdzd_Amt | Average standardized Medicare payment amount. |

## Observations

- The file is large at nearly 9.8 million rows but contains no exact duplicate rows.
- Most missingness is concentrated in provider address and credential fields, which is consistent with organizational records and partially populated contact data.
- Identifiers such as ZIP and FIPS should be preserved as text during ETL to avoid losing leading zeros.
- This profile is suitable as the baseline for the remaining years once the same validation rules are applied consistently.
