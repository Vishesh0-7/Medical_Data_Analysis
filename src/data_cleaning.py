"""Data cleaning utilities for CMS Medicare provider data."""

from __future__ import annotations

import pandas as pd


RAW_TO_CLEAN_COLUMN_MAP = {
    "Rndrng_NPI": "npi",
    "Rndrng_Prvdr_Last_Org_Name": "last_org_name",
    "Rndrng_Prvdr_First_Name": "first_name",
    "Rndrng_Prvdr_MI": "middle_initial",
    "Rndrng_Prvdr_Crdntls": "credentials",
    "Rndrng_Prvdr_Ent_Cd": "entity_code",
    "Rndrng_Prvdr_St1": "address_line_1",
    "Rndrng_Prvdr_St2": "address_line_2",
    "Rndrng_Prvdr_City": "city",
    "Rndrng_Prvdr_State_Abrvtn": "state_abbreviation",
    "Rndrng_Prvdr_State_FIPS": "state_fips",
    "Rndrng_Prvdr_Zip5": "zip5",
    "Rndrng_Prvdr_RUCA": "ruca_code",
    "Rndrng_Prvdr_RUCA_Desc": "ruca_description",
    "Rndrng_Prvdr_Cntry": "country",
    "Rndrng_Prvdr_Type": "provider_type",
    "Rndrng_Prvdr_Mdcr_Prtcptg_Ind": "medicare_participation_ind",
    "HCPCS_Cd": "hcpcs_code",
    "HCPCS_Desc": "hcpcs_description",
    "HCPCS_Drug_Ind": "hcpcs_drug_ind",
    "Place_Of_Srvc": "place_of_service",
    "Tot_Benes": "tot_benes",
    "Tot_Srvcs": "tot_srvcs",
    "Tot_Bene_Day_Srvcs": "tot_bene_day_srvcs",
    "Avg_Sbmtd_Chrg": "avg_sbmtd_chrg",
    "Avg_Mdcr_Alowd_Amt": "avg_mdcr_alowd_amt",
    "Avg_Mdcr_Pymt_Amt": "avg_mdcr_pymt_amt",
    "Avg_Mdcr_Stdzd_Amt": "avg_mdcr_stdzd_amt",
}

CLEAN_COLUMN_ORDER = [
    "npi",
    "last_org_name",
    "first_name",
    "middle_initial",
    "credentials",
    "entity_code",
    "address_line_1",
    "address_line_2",
    "city",
    "state_abbreviation",
    "state_fips",
    "zip5",
    "ruca_code",
    "ruca_description",
    "country",
    "provider_type",
    "medicare_participation_ind",
    "hcpcs_code",
    "hcpcs_description",
    "hcpcs_drug_ind",
    "place_of_service",
    "tot_benes",
    "tot_srvcs",
    "tot_bene_day_srvcs",
    "avg_sbmtd_chrg",
    "avg_mdcr_alowd_amt",
    "avg_mdcr_pymt_amt",
    "avg_mdcr_stdzd_amt",
]

TEXT_COLUMNS = [
    "npi",
    "last_org_name",
    "first_name",
    "middle_initial",
    "credentials",
    "entity_code",
    "address_line_1",
    "address_line_2",
    "city",
    "state_abbreviation",
    "state_fips",
    "zip5",
    "ruca_description",
    "country",
    "provider_type",
    "medicare_participation_ind",
    "hcpcs_code",
    "hcpcs_description",
    "hcpcs_drug_ind",
    "place_of_service",
]

INTEGER_COLUMNS = ["tot_benes", "tot_bene_day_srvcs"]
FLOAT_COLUMNS = [
    "ruca_code",
    "tot_srvcs",
    "avg_sbmtd_chrg",
    "avg_mdcr_alowd_amt",
    "avg_mdcr_pymt_amt",
    "avg_mdcr_stdzd_amt",
]


def standardize_column_names(df: pd.DataFrame) -> pd.DataFrame:
    """Standardize source column names for downstream processing."""
    data = df.copy()
    data.columns = [column.strip() for column in data.columns]
    data = data.rename(columns=RAW_TO_CLEAN_COLUMN_MAP)
    return data


