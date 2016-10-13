# Setup environment variables. I think having these would be a helpful way to
# start having a more system independent place for tracking things like IDs
# or the platform we're on. This also makes it easier to mock these parameters
# out when testing.
WAGGLE_ROOT="/usr/lib/waggle"
WAGGLE_ID=$(ip link | awk '/ether 00:1e:06/ { print $2 }' | sed 's/://g')

# Delete existing Waggle environment.
sed -i -e '/^WAGGLE/d' /etc/environment

# Append new Waggle environment.
echo "WAGGLE_ROOT=$WAGGLE_ROOT" >> /etc/environment
echo "WAGGLE_ID=$WAGGLE_ID" >> /etc/environment

# Install latest RabbitMQ server.
echo 'deb http://www.rabbitmq.com/debian/ testing main' | sudo tee /etc/apt/sources.list.d/rabbitmq.list
wget -O- https://www.rabbitmq.com/rabbitmq-release-signing-key.asc | sudo apt-key add -
apt-get update
apt-get install -y rabbitmq-server

# Ensure that RabbitMQ server is running.
service rabbitmq-server start

# Enable RabbitMQ plugins.
rabbitmq-plugins enable rabbitmq_management rabbitmq_shovel rabbitmq_shovel_management

# Configure RabbitMQ shovels.
rabbitmqctl set_parameter shovel data-shovel "{\"src-uri\": \"amqp://localhost\", \"src-queue\": \"data\", \"dest-uri\": \"amqps://node:waggle@beehive1.mcs.anl.gov:23181?cacertfile=/usr/lib/waggle/SSL/waggleca/cacert.pem&certfile=/usr/lib/waggle/SSL/node/cert.pem&keyfile=/usr/lib/waggle/SSL/node/key.pem&verify=verify_peer\", \"dest-exchange\": \"data-pipeline-in\", \"ack-mode\": \"on-confirm\", \"reconnect-delay\": 60, \"publish-properties\": {\"delivery_mode\": 2, \"reply_to\": \"$WAGGLE_ID\"}}"
rabbitmqctl set_parameter shovel logs-shovel "{\"src-uri\": \"amqp://localhost\", \"src-queue\": \"logs\", \"dest-uri\": \"amqps://node:waggle@beehive1.mcs.anl.gov:23181?cacertfile=/usr/lib/waggle/SSL/waggleca/cacert.pem&certfile=/usr/lib/waggle/SSL/node/cert.pem&keyfile=/usr/lib/waggle/SSL/node/key.pem&verify=verify_peer\", \"dest-exchange\": \"logs\", \"ack-mode\": \"on-confirm\", \"reconnect-delay\": 60, \"publish-properties\": {\"delivery_mode\": 2, \"reply_to\": \"$WAGGLE_ID\"}}"
rabbitmqctl set_parameter shovel image-shovel "{\"src-uri\": \"amqp://localhost\", \"src-queue\": \"images\", \"dest-uri\": \"amqps://node:waggle@beehive1.mcs.anl.gov:23181?cacertfile=/usr/lib/waggle/SSL/waggleca/cacert.pem&certfile=/usr/lib/waggle/SSL/node/cert.pem&keyfile=/usr/lib/waggle/SSL/node/key.pem&verify=verify_peer\", \"dest-exchange\": \"images\", \"ack-mode\": \"on-confirm\", \"reconnect-delay\": 60, \"publish-properties\": {\"delivery_mode\": 2, \"reply_to\": \"$WAGGLE_ID\"}}"
