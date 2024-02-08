#!/bin/bash

export MODE="$MODE"
export SERVER_IP="$SERVER_IP"
export PORT="$PORT"
export MSS="${MSS:-1460}"
export TIMEOUT="${TIMEOUT:-60}"

echo "Mode: $MODE"
echo "Server IP: $SERVER_IP"
echo "Port: $PORT"
echo "MSS: $MSS"
echo "Timeout: $TIMEOUT"

if [ "$MODE" = "client" ]; then
    iperf3 --parallel 1 --client "$SERVER_IP" --set-mss "$MSS" --timeout "$TIMEOUT" --bandwidth 0 --zerocopy --port "$PORT"
elif [ "$MODE" = "server" ]; then
    if [ -z "$SERVER_IP" ]; then
        SERVER_IP=$(ip -4 addr show eth0 | grep -oP '(?<=inet\s)\d+(\.\d+){3}')
    fi
    echo "Starting server on IP: $SERVER_IP:$PORT"
    iperf3 --bind "$SERVER_IP" --server --one-off --daemon --port "$PORT"
else
    echo "Unknown mode: $MODE"
    exit 1
fi

