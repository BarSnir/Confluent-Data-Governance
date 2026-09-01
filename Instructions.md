# Confluent Cloud Advanced Data Governance & Real-Time Cybersecurity Demo

## 1. Project Overview

This project demonstrates an end-to-end **real-time cybersecurity data platform** built around:

* PostgreSQL
* Debezium CDC
* Confluent Cloud
* Confluent Cloud Schema Registry
* Protocol Buffers (Protobuf)
* Confluent Advanced Data Governance
* Confluent Cloud Flink
* Flink AI/ML capabilities
* Threat Intelligence and CVE enrichment
* Python producers and consumers
* Elasticsearch
* Kibana
* Tableflow
* Confluent Cloud Object Storage
* Local Apache Spark

The project should be designed primarily as a **demonstration environment**.

The main priorities are:

1. Easy local setup.
2. Clear separation between local Docker components and Confluent Cloud resources.
3. Infrastructure/configuration that can be reproduced easily.
4. Rich Confluent Data Governance metadata.
5. Protobuf schemas for every Kafka topic.
6. A realistic cybersecurity use case.
7. Easy-to-follow commands for running every stage of the demo.
8. Code that can be generated, understood, modified, and demonstrated without unnecessary complexity.

---

# 2. High-Level Architecture

The target architecture is:

```text
                         ┌──────────────────────┐
                         │      PostgreSQL      │
                         │                      │
                         │ assets               │
                         │ network_interfaces   │
                         │ asset_cves           │
                         └──────────┬───────────┘
                                    │
                               PostgreSQL WAL
                                    │
                                    ▼
                         ┌──────────────────────┐
                         │       Debezium       │
                         │ PostgreSQL Connector │
                         └──────────┬───────────┘
                                    │
                                    ▼
                    ┌──────────────────────────────┐
                    │       Confluent Cloud        │
                    │                              │
                    │ Kafka + Schema Registry      │
                    │ Protobuf Schemas             │
                    │ Data Governance              │
                    │ Tags / Labels / Metadata     │
                    └──────────────┬───────────────┘
                                   │
                                   ▼
                         ┌──────────────────────┐
                         │ Confluent Cloud      │
                         │ Flink                │
                         │                      │
                         │ Enrichment           │
                         │ CEP                  │
                         │ AI / ML              │
                         │ Aggregations         │
                         └──────────┬───────────┘
                                    │
                 ┌──────────────────┴──────────────────┐
                 │                                     │
                 ▼                                     ▼
       Cybersecurity Findings                  Tableflow
                 │                                     │
                 ▼                                     ▼
          Python Consumer                     Object Storage
                 │                                     │
                 ▼                                     ▼
          Elasticsearch                       Local Spark
                 │
                 ▼
              Kibana
```

---

# 3. Project Structure

The implementation should use a simple structure similar to:

```text
.
├── README.md
├── docker-compose.yml
├── .env.example
│
├── postgres/
│   ├── init.sql
│   └── postgresql.conf
│
├── generator/
│   ├── requirements.txt
│   ├── Dockerfile
│   └── generator.py
│
├── debezium/
│   ├── connector.json
│   └── README.md
│
├── schemas/
│   ├── assets.proto
│   ├── network_interfaces.proto
│   ├── asset_cves.proto
│   └── security_findings.proto
│
├── governance/
│   ├── tags/
│   ├── metadata/
│   └── scripts/
│
├── flink/
│   ├── ddl/
│   ├── enrichment/
│   ├── cep/
│   ├── ml/
│   └── aggregations/
│
├── consumer/
│   ├── requirements.txt
│   ├── Dockerfile
│   └── security_findings_consumer.py
│
├── elasticsearch/
│   ├── mappings/
│   └── kibana/
│
├── tableflow/
│   └── README.md
│
└── spark/
    ├── requirements.txt
    └── read_tableflow.py
```

The exact structure may be adjusted if necessary, but implementation should remain simple and modular.

---

# 4. Stage 0 – PostgreSQL Prerequisites

The PostgreSQL database is the source of the entire demo.

Create the following three tables exactly as the initial data model.

## 4.1 Assets

