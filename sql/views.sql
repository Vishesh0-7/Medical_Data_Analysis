-- Reusable reporting views for dashboards and analysis.
-- TODO: Finalize joins and business definitions after the schema is implemented.

CREATE OR REPLACE VIEW vw_provider_service_summary AS
SELECT
    p.npi,
    p.provider_type,
    g.city,
    g.state_abbreviation,
    g.zip5,
    s.hcpcs_code,
    s.hcpcs_description,
    s.place_of_service,
    f.data_year,
    f.tot_benes,
    f.tot_srvcs,
    f.tot_bene_day_srvcs,
    f.avg_sbmtd_chrg,
    f.avg_mdcr_alowd_amt,
    f.avg_mdcr_pymt_amt,
    f.avg_mdcr_stdzd_amt
FROM fact_provider_service f
LEFT JOIN dim_provider p ON f.provider_key = p.provider_key
LEFT JOIN dim_geography g ON f.geography_key = g.geography_key
LEFT JOIN dim_service s ON f.service_key = s.service_key;

CREATE OR REPLACE VIEW vw_yearly_provider_trends AS
SELECT
    p.npi,
    f.data_year,
    SUM(COALESCE(f.tot_benes, 0)) AS total_beneficiaries,
    SUM(COALESCE(f.tot_srvcs, 0)) AS total_services,
    AVG(f.avg_mdcr_pymt_amt) AS avg_payment_amount,
    AVG(f.avg_mdcr_alowd_amt) AS avg_allowed_amount
FROM fact_provider_service f
LEFT JOIN dim_provider p ON f.provider_key = p.provider_key
GROUP BY p.npi, f.data_year;
-- ============================================================================
-- 7. ANALYTICAL VIEWS
-- ============================================================================

-- View 1: Provider Performance Summary
CREATE OR REPLACE VIEW v_provider_performance AS
SELECT
    p.provider_key,
    p.npi,
    p.last_org_name,
    p.provider_type,
    g.state_abbreviation,
    f.data_year,
    COUNT(*) AS service_records,
    SUM(f.tot_srvcs) AS total_services,
    ROUND(AVG(f.avg_mdcr_pymt_amt), 2) AS avg_payment_per_service,
    SUM(f.avg_mdcr_pymt_amt * f.tot_srvcs) AS total_payment,
    ROUND(SUM(f.avg_mdcr_stdzd_amt * f.tot_srvcs) / NULLIF(SUM(f.tot_srvcs), 0), 2) AS standardized_rate,
    ROUND(SUM(f.avg_mdcr_pymt_amt * f.tot_srvcs) / NULLIF(SUM(f.avg_sbmtd_chrg * f.tot_srvcs), 0) * 100, 2) AS payment_to_charge_pct,
    MAX(f.avg_mdcr_alowd_amt) AS max_allowed_per_service,
    MIN(f.avg_mdcr_alowd_amt) AS min_allowed_per_service
FROM fact_provider_service f
JOIN dim_provider p ON f.provider_key = p.provider_key
JOIN dim_geography g ON f.geography_key = g.geography_key
GROUP BY p.provider_key, p.npi, p.last_org_name, p.provider_type, g.state_abbreviation, f.data_year;

-- View 2: Service Performance Analytics
CREATE OR REPLACE VIEW v_service_performance AS
SELECT
    s.service_key,
    s.hcpcs_code,
    s.hcpcs_description,
    s.place_of_service,
    f.data_year,
    COUNT(DISTINCT f.provider_key) AS provider_count,
    SUM(f.tot_srvcs) AS total_services,
    ROUND(AVG(f.avg_mdcr_pymt_amt), 2) AS avg_payment,
    ROUND(MIN(f.avg_mdcr_pymt_amt), 2) AS min_payment,
    ROUND(MAX(f.avg_mdcr_pymt_amt), 2) AS max_payment,
    ROUND(STDDEV(f.avg_mdcr_pymt_amt), 2) AS stddev_payment,
    SUM(f.avg_mdcr_pymt_amt * f.tot_srvcs) AS total_payment,
    ROUND(SUM(f.avg_mdcr_alowd_amt * f.tot_srvcs) / NULLIF(SUM(f.tot_srvcs), 0), 2) AS effective_allowed_rate
FROM fact_provider_service f
JOIN dim_service s ON f.service_key = s.service_key
GROUP BY s.service_key, s.hcpcs_code, s.hcpcs_description, s.place_of_service, f.data_year;

