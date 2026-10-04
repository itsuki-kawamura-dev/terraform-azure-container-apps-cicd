import os
import json
from flask import Flask, jsonify, request
from azure.identity import DefaultAzureCredential
from azure.servicebus import ServiceBusClient, ServiceBusMessage

app = Flask(__name__)

SERVICEBUS_NAMESPACE = "sbns-container-apps-lab.servicebus.windows.net"
QUEUE_NAME = "jobs"

credential = DefaultAzureCredential(managed_identity_client_id=os.environ["AZURE_CLIENT_ID"])


@app.route("/")
def home():
    return jsonify({
        "message": "Azure Container Apps API is running"
    })


@app.route("/health")
def health():
    return jsonify({
        "status": "healthy"
    }), 200


@app.route("/jobs", methods=["POST"])
def create_job():
    body = request.get_json(silent=True) or {}

    message = ServiceBusMessage(json.dumps(body))

    with ServiceBusClient(
        fully_qualified_namespace=SERVICEBUS_NAMESPACE,
        credential=credential
    ) as client:

        sender = client.get_queue_sender(queue_name=QUEUE_NAME)

        with sender:
            sender.send_messages(message)

    return jsonify({
        "status": "queued",
        "job": body
    }), 202


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)