```sql
CREATE TABLE assets (
    tenant_id VARCHAR(64) NOT NULL,
    asset_id UUID NOT NULL,
    device_type VARCHAR(50) NOT NULL,
    os_vendor VARCHAR(100),
    os_version VARCHAR(50),
    firmware_version VARCHAR(50),
    risk_level VARCHAR(20) DEFAULT 'LOW',
    is_quarantined BOOLEAN DEFAULT FALSE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (tenant_id, asset_id)
);
```

## 4.2 Network Interfaces

```sql
CREATE TABLE network_interfaces (
    tenant_id VARCHAR(64) NOT NULL,
    interface_id UUID NOT NULL,
    asset_id UUID NOT NULL,
    mac_address VARCHAR(17) NOT NULL,
    ip_address VARCHAR(45),
    is_active BOOLEAN DEFAULT TRUE,
    last_seen_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (tenant_id, interface_id),
    FOREIGN KEY (tenant_id, asset_id)
        REFERENCES assets(tenant_id, asset_id)
        ON DELETE CASCADE
);
```

## 4.3 Asset CVEs

```sql
CREATE TABLE asset_cves (
    tenant_id VARCHAR(64) NOT NULL,
    cve_record_id SERIAL NOT NULL,
    asset_id UUID NOT NULL,
    cve_id VARCHAR(20) NOT NULL,
    cvss_score DECIMAL(3,1),
    severity VARCHAR(20) NOT NULL,
    discovered_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (tenant_id, cve_record_id),
    FOREIGN KEY (tenant_id, asset_id)
        REFERENCES assets(tenant_id, asset_id)
        ON DELETE CASCADE
);
```

## 4.4 Debezium Replica Identity

The following configuration is mandatory:

```sql
ALTER TABLE assets REPLICA IDENTITY FULL;
ALTER TABLE network_interfaces REPLICA IDENTITY FULL;
ALTER TABLE asset_cves REPLICA IDENTITY FULL;
```

This must be part of the PostgreSQL initialization script.

---

# 5. PostgreSQL WAL Configuration

PostgreSQL must be configured for logical replication so that Debezium can consume changes from the WAL.

At minimum configure:

```conf
wal_level = logical
max_wal_senders = 10
max_replication_slots = 10
```

The Docker PostgreSQL environment must start with logical replication enabled.

The implementation should verify the configuration during startup/documentation using queries such as:

```sql
SHOW wal_level;
SHOW max_wal_senders;
SHOW max_replication_slots;
```

Expected:

```text
wal_level
---------
logical
```

Debezium must use a dedicated replication slot.

---

# 6. Python Database Workload Generator

Create a Python client responsible for continuously generating realistic activity in PostgreSQL.

The generator must:

* Connect to PostgreSQL.
* Run continuously.
* Execute a workload every **10 seconds**.
* Generate between **10 and 50 operations per cycle**.
* Perform both `INSERT` and `UPDATE` operations.
* Operate across all three tables.
* Maintain referential integrity.
* Generate realistic UUIDs.
* Generate realistic device information.
* Generate realistic MAC/IP addresses.
* Generate fictional tenant/company names.
* Generate realistic-looking CVE IDs and CVSS scores for demo purposes.

Example fictional tenants:

```text
Acme Cyber Defense
Globex Technologies
Umbrella Networks
Wayne Enterprises
Stark Industries
Cyberdyne Systems
```

These names are fictional/demo metadata and must not represent actual customer data.

Updates should include scenarios such as:

```text
device OS version changed
firmware upgraded
device quarantined
risk LOW -> MEDIUM
risk MEDIUM -> HIGH
network interface becomes inactive
IP address changes
new CVE discovered
CVSS score changes
```

The generator should print concise activity logs.

Example:

```text
[GENERATOR] tenant=acme asset=71f... UPDATE risk_level HIGH
[GENERATOR] tenant=globex asset=81a... INSERT network_interface
[GENERATOR] tenant=wayne asset=19c... INSERT CVE-2026-12345
```

---

# 7. Debezium CDC

Deploy a Debezium PostgreSQL connector using Docker.

Debezium must monitor:

```text
assets
network_interfaces
asset_cves
```

Changes must be streamed into Confluent Cloud.

The implementation should configure:

* PostgreSQL logical decoding
* replication slot
* publication
* Kafka bootstrap servers
* SASL authentication
* TLS
* Schema Registry
* Protobuf serialization where applicable

The final Kafka representation must use **Protobuf schemas** registered in Confluent Cloud Schema Registry.

