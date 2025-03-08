#!/bin/bash
# Container-related functions

# Function to get list of running LXC containers
get_running_containers() {
  lxc-ls -1 --running
}

# Function to check container connectivity
check_container_connectivity() {
  local container="$1"
  
  if lxc-attach -n "$container" -- ping -c 1 -W 2 1.1.1.1 >/dev/null 2>&1; then
    return 0
  else
    return 1
  fi
}

# Function to check container DNS resolution
check_container_dns() {
  local container="$1"
  
  if lxc-attach -n "$container" -- ping -c 1 -W 2 google.com >/dev/null 2>&1; then
    return 0
  else
    return 1
  fi
}

# Function to get container network information
get_container_network_info() {
  local container="$1"
  local info=""
  
  # Get container IP addresses
  local ip_info=$(lxc-attach -n "$container" -- ip -4 -o addr show scope global | awk '{print $4}' | cut -d/ -f1)
  if [ ! -z "$ip_info" ]; then
    info+="IP: $ip_info\n"
  fi
  
  # Check internet connectivity
  if check_container_connectivity "$container"; then
    info+="Internet: ✅\n"
  else
    info+="Internet: ❌\n"
  fi
  
  # Check DNS resolution
  if check_container_dns "$container"; then
    info+="DNS: ✅\n"
  else
    info+="DNS: ❌\n"
  fi
  
  echo -e "$info"
}
