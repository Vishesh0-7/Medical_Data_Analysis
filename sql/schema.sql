-- Star schema for Medicare Provider Analytics & Anomaly Detection.
-- Grain: one row per provider + service + geography + reporting year.

CREATE TABLE IF NOT EXISTS dim_provider (
    provider_key BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    npi CHAR(10) NOT NULL,
    last_org_name TEXT,
    first_name TEXT,
    middle_initial VARCHAR(10),
    credentials VARCHAR(100),
    entity_code CHAR(1),
    provider_type TEXT,
    medicare_participation_ind CHAR(1),
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_dim_provider_npi UNIQUE (npi)
);

CREATE INDEX IF NOT EXISTS idx_dim_provider_npi ON dim_provider (npi);

CREATE TABLE IF NOT EXISTS dim_geography (
    geography_key BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    address_line_1 TEXT,
    address_line_2 TEXT,
    city TEXT,
    state_abbreviation CHAR(2),
    state_fips CHAR(2),
    zip5 VARCHAR(10),
    country VARCHAR(50),
    ruca_code NUMERIC(4, 1),
    ruca_description TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_dim_geography UNIQUE (
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
);

CREATE INDEX IF NOT EXISTS idx_dim_geography_state_abbreviation ON dim_geography (state_abbreviation);
CREATE INDEX IF NOT EXISTS idx_dim_geography_zip5 ON dim_geography (zip5);

CREATE TABLE IF NOT EXISTS dim_service (
    service_key BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    hcpcs_code VARCHAR(10) NOT NULL,
    hcpcs_description TEXT,
    hcpcs_drug_ind CHAR(1),
    place_of_service CHAR(1),
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_dim_service UNIQUE (hcpcs_code, place_of_service)
);

CREATE INDEX IF NOT EXISTS idx_dim_service_hcpcs_code ON dim_service (hcpcs_code);

CREATE TABLE IF NOT EXISTS fact_provider_service (
    fact_key BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    provider_key BIGINT NOT NULL REFERENCES dim_provider(provider_key),
    geography_key BIGINT NOT NULL REFERENCES dim_geography(geography_key),
    service_key BIGINT NOT NULL REFERENCES dim_service(service_key),
    data_year INTEGER NOT NULL,
    tot_benes BIGINT,
    tot_srvcs NUMERIC(18, 6),
    tot_bene_day_srvcs BIGINT,
    avg_sbmtd_chrg NUMERIC(18, 6),
    avg_mdcr_alowd_amt NUMERIC(18, 6),
    avg_mdcr_pymt_amt NUMERIC(18, 6),
    avg_mdcr_stdzd_amt NUMERIC(18, 6),
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_fact_provider_service UNIQUE (provider_key, geography_key, service_key, data_year),
    CONSTRAINT chk_fact_provider_service_year CHECK (data_year BETWEEN 1900 AND 2100),
    CONSTRAINT chk_fact_provider_service_tot_benes CHECK (tot_benes IS NULL OR tot_benes >= 0),
    CONSTRAINT chk_fact_provider_service_tot_srvcs CHECK (tot_srvcs IS NULL OR tot_srvcs >= 0),
    CONSTRAINT chk_fact_provider_service_tot_bene_day_srvcs CHECK (tot_bene_day_srvcs IS NULL OR tot_bene_day_srvcs >= 0)
);

CREATE INDEX IF NOT EXISTS idx_fact_provider_service_provider_key ON fact_provider_service (provider_key);
CREATE INDEX IF NOT EXISTS idx_fact_provider_service_geography_key ON fact_provider_service (geography_key);
CREATE INDEX IF NOT EXISTS idx_fact_provider_service_service_key ON fact_provider_service (service_key);
CREATE INDEX IF NOT EXISTS idx_fact_provider_service_data_year ON fact_provider_service (data_year);

CREATE TABLE IF NOT EXISTS etl_audit_log (
    audit_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    pipeline_name VARCHAR(255) NOT NULL,
    source_file VARCHAR(500),
    run_status VARCHAR(50) NOT NULL,
    rows_read BIGINT,
    rows_written BIGINT,
    run_started_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    run_finished_at TIMESTAMP
);

COMMENT ON TABLE dim_provider IS 'Provider dimension containing the rendering provider identity and professional attributes.';
COMMENT ON TABLE dim_geography IS 'Geography dimension containing the provider location and RUCA attributes.';
COMMENT ON TABLE dim_service IS 'Service dimension containing HCPCS and place-of-service descriptors.';
COMMENT ON TABLE fact_provider_service IS 'Fact table at provider-service-geography-year grain containing utilization and payment measures.';
COMMENT ON TABLE etl_audit_log IS 'Audit log for ETL pipeline executions.';

COMMENT ON COLUMN dim_provider.npi IS 'National Provider Identifier for the rendering provider.';
COMMENT ON COLUMN dim_provider.last_org_name IS 'Provider last name for an individual or organization name for an organization.';
COMMENT ON COLUMN dim_provider.first_name IS 'Provider first name when the provider is an individual.';
COMMENT ON COLUMN dim_provider.middle_initial IS 'Provider middle initial when available.';
COMMENT ON COLUMN dim_provider.credentials IS 'Provider credentials or suffix, such as MD, DO, NP, or similar.';
COMMENT ON COLUMN dim_provider.entity_code IS 'Provider entity type code indicating individual versus organization.';
COMMENT ON COLUMN dim_provider.provider_type IS 'Provider specialty or type classification.';
COMMENT ON COLUMN dim_provider.medicare_participation_ind IS 'Indicator showing whether the provider participates in Medicare.';

COMMENT ON COLUMN dim_geography.address_line_1 IS 'Primary street address line.';
COMMENT ON COLUMN dim_geography.address_line_2 IS 'Secondary street address line or suite information.';
COMMENT ON COLUMN dim_geography.city IS 'Provider city.';
COMMENT ON COLUMN dim_geography.state_abbreviation IS 'Two-letter state abbreviation.';
COMMENT ON COLUMN dim_geography.state_fips IS 'State Federal Information Processing Standards code.';
COMMENT ON COLUMN dim_geography.zip5 IS 'Five-digit ZIP code, preserved as text to retain leading zeros.';
COMMENT ON COLUMN dim_geography.country IS 'Provider country.';
COMMENT ON COLUMN dim_geography.ruca_code IS 'Rural-Urban Commuting Area code.';
COMMENT ON COLUMN dim_geography.ruca_description IS 'Human-readable RUCA classification description.';

COMMENT ON COLUMN dim_service.hcpcs_code IS 'Healthcare Common Procedure Coding System code for the service.';
COMMENT ON COLUMN dim_service.hcpcs_description IS 'Plain-language description of the HCPCS-coded service.';
COMMENT ON COLUMN dim_service.hcpcs_drug_ind IS 'Indicator showing whether the HCPCS code represents a drug.';
COMMENT ON COLUMN dim_service.place_of_service IS 'Place-of-service code for where the service was delivered.';

COMMENT ON COLUMN fact_provider_service.provider_key IS 'Foreign key to the provider dimension.';
COMMENT ON COLUMN fact_provider_service.geography_key IS 'Foreign key to the geography dimension.';
COMMENT ON COLUMN fact_provider_service.service_key IS 'Foreign key to the service dimension.';
COMMENT ON COLUMN fact_provider_service.data_year IS 'Reporting year from the source file.';
COMMENT ON COLUMN fact_provider_service.tot_benes IS 'Total number of distinct beneficiaries served.';
COMMENT ON COLUMN fact_provider_service.tot_srvcs IS 'Total number of services rendered.';
COMMENT ON COLUMN fact_provider_service.tot_bene_day_srvcs IS 'Total beneficiary day services reported.';
COMMENT ON COLUMN fact_provider_service.avg_sbmtd_chrg IS 'Average submitted charge amount.';
COMMENT ON COLUMN fact_provider_service.avg_mdcr_alowd_amt IS 'Average Medicare allowed amount.';
COMMENT ON COLUMN fact_provider_service.avg_mdcr_pymt_amt IS 'Average Medicare payment amount.';
COMMENT ON COLUMN fact_provider_service.avg_mdcr_stdzd_amt IS 'Average standardized Medicare payment amount.';

COMMENT ON COLUMN etl_audit_log.pipeline_name IS 'Name of the ETL pipeline or job.';
COMMENT ON COLUMN etl_audit_log.source_file IS 'Source file processed during the run.';
COMMENT ON COLUMN etl_audit_log.run_status IS 'Run status such as success or failure.';
COMMENT ON COLUMN etl_audit_log.rows_read IS 'Number of source rows read by the pipeline.';
COMMENT ON COLUMN etl_audit_log.rows_written IS 'Number of rows written to the target tables.';
