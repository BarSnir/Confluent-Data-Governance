# Tableflow Demo Notes

## Target Topic and Storage

Tableflow is enabled by Terraform for `security_findings` as an Iceberg table in Confluent-managed object storage. No customer-managed bucket or cloud-provider integration is required.

## Provision

```bash
./scripts/terraform_clean.sh apply -target=confluent_tableflow_topic.security_findings
```

This requires a Cloud or Global API key authorized to use Tableflow in the Confluent Cloud environment.

## Spark Aggregation

After the table materializes, add its fully-qualified table identifier to `.env`:

```bash
TABLEFLOW_TABLE_NAME=<catalog>.<database>.<table>
```

Run the 10-minute rollup:

```bash
source .env
spark-submit --packages org.apache.iceberg:iceberg-spark-runtime-3.5_2.12:<iceberg-version> spark/read_tableflow.py
```

The job groups records into 10-minute event-time windows by tenant, severity, and predicted risk. It returns the finding count plus average CVSS and anomaly scores.

## Verification

- Confirm the Terraform output `tableflow_table_path` has a Confluent-managed object-storage path.
- Confirm the Iceberg table appears in the Tableflow catalog.
- Validate 10-minute aggregation rows while demo traffic is running.
