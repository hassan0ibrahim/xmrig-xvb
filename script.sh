#!/bin/bash

ADDRESS=""
TOKEN=""
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
  local status="p2pool"
  local mins=0

  while true; do
    local value=$(get_block_value)
    read avg1 avg24 <<< $(get_avg_values)

    echo -e "$((mins/6))h"
    echo -e "$avg1,$avg24"
    echo -e "$value"

    if [[ "$value" -gt 0 && $(awk "BEGIN {print ($avg24 < 10 && $avg1 < 10)}") == "1" ]]; then
      new_status="xvb"
      command="$COMMAND_IF_TRUE"
    else
      new_status="p2pool"
      command="$COMMAND_IF_FALSE"
    fi

    if [[ "$new_status" != "$status" ]]; then
      echo -e "Switching to $new_status"
      start_xmrig "$command"
      status="$new_status"
    fi

    mins=$((mins + 1))
    sleep 600
  done
}

main
