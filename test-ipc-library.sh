#!/bin/sh
# Test script for aira-ipc.sh library

# Source the library
. ./usr/lib/aira-ipc.sh

echo "Testing aira-ipc.sh library..."

# Test availability
if aira_ipc_available; then
    echo "✓ IPC bus is available"
else
    echo "✗ IPC bus is not available"
    exit 1
fi

# Test ping
if aira_ipc_ping "library-test"; then
    echo "✓ IPC ping successful"
    echo "  Response: $_AIRA_IPC_RESPONSE"
else
    echo "✗ IPC ping failed"
    echo "  Error: $_AIRA_IPC_ERROR"
    exit 1
fi

# Test list services
if aira_ipc_list_services; then
    echo "✓ IPC list services successful"
    echo "  Services:"
    printf "%s\n" "$_AIRA_IPC_RESPONSE" | sed 's/^/    /'
else
    echo "✗ IPC list services failed"
    echo "  Error: $_AIRA_IPC_ERROR"
    exit 1
fi

# Test call system version
if aira_ipc_call_first system version; then
    echo "✓ IPC call system version successful"
    echo "  Version: $_AIRA_IPC_RESPONSE_FIRST"
else
    echo "✗ IPC call system version failed"
    echo "  Error: $_AIRA_IPC_ERROR"
    exit 1
fi

# Test call system info (multi-line response)
if aira_ipc_call system info; then
    echo "✓ IPC call system info successful"
    echo "  Info lines:"
    printf "%s\n" "$_AIRA_IPC_RESPONSE" | sed 's/^/    /'
else
    echo "✗ IPC call system info failed"
    echo "  Error: $_AIRA_IPC_ERROR"
    exit 1
fi

echo "All tests passed!"
exit 0