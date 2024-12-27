#!/bin/bash

# Default values
CHECK_INTERVAL=5  # Seconds between checks
DIRS=()
RELOAD_COMMAND=""
MODE="any"  # can be "any" or "all"

# Function to print usage
usage() {
    echo "Usage: $0 -d <directory1> [-d <directory2> ...] -c <reload_command> [-i <check_interval>] [-m <mode>]"
    echo "  -d: Directory to monitor (can be specified multiple times)"
    echo "  -c: Command to execute when directory/directories disappear"
    echo "  -i: Check interval in seconds (default: 5)"
    echo "  -m: Trigger mode: 'any' (default) or 'all'"
    echo "      'any': Execute when any monitored directory disappears"
    echo "      'all': Execute when all monitored directories disappear"
    exit 1
}

# Parse command line arguments
while getopts "d:c:i:m:h" opt; do
    case $opt in
        d) DIRS+=("$OPTARG") ;;
        c) RELOAD_COMMAND="$OPTARG" ;;
        i) CHECK_INTERVAL="$OPTARG" ;;
        m) MODE="$OPTARG" ;;
        h) usage ;;
        *) usage ;;
    esac
done

# Validate required parameters
if [ ${#DIRS[@]} -eq 0 ] || [ -z "$RELOAD_COMMAND" ]; then
    echo "Error: At least one directory and reload command are required"
    usage
fi

# Validate mode
if [ "$MODE" != "any" ] && [ "$MODE" != "all" ]; then
    echo "Error: Mode must be either 'any' or 'all'"
    usage
fi

# Validate directories exist at start
for dir in "${DIRS[@]}"; do
    if [ ! -d "$dir" ]; then
        echo "Error: Directory $dir does not exist"
        exit 1
    fi
done

# Print monitoring configuration
echo "Starting directory monitor with mode: $MODE"
echo "Directories being monitored:"
printf '%s\n' "${DIRS[@]}" | sed 's/^/  /'
echo "Will execute: $RELOAD_COMMAND"
echo "Checking every $CHECK_INTERVAL seconds"

# Function to check directory status
check_directories() {
    local missing=0
    local total=${#DIRS[@]}
    local missing_dirs=()

    for dir in "${DIRS[@]}"; do
        if [ ! -d "$dir" ]; then
            ((missing++))
            missing_dirs+=("$dir")
        fi
    done

    if [ "$MODE" = "any" ] && [ $missing -gt 0 ]; then
        echo "The following directories have disappeared at $(date):"
        printf '%s\n' "${missing_dirs[@]}" | sed 's/^/  /'
        return 0
    elif [ "$MODE" = "all" ] && [ $missing -eq $total ]; then
        echo "All monitored directories have disappeared at $(date)"
        return 0
    fi
    return 1
}

# Main monitoring loop
while true; do
    if check_directories; then
        echo "Executing reload command: $RELOAD_COMMAND"
        eval "$RELOAD_COMMAND"
        exit 0
    fi
    sleep "$CHECK_INTERVAL"
done


