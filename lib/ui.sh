#!/bin/bash

# Colors for better output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m' # No Color
BG_BLUE='\033[44m'
BG_GREEN='\033[42m'

# Function for drawing boxes
draw_box() {
  local width=$1
  local title="$2"
  local color="$3"
  local padding=$(( (width - ${#title}) / 2 ))
  
  echo -e "${color}${BOLD}"
  printf '╔═%s═╗\n' "$(printf '═%.0s' $(seq 1 $((width-4))))"
  printf '║ %*s%s%*s ║\n' $padding "" "$title" $((padding - ${#title} % 2))
  printf '╚═%s═╝\n' "$(printf '═%.0s' $(seq 1 $((width-4))))"
  echo -e "${NC}"
}

# Function to display social media links
show_social_links() {
  echo
  echo -e "${YELLOW}YouTube: ${GREEN}https://www.youtube.com/@connectedsecure${NC}"
  echo -e "${YELLOW}Follow on X: ${GREEN}https://x.com/SecureConnected${NC}"
  echo
}

# Function to display a centered header
header() {
  local text="$1"
  local width=70
  local padding=$(( (width - ${#text}) / 2 ))
  
  echo
  echo -e "${BG_BLUE}${BOLD}$(printf '%*s' $width "")${NC}"
  echo -e "${BG_BLUE}${BOLD}$(printf '%*s%s%*s' $padding "" "$text" $((padding - ${#text} % 2)) "")${NC}"
  echo -e "${BG_BLUE}${BOLD}$(printf '%*s' $width "")${NC}"
  echo
}

# Function to display a progress bar
progress_bar() {
  local current=$1
  local total=$2
  local width=50
  local percentage=$((current * 100 / total))
  local completed=$((width * current / total))
  
  printf "${BOLD}[${GREEN}"
  printf '▓%.0s' $(seq 1 $completed)
  printf "${NC}${BOLD}"
  printf '░%.0s' $(seq $((completed + 1)) $width)
  printf "${BOLD}] %3d%%${NC} (%d/%d)\n" $percentage $current $total
}

# Function to show the summary of the scan
show_summary() {
  header "SUMMARY REPORT"
  
  echo -e "Total Containers: ${BOLD}${CONTAINERS_TOTAL}${NC}"
  echo
  
  # Show containers with Tailscale Serve first
  if [ ${#CONTAINERS_SERVE_LIST[@]} -gt 0 ]; then
    draw_box 70 "SERVICES WITH TAILSCALE SERVE" "${GREEN}"
    for container in "${CONTAINERS_SERVE_LIST[@]}"; do
      echo -e "${BOLD}${container}:${NC}"
      
      SERVICE_INFO="${CONTAINER_SERVICES[$container]}"
      if [ ! -z "$SERVICE_INFO" ]; then
        echo -e "  ${BLUE}• Service:${NC} $SERVICE_INFO"
      fi
      
      if [ ! -z "${CONTAINER_DOMAINS[$container]}" ]; then
        echo -e "  ${BLUE}• Domain:${NC} ${CONTAINER_DOMAINS[$container]}"
      fi
      
      echo
    done
  fi
  
  # Show services without Tailscale Serve
  if [ ${#CONTAINERS_NO_SERVE_LIST[@]} -gt 0 ]; then
    draw_box 70 "SERVICES WITHOUT TAILSCALE SERVE" "${YELLOW}"
    for container in "${CONTAINERS_NO_SERVE_LIST[@]}"; do
      echo -e "${BOLD}${container}:${NC}"
      
      SERVICE_INFO="${CONTAINER_SERVICES[$container]}"
      if [ ! -z "$SERVICE_INFO" ]; then
        echo -e "  ${BLUE}• Service:${NC} $SERVICE_INFO"
      fi
      
      PORT="${CONTAINER_PORTS[$container]}"
      if [ ! -z "$PORT" ]; then
        echo -e "  ${BLUE}• Listening on port(s):${NC} $PORT"
        
        IP="${CONTAINER_IPS[$container]}"
        if [ ! -z "$IP" ]; then
          echo -e "  ${GREEN}• Setup command:${NC}"
          echo -e "    ${CYAN}lxc-attach -n $container -- tailscale serve https://$container.fox-inconnu.ts.net:$PORT${NC}"
        else
          echo -e "  ${YELLOW}• No Tailscale IP found. Install Tailscale first.${NC}"
        fi
      else
        echo -e "  ${YELLOW}• No port information found${NC}"
      fi
      
      echo
    done
  fi
  
  # Containers without Tailscale
  if [ ${CONTAINERS_MISSING_TAILSCALE} -gt 0 ]; then
    draw_box 70 "CONTAINERS WITHOUT TAILSCALE" "${RED}"
    for container in "${CONTAINERS_NO_TAILSCALE_LIST[@]}"; do
      echo -e "${BOLD}${container}:${NC}"
      
      SERVICE_INFO="${CONTAINER_SERVICES[$container]}"
      if [ ! -z "$SERVICE_INFO" ]; then
        echo -e "  ${BLUE}• Service:${NC} $SERVICE_INFO"
      else
        echo -e "  ${YELLOW}• No services detected${NC}"
      fi
      
      # Installation commands
      echo -e "  ${GREEN}• Installation commands:${NC}"
      echo -e "    ${CYAN}lxc-attach -n $container -- apt update${NC}"
      echo -e "    ${CYAN}lxc-attach -n $container -- apt install -y curl${NC}"
      echo -e "    ${CYAN}lxc-attach -n $container -- curl -fsSL https://tailscale.com/install.sh | sh${NC}"
      echo -e "    ${CYAN}lxc-attach -n $container -- tailscale up${NC}"
      echo
    done
  fi
  
  # Human-friendly conclusion
  header "CONCLUSION"
  
  if [ ${CONTAINERS_WITH_TAILSCALE} -eq ${CONTAINERS_TOTAL} ]; then
    echo -e "✅ ${GREEN}Great! All containers have Tailscale installed.${NC}"
  else
    echo -e "⚠️ ${YELLOW}${CONTAINERS_MISSING_TAILSCALE} container(s) don't have Tailscale installed.${NC}"
    echo -e "   Consider installing Tailscale on: ${YELLOW}$(IFS=", "; echo "${CONTAINERS_NO_TAILSCALE_LIST[*]}")${NC}"
    echo -e "   Use the installation commands shown above for each container."
  fi
  
  # Check for services without Tailscale Serve
  SERVICES_WITHOUT_SERVE=0
  for container in "${CONTAINERS_SERVICE_LIST[@]}"; do
    if [[ " ${CONTAINERS_TAILSCALE_LIST[*]} " =~ " ${container} " ]] && ! [[ " ${CONTAINERS_SERVE_LIST[*]} " =~ " ${container} " ]]; then
      SERVICES_WITHOUT_SERVE=$((SERVICES_WITHOUT_SERVE + 1))
    fi
  done
  
  if [ $SERVICES_WITHOUT_SERVE -gt 0 ]; then
    echo -e "💡 ${BLUE}${SERVICES_WITHOUT_SERVE} service(s) could benefit from Tailscale Serve for HTTPS access.${NC}"
    echo -e "   See the 'SERVICES WITHOUT TAILSCALE SERVE' section for setup commands."
  elif [ ${CONTAINERS_WITH_SERVE} -eq 0 ]; then
    echo -e "❓ ${YELLOW}None of your containers are using Tailscale Serve for HTTPS.${NC}"
    echo -e "   Consider setting up Tailscale Serve for your web services for easy secure access."
  else
    echo -e "✅ ${GREEN}Good job! You're using Tailscale Serve to expose your services securely.${NC}"
  fi
  
  CONTAINERS_NEEDING_ATTENTION=$((CONTAINERS_MISSING_TAILSCALE + SERVICES_WITHOUT_SERVE))
  if [ ${CONTAINERS_NEEDING_ATTENTION} -gt 0 ]; then
    echo -e "⚠️ ${RED}${CONTAINERS_NEEDING_ATTENTION} container(s) need attention. Check the issues listed above.${NC}"
  else
    echo -e "✅ ${GREEN}Everything looks good! No issues detected.${NC}"
  fi
}

# Function to show progress during operations
show_progress() {
  local current=$1
  local total=$2
  local message="$3"
  local width=50
  local percentage=$((current * 100 / total))
  local completed=$((width * current / total))
  
  printf "\r${message} [${GREEN}"
  printf '▓%.0s' $(seq 1 $completed)
  printf "${NC}"
  printf '░%.0s' $(seq $((completed + 1)) $width)
  printf "${NC}] %3d%%${NC}" $percentage
}

# Function to complete the progress display
complete_progress() {
  echo -e "\n${GREEN}Scan completed!${NC}\n"
}
