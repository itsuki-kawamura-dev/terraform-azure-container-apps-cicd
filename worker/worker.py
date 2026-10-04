import os
import uuid
import json

from azure.identity import DefaultAzureCredential
from azure.servicebus import ServiceBusClient
from azure.storage.blob import BlobServiceClient

SERVICEBUS_NAMESPACE = "sbns-container-apps-lab.servicebus.windows.net"
QUEUE_NAME = "jobs"

STORAGE_ACCOUNT_URL = "https://stitsukicontainerlab.blob.core.windows.net"
CONTAINER_NAME = "results"

credential = DefaultAzureCredential(
    managed_identity_client_id=os.environ["AZURE_CLIENT_ID"]
)

blob_service_client = BlobServiceClient(
    account_url=STORAGE_ACCOUNT_URL,
    credential=credential
)

with ServiceBusClient(
    fully_qualified_namespace=SERVICEBUS_NAMESPACE,
    credential=credential
) as client:

    receiver = client.get_queue_receiver(
        queue_name=QUEUE_NAME,
        max_wait_time=30
    )

    with receiver:
        for message in receiver:
            print(f"Received: {message}", flush=True)

            body = json.loads(message)

            blob_name = f"{uuid.uuid4()}.txt"

            blob_client = blob_service_client.get_blob_client(
                container=CONTAINER_NAME,
                blob=blob_name
            )

try:
    blob_client.upload_blob(
        json.dumps(body),
        overwrite=True
    )

    print(f"Saved to Blob: {blob_name}", flush=True)

    receiver.complete_message(message)

except Exception as e:
    print(f"Failed to process message: {e}", flush=True)