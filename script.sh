#!/bin/bash

ADDRESS="INSERT YOUR WALLET ADDRESS"
TOKEN="INSERT YOUR XvB TOKEN"
COMMAND_IF_TRUE="./xmrig -o eu.xmrvsbeast.com:4247 -u ${ADDRESS:0:8} --randomx-1gb"
COMMAND_IF_FALSE="./xmrig -o 127.0.0.1:3333 --randomx-1gb"

URL="https://mini.p2pool.observer/miner/$ADDRESS"
BONUS_URL="https://xmrvsbeast.com/cgi-bin/p2pool_bonus_history_api.cgi?address=$ADDRESS&token=$TOKEN"

get_block_value() {
  curl -s "$URL" | grep -oP '(?<=<td>).*?(?=</td>)' | grep -m1 'blocks' | grep -o '^[0-9]'
}

get_avg_values() {
  local avg24=$(curl -s "$BONUS_URL" | grep -o '"donor_24hr_avg":[^,}]*' | grep -oP '(?<=donor_24hr_avg": )\d+\.\d+')
  local avg1=$(curl -s "$BONUS_URL" | grep -o '"donor_1hr_avg":[^,}]*' | grep -oP '(?<=donor_1hr_avg": )\d+\.\d+')
  echo "$avg1 $avg24"
}

start_xmrig() {
  local command=$1
  pkill --signal SIGINT xmrig 2>/dev/null
  eval "$command" &
}

main() {
  local value=$(get_block_value)
  read avg1 avg24 <<< $(get_avg_values)
  # Start Xmrig
  if awk "BEGIN {exit !($value > 0 && ($avg24 < 10 || $avg1 < 10))}"; then
    eval '$COMMAND_IF_TRUE' &
    status="xvb"
  else
    eval '$COMMAND_IF_FALSE' &
    status="p2pool"
  fi
  local mins=0
  while true; do
    local value=$(get_block_value)
    read avg1 avg24 <<< $(get_avg_values)

    echo -e "$((mins/6))h$((mins*10%60))m"
    echo -e "$avg1,$avg24"
    echo -e "$value"

    # Check if both values are greater than 10
    if awk "BEGIN {exit !($value > 0 && ($avg24 < 10 || $avg1 < 10))}"; then
      # Stop the true command if it's running
      if [[ $status == "p2pool" ]]; then
        echo -e "Mining on XvB"
        status="xvb"
        pkill --signal SIGINT xmrig
        # Uncomment and modify the following line if needed
        eval '$COMMAND_IF_TRUE' &
      else
        echo -e $status
      fi
    else
      # Stop the true command if it's running
      if [[ $status == "xvb" ]]; then
        echo -e "Mining on p2pool"
        status="p2pool"
        pkill --signal SIGINT xmrig
        # Uncomment and modify the following line if needed
        eval '$COMMAND_IF_FALSE' &
      else
        echo -e $status
      fi
    fi
    mins=$((mins + 1))
    sleep 600
  done
}

main
