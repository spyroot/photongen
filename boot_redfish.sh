#!/bin/bash

# Redfish credentials and host
REDFISH_USERNAME="admin"
REDFISH_PASSWORD="iamevil666"

HOST="192.168.254.207"
HOST_IP="192.168.254.228"
ISO_URL="http://$HOST_IP:8000/ph5-rt-refresh_adj.iso"
ISO_PATH="/app/ph5-rt-refresh_adj.iso"

# Function to start the HTTP server
start_http_server() {
    echo "Starting HTTP server to serve the ISO at $ISO_URL"
    cd /app
    nohup python3 -m http.server 8000 > /dev/null 2>&1 &
    HTTP_SERVER_PID=$!
}

# Function to stop the HTTP server
stop_http_server() {
    echo "Stopping HTTP server..."
    kill "$HTTP_SERVER_PID"
}

# Function to interact with Redfish API
redfish_command() {
    local method=$1
    local endpoint=$2
    local data=$3

    response=$(curl -s -k -u "$REDFISH_USERNAME:$REDFISH_PASSWORD" \
        -X "$method" \
        -H "Content-Type: application/json" \
        -d "$data" \
        "https://$HOST/redfish/v1/$endpoint")

    if [[ $? -ne 0 ]]; then
        echo "Error: Failed to communicate with Redfish API at $HOST."
        exit 1
    fi

    echo "$response" | grep -q '"error"' && {
        echo "Error in response: $response"
        exit 1
    }
    echo "$response"
}

# Check if the ISO file exists
if [[ ! -f "$ISO_PATH" ]]; then
    echo "Error: ISO file not found at $ISO_PATH."
    exit 1
fi

start_http_server

trap stop_http_server EXIT

echo "Mounting ISO via Virtual Media on $HOST..."
redfish_command "POST" "Managers/1/VirtualMedia/CD" \
    "{\"Image\": \"$ISO_URL\", \"Inserted\": true, \"WriteProtected\": true}"

echo "Setting boot to Virtual Media for next boot only..."
redfish_command "PATCH" "Systems/1" \
    '{"Boot": {"BootSourceOverrideEnabled": "Once", "BootSourceOverrideTarget": "Cd"}}'

echo "Rebooting the system to boot from ISO..."
redfish_command "POST" "Systems/1/Actions/ComputerSystem.Reset" \
    '{"ResetType": "ForceRestart"}'

echo "System reboot initiated. The system should boot from the specified ISO."
