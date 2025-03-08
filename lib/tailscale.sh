#!/bin/bash
# Tailscale related functions

# Declare associative array for storing Tailscale IPs
declare -A CONTAINER_IPS

# Function to check if a container has Tailscale installed and running
check_tailscale() {
  local container=$1
  
  # Check if tailscale is installed
  if lxc-attach -n "$container" -- which tailscale >/dev/null 2>&1; then
    # Check if tailscale daemon is running
    if lxc-attach -n "$container" -- pgrep tailscaled >/dev/null 2>&1; then
      # Check if tailscale is connected to the network
      if lxc-attach -n "$container" -- tailscale status >/dev/null 2>&1; then
        # Get the Tailscale IP and store it
        local ts_ip=$(lxc-attach -n "$container" -- tailscale ip -4 2>/dev/null)
        if [ ! -z "$ts_ip" ]; then
          CONTAINER_IPS[$container]="$ts_ip"
        fi
        return 0
      else
        # Tailscale is installed but not connected
        log_message "Container $container has Tailscale but it's not connected"
        return 1
      fi
    else
      # tailscaled is not running
      log_message "Container $container has Tailscale but tailscaled is not running"
      return 1
    fi
  else
    # Tailscale is not installed
    log_message "Container $container doesn't have Tailscale installed"
    return 1
  fi
}

