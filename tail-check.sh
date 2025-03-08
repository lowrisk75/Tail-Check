#!/bin/bash

# Import library scripts
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$DIR/lib/ui.sh"
source "$DIR/lib/containers.sh"
source "$DIR/lib/services.sh"
source "$DIR/lib/tailscale.sh"
source "$DIR/lib/serve.sh"

# Verbose mode flag
VERBOSE=0

# Function to log messages
log_message() {
  local message="$1"
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $message" >> tailscale_setup.log
  if [ $VERBOSE -eq 1 ]; then
    echo -e "${YELLOW}[LOG] $message${NC}"
  fi
}

# Initialize arrays
declare -A CONTAINER_SERVICES
declare -A CONTAINER_PORTS
declare -A CONTAINER_IPS
declare -A CONTAINER_DOMAINS
declare -A CONTAINER_SERVICE_NAMES

# Initialize lists
CONTAINERS_TAILSCALE_LIST=()
CONTAINERS_NO_TAILSCALE_LIST=()
CONTAINERS_SERVE_LIST=()
CONTAINERS_NO_SERVE_LIST=()
CONTAINERS_SERVICE_LIST=()

# Initialize counters
CONTAINERS_TOTAL=0
CONTAINERS_WITH_TAILSCALE=0
CONTAINERS_MISSING_TAILSCALE=0
CONTAINERS_WITH_SERVE=0

# Create log file if it doesn't exist
touch tailscale_setup.log