Avoid unnecessary connector complexity. Configuration should be reproducible from a JSON/config file and environment variables.

---

# 8. Kafka Topics

At minimum the project should produce logical topics representing:

```text
assets
network-interfaces
asset-cves
security-findings
```

Additional topics may be introduced for:

```text
threat-intelligence
cve-reference-data
device-events
security-alerts
security-aggregations
```

Naming should be consistent throughout the project.

---

# 9. Protobuf Requirement

**Every governed application topic must have a Protobuf schema.**

Do not leave production/demo topics without schemas.

Create `.proto` definitions under:

```text
/schemas
```

At minimum:

```text
assets.proto
network_interfaces.proto
asset_cves.proto
security_findings.proto
```

Where appropriate, schemas should include fields that make governance demonstrations interesting, such as:

```text
tenant_id
asset_id
device_type
os_vendor
os_version
risk_level
ip_address
mac_address
cve_id
cvss_score
severity
event_time
```

Schemas should be registered with Confluent Cloud Schema Registry.

---

# 10. Stage 1 – Confluent Advanced Data Governance

The first major milestone of the project is to have all PostgreSQL CDC data available in Confluent Cloud and fully governed.

The project must demonstrate **Advanced Data Governance capabilities**, not simply Kafka ingestion.

Each relevant topic should have useful:

* Tags
* Labels
* Metadata
* Descriptions
* Business context
* Ownership information
* Classification information

Do not apply identical metadata to every topic.

Metadata should demonstrate that different datasets can belong to different fictional companies, domains, teams, or sensitivity categories.

Example conceptual metadata:

```text
Company: Acme Cyber Defense
Domain: Endpoint Security
Environment: Demo
Owner: Security Platform Team
DataType: Asset Inventory
Sensitivity: Internal
```

Another topic might contain:

```text
Company: Globex Technologies
Domain: Vulnerability Management
Owner: Vulnerability Engineering
DataType: CVE
Sensitivity: Confidential
```

Another:

```text
Company: Wayne Enterprises
Domain: Network Security
Owner: Network Operations
DataType: Network Interface
```

---

# 11. Searchable Governance Demo

A major requirement is demonstrating **metadata-driven discovery**.

After governance metadata has been configured, a user should be able to use Confluent Cloud search/discovery capabilities and search for something similar to:

```text
Acme Cyber Defense
```

and discover relevant datasets/topics associated with that company.

Likewise searches for concepts such as:

```text
CVE
Vulnerability
Network Security
Endpoint
Confidential
```

should help discover the appropriate governed resources where supported.

This is one of the core demo scenarios of the project.

---

# 12. Governance Requirements Per Topic

Every relevant Kafka topic must have:

```text
Protobuf Schema
Description
Tags
Labels / Metadata
Owner
Domain
Environment
Data Classification
```

However, the actual values must differ between topics.

The project should intentionally demonstrate meaningful metadata instead of attaching every possible tag to every resource.

---

# 13. Stage 1 Definition of Done

Stage 1 is complete when:

```text
PostgreSQL
      ↓
Debezium
      ↓
Confluent Cloud Kafka
      ↓
Protobuf Schema Registry
      ↓
Advanced Data Governance
```

is working.

The user should be able to:

1. Modify PostgreSQL data.
2. Observe the CDC event in Kafka.
3. Inspect its Protobuf schema.
4. Inspect tags/metadata.
5. Search Confluent Cloud using governance metadata.
6. Find datasets using fictional company names and security concepts.

---

# 14. Stage 2 – Real-Time Cybersecurity Analytics with Flink

The second stage uses **Confluent Cloud Flink** to process the datasets.

The processing pipeline must demonstrate the following capabilities.

## Stream Enrichment

Join streaming device/asset telemetry in real time with:

* Threat Intelligence feeds
* CVE vulnerability data
* Asset information
* Network interface information

Example:

```text
Device Event
      +
Asset
      +
Network Interface
      +
CVE
      +
Threat Intelligence
      ↓
Enriched Security Event
```

---

# 15. Pattern Matching / CEP

Use Flink pattern detection / CEP capabilities where appropriate to identify suspicious behavior.

Possible demonstration scenarios include:

```text
HIGH-risk asset
+
critical CVE
+
active network interface
+
suspicious network activity
=
potential security incident
```

Another example:

```text
multiple suspicious events
within a defined time window
for the same asset
=
security alert
```

