#!/bin/bash
# ANL:waggle-license
#  This file is part of the Waggle Platform.  Please see the file
#  LICENSE.waggle.txt for the legal details of the copyright and software
#  license.  For more details on the Waggle project, visit:
#           http://www.wa8.gl
# ANL:waggle-license

echo -n "Checking .erlang.cookie..."
cookie_length_check_result=$(cat /var/lib/rabbitmq/.erlang.cookie | wc -c)
if [ "$cookie_length_check_result" != "0" ];  then
  echo "correct"
else
  echo "wrong - removing /var/lib/rabbitmq/.erlang.cookie file..."
  rm -f /var/lib/rabbitmq/.erlang.cookie
fi

echo "Checking done"
