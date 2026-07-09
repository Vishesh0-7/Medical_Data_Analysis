"""ETL entry point for Medicare Provider Analytics & Anomaly Detection."""

from __future__ import annotations

import csv
import logging
import re
from pathlib import Path
from typing import Iterable

from sqlalchemy import create_engine, text


PROJECT_ROOT = Path(__file__).resolve().parents[1]
RAW_DATA_DIR = PROJECT_ROOT / "Data" / "raw"
LOG_DIR = PROJECT_ROOT / "logs"
TARGET_DB_URL = "postgresql+psycopg2://medicare_user:medicare_password@localhost:5433/medicare_provider_analytics"
PIPELINE_NAME = "provider_service_etl_all_years"
STAGING_TABLE = "stg_provider_service"
CLEANED_STAGE_TABLE = "cleaned_provider_service"
SOURCE_FILE_PATTERN = re.compile(r"D(?P<year_code>\d{2})_Prov_Svc\.csv$", re.IGNORECASE)

RAW_SOURCE_COLUMNS = [
    "Rndrng_NPI",
    "Rndrng_Prvdr_Last_Org_Name",
    "Rndrng_Prvdr_First_Name",
    "Rndrng_Prvdr_MI",
    "Rndrng_Prvdr_Crdntls",
    "Rndrng_Prvdr_Ent_Cd",
    "Rndrng_Prvdr_St1",
    "Rndrng_Prvdr_St2",
    "Rndrng_Prvdr_City",
    "Rndrng_Prvdr_State_Abrvtn",
    "Rndrng_Prvdr_State_FIPS",
    "Rndrng_Prvdr_Zip5",
    "Rndrng_Prvdr_RUCA",
    "Rndrng_Prvdr_RUCA_Desc",
    "Rndrng_Prvdr_Cntry",
    "Rndrng_Prvdr_Type",
    "Rndrng_Prvdr_Mdcr_Prtcptg_Ind",
    "HCPCS_Cd",
    "HCPCS_Desc",
    "HCPCS_Drug_Ind",
    "Place_Of_Srvc",
    "Tot_Benes",
    "Tot_Srvcs",
    "Tot_Bene_Day_Srvcs",
    "Avg_Sbmtd_Chrg",
    "Avg_Mdcr_Alowd_Amt",
    "Avg_Mdcr_Pymt_Amt",
    "Avg_Mdcr_Stdzd_Amt",
]

CLEAN_STAGE_COLUMNS = [
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
    "data_year",
]


def setup_logging() -> logging.Logger:
    """Configure console and file logging for the pipeline."""
    LOG_DIR.mkdir(parents=True, exist_ok=True)
    logger = logging.getLogger("medicare_provider_analytics")
    logger.setLevel(logging.INFO)

    if not logger.handlers:
        formatter = logging.Formatter(
            fmt="%(asctime)s | %(levelname)s | %(name)s | %(message)s"
        )
        stream_handler = logging.StreamHandler()
        stream_handler.setFormatter(formatter)
        file_handler = logging.FileHandler(LOG_DIR / "etl_pipeline.log", encoding="utf-8")
        file_handler.setFormatter(formatter)
        logger.addHandler(stream_handler)
        logger.addHandler(file_handler)

    return logger


def discover_source_files(raw_data_dir: Path) -> list[Path]:
    """Return CMS source files available for ingestion."""
    return sorted(raw_data_dir.glob("*.csv"))


def extract_data_year(source_file: Path) -> int:
    """Extract the reporting year from the CMS filename."""
    match = SOURCE_FILE_PATTERN.search(source_file.name)
    if not match:
        raise ValueError(f"Unable to parse data year from filename: {source_file.name}")

    year_code = int(match.group("year_code"))
    return 2000 + year_code


def read_source_header(source_file: Path) -> list[str]:
    """Read the CSV header without loading the full file."""
    with source_file.open("r", encoding="utf-8", newline="") as handle:
        reader = csv.reader(handle)
        return next(reader)


def validate_source_files(source_files: Iterable[Path]) -> None:
    """Validate source inventory and make sure all CSVs share one schema."""
    discovered = list(source_files)
    if not discovered:
        raise FileNotFoundError(f"No CSV files found in {RAW_DATA_DIR}")

    expected_columns = None
    for source_file in discovered:
        header = read_source_header(source_file)
        if expected_columns is None:
            expected_columns = header
            continue
        if header != expected_columns:
            raise ValueError(
                f"Schema mismatch in {source_file.name}. Expected {expected_columns} but got {header}"
            )

    if expected_columns != RAW_SOURCE_COLUMNS:
        raise ValueError(
            f"Unexpected canonical schema. Expected {RAW_SOURCE_COLUMNS} but got {expected_columns}"
        )


