#!/bin/sh
# aira-ipc.sh — Shared IPC client library for AiraOS applications
# Provides functions for making IPC bus calls without spawning subprocesses
# Designed to be sourced by applications: . /usr/lib/aira-ipc.sh

# Configuration (can be overridden by environment)
AIRA_IPC_HOST="${AIRA_IPC_HOST:-127.0.0.1}"
AIRA_IPC_PORT="${AIRA_IPC_PORT:-41234}"
AIRA_IPC_TIMEOUT="${AIRA_IPC_TIMEOUT:-5}"
AIRA_IPC_RUN_DIR="${AIRA_IPC_RUN_DIR:-/run/aira-ipc}"
# Result vars (pre-initialised so `set -u` consumers never see unbound vars)
_AIRA_IPC_RESPONSE="${_AIRA_IPC_RESPONSE:-}"
_AIRA_IPC_ERROR="${_AIRA_IPC_ERROR:-}"
_AIRA_IPC_RESPONSE_FIRST="${_AIRA_IPC_RESPONSE_FIRST:-}"

# Internal function: Get sender identifier in format "uid:username"
_aira_ipc_sender() {
    printf "%s:%s" "$(id -u 2>/dev/null || echo ?)" "$(id -un 2>/dev/null || echo ?)"
}

# Internal function: Get authentication string (root token if available and running as root)
_aira_ipc_auth() {
    if [ "$(id -u 2>/dev/null)" = "0" ] && [ -f "${AIRA_IPC_RUN_DIR}/root.token" ]; then
        printf "root:%s" "$(cat "${AIRA_IPC_RUN_DIR}/root.token" 2>/dev/null)"
    else
        printf "none"
    fi
}

# Internal function: Validate service/method names (must match bus rules)
# Returns 0 if valid, 1 otherwise. Prevents '|' / newline injection.
_aira_ipc_valid_name() {
    case "$1" in
        ""|*[!a-z0-9_-]*) return 1 ;;
    esac
    case "$1" in [a-z]*) return 0 ;; *) return 1 ;; esac
}

# Internal function: Make raw IPC call via netcat
# Returns: 0 on success with payload in _AIRA_IPC_RESPONSE, 1 on failure
# Usage: _aira_ipc_raw_call <service> <method> <args> <timeout>
_aira_ipc_raw_call() {
    local service="$1" method="$2" args="$3" timeout="$4"
    local _id _req _resp _rc _ver _rid _st _pay

    _aira_ipc_valid_name "$service" || { _AIRA_IPC_ERROR="bad service name: $service"; return 1; }
    _aira_ipc_valid_name "$method" || { _AIRA_IPC_ERROR="bad method name: $method"; return 1; }
    case "$timeout" in ''|*[!0-9]*) timeout="$AIRA_IPC_TIMEOUT" ;; esac

    # Unique request id within 32-char bus limit: pid + time + random
    _id="c$$-$(date +%s 2>/dev/null || echo 0)-${RANDOM:-0}"
    _id="$(printf "%s" "$_id" | cut -c1-32)"
    _req="AIRA1|$_id|$(_aira_ipc_sender)|$service|$method|$(_aira_ipc_auth)|$args"

    # Make the actual network call
    if command -v timeout >/dev/null 2>&1; then
        _resp="$(printf "%s\n" "$_req" | timeout "$timeout" nc -w "$timeout" "$AIRA_IPC_HOST" "$AIRA_IPC_PORT" 2>&1)"
        _rc="$?"
    else
        _resp="$(printf "%s\n" "$_req" | nc -w "$timeout" "$AIRA_IPC_HOST" "$AIRA_IPC_PORT" 2>&1)"
        _rc="$?"
    fi

    if [ "$_rc" != "0" ]; then
        # Bus unreachable
        return 1
    fi

    # Parse response
    _ver="$(printf "%s" "$_resp" | cut -d'|' -f1)"
    _rid="$(printf "%s" "$_resp" | cut -d'|' -f2)"
    _st="$(printf "%s" "$_resp" | cut -d'|' -f3)"
    _pay="$(printf "%s" "$_resp" | cut -d'|' -f4-)"

    [ "$_ver" = "AIRA1" ] || { return 1; }  # Bad version
    [ "$_rid" = "$_id" ] || { return 1; }   # ID mismatch

    if [ "$_st" = "OK" ]; then
        # Convert semicolon-separated lines back to newlines for easier processing
        _AIRA_IPC_RESPONSE="$(printf "%s\n" "$_pay" | tr ';' '\n')"
        return 0
    else
        # Error response
        _AIRA_IPC_ERROR="$_pay"
        return 1
    fi
}

