import os
import time
from datetime import datetime, timezone
from hashlib import sha256

from elasticsearch import Elasticsearch, helpers

BI_INDEX = "security-findings-bi"
REFRESH_SECONDS = int(os.getenv("BI_REFRESH_SECONDS", "30"))


def _client():
    return Elasticsearch(os.getenv("ELASTICSEARCH_URL", "http://elasticsearch:9200"))


def _timestamp(epoch_millis):
    return datetime.fromtimestamp(epoch_millis / 1000, timezone.utc).isoformat().replace(
        "+00:00", "Z"
    )


def _actions(aggregation):
    for time_bucket in aggregation["windows"]["buckets"]:
        for tenant_bucket in time_bucket["tenants"]["buckets"]:
            for severity_bucket in tenant_bucket["severities"]["buckets"]:
                for risk_bucket in severity_bucket["risks"]["buckets"]:
                    document = {
                        "window_start": _timestamp(time_bucket["key"]),
                        "window_end": _timestamp(time_bucket["key"] + 600000),
                        "tenant_id": tenant_bucket["key"],
                        "severity": severity_bucket["key"],
                        "predicted_risk": risk_bucket["key"],
                        "findings": risk_bucket["doc_count"],
                        "avg_cvss_score": risk_bucket["avg_cvss_score"]["value"],
                        "avg_anomaly_score": risk_bucket["avg_anomaly_score"]["value"],
                    }
                    document_id = sha256(
                        "|".join(
                            str(document[field])
                            for field in (
                                "window_start",
                                "tenant_id",
                                "severity",
                                "predicted_risk",
                            )
                        ).encode("utf-8")
                    ).hexdigest()
                    yield {"_index": BI_INDEX, "_id": document_id, "_source": document}


def rebuild_index(client):
    client.indices.put_index_template(
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
    if not client.indices.exists(index=BI_INDEX):
        client.indices.create(index=BI_INDEX)

    response = client.search(
        index="security-findings",
        size=0,
        query={"exists": {"field": "severity"}},
        aggs={
            "windows": {
                "date_histogram": {
                    "field": "event_time",
                    "fixed_interval": "10m",
                    "min_doc_count": 1,
                },
                "aggs": {
                    "tenants": {
                        "terms": {"field": "tenant_id", "size": 1000},
                        "aggs": {
                            "severities": {
                                "terms": {"field": "severity", "size": 10},
                                "aggs": {
                                    "risks": {
                                        "terms": {"field": "predicted_risk", "size": 10},
                                        "aggs": {
                                            "avg_cvss_score": {"avg": {"field": "cvss_score"}},
                                            "avg_anomaly_score": {
                                                "avg": {"field": "anomaly_score"}
                                            },
                                        },
                                    }
                                },
                            }
                        },
                    }
                },
            }
        },
    )

    client.delete_by_query(index=BI_INDEX, query={"match_all": {}}, refresh=True)
    actions = list(_actions(response["aggregations"]))
    if actions:
        helpers.bulk(client, actions, refresh=True)
    print(f"[BI] indexed_documents={len(actions)}", flush=True)


def main():
    client = _client()
    while True:
        try:
            rebuild_index(client)
        except Exception as exc:
            print(f"[BI] aggregation_error={exc}", flush=True)
        time.sleep(REFRESH_SECONDS)


if __name__ == "__main__":
    main()