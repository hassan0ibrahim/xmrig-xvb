#!/bin/bash

if [ "$#" -ne 2 ]; then
  echo "Usage: ./script <Wallet Address> <XvB Token>"
  exit 1
fi
if [ "$EUID" -ne 0 ]; then
  echo "This script must be run with sudo."
  exit 1
fi
if [ -z "$(pgrep p2pool)" ]; then
  echo "P2pool isn't running, run it first using ./p2pool-v4.1-linux-x64/p2pool --mini --host <MoneroNodeAddress> --wallet <WalletAddress>"
  exit 1
fi
ADDRESS="$1"
TOKEN="$2"
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

main() {
  local value=$(get_block_value)
  read avg1 avg24 <<< $(get_avg_values)
  local mins=0
  # Start Xmrig
  if awk "BEGIN {exit !($value > 0 && ($avg24 < 10 || $avg1 < 10))}"; then
    eval '$COMMAND_IF_TRUE' &
    status="xvb"
  else
    eval '$COMMAND_IF_FALSE' &
    status="p2pool"
  fi
  while true; do
    local value=$(get_block_value)
    read avg1 avg24 <<< $(get_avg_values)

    echo -e "$((mins/6))h$((mins*10%60))m"
    echo -e "$avg1,$avg24"
    echo -e "$value"

    # Check if both values are less than 10 and there's atleast 1 share in P2pool
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
        echo -e "Mining on P2pool"
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