def _get_engine():
    return create_engine(TARGET_DB_URL, future=True)


def _create_staging_table(connection) -> None:
    connection.exec_driver_sql(f"DROP TABLE IF EXISTS {STAGING_TABLE};")
    connection.exec_driver_sql(
        f"""
        CREATE UNLOGGED TABLE {STAGING_TABLE} (
            npi TEXT,
            last_org_name TEXT,
            first_name TEXT,
            middle_initial TEXT,
            credentials TEXT,
            entity_code TEXT,
            address_line_1 TEXT,
            address_line_2 TEXT,
            city TEXT,
            state_abbreviation TEXT,
            state_fips TEXT,
            zip5 TEXT,
            ruca_code TEXT,
            ruca_description TEXT,
            country TEXT,
            provider_type TEXT,
            medicare_participation_ind TEXT,
            hcpcs_code TEXT,
            hcpcs_description TEXT,
            hcpcs_drug_ind TEXT,
            place_of_service TEXT,
            tot_benes TEXT,
            tot_srvcs TEXT,
            tot_bene_day_srvcs TEXT,
            avg_sbmtd_chrg TEXT,
            avg_mdcr_alowd_amt TEXT,
            avg_mdcr_pymt_amt TEXT,
            avg_mdcr_stdzd_amt TEXT,
            data_year INTEGER
        );
        """
    )


def _truncate_target_tables(connection) -> None:
    connection.execute(
        text(
            "TRUNCATE TABLE fact_provider_service, dim_provider, dim_geography, dim_service, etl_audit_log RESTART IDENTITY CASCADE"
        )
    )


def _truncate_staging_table(connection) -> None:
    connection.execute(text(f"TRUNCATE TABLE {STAGING_TABLE}"))


def _copy_source_file_to_stage(raw_connection, source_file: Path) -> None:
    copy_sql = f"""
        COPY {STAGING_TABLE} ({', '.join(CLEAN_STAGE_COLUMNS[:-1])})
        FROM STDIN WITH (FORMAT CSV, HEADER TRUE)
    """
    with raw_connection.cursor() as cursor:
        with source_file.open("r", encoding="utf-8", newline="") as handle:
            cursor.copy_expert(copy_sql, handle)
    raw_connection.commit()


def _mark_staging_year(connection, data_year: int) -> None:
    connection.execute(
        text(f"UPDATE {STAGING_TABLE} SET data_year = :data_year"),
        {"data_year": data_year},
    )


