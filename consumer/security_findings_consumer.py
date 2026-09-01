import json
import os
import signal
import sys
from hashlib import sha256
from datetime import datetime, timezone

from confluent_kafka import OFFSET_BEGINNING, Consumer, TopicPartition
from confluent_kafka.schema_registry.protobuf import ProtobufDeserializer
from confluent_kafka.serialization import MessageField, SerializationContext
from elasticsearch import Elasticsearch

from security_findings_pb2 import SecurityFinding

RUNNING = True


def _stop(_sig, _frame):
    global RUNNING
    RUNNING = False


def _elasticsearch_client():
    url = os.getenv("ELASTICSEARCH_URL", "http://elasticsearch:9200")
    return Elasticsearch(url)


def _kafka_consumer():
    return Consumer(
        {
            "bootstrap.servers": os.getenv("CONFLUENT_BOOTSTRAP_SERVERS", ""),
            "group.id": os.getenv(
                "SECURITY_FINDINGS_CONSUMER_GROUP",
                "security-findings-elasticsearch-v1",
            ),
            "auto.offset.reset": "earliest",
            "enable.auto.commit": True,
            "security.protocol": "SASL_SSL",
            "sasl.mechanism": "PLAIN",
            "sasl.username": os.getenv("CONFLUENT_KAFKA_API_KEY", ""),
            "sasl.password": os.getenv("CONFLUENT_KAFKA_API_SECRET", ""),
        }
    )


def _protobuf_deserializer():
    return ProtobufDeserializer(
        SecurityFinding,
        {
            "schema.registry.url": os.getenv("SCHEMA_REGISTRY_URL", ""),
            "basic.auth.user.info": (
                f"{os.getenv('SCHEMA_REGISTRY_API_KEY', '')}:"
                f"{os.getenv('SCHEMA_REGISTRY_API_SECRET', '')}"
            ),
            "use.deprecated.format": False,
        },
    )


def _normalize_event_time(event_time):
    parsed = datetime.fromisoformat(event_time.replace(" ", "T"))
    if parsed.tzinfo is None:
        parsed = parsed.replace(tzinfo=timezone.utc)
    return parsed.isoformat(timespec="microseconds").replace("+00:00", "Z")


def _to_document(raw_value, topic, deserializer):
    try:
        finding = deserializer(
            raw_value, SerializationContext(topic, MessageField.VALUE)
        )
        return {
            "tenant_id": finding.tenant_id,
            "asset_id": finding.asset_id,
            "device_type": finding.device_type,
            "ip_address": finding.ip_address,
            "cve_id": finding.cve_id,
            "cvss_score": finding.cvss_score,
            "severity": finding.severity,
            "anomaly_score": finding.anomaly_score,
            "finding_type": finding.finding_type,
            "predicted_risk": finding.predicted_risk,
            "model_version": finding.model_version,
            "event_time": _normalize_event_time(finding.event_time),
        }
    except Exception as exc:
        print(f"[CONSUMER] skipping undecodable record: {exc}", flush=True)
        return None


def _assign_earliest_partitions(consumer, topic):
    metadata = consumer.list_topics(topic=topic, timeout=20)
    topic_metadata = metadata.topics.get(topic)
    if topic_metadata is None or topic_metadata.error is not None:
        raise RuntimeError(f"unable to read Kafka metadata for topic={topic}")

    consumer.assign(
        [
            TopicPartition(topic, partition, OFFSET_BEGINNING)
            for partition in topic_metadata.partitions
        ]
    )


def _document_id(doc):
    stable_fields = [
        doc.get("tenant_id", ""),
        doc.get("asset_id", ""),
        doc.get("cve_id", ""),
        doc.get("event_time", ""),
        doc.get("predicted_risk", ""),
    ]
    return sha256("|".join(stable_fields).encode("utf-8")).hexdigest()


def main():
    signal.signal(signal.SIGINT, _stop)
    signal.signal(signal.SIGTERM, _stop)

    topic = os.getenv("SECURITY_FINDINGS_TOPIC", "security_findings")

    es = _elasticsearch_client()
    consumer = _kafka_consumer()
    _assign_earliest_partitions(consumer, topic)
    deserializer = _protobuf_deserializer()

    es.indices.put_index_template(
        name="security-findings-template",
        index_patterns=["security-findings*"],
        template={
            "mappings": {
                "properties": {
                    "tenant_id": {"type": "keyword"},
                    "asset_id": {"type": "keyword"},
                    "device_type": {"type": "keyword"},
                    "ip_address": {"type": "ip"},
                    "cve_id": {"type": "keyword"},
                    "cvss_score": {"type": "float"},
                    "severity": {"type": "keyword"},
                    "anomaly_score": {"type": "float"},
                    "finding_type": {"type": "keyword"},
                    "predicted_risk": {"type": "keyword"},
                    "model_version": {"type": "keyword"},
                    "event_time": {"type": "date"},
                }
            }
        },
    )
    if not es.indices.exists(index="security-findings"):
        es.indices.create(index="security-findings")
    es.delete_by_query(
        index="security-findings",
        query={"bool": {"must_not": [{"exists": {"field": "severity"}}]}},
        conflicts="proceed",
        refresh=True,
    )

    print(f"[CONSUMER] assigned earliest offsets topic={topic}", flush=True)

    while RUNNING:
        msg = consumer.poll(1.0)
        if msg is None:
            continue
        if msg.error():
            print(f"[CONSUMER] error={msg.error()}")
            continue

        payload = msg.value()
        if not payload:
            print("[CONSUMER] skipping tombstone record", flush=True)
            continue
        doc = _to_document(payload, topic, deserializer)
        if doc is None:
            continue

        print("=" * 48)
        print("SECURITY FINDING")
        print("=" * 48)
        print(json.dumps(doc, indent=2, sort_keys=True))
        print("=" * 48)

        es.index(index="security-findings", id=_document_id(doc), document=doc)

    consumer.close()
    print("[CONSUMER] stopped")


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:
        print(f"[CONSUMER] fatal_error={exc}")
        sys.exit(1)
