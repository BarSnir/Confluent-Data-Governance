# Apply Stream Catalog Metadata

Apply versioned Stream Catalog tags and business metadata to the four Kafka topics:

```bash
./governance/scripts/apply_stream_catalog.sh
```

The script creates missing tag definitions, creates the `CybersecurityDataProduct` business-metadata definition, then applies topic description, owner, tags, and business metadata from `governance/metadata/*.metadata.json`.

## Prerequisites

- **Tags:** The supplied principal must already have Stream Catalog write access, such as `DataSteward` or `EnvironmentAdmin` at the environment scope.
- **Business metadata:** The Confluent Cloud environment must have the **Stream Governance Advanced** package enabled.

This project deliberately does not create, change, or manage Stream Catalog RBAC. Supply an existing authorized Catalog/Schema Registry API key in `.env`:

```bash
CATALOG_API_KEY=<existing-authorized-key>
CATALOG_API_SECRET=<existing-authorized-secret>
```

If those variables are omitted, the script uses `SCHEMA_REGISTRY_API_KEY` and `SCHEMA_REGISTRY_API_SECRET`. The current project service-account key has Schema Registry write access only and cannot create Stream Catalog tags.

Verify catalog tagging and metadata through the Confluent Cloud Console's Catalog Management and global search. Useful search terms include `Acme`, `Globex`, `NetworkSecurity`, `CVE`, and `ThreatDetection`.
