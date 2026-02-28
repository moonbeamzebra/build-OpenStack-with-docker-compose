# required : apt install python3-pika
import pika

url = "amqp://openstack:rabbit1@rabbitmq:5672/openstack"

params = pika.URLParameters(url)

try:
    connection = pika.BlockingConnection(params)
    print("✅ Connection successful!")
    connection.close()
except Exception as e:
    print("❌ Connection failed:")
    print(e)

