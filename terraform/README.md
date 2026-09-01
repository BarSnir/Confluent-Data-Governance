Terraform for Confluent Cloud Resources

This folder provisions Confluent Cloud resources required by the demo project:
- Environment
- Kafka cluster
- Service account + role binding
- Kafka API key
- Schema Registry API key
- Core Kafka topics
- Protobuf schema subjects
- Flink compute pool

Quick start
1. Copy variables file:
   cp terraform/terraform.tfvars.example terraform/terraform.tfvars
2. Edit terraform/terraform.tfvars and set cloud API credentials and region details.
3. Run:
   cd terraform
   terraform init
   terraform plan
   terraform apply

Export values into project env
1. From terraform folder run:
   terraform output -raw confluent_bootstrap_servers
   terraform output -raw kafka_api_key
   terraform output -raw kafka_api_secret
   terraform output -raw schema_registry_url
   terraform output -raw schema_registry_api_key
   terraform output -raw schema_registry_api_secret
2. Copy those values into .env file in project root.

Destroy
cd terraform
terraform destroy

Notes
- Confluent Cloud API keys used by Terraform must be Cloud-scoped management keys.
- Topic names and schema subjects align with this repository layout.
- Governance metadata tagging is kept in governance folder for UI/API application workflows.
