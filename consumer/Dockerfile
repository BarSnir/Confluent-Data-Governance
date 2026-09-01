FROM python:3.12-slim

WORKDIR /app

COPY consumer/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY schemas/security_findings.proto /schemas/security_findings.proto
RUN python -m grpc_tools.protoc -I/schemas --python_out=. /schemas/security_findings.proto

COPY consumer/security_findings_consumer.py .
COPY consumer/bi_aggregator.py .

CMD ["python", "security_findings_consumer.py"]
