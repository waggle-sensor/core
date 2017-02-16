#!/bin/bash


try_set_time()
{
  local __check_interval__=$2
  local node_controller_ip=`cat /etc/waggle/node_controller_host`
  local wagman_date=0
  unset date

  # get epoch from server
  local exit_code
  if [ "x$ODROID_MODEL" == "xODROIDXU" ]; then
    echo "On an XU4. Getting the epoch from the Node Controller..."
    date=$(ssh -i /usr/lib/waggle/SSL/guest/id_rsa_waggle_aot_guest_node \
      -o "StrictHostKeyChecking no" -o "ConnectTimeout 2" \
      waggle@${node_controller_ip} -x date +%s)
    exit_code=$?
    if [ ${exit_code} -ne 0 ]; then
      echo "Warning: Failed to get the time from the Node Controller."
      return ${exit_code}
    fi
  elif [ "x$ODROID_MODEL" == "xODROIDC" ]; then
    echo "On a C1+. Getting the epoch from Beehive..."
    local server_hostname_file="/etc/waggle/server_host"
    while [ ! -e $server_hostname_file ]; do
      echo "The Beehive hostname has not been set. Retrying in 1 hour..."
      sleep 1h
    done
    local server_host=`cat $server_hostname_file`
    local curl_out=$(curl -s --max-time 10 --connect-timeout 10 http://${server_host}/api/1/epoch)
    exit_code=$?
    if [ ${exit_code} -eq 0 ] ; then
      date_json=$(echo $curl_out | tr '\n' ' ')
      date=$(python -c "import json; print(json.loads('${date_json}')['epoch'])") || unset date
      echo "Got date '${date} from Beehive."
    else
      echo "Warning: could not get the epoch from Beehive."
      unset date
    fi
  else
    echo "Error: unrecognized Odroid model '${ODROID_MODEL}'"
    exit 2
  fi

  # if date is not empty, set date
  if [ ! "${date}x" == "x" ] ; then
    echo "Setting the date/time update interval to 24 hours..."
    eval ${check_interval}=86400  # 24 hours
    echo "Setting the system epoch to ${date}..."
    date -s@${date}
    exit_code=$?
    if [ ${exit_code} -ne 0 ] ; then
      echo "Error: failed to set the system date/time."
       return ${exit_code}
    fi

    # Update the WagMan date when necessary
    if [[ "x$ODROID_MODEL" == "xODROIDC" && $date -gt $wagman_date ]]; then
      echo "Setting the Wagman date/time..."
      wagman-client date $(date +"%Y %m %d %H %M %S") || true
    fi

    # Sync the system time with the hardware clock
    echo "Syncing the hardware clock with the system date/time..."
    hwclock -w
  elif [ "x$ODROID_MODEL" == "xODROIDC" ]; then
    echo "Setting the date/time update interval to 10 seconds..."
    eval ${check_interval}=10  # 10 seconds
    wagman_date=$(wagman-client epoch) || wagman_date=0
    echo "Wagman epoch: ${wagman_date}"
    system_date=$(date +%s)
    echo "System epoch: ${system_date}"
    wagman_build_date=$(wagman-client ver | sed -n -e 's/time //p') || wagman_build_date=0
    echo "Wagman build epoch: ${wagman_build_date}"
    guest_node_date=$(ssh -i /usr/lib/waggle/SSL/guest/id_rsa_waggle_aot_guest_node \
                        -o "StrictHostKeyChecking no" -o "ConnectTimeout 30" \
                        waggle@10.31.81.51 -x date +%s) || guest_node_date=0
    echo "Guest Node epoch: ${guest_node_date}"
    dates=($system_date $wagman_date $wagman_build_date $guest_node_date)
    IFS=$'\n'
    date=$(echo "${dates[*]}" | sort -nr | head -n1)
    echo "Setting the system epoch to ${date}..."
    date -s @$date
  fi

  return 0
}

main() {
echo "detecting Odroid model..."
# Detect Odroid model. Sets ODROID_MODEL global variable
. /usr/lib/waggle/core/scripts/detect_odroid_model.sh

  set +e

  local check_interval

  echo "entering main time check loop..."
  while [ 1 ] ; do
    while [ 1 ] ; do
      echo "attempting to set the time..."
      try_set_time check_interval
      if [ $? -ne 0 ] ; then
        # did not set time, will try again.
        echo "failed to set time. retrying in 10 seconds..."
        sleep 10
      else
        echo "Successfully updated dates/times."
      fi
    done

    echo "The next time update will be in ${check_interval} seconds."
    sleep ${check_interval}
  done
}

main