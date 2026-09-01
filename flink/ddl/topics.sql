-- Confluent Cloud Flink tables for Debezium Protobuf CDC envelopes.
-- Apply this file before deploying the detection or prediction statements.

CREATE TABLE assets_cdc (
  after ROW<
    tenant_id STRING,
    asset_id STRING,
    device_type STRING,
    os_vendor STRING,
    os_version STRING,
    firmware_version STRING,
    risk_level STRING,
    is_quarantined BOOLEAN
  >,
  op STRING,
  ts_ms BIGINT
) WITH (
  'connector' = 'confluent',
  'kafka.topic' = 'assets',
  'value.format' = 'protobuf-registry',
  'scan.startup.mode' = 'earliest-offset',
  'error-handling.mode' = 'ignore'
);

CREATE TABLE network_interfaces_cdc (
  after ROW<
    tenant_id STRING,
    interface_id STRING,
    asset_id STRING,
    mac_address STRING,
    ip_address STRING,
    is_active BOOLEAN
  >,
  op STRING,
  ts_ms BIGINT
) WITH (
  'connector' = 'confluent',
  'kafka.topic' = 'network_interfaces',
  'value.format' = 'protobuf-registry',
  'scan.startup.mode' = 'earliest-offset',
  'error-handling.mode' = 'ignore'
);

CREATE TABLE asset_cves_cdc (
  after ROW<
    tenant_id STRING,
    cve_record_id INT,
    asset_id STRING,
    cve_id STRING,
    cvss_score DOUBLE,
    severity STRING
  >,
  op STRING,
  ts_ms BIGINT
) WITH (
  'connector' = 'confluent',
  'kafka.topic' = 'asset_cves',
  'value.format' = 'protobuf-registry',
  'scan.startup.mode' = 'earliest-offset',
  'error-handling.mode' = 'ignore'
);

CREATE VIEW assets AS
SELECT after.*
FROM assets_cdc
WHERE after IS NOT NULL AND op IN ('c', 'r', 'u');

CREATE VIEW network_interfaces AS
SELECT after.*
FROM network_interfaces_cdc
WHERE after IS NOT NULL AND op IN ('c', 'r', 'u');

CREATE VIEW asset_cves AS
SELECT after.*
FROM asset_cves_cdc
WHERE after IS NOT NULL AND op IN ('c', 'r', 'u');

CREATE TABLE security_findings (
  key BYTES NOT NULL,
  tenant_id STRING,
  asset_id STRING,
  device_type STRING,
  ip_address STRING,
  cve_id STRING,
  cvss_score DOUBLE,
  severity STRING,
  anomaly_score DOUBLE,
  finding_type STRING,
  predicted_risk STRING,
  model_version STRING,
  event_time STRING,
  PRIMARY KEY (key) NOT ENFORCED
) WITH (
  'connector' = 'confluent',
  'kafka.topic' = 'security_findings',
  'value.format' = 'protobuf-registry',
  'changelog.mode' = 'upsert'
);