def _clean_identifier(series: pd.Series, width: int) -> pd.Series:
    cleaned = series.astype("string").str.strip().str.replace(r"\.0$", "", regex=True)
    cleaned = cleaned.str.replace(r"[^0-9]", "", regex=True)
    cleaned = cleaned.str.zfill(width)
    return cleaned.replace({"" : pd.NA})


def _clean_zip(series: pd.Series) -> pd.Series:
    cleaned = series.astype("string").str.strip().str.replace(r"\.0$", "", regex=True)
    cleaned = cleaned.str.extract(r"(\d{5})", expand=False)
    return cleaned.replace({"" : pd.NA})


def coerce_data_types(df: pd.DataFrame) -> pd.DataFrame:
    """Coerce raw values into analysis-friendly types."""
    data = df.copy()

    for column in TEXT_COLUMNS:
        if column in data.columns:
            data[column] = data[column].astype("string").str.strip()

    if "npi" in data.columns:
        data["npi"] = _clean_identifier(data["npi"], 10)

    if "state_fips" in data.columns:
        data["state_fips"] = _clean_identifier(data["state_fips"], 2)

    if "zip5" in data.columns:
        data["zip5"] = _clean_zip(data["zip5"])

    if "entity_code" in data.columns:
        data["entity_code"] = data["entity_code"].astype("string").str.strip().str.upper().str.slice(0, 1)

    if "medicare_participation_ind" in data.columns:
        data["medicare_participation_ind"] = (
            data["medicare_participation_ind"].astype("string").str.strip().str.upper().str.slice(0, 1)
        )

    if "hcpcs_drug_ind" in data.columns:
        data["hcpcs_drug_ind"] = data["hcpcs_drug_ind"].astype("string").str.strip().str.upper().str.slice(0, 1)

    if "place_of_service" in data.columns:
        data["place_of_service"] = data["place_of_service"].astype("string").str.strip().str.upper().str.slice(0, 1)

    for column in INTEGER_COLUMNS:
        if column in data.columns:
            data[column] = pd.to_numeric(data[column], errors="coerce").astype("Int64")

    for column in FLOAT_COLUMNS:
        if column in data.columns:
            data[column] = pd.to_numeric(data[column], errors="coerce").astype("Float64")

    return data


def handle_missing_values(df: pd.DataFrame) -> pd.DataFrame:
    """Apply project-specific missing data rules."""
    data = df.copy()

    for column in TEXT_COLUMNS:
        if column in data.columns:
            data[column] = data[column].replace({"": pd.NA, " ": pd.NA, "NA": pd.NA, "N/A": pd.NA})

    fill_values = {
        "last_org_name": "UNKNOWN",
        "first_name": "UNKNOWN",
        "middle_initial": "",
        "credentials": "UNKNOWN",
        "entity_code": "U",
        "address_line_1": "UNKNOWN",
        "address_line_2": "",
        "city": "UNKNOWN",
        "state_abbreviation": "UN",
        "state_fips": "00",
        "zip5": "00000",
        "ruca_code": -1,
        "ruca_description": "UNKNOWN",
        "country": "US",
        "provider_type": "UNKNOWN",
        "medicare_participation_ind": "U",
        "hcpcs_description": "UNKNOWN",
        "hcpcs_drug_ind": "U",
        "place_of_service": "U",
    }

    for column, value in fill_values.items():
        if column in data.columns:
            data[column] = data[column].fillna(value)

    return data


def remove_duplicates(df: pd.DataFrame) -> pd.DataFrame:
    """Remove exact duplicate rows."""
    return df.drop_duplicates(ignore_index=True)


def clean_provider_service_data(df: pd.DataFrame) -> pd.DataFrame:
    """Run the full cleaning sequence."""
    data = standardize_column_names(df)
    data = coerce_data_types(data)
    data = handle_missing_values(data)
    data = remove_duplicates(data)
    return data.loc[:, CLEAN_COLUMN_ORDER]