# Function to scan all containers
scan_containers() {
  header "SCANNING PROXMOX CONTAINERS"
  
  # Reset arrays and counters
  CONTAINERS_TAILSCALE_LIST=()
  CONTAINERS_NO_TAILSCALE_LIST=()
  CONTAINERS_SERVE_LIST=()
  CONTAINERS_NO_SERVE_LIST=()
  CONTAINERS_SERVICE_LIST=()
  CONTAINERS_WITH_TAILSCALE=0
  CONTAINERS_MISSING_TAILSCALE=0
  CONTAINERS_WITH_SERVE=0
  
  # Get list of running containers
  local containers=($(get_running_containers))
  CONTAINERS_TOTAL=${#containers[@]}
  
  if [ $CONTAINERS_TOTAL -eq 0 ]; then
    echo -e "${RED}No running containers found!${NC}"
    return 1
  fi
  
  echo -e "${GREEN}Found ${BOLD}$CONTAINERS_TOTAL${NC} ${GREEN}running containers${NC}"
  
  local current=0
  for container in "${containers[@]}"; do
    current=$((current + 1))
    show_progress $current $CONTAINERS_TOTAL "Scanning container: $container"
    
    # Check for tailscale
    if check_tailscale "$container"; then
      CONTAINERS_TAILSCALE_LIST+=("$container")
      CONTAINERS_WITH_TAILSCALE=$((CONTAINERS_WITH_TAILSCALE + 1))
      
      # Check for tailscale serve
      check_tailscale_serve "$container"
    else
      CONTAINERS_NO_TAILSCALE_LIST+=("$container")
      CONTAINERS_MISSING_TAILSCALE=$((CONTAINERS_MISSING_TAILSCALE + 1))
    fi
    
    # Check for services
    if check_services "$container"; then
      CONTAINERS_SERVICE_LIST+=("$container")
    fi
    
    sleep 0.1
  done
  
  complete_progress
  echo -e "${GREEN}Scan complete! Found ${BOLD}$CONTAINERS_WITH_TAILSCALE${NC} ${GREEN}containers with Tailscale and ${BOLD}${CONTAINERS_WITH_SERVE}${NC} ${GREEN}using Tailscale Serve${NC}"
  
  # Show quick summary after scan
  show_quick_summary
}

# Function to show a quick summary of containers
show_quick_summary() {
  echo 
  echo -e "${BOLD}Quick Container Summary:${NC}"
  echo -e "-----------------------------------------------------------"
  echo -e "${BOLD}LXC ID   | Status       | Service                 | Ports${NC}"
  echo -e "-----------------------------------------------------------"
  
  # Get list of running containers
  local containers=($(get_running_containers))
  
  for container in "${containers[@]}"; do
    local status="${RED}✗ No Tailscale${NC}"
    
    if [[ " ${CONTAINERS_TAILSCALE_LIST[*]} " =~ " ${container} " ]]; then
      if [[ " ${CONTAINERS_SERVE_LIST[*]} " =~ " ${container} " ]]; then
        status="${GREEN}✓ TS + Serve${NC}"
      else
        status="${BLUE}✓ Tailscale${NC}"
      fi
    fi
    
    local service_name="None detected"
    local port_count=0
    
    if [[ ! -z "${CONTAINER_SERVICES[$container]}" ]]; then
      # Count number of services
      local service_count=$(echo "${CONTAINER_SERVICES[$container]}" | tr ',' '\n' | wc -l)
      if [ $service_count -gt 1 ]; then
        service_name="Multiple ($service_count)"
      else
        service_name="${CONTAINER_SERVICE_NAMES[$container]:-${CONTAINER_SERVICES[$container]}}"
      fi
    fi
    
    if [[ ! -z "${CONTAINER_PORTS[$container]}" ]]; then
      port_count=$(echo "${CONTAINER_PORTS[$container]}" | tr ',' '\n' | wc -l)
    fi
    
    # Pad container ID
    printf "${BOLD}%-8s${NC} | %-12s | %-23s | %s\n" \
      "$container" \
      "$status" \
      "$service_name" \
      "$port_count ports"
  done
  echo -e "-----------------------------------------------------------"
}

# Function to show detailed container info
show_detailed_info() {
  header "DETAILED CONTAINER INFORMATION"
  
  if [ $CONTAINERS_TOTAL -eq 0 ]; then
    echo -e "${RED}No containers scanned yet. Run scan first.${NC}"
    sleep 2
    return
  fi
  
  # Get list of running containers
  local containers=($(get_running_containers))
  
  for container in "${containers[@]}"; do
    echo -e "\n${BOLD}${BLUE}Container: $container${NC}"
    echo -e "${YELLOW}$(printf '=%.0s' {1..50})${NC}"
    
    # Tailscale status
    if [[ " ${CONTAINERS_TAILSCALE_LIST[*]} " =~ " ${container} " ]]; then
      echo -e "${GREEN}✓ Tailscale installed${NC}"
      
      # Tailscale IP
      if [[ ! -z "${CONTAINER_IPS[$container]}" ]]; then
        echo -e "  - Tailscale IP: ${BOLD}${CONTAINER_IPS[$container]}${NC}"
      fi
      
      # Tailscale Serve status
      if [[ " ${CONTAINERS_SERVE_LIST[*]} " =~ " ${container} " ]]; then
        echo -e "  - ${GREEN}✓ Tailscale Serve configured${NC}"
        if [[ ! -z "${CONTAINER_DOMAINS[$container]}" ]]; then
          echo -e "  - Domain: ${BOLD}https://${CONTAINER_DOMAINS[$container]}${NC}"
        fi
      else
        echo -e "  - ${RED}✗ Tailscale Serve not configured${NC}"
      fi
    else
      echo -e "${RED}✗ Tailscale not installed${NC}"
    fi
    
    # Services information
    if [[ ! -z "${CONTAINER_SERVICES[$container]}" ]]; then
      echo -e "\n${BOLD}Services:${NC}"
      IFS=',' read -ra services <<< "${CONTAINER_SERVICES[$container]}"
      IFS=',' read -ra ports <<< "${CONTAINER_PORTS[$container]}"
      
      for ((i=0; i<${#services[@]}; i++)); do
        local service="${services[$i]}"
        local port="${ports[$i]}"
        echo -e "  - ${BLUE}${service}${NC} (port ${BOLD}${port}${NC})"
      done
    else
      echo -e "\n${RED}No services detected${NC}"
    fi
  done
}

# Function to generate homepage dashboard config
generate_homepage_config() {
  header "GENERATING HOMEPAGE DASHBOARD CONFIG"
  
  if [ $CONTAINERS_TOTAL -eq 0 ]; then
    echo -e "${RED}No containers scanned yet. Run scan first.${NC}"
    sleep 2
    return
  fi
  
  local config_file="homepage_config.yaml"
  
  echo -e "${BLUE}Creating homepage dashboard config at ${BOLD}$config_file${NC}"
  
  # Create the file with header
  cat > "$config_file" << YAML
---
# Homepage Dashboard Configuration
# Generated by Tailscale Container Checker

services:
  - name: "Tailscale Services"
    icon: "tailscale"
    items:
YAML
  
  # Add each container with Tailscale Serve
  for container in "${CONTAINERS_SERVE_LIST[@]}"; do
    if [[ ! -z "${CONTAINER_DOMAINS[$container]}" ]]; then
      local service_name="${CONTAINER_SERVICE_NAMES[$container]:-$container}"
      cat >> "$config_file" << YAML
      - name: "$service_name"
        icon: "tailscale"
        url: "https://${CONTAINER_DOMAINS[$container]}"
        subtitle: "Container $container"
YAML
    fi
  done
  
  echo -e "${GREEN}Homepage config generated successfully at ${BOLD}$config_file${NC}"
  log_message "Generated Homepage dashboard config file at $config_file"
  
  # Show a preview
  echo -e "\n${BOLD}Config file preview:${NC}"
  echo -e "${YELLOW}$(printf '=%.0s' {1..50})${NC}"
  cat "$config_file"
  echo -e "${YELLOW}$(printf '=%.0s' {1..50})${NC}"
  
  echo -e "\nYou can use this configuration with Homepage dashboard: https://gethomepage.dev/"
}

# Function to show summary
show_summary() {
  header "CONTAINER SUMMARY"
  
  if [ $CONTAINERS_TOTAL -eq 0 ]; then
    echo -e "${RED}No containers scanned yet. Run scan first.${NC}"
    sleep 2
    return
  fi
  
  echo -e "${BOLD}Container Tailscale Status:${NC}"
  echo -e "  Total containers: ${BOLD}$CONTAINERS_TOTAL${NC}"
  echo -e "  With Tailscale: ${GREEN}$CONTAINERS_WITH_TAILSCALE${NC}"
  echo -e "  Without Tailscale: ${RED}$CONTAINERS_MISSING_TAILSCALE${NC}"
  echo -e "  Using Tailscale Serve: ${GREEN}${CONTAINERS_WITH_SERVE}${NC}"
  
  echo -e "\n${BOLD}Containers With Tailscale (${#CONTAINERS_TAILSCALE_LIST[@]}):${NC}"
  for container in "${CONTAINERS_TAILSCALE_LIST[@]}"; do
    local serve_status=""
    if [[ " ${CONTAINERS_SERVE_LIST[*]} " =~ " ${container} " ]]; then
      serve_status="${GREEN}[Serve]${NC}"
    fi
    echo -e "  - ${BOLD}$container${NC} $serve_status"
  done
  
  if [ ${#CONTAINERS_NO_TAILSCALE_LIST[@]} -gt 0 ]; then
    echo -e "\n${BOLD}Containers Without Tailscale (${#CONTAINERS_NO_TAILSCALE_LIST[@]}):${NC}"
    for container in "${CONTAINERS_NO_TAILSCALE_LIST[@]}"; do
      echo -e "  - ${BOLD}$container${NC}"
    done
  else
    echo -e "\n${GREEN}All containers have Tailscale installed! 👍${NC}"
  fi
  
  echo -e "\n${BOLD}Containers With Services:${NC}"
  for container in "${CONTAINERS_SERVICE_LIST[@]}"; do
    if [[ ! -z "${CONTAINER_SERVICES[$container]}" ]]; then
      echo -e "  - ${BOLD}$container${NC}: ${CONTAINER_SERVICES[$container]}"
    fi
  done
}

# Function to show the main menu
show_menu() {
  clear
  header "TAILSCALE CONTAINER CHECKER"
  echo -e "${BOLD}Select an option:${NC}"
  echo
  echo -e "1) ${BLUE}Scan containers${NC} (find Tailscale and services)"
  
  if [ $CONTAINERS_TOTAL -gt 0 ]; then
    echo -e "2) ${BLUE}Show summary report${NC}"
    echo -e "3) ${BLUE}Show detailed container information${NC}"
    
    if [ $CONTAINERS_MISSING_TAILSCALE -gt 0 ]; then
      echo -e "4) ${BLUE}Install Tailscale${NC} on all containers ($CONTAINERS_MISSING_TAILSCALE needed)"
      echo -e "5) ${BLUE}Install Tailscale${NC} on selected container"
    fi
    
    if [ ${#CONTAINERS_TAILSCALE_LIST[@]} -gt 0 ]; then
      echo -e "6) ${BLUE}Configure Tailscale Serve${NC} on all containers with services"
      echo -e "7) ${BLUE}Configure Tailscale Serve${NC} on selected container"
    fi
    
    if [ ${#CONTAINERS_SERVE_LIST[@]} -gt 0 ]; then
      echo -e "8) ${BLUE}Generate homepage dashboard config${NC}"
    fi
  fi
  
  echo -e "v) ${BLUE}Toggle verbose mode${NC} (currently $([ $VERBOSE -eq 1 ] && echo -e "${GREEN}ON${NC}" || echo -e "${RED}OFF${NC}"))"
  echo -e "q) ${RED}Quit${NC}"
  echo
  
  if [ $CONTAINERS_TOTAL -gt 0 ]; then
    echo -e "${BOLD}Status:${NC}"
    echo -e "  Total containers: ${BOLD}$CONTAINERS_TOTAL${NC}"
    echo -e "  With Tailscale: ${BLUE}$CONTAINERS_WITH_TAILSCALE${NC} / Without: ${YELLOW}$CONTAINERS_MISSING_TAILSCALE${NC}"
    echo -e "  Using Tailscale Serve: ${BLUE}${CONTAINERS_WITH_SERVE}${NC}"
  fi
  
  show_social_links
  
  echo -e "${YELLOW}Enter your choice:${NC}"
  read -p "> " menu_choice
  
  case $menu_choice in
    1)
      scan_containers
      ;;
    2)
      if [ $CONTAINERS_TOTAL -gt 0 ]; then
        show_summary
      else
        echo -e "${RED}No containers scanned yet. Run scan first.${NC}"
        sleep 2
      fi
      ;;
    3)
      if [ $CONTAINERS_TOTAL -gt 0 ]; then
        show_detailed_info
      else
        echo -e "${RED}No containers scanned yet. Run scan first.${NC}"
        sleep 2
      fi
      ;;
    4|5)
      if [ $CONTAINERS_MISSING_TAILSCALE -gt 0 ]; then
        if [ "$menu_choice" -eq 4 ]; then
          install_tailscale_containers
        else
          install_selected_container_tailscale
        fi
      else
        echo -e "${YELLOW}All containers already have Tailscale installed.${NC}"
        sleep 2
      fi
      ;;
    6|7)
      if [ ${#CONTAINERS_TAILSCALE_LIST[@]} -gt 0 ]; then
        if [ "$menu_choice" -eq 6 ]; then
          configure_missing_serve
        else
          configure_selected_container_serve
        fi
      else
        echo -e "${YELLOW}No containers with Tailscale available.${NC}"
        sleep 2
      fi
      ;;
    8)
      if [ ${#CONTAINERS_SERVE_LIST[@]} -gt 0 ]; then
        generate_homepage_config
      else
        echo -e "${YELLOW}No containers using Tailscale Serve available.${NC}"
        sleep 2
      fi
      ;;
    v|V)
      VERBOSE=$((1-VERBOSE))
      echo -e "Verbose mode $([ $VERBOSE -eq 1 ] && echo -e "${GREEN}enabled${NC}" || echo -e "${RED}disabled${NC}")"
      sleep 1
      ;;
    q|Q)
      echo -e "${GREEN}Thank you for using the Tailscale Container Checker!${NC}"
      exit 0
      ;;
    *)
      echo -e "${RED}Invalid choice!${NC}"
      sleep 1
      ;;
  esac
}

# Handle CTRL+C gracefully
trap "echo -e '\n${YELLOW}Script interrupted by user!${NC}'; exit 0" SIGINT

# Main program loop
while true; do
  show_menu
  echo
  echo -e "${YELLOW}Press Enter to continue...${NC}"
  read
done