def _build_cleaned_stage(connection, data_year: int) -> None:
    connection.execute(text(f"DROP TABLE IF EXISTS {CLEANED_STAGE_TABLE}"))
    connection.execute(
        text(
            f"""
            CREATE TEMP TABLE {CLEANED_STAGE_TABLE} AS
            SELECT
                COALESCE(NULLIF(BTRIM(npi), ''), '') AS npi,
                COALESCE(NULLIF(BTRIM(last_org_name), ''), 'UNKNOWN') AS last_org_name,
                COALESCE(NULLIF(BTRIM(first_name), ''), 'UNKNOWN') AS first_name,
                NULLIF(BTRIM(middle_initial), '') AS middle_initial,
                COALESCE(NULLIF(BTRIM(credentials), ''), 'UNKNOWN') AS credentials,
                COALESCE(NULLIF(BTRIM(entity_code), ''), 'U') AS entity_code,
                COALESCE(NULLIF(BTRIM(address_line_1), ''), 'UNKNOWN') AS address_line_1,
                COALESCE(NULLIF(BTRIM(address_line_2), ''), '') AS address_line_2,
                COALESCE(NULLIF(BTRIM(city), ''), 'UNKNOWN') AS city,
                RIGHT('00' || COALESCE(NULLIF(BTRIM(state_abbreviation), ''), 'UN'), 2) AS state_abbreviation,
                RIGHT('00' || COALESCE(NULLIF(BTRIM(state_fips), ''), '00'), 2) AS state_fips,
                COALESCE(NULLIF(BTRIM(zip5), ''), '00000') AS zip5,
                COALESCE(NULLIF(BTRIM(ruca_code), '')::NUMERIC(4,1), -1) AS ruca_code,
                COALESCE(NULLIF(BTRIM(ruca_description), ''), 'UNKNOWN') AS ruca_description,
                COALESCE(NULLIF(BTRIM(country), ''), 'US') AS country,
                COALESCE(NULLIF(BTRIM(provider_type), ''), 'UNKNOWN') AS provider_type,
                COALESCE(NULLIF(BTRIM(medicare_participation_ind), ''), 'U') AS medicare_participation_ind,
                COALESCE(NULLIF(BTRIM(hcpcs_code), ''), '') AS hcpcs_code,
                COALESCE(NULLIF(BTRIM(hcpcs_description), ''), 'UNKNOWN') AS hcpcs_description,
                COALESCE(NULLIF(BTRIM(hcpcs_drug_ind), ''), 'U') AS hcpcs_drug_ind,
                COALESCE(NULLIF(BTRIM(place_of_service), ''), 'U') AS place_of_service,
                NULLIF(BTRIM(tot_benes), '')::BIGINT AS tot_benes,
                NULLIF(BTRIM(tot_srvcs), '')::NUMERIC(18,6) AS tot_srvcs,
                NULLIF(BTRIM(tot_bene_day_srvcs), '')::BIGINT AS tot_bene_day_srvcs,
                NULLIF(BTRIM(avg_sbmtd_chrg), '')::NUMERIC(18,6) AS avg_sbmtd_chrg,
                NULLIF(BTRIM(avg_mdcr_alowd_amt), '')::NUMERIC(18,6) AS avg_mdcr_alowd_amt,
                NULLIF(BTRIM(avg_mdcr_pymt_amt), '')::NUMERIC(18,6) AS avg_mdcr_pymt_amt,
                NULLIF(BTRIM(avg_mdcr_stdzd_amt), '')::NUMERIC(18,6) AS avg_mdcr_stdzd_amt,
                data_year
            FROM {STAGING_TABLE}
            WHERE NULLIF(BTRIM(npi), '') IS NOT NULL
        """
        )
    )
    connection.execute(text(f"CREATE INDEX ON {CLEANED_STAGE_TABLE} (npi)"))
    connection.execute(text(f"CREATE INDEX ON {CLEANED_STAGE_TABLE} (hcpcs_code, place_of_service)"))
    connection.execute(
        text(
            f"CREATE INDEX ON {CLEANED_STAGE_TABLE} (address_line_1, address_line_2, city, state_abbreviation, state_fips, zip5, country, ruca_code, ruca_description)"
        )
    )


def _load_dimensions_and_fact(connection, data_year: int) -> tuple[int, int, int]:
    connection.execute(
        text(
            f"""
            INSERT INTO dim_provider (
                npi,
                last_org_name,
                first_name,
                middle_initial,
                credentials,
                entity_code,
                provider_type,
                medicare_participation_ind
            )
            SELECT DISTINCT
                npi::CHAR(10),
                last_org_name,
                first_name,
                middle_initial,
                credentials,
                entity_code::CHAR(1),
                provider_type,
                medicare_participation_ind::CHAR(1)
            FROM {CLEANED_STAGE_TABLE}
            ON CONFLICT (npi) DO NOTHING
            """
        )
    )

    connection.execute(
        text(
            f"""
            INSERT INTO dim_geography (
                address_line_1,
                address_line_2,
                city,
                state_abbreviation,
                state_fips,
                zip5,
                country,
                ruca_code,
                ruca_description
            )
            SELECT DISTINCT
                address_line_1,
                address_line_2,
                city,
                state_abbreviation::CHAR(2),
                state_fips::CHAR(2),
                zip5,
                country,
                ruca_code,
                ruca_description
            FROM {CLEANED_STAGE_TABLE}
            ON CONFLICT (
                address_line_1,
                address_line_2,
                city,
                state_abbreviation,
                state_fips,
                zip5,
                country,
                ruca_code,
                ruca_description
            ) DO NOTHING
            """
        )
    )

    connection.execute(
        text(
            f"""
            INSERT INTO dim_service (
                hcpcs_code,
                hcpcs_description,
                hcpcs_drug_ind,
                place_of_service
            )
            SELECT DISTINCT
                hcpcs_code,
                hcpcs_description,
                hcpcs_drug_ind::CHAR(1),
                place_of_service::CHAR(1)
            FROM {CLEANED_STAGE_TABLE}
            ON CONFLICT (hcpcs_code, place_of_service) DO NOTHING
            """
        )
    )

    connection.execute(
        text(
            f"""
            INSERT INTO fact_provider_service (
                provider_key,
                geography_key,
                service_key,
                data_year,
                tot_benes,
                tot_srvcs,
                tot_bene_day_srvcs,
                avg_sbmtd_chrg,
                avg_mdcr_alowd_amt,
                avg_mdcr_pymt_amt,
                avg_mdcr_stdzd_amt
            )
            SELECT
                p.provider_key,
                g.geography_key,
                s.service_key,
                cleaned.data_year,
                cleaned.tot_benes,
                cleaned.tot_srvcs,
                cleaned.tot_bene_day_srvcs,
                cleaned.avg_sbmtd_chrg,
                cleaned.avg_mdcr_alowd_amt,
                cleaned.avg_mdcr_pymt_amt,
                cleaned.avg_mdcr_stdzd_amt
            FROM {CLEANED_STAGE_TABLE} cleaned
            JOIN dim_provider p ON p.npi = cleaned.npi::CHAR(10)
            JOIN dim_geography g ON g.address_line_1 = cleaned.address_line_1
                AND g.address_line_2 IS NOT DISTINCT FROM cleaned.address_line_2
                AND g.city = cleaned.city
                AND g.state_abbreviation = cleaned.state_abbreviation::CHAR(2)
                AND g.state_fips = cleaned.state_fips::CHAR(2)
                AND g.zip5 = cleaned.zip5
                AND g.country = cleaned.country
                AND g.ruca_code IS NOT DISTINCT FROM cleaned.ruca_code
                AND g.ruca_description = cleaned.ruca_description
            JOIN dim_service s ON s.hcpcs_code = cleaned.hcpcs_code
                AND s.place_of_service = cleaned.place_of_service::CHAR(1)
            ON CONFLICT (provider_key, geography_key, service_key, data_year) DO NOTHING
            """
        )
    )

    source_rows = int(connection.execute(text(f"SELECT COUNT(*) FROM {STAGING_TABLE}")).scalar_one())
    cleaned_rows = int(connection.execute(text(f"SELECT COUNT(*) FROM {CLEANED_STAGE_TABLE}")).scalar_one())
    loaded_rows = int(
        connection.execute(
            text("SELECT COUNT(*) FROM fact_provider_service WHERE data_year = :data_year"),
            {"data_year": data_year},
        ).scalar_one()
    )
    return source_rows, cleaned_rows, loaded_rows