The exact detection logic may be simplified if required for Confluent Cloud compatibility.

Implementation simplicity is preferred over unnecessary complexity.

---

# 16. AI / ML Integration

Demonstrate ML inference directly against the event stream using capabilities available in Confluent Cloud Flink.

The project should demonstrate:

```text
AI / ML function
        ↓
streaming event
        ↓
risk/anomaly/fraud/threat score
```

Possible model output:

```text
anomaly_score
threat_probability
predicted_risk
model_version
```

Example:

```text
asset_id: 71f...
cve_id: CVE-2026-12345
cvss_score: 9.8
anomaly_score: 0.94
predicted_risk: CRITICAL
```

Where practical, demonstrate Confluent AI integrations/connectors directly against the stream.

Keep the ML component easy to reproduce.

The goal is demonstrating **streaming ML integration**, not building a complicated production ML platform.

---

# 17. Stream Debugging and Aggregations

The Flink section must also demonstrate real-time aggregations and debugging.

Example aggregations:

```text
CVE count per tenant
critical vulnerabilities per tenant
high-risk assets per 5-minute window
quarantined assets
active vulnerable devices
average CVSS score
alerts per tenant
```

Example query concept:

```sql
SELECT
    tenant_id,
    COUNT(*) AS critical_cves
FROM ...
WHERE severity = 'CRITICAL'
GROUP BY tenant_id;
```

Include several queries that are useful during a live demonstration.

---

# 18. Security Findings Topic

Flink must generate a new governed output topic.

Recommended name:

```text
security-findings
```

The topic represents detected security findings.

Example logical record:

```json
{
  "tenant_id": "acme",
  "asset_id": "71f...",
  "device_type": "firewall",
  "ip_address": "10.20.30.40",
  "cve_id": "CVE-2026-12345",
  "cvss_score": 9.8,
  "severity": "CRITICAL",
  "anomaly_score": 0.94,
  "finding_type": "VULNERABLE_ACTIVE_DEVICE",
  "event_time": "2026-08-27T10:30:00Z"
}
```

This example is JSON only for readability.

The actual Kafka topic must use **Protobuf**.

The output topic must also contain governance metadata, tags, ownership, and classification.

---

# 19. Python Security Findings Consumer

Create another Python application that consumes:

```text
security-findings
```

The consumer must:

1. Connect securely to Confluent Cloud.
2. Deserialize Protobuf.
3. Print human-readable security findings.
4. Forward findings into Elasticsearch.

Example console output:

```text
================================================
SECURITY FINDING
================================================

Tenant: Acme Cyber Defense
Asset: 71f...
Device: Firewall
CVE: CVE-2026-12345
CVSS: 9.8
Severity: CRITICAL
Anomaly Score: 0.94

Finding:
VULNERABLE_ACTIVE_DEVICE

================================================
```

---

# 20. Elasticsearch Integration

The security consumer must index findings into Elasticsearch.

Recommended index:

```text
security-findings
```

Fields should support useful filtering and aggregation.

Example:

```text
tenant_id
asset_id
device_type
ip_address
cve_id
cvss_score
severity
anomaly_score
finding_type
event_time
```

Elasticsearch should run locally through Docker unless a simpler implementation is available.

---

# 21. Kibana Dashboard

Provide a prebuilt Kibana dashboard.

The dashboard should require minimal or no manual setup after starting the environment.

Suggested visualizations:

```text
Total Security Findings

Critical Findings

Findings by Tenant

Findings by Severity

Top CVEs

Average CVSS

Average Anomaly Score

Findings Over Time

Most Vulnerable Device Types
```

Include filters for:

```text
tenant
severity
device_type
CVE
finding_type
```

Dashboard assets should be stored in the repository so the demo can be recreated easily.

---

# 22. Stage 3 – Tableflow

Enable **Tableflow** for an appropriate Confluent Cloud topic.

The goal is to expose streaming Kafka data through an analytics-friendly table representation backed by Confluent Cloud object storage.

A suitable topic should be selected, for example:

```text
security-findings
```

or another enriched/aggregated topic.

The README generated by the implementation should document exactly how to enable Tableflow and verify that data is being materialized.

---

# 23. Local Spark Integration

Create a local Spark example capable of reading the Tableflow-backed data.

The goal is:

