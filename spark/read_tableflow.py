import os
from hashlib import sha256

from elasticsearch import Elasticsearch, helpers
from pyspark.sql import SparkSession
from pyspark.sql.functions import avg, col, count, to_timestamp, window

TABLE_NAME = os.getenv("TABLEFLOW_TABLE_NAME", "")
BI_INDEX = "security-findings-bi"

if not TABLE_NAME:
    raise SystemExit(
        "Set TABLEFLOW_TABLE_NAME to the fully qualified Tableflow Iceberg table name."
    )

spark = (
    SparkSession.builder
    .appName("ConfluentTableflowDemo")
    .getOrCreate()
)

findings = spark.table(TABLE_NAME).withColumn(
    "event_timestamp", to_timestamp("event_time")
)

windowed_findings = (
    findings.filter(col("event_timestamp").isNotNull())
    .groupBy(
        window("event_timestamp", "10 minutes").alias("time_window"),
        "tenant_id",
        "severity",
        "predicted_risk",
    )
    .agg(
        count("*").alias("findings"),
        avg("cvss_score").alias("avg_cvss_score"),
        avg("anomaly_score").alias("avg_anomaly_score"),
    )
    .select(
        col("time_window.start").alias("window_start"),
        col("time_window.end").alias("window_end"),
        "tenant_id",
        "severity",
        "predicted_risk",
        "findings",
        "avg_cvss_score",
        "avg_anomaly_score",
    )
)

print("=== FINDINGS IN 10-MINUTE WINDOWS ===")
(
    windowed_findings
    .orderBy(col("window_start").desc(), col("findings").desc())
    .show(200, truncate=False)
)

elasticsearch = Elasticsearch(os.getenv("ELASTICSEARCH_URL", "http://localhost:9200"))
elasticsearch.indices.put_index_template(
    name="security-findings-bi-template",
    index_patterns=[f"{BI_INDEX}*"],
    priority=100,
    template={
        "mappings": {
            "properties": {
                "window_start": {"type": "date"},
                "window_end": {"type": "date"},
                "tenant_id": {"type": "keyword"},
                "severity": {"type": "keyword"},
                "predicted_risk": {"type": "keyword"},
                "findings": {"type": "long"},
                "avg_cvss_score": {"type": "float"},
                "avg_anomaly_score": {"type": "float"},
            }
        }
    },
)
if not elasticsearch.indices.exists(index=BI_INDEX):
    elasticsearch.indices.create(index=BI_INDEX)


def bulk_actions():
    for row in windowed_findings.toLocalIterator():
        document = row.asDict(recursive=True)
        document["window_start"] = document["window_start"].isoformat()
        document["window_end"] = document["window_end"].isoformat()
        document_id = sha256(
            "|".join(
                str(document[field])
                for field in ("window_start", "tenant_id", "severity", "predicted_risk")
            ).encode("utf-8")
        ).hexdigest()
        yield {"_index": BI_INDEX, "_id": document_id, "_source": document}


success, _ = helpers.bulk(elasticsearch, bulk_actions())
print(f"=== ELASTICSEARCH BI INDEX ===\nindexed_documents={success}")

print("=== TOP VULNERABLE DEVICE TYPES ===")
(
    findings.groupBy("device_type")
    .agg(count("*").alias("findings"), avg("cvss_score").alias("avg_cvss_score"))
    .orderBy(col("findings").desc())
    .show(truncate=False)
)