def run_pipeline() -> None:
    """Run the full ETL pipeline end to end for all raw yearly files."""
    logger = setup_logging()
    source_files = discover_source_files(RAW_DATA_DIR)
    validate_source_files(source_files)

    engine = _get_engine()
    total_source_rows = 0
    total_cleaned_rows = 0
    total_loaded_rows = 0

    with engine.begin() as connection:
        _truncate_target_tables(connection)
        _create_staging_table(connection)

    for source_file in source_files:
        data_year = extract_data_year(source_file)
        raw_connection = engine.raw_connection()
        try:
            with engine.begin() as connection:
                _truncate_staging_table(connection)

            _copy_source_file_to_stage(raw_connection, source_file)
        finally:
            raw_connection.close()

        with engine.begin() as connection:
            _mark_staging_year(connection, data_year)
            _build_cleaned_stage(connection, data_year)
            source_rows, cleaned_rows, loaded_rows = _load_dimensions_and_fact(connection, data_year)
            total_source_rows += source_rows
            total_cleaned_rows += cleaned_rows
            total_loaded_rows += loaded_rows

            if cleaned_rows != loaded_rows:
                raise ValueError(
                    f"Row count mismatch for {source_file.name}: cleaned={cleaned_rows}, loaded={loaded_rows}"
                )

            connection.execute(
                text(
                    """
                    INSERT INTO etl_audit_log (
                        pipeline_name,
                        source_file,
                        run_status,
                        rows_read,
                        rows_written,
                        run_finished_at
                    )
                    VALUES (
                        :pipeline_name,
                        :source_file,
                        :run_status,
                        :rows_read,
                        :rows_written,
                        CURRENT_TIMESTAMP
                    )
                    """
                ),
                {
                    "pipeline_name": PIPELINE_NAME,
                    "source_file": source_file.name,
                    "run_status": "SUCCESS",
                    "rows_read": source_rows,
                    "rows_written": loaded_rows,
                },
            )

        logger.info(
            "Loaded %s: source=%s, cleaned=%s, loaded=%s.",
            source_file.name,
            source_rows,
            cleaned_rows,
            loaded_rows,
        )

    logger.info("Total source rows=%s, total cleaned rows=%s, total loaded rows=%s.", total_source_rows, total_cleaned_rows, total_loaded_rows)
    if total_cleaned_rows != total_loaded_rows:
        raise ValueError(
            f"Row count mismatch across all years: cleaned={total_cleaned_rows}, loaded={total_loaded_rows}"
        )

    logger.info("Multi-year ETL pipeline completed successfully.")


if __name__ == "__main__":
    run_pipeline()
