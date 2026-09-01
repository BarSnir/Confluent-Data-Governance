FROM debezium/connect:2.7.3.Final

USER root
RUN mkdir -p /kafka/connect/confluentinc-kafka-connect-protobuf-converter && \
		curl -fsSL \
			"https://hub-downloads.confluent.io/api/plugins/confluentinc/kafka-connect-protobuf-converter/versions/7.7.0/confluentinc-kafka-connect-protobuf-converter-7.7.0.zip" \
			-o /tmp/protobuf-converter.zip && \
		unzip -q /tmp/protobuf-converter.zip -d /kafka/connect/confluentinc-kafka-connect-protobuf-converter && \
		rm /tmp/protobuf-converter.zip
USER kafka