# Public function: Make an IPC call and return the response
# Usage: aira_ipc_call <service> <method> [args...]
# Returns: 0 on success, 1 on failure
# On success: Response available in _AIRA_IPC_RESPONSE (newline-separated lines)
# On failure: Error message in _AIRA_IPC_ERROR
aira_ipc_call() {
    local service="$1" method="$2"
    shift 2
    local args="$*"

    # Reset return variables
    _AIRA_IPC_RESPONSE=""
    _AIRA_IPC_ERROR=""

    if _aira_ipc_raw_call "$service" "$method" "$args" "$AIRA_IPC_TIMEOUT"; then
        return 0
    else
        return 1
    fi
}

# Public function: Make an IPC call and return first line of response
# Usage: aira_ipc_call_first <service> <method> [args...]
# Returns: 0 on success, 1 on failure
# On success: First line of response in _AIRA_IPC_RESPONSE_FIRST
# On failure: Error message in _AIRA_IPC_ERROR
aira_ipc_call_first() {
    aira_ipc_call "$@" || return 1
    _AIRA_IPC_RESPONSE_FIRST="$(printf "%s\n" "$_AIRA_IPC_RESPONSE" | head -n 1)"
    return 0
}

# Public function: Emit an event on the IPC bus
# Usage: aira_ipc_emit <topic> <message>
# Returns: 0 on success, 1 on failure
aira_ipc_emit() {
    local topic="$1" message="$2"

    # Reset return variables
    _AIRA_IPC_RESPONSE=""
    _AIRA_IPC_ERROR=""

    if _aira_ipc_raw_call bus emit "$topic $message" "$AIRA_IPC_TIMEOUT"; then
        return 0
    else
        return 1
    fi
}

# Public function: List available IPC services
# Usage: aira_ipc_list_services
# Returns: 0 on success, 1 on failure
# On success: Service list in _AIRA_IPC_RESPONSE (newline-separated)
aira_ipc_list_services() {
    # Reset return variables
    _AIRA_IPC_RESPONSE=""
    _AIRA_IPC_ERROR=""

    if _aira_ipc_raw_call bus services "" "$AIRA_IPC_TIMEOUT"; then
        return 0
    else
        return 1
    fi
}

# Public function: Ping the IPC bus
# Usage: aira_ipc_ping [message]
# Returns: 0 on success, 1 on failure
# On success: Response in _AIRA_IPC_RESPONSE
aira_ipc_ping() {
    local message="${1:-hello}"

    # Reset return variables
    _AIRA_IPC_RESPONSE=""
    _AIRA_IPC_ERROR=""

    if _aira_ipc_raw_call bus ping "$message" "$AIRA_IPC_TIMEOUT"; then
        return 0
    else
        return 1
    fi
}

# Public function: Check whether a service exists on the bus
# Usage: aira_ipc_has_service <service>
# Returns: 0 if present, 1 if absent/unreachable
aira_ipc_has_service() {
    local _svc="$1" _s
    _AIRA_IPC_ERROR=""
    aira_ipc_list_services >/dev/null 2>&1 || return 1
    for _s in $_AIRA_IPC_RESPONSE; do
        [ "$_s" = "$_svc" ] && return 0
    done
    _AIRA_IPC_ERROR="unknown service: $_svc"
    return 1
}

# Public function: Print response payload to stdout (for command substitution)
# Usage: aira_ipc_print
aira_ipc_print() {
    printf "%s\n" "$_AIRA_IPC_RESPONSE"
}

# Public function: Check if IPC bus is available
# Usage: aira_ipc_available
# Returns: 0 if available, 1 if not
aira_ipc_available() {
    aira_ipc_ping "availability-check" >/dev/null 2>&1
}

# Make library idempotent-safe
return 0 2>/dev/null || true