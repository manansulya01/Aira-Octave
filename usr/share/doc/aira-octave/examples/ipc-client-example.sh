#!/bin/sh
# Example: How to use the shared IPC client library in Wave C applications
# This example shows the pattern for making efficient IPC calls

# Source the shared IPC client library
# Applications should use the full path: . /usr/lib/aira-ipc.sh
. /usr/lib/aira-ipc.sh

# Example 1: Simple call-get-first-line
# Get the system version
if aira_ipc_call_first system version; then
    echo "System version: $_AIRA_IPC_RESPONSE_FIRST"
else
    echo "Failed to get system version: $_AIRA_IPC_ERROR"
    # Fallback to direct method if needed
    echo "System version: $(uname -r)"
fi

# Example 2: Multi-line response processing
# Get detailed system information
if aira_ipc_call system info; then
    echo "System information:"
    # Process each line of the response
    printf "%s\n" "$_AIRA_IPC_RESPONSE" | while IFS= read -r line; do
        echo "  $line"
    done
else
    echo "Failed to get system info: $_AIRA_IPC_ERROR"
    # Fallback
    echo "System information:"
    uname -a
fi

# Example 3: Check availability before making calls
if aira_ipc_available; then
    echo "IPC bus is available, using it for system info"
    # ... make IPC calls as shown above
else
    echo "IPC bus not available, falling back to direct system reads"
    # Use direct /proc/sys reads
fi

# Example 4: Emitting events (for applications that need to notify others)
# Emit a custom event when something significant happens
# aira_ipc_emit "myapp/event" "important thing happened"

# Example 5: Getting a list of services
# Discover what services are available on the bus
if aira_ipc_list_services; then
    echo "Available IPC services:"
    printf "%s\n" "$_AIRA_IPC_RESPONSE" | while IFS= read -r service; do
        echo "  $service"
    done
fi

# Clean up is automatic - no subprocesses to manage
exit 0