```text
Confluent Cloud Kafka
        ↓
Tableflow
        ↓
Confluent Cloud Object Storage
        ↓
Spark Local
```

Provide:

```text
spark/read_tableflow.py
```

or a simple PySpark equivalent.

Example analytical operations:

```text
show security findings
group by tenant
group by severity
find CVSS > 9
calculate average anomaly score
find top vulnerable devices
```

The implementation should document all required Spark dependencies and authentication/configuration.

---

# 24. Docker Requirements

Use Docker wherever it improves reproducibility.

Local Docker components should include, where appropriate:

```text
PostgreSQL
Debezium / Kafka Connect
Python Generator
Python Security Consumer
Elasticsearch
Kibana
```

Do **not** run Kafka locally.

Kafka must be provided by:

```text
Confluent Cloud
```

Likewise:

```text
Schema Registry → Confluent Cloud
Flink → Confluent Cloud
Governance → Confluent Cloud
Tableflow → Confluent Cloud
```

The goal is to demonstrate a hybrid environment:

```text
Local Docker Environment
           │
           ▼
     Confluent Cloud
           │
           ▼
Local Consumers / Analytics
```

---

# 25. Environment Configuration

All credentials must come from environment variables.

Provide:

```text
.env.example
```

Never commit secrets.

Example variables:

```bash
POSTGRES_HOST=
POSTGRES_PORT=
POSTGRES_DB=
POSTGRES_USER=
POSTGRES_PASSWORD=

CONFLUENT_BOOTSTRAP_SERVERS=
CONFLUENT_KAFKA_API_KEY=
CONFLUENT_KAFKA_API_SECRET=

SCHEMA_REGISTRY_URL=
SCHEMA_REGISTRY_API_KEY=
SCHEMA_REGISTRY_API_SECRET=

ELASTICSEARCH_URL=

CONFLUENT_ENVIRONMENT_ID=
CONFLUENT_CLUSTER_ID=
```

Add additional variables as required.

---

# 26. Ease of Implementation

This is a major project requirement.

Prefer:

```text
simple scripts
Docker Compose
small Python applications
SQL files
Protobuf files
environment variables
documented CLI commands
```

over complicated frameworks.

Avoid introducing:

* Kubernetes
* unnecessary microservices
* custom orchestration frameworks
* unnecessary databases
* unnecessary application layers

unless they are required for demonstrating a specific Confluent capability.

---

# 27. One-Command Local Startup

The implementation should aim for:

```bash
cp .env.example .env
```

Configure Confluent Cloud credentials, then:

```bash
docker compose up -d
```

This should start as much of the local environment as reasonably possible.

Provide health checks for local services.

Example:

```bash
docker compose ps
```

should clearly show the state of:

```text
postgres
debezium
generator
consumer
elasticsearch
kibana
```

---

# 28. Recommended Demo Flow

The final README should make the demo runnable in a predictable sequence.

### Step 1 – Start Local Infrastructure

```bash
docker compose up -d
```

### Step 2 – Verify PostgreSQL

Verify:

```sql
SHOW wal_level;
```

and confirm:

```text
logical
```

### Step 3 – Start/Verify Debezium

Confirm all three tables are captured.

### Step 4 – Verify Confluent Cloud

Confirm topics exist and events are arriving.

### Step 5 – Verify Protobuf

Inspect schemas in Schema Registry.

### Step 6 – Demonstrate Governance

Inspect:

```text
tags
metadata
ownership
classification
```

Search for a fictional company such as:

```text
Acme Cyber Defense
```

and demonstrate dataset discovery.

### Step 7 – Run Flink

Deploy/run:

```text
enrichment
CVE correlation
CEP/pattern detection
ML inference
aggregations
```

### Step 8 – Generate Security Finding

Cause the generator to produce data matching a detection rule.

Observe:

```text
security-findings
```

### Step 9 – Observe Python Consumer

The consumer should print the finding.

### Step 10 – Open Kibana

Open the preconfigured cybersecurity dashboard.

### Step 11 – Demonstrate Tableflow

Show that the Kafka dataset is available through Tableflow.

### Step 12 – Query from Spark

Run the local Spark example and perform analytical queries against the Tableflow data.

---

# 29. Demo Scenario

Provide at least one deterministic scenario that can easily trigger an alert.

For example:

