-- ============================================================================
-- MEDICARE PROVIDER ANALYTICS & ANOMALY DETECTION
-- ============================================================================
-- 1. SPENDING TREND QUERIES
-- ============================================================================

-- Annual spending trends by provider type
SELECT
    p.provider_type,
    f.data_year,
    COUNT(DISTINCT f.provider_key) AS provider_count,
    COUNT(DISTINCT f.geography_key) AS service_location_count,
    SUM(f.tot_srvcs) AS total_services,
    SUM(f.avg_sbmtd_chrg * f.tot_srvcs) AS total_submitted_charges,
    SUM(f.avg_mdcr_alowd_amt * f.tot_srvcs) AS total_allowed_amount,
    SUM(f.avg_mdcr_pymt_amt * f.tot_srvcs) AS total_medicare_payment,
    ROUND(SUM(f.avg_mdcr_pymt_amt * f.tot_srvcs) / NULLIF(SUM(f.avg_sbmtd_chrg * f.tot_srvcs), 0), 4) AS payment_to_charge_ratio,
    ROUND(SUM(f.avg_mdcr_alowd_amt * f.tot_srvcs) / NULLIF(SUM(f.tot_srvcs), 0), 2) AS avg_allowed_per_service
FROM fact_provider_service f
JOIN dim_provider p ON f.provider_key = p.provider_key
GROUP BY p.provider_type, f.data_year
ORDER BY f.data_year DESC, total_medicare_payment DESC;

-- Year-over-year spending growth analysis
WITH yearly_trends AS (
    SELECT
        p.provider_type,
        f.data_year,
        SUM(f.avg_mdcr_pymt_amt * f.tot_srvcs) AS total_payment
    FROM fact_provider_service f
    JOIN dim_provider p ON f.provider_key = p.provider_key
    GROUP BY p.provider_type, f.data_year
)
SELECT
    provider_type,
    data_year,
    total_payment,
    LAG(total_payment) OVER (PARTITION BY provider_type ORDER BY data_year) AS prev_year_payment,
    ROUND(((total_payment - LAG(total_payment) OVER (PARTITION BY provider_type ORDER BY data_year)) 
        / NULLIF(LAG(total_payment) OVER (PARTITION BY provider_type ORDER BY data_year), 0)) * 100, 2) AS yoy_growth_pct
FROM yearly_trends
ORDER BY provider_type, data_year DESC;

-- Quarterly spending trends (using data_year, extrapolated to months if needed)
SELECT
    f.data_year,
    p.provider_type,
    CASE WHEN EXTRACT(MONTH FROM CURRENT_DATE) <= 3 THEN 'Q1'
         WHEN EXTRACT(MONTH FROM CURRENT_DATE) <= 6 THEN 'Q2'
         WHEN EXTRACT(MONTH FROM CURRENT_DATE) <= 9 THEN 'Q3'
         ELSE 'Q4' END AS quarter,
    SUM(f.tot_srvcs) AS services,
    SUM(f.avg_mdcr_pymt_amt * f.tot_srvcs) AS total_payment
FROM fact_provider_service f
JOIN dim_provider p ON f.provider_key = p.provider_key
GROUP BY f.data_year, p.provider_type
ORDER BY f.data_year DESC, provider_type;

-- ============================================================================
-- 2. PROVIDER ANALYSIS QUERIES
-- ============================================================================

-- Top 100 providers by payment volume with performance metrics
SELECT
    ROW_NUMBER() OVER (ORDER BY SUM(f.avg_mdcr_pymt_amt * f.tot_srvcs) DESC) AS rank,
    p.npi,
    p.last_org_name,
    p.provider_type,
    COUNT(DISTINCT f.data_year) AS years_in_data,
    COUNT(DISTINCT f.geography_key) AS service_locations,
    SUM(f.tot_srvcs) AS total_services,
    SUM(f.avg_mdcr_pymt_amt * f.tot_srvcs) AS total_payment,
    ROUND(AVG(f.avg_mdcr_pymt_amt), 2) AS avg_per_service,
    ROUND(SUM(f.avg_mdcr_stdzd_amt * f.tot_srvcs) / NULLIF(SUM(f.tot_srvcs), 0), 2) AS standardized_payment_rate
