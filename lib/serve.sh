#!/bin/bash

# Function to check if a container is using Tailscale Serve
check_tailscale_serve() {
    local container="$1"
    
    # Log the check
    log_message "Checking if container $container is using Tailscale Serve"
    
    # Run tailscale status in the container to get serve info
    local serve_output=$(lxc-attach -n "$container" -- bash -c "tailscale status" 2>/dev/null | grep -i "serve")
    
    if [[ ! -z "$serve_output" ]]; then
        CONTAINERS_SERVE_LIST+=("$container")
        CONTAINERS_WITH_SERVE=$((CONTAINERS_WITH_SERVE + 1))
        
        # Extract domain info if available
        local domain=$(echo "$serve_output" | grep -oP 'https?://\K[^:]+' | head -1)
        if [[ ! -z "$domain" ]]; then
            CONTAINER_DOMAINS["$container"]="$domain"
        fi
        
        return 0
    else
        # If container has tailscale but not serve
        if [[ " ${CONTAINERS_TAILSCALE_LIST[*]} " =~ " ${container} " ]]; then
            CONTAINERS_NO_SERVE_LIST+=("$container")
        fi
        
        return 1
    fi
}

# Function to install Tailscale on selected container
install_selected_container_tailscale() {
    if [ ${#CONTAINERS_NO_TAILSCALE_LIST[@]} -eq 0 ]; then
        echo -e "${YELLOW}All containers already have Tailscale installed.${NC}"
        sleep 2
        return
    fi
    
    echo -e "${BOLD}Select a container to install Tailscale on:${NC}"
    local i=1
    for container in "${CONTAINERS_NO_TAILSCALE_LIST[@]}"; do
        echo -e "$i) $container"
        i=$((i+1))
    done
    
    read -p "Enter selection (1-$((i-1))): " selection
    
    if ! [[ "$selection" =~ ^[0-9]+$ ]] || [ "$selection" -lt 1 ] || [ "$selection" -gt $((i-1)) ]; then
        echo -e "${RED}Invalid selection!${NC}"
        sleep 2
        return
    fi
    
    local selected_container="${CONTAINERS_NO_TAILSCALE_LIST[$((selection-1))]}"
    
    if [ -z "$selected_container" ]; then
        echo -e "${RED}Invalid selection!${NC}"
        sleep 2
        return
    fi
    
    echo -e "${BLUE}Installing Tailscale on ${BOLD}$selected_container${NC}"
    log_message "Installing Tailscale on container $selected_container"
    
    lxc-attach -n "$selected_container" -- apt update
    lxc-attach -n "$selected_container" -- apt install -y curl
    lxc-attach -n "$selected_container" -- bash -c "curl -fsSL https://tailscale.com/install.sh | sh"
    lxc-attach -n "$selected_container" -- tailscale up
    
    echo -e "${GREEN}Tailscale installed on ${BOLD}$selected_container${NC}"
    log_message "Tailscale installation completed on container $selected_container"
    
    # Update lists
    CONTAINERS_TAILSCALE_LIST+=("$selected_container")
    
    # Remove from no tailscale list
    for i in "${!CONTAINERS_NO_TAILSCALE_LIST[@]}"; do
        if [[ "${CONTAINERS_NO_TAILSCALE_LIST[i]}" = "$selected_container" ]]; then
            unset 'CONTAINERS_NO_TAILSCALE_LIST[i]'
        fi
    done
    
    CONTAINERS_NO_TAILSCALE_LIST=("${CONTAINERS_NO_TAILSCALE_LIST[@]}")
    CONTAINERS_WITH_TAILSCALE=$((CONTAINERS_WITH_TAILSCALE + 1))
    CONTAINERS_MISSING_TAILSCALE=$((CONTAINERS_MISSING_TAILSCALE - 1))
    
    sleep 2
}

# Function to install Tailscale on all containers that don't have it
install_tailscale_containers() {
    if [ ${#CONTAINERS_NO_TAILSCALE_LIST[@]} -eq 0 ]; then
        echo -e "${YELLOW}All containers already have Tailscale installed.${NC}"
        sleep 2
        return
    fi
    
    echo -e "${BLUE}Installing Tailscale on ${BOLD}${#CONTAINERS_NO_TAILSCALE_LIST[@]}${NC} ${BLUE}containers${NC}"
    log_message "Starting batch installation of Tailscale on ${#CONTAINERS_NO_TAILSCALE_LIST[@]} containers"
    
    local current=0
    local total=${#CONTAINERS_NO_TAILSCALE_LIST[@]}
    
    for container in "${CONTAINERS_NO_TAILSCALE_LIST[@]}"; do
        current=$((current + 1))
        show_progress $current $total "Installing on $container"
        
        lxc-attach -n "$container" -- apt update >/dev/null 2>&1
        lxc-attach -n "$container" -- apt install -y curl >/dev/null 2>&1
        lxc-attach -n "$container" -- bash -c "curl -fsSL https://tailscale.com/install.sh | sh" >/dev/null 2>&1
        lxc-attach -n "$container" -- tailscale up >/dev/null 2>&1
        
        # Update counters
        CONTAINERS_TAILSCALE_LIST+=("$container")
        CONTAINERS_WITH_TAILSCALE=$((CONTAINERS_WITH_TAILSCALE + 1))
        
        log_message "Tailscale installed on container $container"
        sleep 1
    done
    
    complete_progress
    CONTAINERS_MISSING_TAILSCALE=0
    CONTAINERS_NO_TAILSCALE_LIST=()
    
    echo -e "${GREEN}Tailscale installed on all containers!${NC}"
    log_message "Completed batch installation of Tailscale on all containers"
    sleep 2
}

# Function to configure Tailscale Serve on one container
configure_selected_container_serve() {
    local eligible_containers=()
    
    # Find containers with Tailscale but without Serve
    for container in "${CONTAINERS_TAILSCALE_LIST[@]}"; do
        if ! [[ " ${CONTAINERS_SERVE_LIST[*]} " =~ " ${container} " ]]; then
            eligible_containers+=("$container")
        fi
    done
    
    if [ ${#eligible_containers[@]} -eq 0 ]; then
        echo -e "${YELLOW}No containers available for Tailscale Serve configuration.${NC}"
        sleep 2
        return
    fi
    
    echo -e "${BOLD}Select a container to configure Tailscale Serve on:${NC}"
    local i=1
    for container in "${eligible_containers[@]}"; do
        echo -e "$i) $container"
        i=$((i+1))
    done
    
    read -p "Enter selection (1-$((i-1))): " selection
    
    if ! [[ "$selection" =~ ^[0-9]+$ ]] || [ "$selection" -lt 1 ] || [ "$selection" -gt $((i-1)) ]; then
        echo -e "${RED}Invalid selection!${NC}"
        sleep 2
        return
    fi
    
    local selected_container="${eligible_containers[$((selection-1))]}"
    
    # Get ports for the container
    local port="${CONTAINER_PORTS[$selected_container]}"
    if [ -z "$port" ]; then
        echo -e "${YELLOW}No port information found for $selected_container${NC}"
        read -p "Enter port number to expose: " port
    fi
    
    echo -e "${BLUE}Configuring Tailscale Serve on ${BOLD}$selected_container${NC} for port ${BOLD}$port${NC}"
    log_message "Configuring Tailscale Serve on container $selected_container for port $port"
    
    # Configure Tailscale Serve
    lxc-attach -n "$selected_container" -- tailscale serve https://$selected_container.fox-inconnu.ts.net:$port
    
    echo -e "${GREEN}Tailscale Serve configured on ${BOLD}$selected_container${NC}"
    
    # Update lists
    CONTAINERS_SERVE_LIST+=("$selected_container")
    CONTAINERS_WITH_SERVE=$((CONTAINERS_WITH_SERVE + 1))
    
    # Remove from no serve list
    for i in "${!CONTAINERS_NO_SERVE_LIST[@]}"; do
        if [[ "${CONTAINERS_NO_SERVE_LIST[i]}" = "$selected_container" ]]; then
            unset 'CONTAINERS_NO_SERVE_LIST[i]'
        fi
    done
    
    CONTAINERS_NO_SERVE_LIST=("${CONTAINERS_NO_SERVE_LIST[@]}")
    
    sleep 2
}

# Function to configure Tailscale Serve on all eligible containers
configure_missing_serve() {
    local eligible_containers=()
    
    # Find containers with Tailscale but without Serve
    for container in "${CONTAINERS_TAILSCALE_LIST[@]}"; do
        if ! [[ " ${CONTAINERS_SERVE_LIST[*]} " =~ " ${container} " ]]; then
            # Only include if it has port information
            if [ ! -z "${CONTAINER_PORTS[$container]}" ]; then
                eligible_containers+=("$container")
            fi
        fi
    done
    
    if [ ${#eligible_containers[@]} -eq 0 ]; then
        echo -e "${YELLOW}No containers available for Tailscale Serve configuration.${NC}"
        sleep 2
        return
    fi
    
    echo -e "${BLUE}Configuring Tailscale Serve on ${BOLD}${#eligible_containers[@]}${NC} ${BLUE}containers${NC}"
    log_message "Starting batch configuration of Tailscale Serve on ${#eligible_containers[@]} containers"
    
    local current=0
    local total=${#eligible_containers[@]}
    
    for container in "${eligible_containers[@]}"; do
        current=$((current + 1))
        local port="${CONTAINER_PORTS[$container]}"
        
        show_progress $current $total "Configuring on $container (port $port)"
        
        # Configure Tailscale Serve
        lxc-attach -n "$container" -- tailscale serve https://$container.fox-inconnu.ts.net:$port >/dev/null 2>&1
        
        # Update lists
        CONTAINERS_SERVE_LIST+=("$container")
        CONTAINERS_WITH_SERVE=$((CONTAINERS_WITH_SERVE + 1))
        
        log_message "Tailscale Serve configured on container $container for port $port"
        sleep 0.5
    done
    
    complete_progress
    
    # Remove from no serve list
    for container in "${eligible_containers[@]}"; do
        for i in "${!CONTAINERS_NO_SERVE_LIST[@]}"; do
            if [[ "${CONTAINERS_NO_SERVE_LIST[i]}" = "$container" ]]; then
                unset 'CONTAINERS_NO_SERVE_LIST[i]'
            fi
        done
    done
    
    CONTAINERS_NO_SERVE_LIST=("${CONTAINERS_NO_SERVE_LIST[@]}")
    
    echo -e "${GREEN}Tailscale Serve configured on all eligible containers!${NC}"
    log_message "Completed batch configuration of Tailscale Serve on all eligible containers"
    sleep 2
}