-- View 3: Geographic Performance Analytics
CREATE OR REPLACE VIEW v_geography_performance AS
SELECT
    g.geography_key,
    g.state_abbreviation,
    g.city,
    g.ruca_code,
    f.data_year,
    COUNT(DISTINCT f.provider_key) AS provider_count,
    COUNT(DISTINCT f.service_key) AS service_count,
    SUM(f.tot_srvcs) AS total_services,
    SUM(f.avg_mdcr_pymt_amt * f.tot_srvcs) AS total_payment,
    ROUND(AVG(f.avg_mdcr_pymt_amt), 2) AS avg_payment_per_service,
    ROUND(SUM(f.avg_mdcr_pymt_amt * f.tot_srvcs) / NULLIF(SUM(f.tot_srvcs), 0), 2) AS effective_rate
FROM fact_provider_service f
JOIN dim_geography g ON f.geography_key = g.geography_key
GROUP BY g.geography_key, g.state_abbreviation, g.city, g.ruca_code, f.data_year;

-- View 4: Anomaly Detection Staging
CREATE OR REPLACE VIEW v_anomaly_candidates AS
WITH provider_service_analysis AS (
    SELECT
        p.provider_key,
        p.npi,
        p.last_org_name,
        s.service_key,
        s.hcpcs_code,
        f.data_year,
        f.tot_srvcs,
        f.avg_mdcr_pymt_amt,
        f.avg_mdcr_stdzd_amt,
        AVG(f.avg_mdcr_pymt_amt) OVER (PARTITION BY s.hcpcs_code, f.data_year) AS national_avg_payment,
        STDDEV(f.avg_mdcr_pymt_amt) OVER (PARTITION BY s.hcpcs_code, f.data_year) AS national_stddev_payment,
        RANK() OVER (PARTITION BY s.hcpcs_code, f.data_year ORDER BY f.tot_srvcs DESC) AS utilization_rank
    FROM fact_provider_service f
    JOIN dim_provider p ON f.provider_key = p.provider_key
    JOIN dim_service s ON f.service_key = s.service_key
)
SELECT
    provider_key,
    npi,
    last_org_name,
    service_key,
    hcpcs_code,
    data_year,
    tot_srvcs,
    avg_mdcr_pymt_amt,
    avg_mdcr_stdzd_amt,
    national_avg_payment,
    ROUND((avg_mdcr_pymt_amt - national_avg_payment) / NULLIF(national_stddev_payment, 0), 2) AS z_score,
    CASE 
        WHEN ABS((avg_mdcr_pymt_amt - national_avg_payment) / NULLIF(national_stddev_payment, 0)) > 3 THEN 'CRITICAL'
        WHEN ABS((avg_mdcr_pymt_amt - national_avg_payment) / NULLIF(national_stddev_payment, 0)) > 2 THEN 'HIGH'
        WHEN ABS((avg_mdcr_pymt_amt - national_avg_payment) / NULLIF(national_stddev_payment, 0)) > 1.5 THEN 'MEDIUM'
        ELSE 'LOW'
    END AS anomaly_severity,
    utilization_rank
FROM provider_service_analysis
WHERE utilization_rank <= 100;

-- View 5: Year-over-Year Comparison
CREATE OR REPLACE VIEW v_yoy_comparison AS
WITH yearly_provider_metrics AS (
    SELECT
        p.provider_key,
        p.npi,
        p.last_org_name,
        f.data_year,
        SUM(f.tot_srvcs) AS services,
        SUM(f.avg_mdcr_pymt_amt * f.tot_srvcs) AS payment,
        COUNT(DISTINCT f.geography_key) AS locations
    FROM fact_provider_service f
    JOIN dim_provider p ON f.provider_key = p.provider_key
    GROUP BY p.provider_key, p.npi, p.last_org_name, f.data_year
)
SELECT
    npi,
    last_org_name,
    data_year,
    services,
    payment,
    locations,
    LAG(services) OVER (PARTITION BY provider_key ORDER BY data_year) AS prev_services,
    LAG(payment) OVER (PARTITION BY provider_key ORDER BY data_year) AS prev_payment,
    ROUND(((services - LAG(services) OVER (PARTITION BY provider_key ORDER BY data_year)) /
        NULLIF(LAG(services) OVER (PARTITION BY provider_key ORDER BY data_year), 0)) * 100, 2) AS service_growth_pct,
    ROUND(((payment - LAG(payment) OVER (PARTITION BY provider_key ORDER BY data_year)) /
        NULLIF(LAG(payment) OVER (PARTITION BY provider_key ORDER BY data_year), 0)) * 100, 2) AS payment_growth_pct
FROM yearly_provider_metrics;
