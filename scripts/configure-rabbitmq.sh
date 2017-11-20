#!/bin/bash

echo -n "Checking .erlang.cookie..."
cookie_length_check_result=$(cat /var/lib/rabbitmq/.erlang.cookie | wc -c)
if [ "$cookie_length_check_result" != "0" ];  then
  echo "correct"
else
  echo "wrong - removing /var/lib/rabbitmq/.erlang.cookie file..."
  rm -f /var/lib/rabbitmq/.erlang.cookie
fi

echo "Checking done"