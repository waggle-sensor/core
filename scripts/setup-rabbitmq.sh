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