# Function to install Tailscale on all containers that need it
install_tailscale_containers() {
  local containers=("${CONTAINERS_NO_TAILSCALE_LIST[@]}")
  local count=${#containers[@]}
  
  if [ $count -eq 0 ]; then
    echo -e "${YELLOW}No containers found that need Tailscale installed.${NC}"
    return
  fi
  
  header "INSTALLING TAILSCALE"
  echo -e "Installing Tailscale on $count containers...\n"
  
  for container in "${containers[@]}"; do
    install_tailscale_on_container "$container"
  done
  
  echo -e "\n${GREEN}Tailscale installation completed.${NC}"
}

# Function to install Tailscale on a specific container
install_tailscale_on_container() {
  local container="$1"
  echo -e "${BLUE}Installing Tailscale on container: ${BOLD}${container}${NC}"
  
  # Log the operation
  log_message "Installing Tailscale on container $container"
  
  # Check if Tailscale is already installed
  if lxc-attach -n "$container" -- which tailscale >/dev/null 2>&1; then
    echo -e "${YELLOW}Tailscale is already installed on $container.${NC}"
    return 0
  fi
  
  # Update package lists
  echo -e "${BLUE}Updating package lists...${NC}"
  lxc-attach -n "$container" -- apt-get update -q >/dev/null 2>&1
  
  # Install curl if not already installed
  if ! lxc-attach -n "$container" -- which curl >/dev/null 2>&1; then
    echo -e "${BLUE}Installing curl...${NC}"
    lxc-attach -n "$container" -- apt-get install -y curl >/dev/null 2>&1
  fi
  
  # Install Tailscale
  echo -e "${BLUE}Installing Tailscale...${NC}"
  lxc-attach -n "$container" -- bash -c "curl -fsSL https://tailscale.com/install.sh | sh" >/dev/null 2>&1
  
  # Check if installation was successful
  if ! lxc-attach -n "$container" -- which tailscale >/dev/null 2>&1; then
    echo -e "${RED}Failed to install Tailscale on $container.${NC}"
    log_message "Failed to install Tailscale on $container"
    return 1
  fi
  
  # Start Tailscale and authenticate
  echo -e "${GREEN}Tailscale installed successfully on $container.${NC}"
  echo -e "${YELLOW}You need to authenticate Tailscale. Run this command to get an auth link:${NC}"
  echo -e "${CYAN}lxc-attach -n $container -- tailscale up${NC}"
  
  # Ask if user wants to authenticate now
  echo -e "${YELLOW}Do you want to authenticate Tailscale now? (y/n)${NC}"
  read -p "> " auth_now
  
  if [[ "$auth_now" == "y" || "$auth_now" == "Y" ]]; then
    echo -e "${GREEN}Running 'tailscale up' command. Follow the instructions to authenticate.${NC}"
    lxc-attach -n "$container" -- tailscale up
    
    # Check if Tailscale is now connected
    if check_tailscale "$container"; then
      echo -e "${GREEN}Tailscale authenticated successfully!${NC}"
      
      # Add container to tailscale list and remove from no_tailscale list
      CONTAINERS_TAILSCALE_LIST+=("$container")
      CONTAINERS_WITH_TAILSCALE=$((CONTAINERS_WITH_TAILSCALE + 1))
      
      # Remove from no tailscale list
      local new_no_tailscale_list=()
      for c in "${CONTAINERS_NO_TAILSCALE_LIST[@]}"; do
        if [ "$c" != "$container" ]; then
          new_no_tailscale_list+=("$c")
        fi
      done
      CONTAINERS_NO_TAILSCALE_LIST=("${new_no_tailscale_list[@]}")
      CONTAINERS_MISSING_TAILSCALE=$((CONTAINERS_MISSING_TAILSCALE - 1))
    else
      echo -e "${YELLOW}Tailscale was installed but is not connected yet.${NC}"
    fi
  else
    echo -e "${YELLOW}Skipping authentication. Remember to run 'tailscale up' later.${NC}"
  fi
  
  # If we got here, the installation was successful
  log_message "Successfully installed Tailscale on container $container"
  return 0
}

# Function to install Tailscale on a specific container selected by user
install_selected_container_tailscale() {
  echo -e "${BLUE}Available containers without Tailscale:${NC}"
  
  # Show containers without Tailscale
  if [ ${#CONTAINERS_NO_TAILSCALE_LIST[@]} -eq 0 ]; then
    echo -e "${YELLOW}All containers already have Tailscale installed!${NC}"
    return
  fi
  
  local i=1
  for container in "${CONTAINERS_NO_TAILSCALE_LIST[@]}"; do
    echo "$i) $container"
    i=$((i+1))
  done
  
  echo
  echo -e "${YELLOW}Enter the number of the container to install Tailscale on, or 'q' to quit:${NC}"
  read -p "> " container_choice
  
  if [[ "$container_choice" == "q" || "$container_choice" == "Q" ]]; then
    return
  fi
  
  if [[ "$container_choice" =~ ^[0-9]+$ ]] && [ "$container_choice" -ge 1 ] && [ "$container_choice" -le ${#CONTAINERS_NO_TAILSCALE_LIST[@]} ]; then
    selected_container="${CONTAINERS_NO_TAILSCALE_LIST[$((container_choice-1))]}"
    install_tailscale_on_container "$selected_container"
  else
    echo -e "${RED}Invalid choice.${NC}"
  fi
}

# Function to check Tailscale connectivity in container
check_tailscale_connectivity() {
  local container="$1"
  
  # First check if Tailscale is installed and running
  if ! check_tailscale "$container"; then
    return 1
  fi
  
  # Get Tailscale IP of another node to ping (if available)
  local target_ip=""
  for other_container in "${CONTAINERS_TAILSCALE_LIST[@]}"; do
    if [[ "$other_container" != "$container" ]]; then
      target_ip="${CONTAINER_IPS[$other_container]}"
      if [ ! -z "$target_ip" ]; then
        break
      fi
    fi
  done
  
  # If no other container with Tailscale found, try pinging Tailscale's MagicDNS test domain
  if [ -z "$target_ip" ]; then
    if lxc-attach -n "$container" -- ping -c 1 -W 2 100.100.100.100 >/dev/null 2>&1; then
      return 0
    else
      return 1
    fi
  else
    # Ping the other Tailscale node
    if lxc-attach -n "$container" -- ping -c 1 -W 2 "$target_ip" >/dev/null 2>&1; then
      return 0
    else
      return 1
    fi
  fi
}

# Function to get Tailscale network details
get_tailscale_info() {
  local container="$1"
  local info=""
  
  # Check if Tailscale is installed and connected
  if ! check_tailscale "$container"; then
    echo "Tailscale not installed or not running"
    return 1
  fi
  
  # Get Tailscale IP
  local ts_ip="${CONTAINER_IPS[$container]}"
  if [ ! -z "$ts_ip" ]; then
    info+="Tailscale IP: $ts_ip\n"
  fi
  
  # Get hostname in Tailscale network
  local ts_hostname=$(lxc-attach -n "$container" -- tailscale status --self 2>/dev/null | grep -o '[^ ]*\.ts\.net')
  if [ ! -z "$ts_hostname" ]; then
    info+="Tailscale Hostname: $ts_hostname\n"
  fi
  
  # Check Tailscale connectivity
  if check_tailscale_connectivity "$container"; then
    info+="Tailscale Network: ✅\n"
  else
    info+="Tailscale Network: ❌\n"
  fi
  
  echo -e "$info"
}
