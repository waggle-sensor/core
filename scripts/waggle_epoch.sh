#!/bin/bash
set -e

# This script tries to get the time from the beehive server. 

ODROID_MODEL=`head -n 1 /media/boot/boot.ini | cut -d '-' -f 1 | tr -d '\n'`
NODE_CONTROLLER_IP=`cat /etc/waggle/node_controller_host`
if [ "x$ODROID_MODEL" == "xODROIDC" ]; then
  server_hostname_file="/etc/waggle/server_host"
  while [ ! -e $server_hostname_file ]; do
    sleep 1h
  done
  SERVER_HOST=`cat $server_hostname_file`
fi

CHECK_INTERVAL='24h'

try_set_time()
{
  wagman_date=0
  unset date

  # get epoch from server
  set +e
  if [ "x$ODROID_MODEL" == "xODROIDXU" ]; then
    date=$(ssh -i /usr/lib/waggle/SSL/guest/id_rsa_waggle_aot_guest_node \
      -o "StrictHostKeyChecking no" -o "ConnectTimeout 2" \
      waggle@${NODE_CONTROLLER_IP} -x date +%s)
    EXIT_CODE=$?
    if [ ${EXIT_CODE} -ne 0 ]; then
      return ${EXIT_CODE}
    fi
  else
    curl_out=$(curl -s --max-time 10 --connect-timeout 10 http://${SERVER_HOST}/api/1/epoch)
    EXIT_CODE=$?
    if [ ${EXIT_CODE} -eq 0 ] ; then
      date_json=$(echo $curl_out | tr '\n' ' ')
      date=$(python -c "import json; print(json.loads('${date_json}')['epoch'])") || unset date
    else
      unset date
    fi
  fi
  set -e

  # if date is not empty, set date
  if [ ! "${date}x" == "x" ] ; then
    CHECK_INTERVAL='24h'
    set -x
    date -s@${date}
    EXIT_CODE=$?
    if [ ${EXIT_CODE} -ne 0 ] ; then
       return ${EXIT_CODE}
    fi

    # Update the WagMan date when necessary
    if [[ "x$ODROID_MODEL" == "xODROIDC" && $date -gt $wagman_date ]]; then
      wagman-client date $(date +"%Y %m %d %H %M %S") || true
    fi

    # Sync the system time with the hardware clock
    hwclock -w
  elif [ "x$ODROID_MODEL" == "xODROIDC" ]; then
    CHECK_INTERVAL='10'
    wagman_date=$(wagman-client epoch) || wagman_date=0
    system_date=$(date +%s)
    wagman_build_date=$(wagman-client ver | sed -n -e 's/time //p') || wagman_build_date=0
    guest_node_date=$(ssh -i /usr/lib/waggle/SSL/guest/id_rsa_waggle_aot_guest_node \
                        -o "StrictHostKeyChecking no" -o "ConnectTimeout 30" \
                        waggle@10.31.81.51 -x date +%s) || guest_node_date=0
    dates=($system_date $wagman_date $wagman_build_date $guest_node_date)
    IFS=$'\n'
    date=$(echo "${dates[*]}" | sort -nr | head -n1)
    date -s @$date
  fi

  return 0
}

########### start ###########

while [ 1 ] ; do
  
  while [ 1 ] ; do
    try_set_time
    if [ $? -eq 0 ] ; then
      break
    fi
    # did not set time, will try again.
    sleep 10
  done

  echo "sleep ${CHECK_INTERVAL}"
  sleep ${CHECK_INTERVAL}
done