```text
Tenant:
Acme Cyber Defense

Asset:
Firewall-001

Risk:
HIGH

Network:
Active

CVE:
CVE-DEMO-0001

CVSS:
9.8

Severity:
CRITICAL

ML anomaly score:
> 0.90
```

Expected pipeline:

```text
PostgreSQL
   ↓
Debezium CDC
   ↓
Confluent Cloud
   ↓
Protobuf
   ↓
Flink Enrichment
   ↓
CVE Correlation
   ↓
Threat Detection / ML
   ↓
security-findings
   ↓
Python Consumer
   ↓
Elasticsearch
   ↓
Kibana
```

This scenario should be triggerable through a script or clearly documented SQL statements so the entire project can be demonstrated reliably.

---

# 30. Implementation Verification

Include scripts or commands that allow each layer to be tested independently.

The project should make it easy to answer:

```text
Is PostgreSQL generating changes?

Is WAL logical replication working?

Is Debezium capturing changes?

Are events reaching Confluent Cloud?

Are Protobuf schemas registered?

Does every topic have governance metadata?

Can datasets be discovered through metadata?

Are Flink jobs/statements running?

Is enrichment working?

Is CVE correlation working?

Is ML inference working?

Are security findings being produced?

Is the Python consumer receiving them?

Is Elasticsearch receiving documents?

Is Kibana displaying the findings?

Is Tableflow enabled?

Can local Spark read the Tableflow dataset?
```

---

# 31. Definition of Done

The project is complete when the following end-to-end flow works:

```text
PostgreSQL
    │
    │ CDC / WAL
    ▼
Debezium
    │
    ▼
Confluent Cloud Kafka
    │
    ├── Protobuf Schema Registry
    │
    ├── Advanced Data Governance
    │       ├── Tags
    │       ├── Metadata
    │       ├── Ownership
    │       └── Search / Discovery
    │
    ▼
Confluent Cloud Flink
    │
    ├── Stream Enrichment
    ├── Threat Intelligence
    ├── CVE Correlation
    ├── CEP / Pattern Detection
    ├── AI / ML Inference
    └── Real-Time Aggregations
    │
    ▼
security-findings
    │
    ├───────────────┐
    │               │
    ▼               ▼
Python Consumer   Tableflow
    │               │
    ▼               ▼
Elasticsearch    Object Storage
    │               │
    ▼               ▼
Kibana           Local Spark
```

The most important outcome is a clear demonstration of how **Confluent Cloud can provide governed, discoverable, schema-managed streaming data and then use that same data for real-time cybersecurity enrichment, detection, AI/ML inference, operational visualization, and analytical consumption.**

---

# 32. Instructions for GitHub Copilot / Implementation Agent

When implementing this repository:

1. Implement the project incrementally according to the stages in this README.
2. Do not invent unnecessary infrastructure.
3. Prefer Python for helper applications.
4. Prefer Docker Compose for local infrastructure.
5. Keep Kafka, Schema Registry, Flink, Governance, and Tableflow in Confluent Cloud.
6. Use PostgreSQL as the source database.
7. Configure PostgreSQL WAL correctly for Debezium.
8. Use the exact three PostgreSQL tables defined in this document.
9. Capture all three tables through Debezium.
10. Use Protobuf for every governed Kafka topic.
11. Register schemas in Confluent Cloud Schema Registry.
12. Add meaningful tags, labels, metadata, ownership, and classification to every relevant topic.
13. Do not assign identical governance metadata to every topic.
14. Include fictional companies in metadata so metadata-based discovery can be demonstrated.
15. Implement Flink enrichment between asset, network, CVE, and threat datasets.
16. Implement at least one deterministic security detection rule.
17. Demonstrate pattern/CEP-style detection.
18. Demonstrate an AI/ML inference capability available through Confluent Cloud/Flink.
19. Produce a governed `security-findings` topic.
20. Create a Python Protobuf consumer for `security-findings`.
21. Send findings to Elasticsearch.
22. Provide an importable/preconfigured Kibana dashboard.
23. Enable/document Tableflow.
24. Provide a local Spark example for reading the Tableflow dataset.
25. Never hardcode credentials.
26. Provide `.env.example`.
27. Provide clear commands for every setup step.
28. Add verification commands after every major component.
29. Make failures easy to debug through useful logs.
30. Optimize the repository for **demo reliability and ease of implementation**, rather than unnecessary production complexity.
