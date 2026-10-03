import os

from azure.identity import DefaultAzureCredential
from azure.servicebus import ServiceBusClient

SERVICEBUS_NAMESPACE = "sbns-container-apps-lab.servicebus.windows.net"
QUEUE_NAME = "jobs"

credential = DefaultAzureCredential(
    managed_identity_client_id=os.environ["AZURE_CLIENT_ID"]
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
            print(f"Received: {message}")
            receiver.complete_message(message)