FROM fact_provider_service f
JOIN dim_provider p ON f.provider_key = p.provider_key
GROUP BY p.provider_key, p.npi, p.last_org_name, p.provider_type
HAVING SUM(f.tot_srvcs) > 100
ORDER BY total_payment DESC
LIMIT 100;

-- Provider growth/decline analysis
WITH provider_yearly AS (
    SELECT
        p.provider_key,
        p.npi,
        p.last_org_name,
        f.data_year,
        SUM(f.tot_srvcs) AS services,
        SUM(f.avg_mdcr_pymt_amt * f.tot_srvcs) AS payment
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
    LAG(services) OVER (PARTITION BY provider_key ORDER BY data_year) AS prev_services,
    LAG(payment) OVER (PARTITION BY provider_key ORDER BY data_year) AS prev_payment,
    ROUND(((services - LAG(services) OVER (PARTITION BY provider_key ORDER BY data_year)) 
        / NULLIF(LAG(services) OVER (PARTITION BY provider_key ORDER BY data_year), 0)) * 100, 2) AS service_growth_pct,
    ROUND(((payment - LAG(payment) OVER (PARTITION BY provider_key ORDER BY data_year)) 
        / NULLIF(LAG(payment) OVER (PARTITION BY provider_key ORDER BY data_year), 0)) * 100, 2) AS payment_growth_pct
FROM provider_yearly
WHERE data_year >= 2020
ORDER BY provider_key, data_year;

-- High-variance providers (potential anomalies)
WITH provider_stats AS (
    SELECT
        p.provider_key,
        p.npi,
        p.last_org_name,
        AVG(f.avg_mdcr_pymt_amt) AS avg_payment,
        STDDEV(f.avg_mdcr_pymt_amt) AS stddev_payment,
        MAX(f.avg_mdcr_pymt_amt) AS max_payment,
        MIN(f.avg_mdcr_pymt_amt) AS min_payment
    FROM fact_provider_service f
    JOIN dim_provider p ON f.provider_key = p.provider_key
    GROUP BY p.provider_key, p.npi, p.last_org_name
    HAVING STDDEV(f.avg_mdcr_pymt_amt) IS NOT NULL
)
SELECT
    npi,
    last_org_name,
    avg_payment,
    stddev_payment,
    max_payment,
    min_payment,
    ROUND(stddev_payment / NULLIF(avg_payment, 0), 2) AS coefficient_of_variation,
    ROUND((max_payment - min_payment) / NULLIF(avg_payment, 0), 2) AS range_to_mean_ratio
FROM provider_stats
WHERE ROUND(stddev_payment / NULLIF(avg_payment, 0), 2) > 0.5
ORDER BY coefficient_of_variation DESC
LIMIT 50;

-- ============================================================================
-- 3. SPECIALTY ANALYSIS QUERIES
-- ============================================================================

-- Top services by payment volume
SELECT
    ROW_NUMBER() OVER (ORDER BY SUM(f.avg_mdcr_pymt_amt * f.tot_srvcs) DESC) AS rank,
    s.hcpcs_code,
    s.hcpcs_description,
    s.place_of_service,
    COUNT(DISTINCT f.provider_key) AS provider_count,
    SUM(f.tot_srvcs) AS total_services,
    SUM(f.avg_mdcr_pymt_amt * f.tot_srvcs) AS total_payment,
    ROUND(AVG(f.avg_mdcr_pymt_amt), 2) AS avg_payment_per_service,
    ROUND(SUM(f.avg_mdcr_alowd_amt * f.tot_srvcs) / NULLIF(SUM(f.tot_srvcs), 0), 2) AS avg_allowed_amount
FROM fact_provider_service f
JOIN dim_service s ON f.service_key = s.service_key
GROUP BY s.service_key, s.hcpcs_code, s.hcpcs_description, s.place_of_service
HAVING SUM(f.tot_srvcs) > 1000
ORDER BY total_payment DESC
LIMIT 50;

-- Service utilization trends over time
SELECT
    s.hcpcs_code,
    s.hcpcs_description,
    f.data_year,
    SUM(f.tot_srvcs) AS services,
    COUNT(DISTINCT f.provider_key) AS providers_using_service,
    ROUND(AVG(f.avg_mdcr_pymt_amt), 2) AS avg_payment,
    ROUND(SUM(f.avg_mdcr_pymt_amt * f.tot_srvcs) / NULLIF(SUM(f.tot_srvcs), 0), 2) AS weighted_avg_payment
FROM fact_provider_service f
JOIN dim_service s ON f.service_key = s.service_key
GROUP BY s.service_key, s.hcpcs_code, s.hcpcs_description, f.data_year
ORDER BY f.data_year DESC, services DESC;

-- Services by place of service analysis
SELECT
    s.place_of_service,
    COUNT(DISTINCT s.hcpcs_code) AS service_count,
    COUNT(DISTINCT f.provider_key) AS provider_count,
    SUM(f.tot_srvcs) AS total_services,
    SUM(f.avg_mdcr_pymt_amt * f.tot_srvcs) AS total_payment,
    ROUND(AVG(f.avg_mdcr_pymt_amt), 2) AS avg_payment,
    ROUND(SUM(f.avg_mdcr_pymt_amt * f.tot_srvcs) / NULLIF(SUM(f.tot_srvcs), 0), 2) AS effective_rate
FROM fact_provider_service f
JOIN dim_service s ON f.service_key = s.service_key
GROUP BY s.place_of_service
ORDER BY total_payment DESC;

-- ============================================================================
-- 4. STATE-LEVEL ANALYSIS QUERIES
-- ============================================================================

-- State payment and utilization summary
SELECT
    g.state_abbreviation AS provider_state,
    f.data_year,
    COUNT(DISTINCT f.provider_key) AS provider_count,
    COUNT(DISTINCT f.geography_key) AS practice_locations,
    COUNT(DISTINCT f.service_key) AS unique_services,
    SUM(f.tot_srvcs) AS total_services,
    SUM(f.avg_sbmtd_chrg * f.tot_srvcs) AS total_charges,
    SUM(f.avg_mdcr_alowd_amt * f.tot_srvcs) AS total_allowed,
    SUM(f.avg_mdcr_pymt_amt * f.tot_srvcs) AS total_payment,
    ROUND(SUM(f.avg_mdcr_pymt_amt * f.tot_srvcs) / NULLIF(SUM(f.tot_srvcs), 0), 2) AS avg_payment_per_service,
    ROUND(SUM(f.avg_mdcr_pymt_amt * f.tot_srvcs) / NULLIF(SUM(f.avg_sbmtd_chrg * f.tot_srvcs), 0) * 100, 2) AS payment_to_charge_pct
FROM fact_provider_service f
JOIN dim_geography g ON f.geography_key = g.geography_key
GROUP BY g.state_abbreviation, f.data_year
ORDER BY f.data_year DESC, total_payment DESC;

-- State-level variation analysis (identifies outliers)
WITH state_stats AS (
    SELECT
        g.state_abbreviation AS provider_state,
        f.data_year,
        SUM(f.tot_srvcs) AS services,
        SUM(f.avg_mdcr_pymt_amt * f.tot_srvcs) AS payment,
        AVG(f.avg_mdcr_pymt_amt) AS avg_rate
    FROM fact_provider_service f
    JOIN dim_geography g ON f.geography_key = g.geography_key
    GROUP BY g.state_abbreviation, f.data_year
)
SELECT
    provider_state,
    data_year,
    services,
    payment,
    avg_rate,
    (SELECT AVG(avg_rate) FROM state_stats WHERE data_year = ss.data_year) AS national_avg_rate,
    ROUND(avg_rate / (SELECT AVG(avg_rate) FROM state_stats WHERE data_year = ss.data_year), 3) AS variation_index
FROM state_stats ss
WHERE data_year >= 2020
ORDER BY data_year DESC, variation_index DESC;

-- Top and bottom states by payment per service
WITH latest_year AS (
    SELECT MAX(data_year) AS yr
    FROM fact_provider_service
),
state_payment AS (
    SELECT
        g.state_abbreviation AS provider_state,
        ROUND(AVG(f.avg_mdcr_pymt_amt), 2) AS avg_payment_per_service,
        SUM(f.tot_srvcs) AS total_services
    FROM fact_provider_service f
    JOIN dim_geography g ON f.geography_key = g.geography_key
    JOIN latest_year ly ON f.data_year = ly.yr
    GROUP BY g.state_abbreviation
),
top_states AS (
    SELECT
        'Top Performers' AS category,
        ROW_NUMBER() OVER (ORDER BY avg_payment_per_service DESC) AS rank,
        provider_state,
        avg_payment_per_service,
        total_services
    FROM state_payment
    ORDER BY avg_payment_per_service DESC
    LIMIT 10
),
low_states AS (
    SELECT
        'Low Performers' AS category,
        ROW_NUMBER() OVER (ORDER BY avg_payment_per_service ASC) AS rank,
        provider_state,
        avg_payment_per_service,
        total_services
    FROM state_payment
    ORDER BY avg_payment_per_service ASC
    LIMIT 10
)
SELECT * FROM top_states
UNION ALL
SELECT * FROM low_states
ORDER BY category, rank;

-- ============================================================================
-- 5. COVID IMPACT ANALYSIS (2019-2023)
-- ============================================================================

-- Service utilization before/during/after COVID
WITH covid_periods AS (
    SELECT
        p.provider_type,
        CASE 
            WHEN f.data_year <= 2019 THEN 'Pre-COVID'
            WHEN f.data_year BETWEEN 2020 AND 2021 THEN 'During COVID'
            ELSE 'Post-COVID'
        END AS period,
        SUM(f.tot_srvcs) AS services,
        SUM(f.avg_mdcr_pymt_amt * f.tot_srvcs) AS payment,
        COUNT(DISTINCT f.provider_key) AS active_providers
    FROM fact_provider_service f
    JOIN dim_provider p ON f.provider_key = p.provider_key
    WHERE f.data_year BETWEEN 2019 AND 2023
    GROUP BY p.provider_type, period
)
SELECT
    provider_type,
    period,
    services,
    payment,
    active_providers,
    LAG(services) OVER (PARTITION BY provider_type ORDER BY 
        CASE WHEN period = 'Pre-COVID' THEN 1
             WHEN period = 'During COVID' THEN 2
             ELSE 3 END) AS prev_period_services,
    ROUND(((services - LAG(services) OVER (PARTITION BY provider_type ORDER BY 
        CASE WHEN period = 'Pre-COVID' THEN 1
             WHEN period = 'During COVID' THEN 2
             ELSE 3 END)) / 
        NULLIF(LAG(services) OVER (PARTITION BY provider_type ORDER BY 
        CASE WHEN period = 'Pre-COVID' THEN 1
             WHEN period = 'During COVID' THEN 2
             ELSE 3 END), 0)) * 100, 2) AS change_pct
FROM covid_periods
ORDER BY provider_type, 
    CASE WHEN period = 'Pre-COVID' THEN 1
         WHEN period = 'During COVID' THEN 2
         ELSE 3 END;

-- Service-specific COVID impact
SELECT
    s.hcpcs_code,
    s.hcpcs_description,
    SUM(CASE WHEN f.data_year IN (2018, 2019) THEN f.tot_srvcs ELSE 0 END) AS pre_covid_services,
    SUM(CASE WHEN f.data_year IN (2020, 2021) THEN f.tot_srvcs ELSE 0 END) AS covid_services,
    SUM(CASE WHEN f.data_year IN (2022, 2023) THEN f.tot_srvcs ELSE 0 END) AS post_covid_services,
    ROUND(
        ((SUM(CASE WHEN f.data_year IN (2020, 2021) THEN f.tot_srvcs ELSE 0 END) -
          SUM(CASE WHEN f.data_year IN (2018, 2019) THEN f.tot_srvcs ELSE 0 END)) /
         NULLIF(SUM(CASE WHEN f.data_year IN (2018, 2019) THEN f.tot_srvcs ELSE 0 END), 0)) * 100, 2
    ) AS covid_impact_pct
FROM fact_provider_service f
JOIN dim_service s ON f.service_key = s.service_key
WHERE f.data_year BETWEEN 2018 AND 2023
GROUP BY s.service_key, s.hcpcs_code, s.hcpcs_description
HAVING SUM(CASE WHEN f.data_year IN (2018, 2019) THEN f.tot_srvcs ELSE 0 END) > 10000
ORDER BY covid_impact_pct
LIMIT 30;

-- ============================================================================
-- 6. RANKING & WINDOW FUNCTION QUERIES
-- ============================================================================

-- Provider percentile ranking within state
SELECT
    p.last_org_name,
    p.npi,
    g.state_abbreviation AS provider_state,
    SUM(f.avg_mdcr_pymt_amt * f.tot_srvcs) AS total_payment,
    PERCENT_RANK() OVER (PARTITION BY g.state_abbreviation ORDER BY SUM(f.avg_mdcr_pymt_amt * f.tot_srvcs)) AS percentile_rank,
    ROUND(PERCENT_RANK() OVER (PARTITION BY g.state_abbreviation ORDER BY SUM(f.avg_mdcr_pymt_amt * f.tot_srvcs)) * 100, 2) AS percentile,
    NTILE(4) OVER (PARTITION BY g.state_abbreviation ORDER BY SUM(f.avg_mdcr_pymt_amt * f.tot_srvcs)) AS quartile
FROM fact_provider_service f
JOIN dim_provider p ON f.provider_key = p.provider_key
JOIN dim_geography g ON f.geography_key = g.geography_key
GROUP BY p.provider_key, p.last_org_name, p.npi, g.state_abbreviation
HAVING SUM(f.tot_srvcs) > 50
ORDER BY provider_state, percentile DESC;

-- Running total and cumulative percentage
SELECT
    f.data_year,
    s.hcpcs_code,
    SUM(f.tot_srvcs) AS services,
    SUM(SUM(f.tot_srvcs)) OVER (PARTITION BY f.data_year ORDER BY SUM(f.tot_srvcs) DESC) AS cumulative_services,
    ROUND(
        SUM(SUM(f.tot_srvcs)) OVER (PARTITION BY f.data_year ORDER BY SUM(f.tot_srvcs) DESC) /
        SUM(SUM(f.tot_srvcs)) OVER (PARTITION BY f.data_year) * 100,
        2
    ) AS cumulative_pct
FROM fact_provider_service f
JOIN dim_service s ON f.service_key = s.service_key
GROUP BY f.data_year, s.hcpcs_code
ORDER BY f.data_year DESC, services DESC
LIMIT 50;

-- Top N services per provider (Top 5 services per provider)
WITH ranked_services AS (
    SELECT
        p.provider_key,
        p.npi,
        p.last_org_name,
        s.hcpcs_code,
        s.hcpcs_description,
        SUM(f.tot_srvcs) AS services,
        ROW_NUMBER() OVER (PARTITION BY p.provider_key ORDER BY SUM(f.tot_srvcs) DESC) AS service_rank
    FROM fact_provider_service f
    JOIN dim_provider p ON f.provider_key = p.provider_key
    JOIN dim_service s ON f.service_key = s.service_key
    GROUP BY p.provider_key, p.npi, p.last_org_name, s.hcpcs_code, s.hcpcs_description
)
SELECT
    npi,
    last_org_name,
    hcpcs_code,
    hcpcs_description,
    services,
    service_rank
FROM ranked_services
WHERE service_rank <= 5
ORDER BY npi, service_rank;

-- Deviation from regional average (Z-score approximation)
WITH provider_service_stats AS (
    SELECT
        g.state_abbreviation AS provider_state,
        s.hcpcs_code,
        f.avg_mdcr_pymt_amt AS payment_amount,
        AVG(f.avg_mdcr_pymt_amt) OVER (PARTITION BY g.state_abbreviation, s.hcpcs_code) AS regional_avg,
        STDDEV(f.avg_mdcr_pymt_amt) OVER (PARTITION BY g.state_abbreviation, s.hcpcs_code) AS regional_stddev
    FROM fact_provider_service f
    JOIN dim_provider p ON f.provider_key = p.provider_key
    JOIN dim_geography g ON f.geography_key = g.geography_key
    JOIN dim_service s ON f.service_key = s.service_key
)
SELECT
    provider_state,
    hcpcs_code,
    payment_amount,
    regional_avg,
    regional_stddev,
    ROUND((payment_amount - regional_avg) / NULLIF(regional_stddev, 0), 2) AS z_score
FROM provider_service_stats
WHERE regional_stddev > 0
  AND ABS((payment_amount - regional_avg) / NULLIF(regional_stddev, 0)) > 2.5
ORDER BY ABS(z_score) DESC
LIMIT 100;

