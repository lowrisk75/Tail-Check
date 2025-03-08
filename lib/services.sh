#!/bin/bash
# Service detection functions

# Array of common service names to check
COMMON_SERVICES=(
  # Web servers
  "nginx"
  "apache2"
  "httpd"
  "lighttpd"
  "caddy"
  "traefik"
  
  # Media servers
  "plex" 
  "emby"
  "jellyfin"
  "kodi"
  
  # *arr apps
  "sonarr"
  "radarr"
  "lidarr"
  "readarr"
  "prowlarr"
  "bazarr"
  "jackett"
  
  # Download clients
  "nzbget"
  "sabnzbd"
  "transmission"
  "deluge"
  "qbittorrent"
  "rtorrent"
  "aria2c"
  
  # Home automation
  "homeassistant"
  "nodered"
  "openhab"
  "domoticz"
  
  # Monitoring and metrics
  "grafana"
  "influxdb"
  "prometheus"
  "telegraf"
  "netdata"
  "zabbix"
  
  # Databases
  "mariadb"
  "mysql"
  "postgresql"
  "mongodb"
  "redis"
  "cassandra"
  "elasticsearch"
  
  # Message brokers
  "emqx"
  "mosquitto"
  "rabbitmq"
  "kafka"
  "activemq"
  
  # Containers & orchestration
  "docker"
  "containerd"
  "kubelet"
  "k3s"
  
  # DNS & networking
  "pihole"
  "bind9"
  "unbound"
  "dnsmasq"
  
  # VPN
  "openvpn"
  "wireguard"
  
  # Misc
  "gitea"
  "gitlab"
  "nextcloud"
  "vaultwarden"
  "syncthing"
  "searxng"
  "photoprism"
  "adguard"
)

# Function to check for running services in a container
check_services() {
  local container="$1"
  local found_services=""
  local found_any=false
  
  # Check for common services using systemctl
  if lxc-attach -n "$container" -- which systemctl >/dev/null 2>&1; then
    for service in "${COMMON_SERVICES[@]}"; do
      if lxc-attach -n "$container" -- systemctl is-active --quiet "$service" 2>/dev/null; then
        found_services+="$service "
        found_any=true
      fi
    done
  fi
  
  # Also check using ps for containers without systemd
  for service in "${COMMON_SERVICES[@]}"; do
    if lxc-attach -n "$container" -- ps aux | grep -v grep | grep -q "\b$service\b"; then
      # Only add if not already found
      if [[ ! "$found_services" =~ "$service" ]]; then
        found_services+="$service "
        found_any=true
      fi
    fi
  done
  
  # Get all open ports
  local ports=$(lxc-attach -n "$container" -- ss -tulnp | grep LISTEN | awk '{print $5}' | sed 's/.*://' | sort -n | uniq | tr '\n' ' ')
  
  # Store the ports in the container ports array
  CONTAINER_PORTS[$container]="$ports"
  
  # If we didn't find any known services but there are open ports, mark as unknown service
  if [ "$found_any" = false ] && [ ! -z "$ports" ]; then
    found_services="unknown service (ports: $ports)"
    found_any=true
  fi
  
  # Store the found services in the container services array if any were found
  if [ "$found_any" = true ]; then
    CONTAINER_SERVICES[$container]="$found_services"
    return 0
  else
    return 1
  fi
}

# Function to get recommended port for a service
get_recommended_port() {
  local service="$1"
  
  case "$service" in
    # Web servers
    nginx|apache2|httpd|lighttpd|caddy|traefik)
      echo "80"
      ;;
    
    # Media servers
    plex)
      echo "32400"
      ;;
    jellyfin|emby)
      echo "8096"
      ;;
    kodi)
      echo "8080"
      ;;
    
    # *arr apps
    sonarr)
      echo "8989"
      ;;
    radarr)
      echo "7878"
      ;;
    lidarr)
      echo "8686"
      ;;
    readarr)
      echo "8787"
      ;;
    prowlarr)
      echo "9696"
      ;;
    bazarr)
      echo "6767"
      ;;
    jackett)
      echo "9117"
      ;;
    
    # Download clients
    nzbget)
      echo "6789"
      ;;
    sabnzbd)
      echo "8080"
      ;;
    transmission)
      echo "9091"
      ;;
    deluge)
      echo "8112"
      ;;
    qbittorrent)
      echo "8080"
      ;;
    
    # Home automation
    homeassistant)
      echo "8123"
      ;;
    nodered)
      echo "1880"
      ;;
    openhab)
      echo "8080"
      ;;
    domoticz)
      echo "8080"
      ;;
    
    # Monitoring and metrics
    grafana)
      echo "3000"
      ;;
    influxdb)
      echo "8086"
      ;;
    prometheus)
      echo "9090"
      ;;
    netdata)
      echo "19999"
      ;;
    
    # Databases
    mariadb|mysql)
      echo "3306"
      ;;
    postgresql)
      echo "5432"
      ;;
    mongodb)
      echo "27017"
      ;;
    redis)
      echo "6379"
      ;;
    elasticsearch)
      echo "9200"
      ;;
    
    # Message brokers
    emqx)
      echo "18083"  # Dashboard port
      ;;
    mosquitto)
      echo "1883"
      ;;
    rabbitmq)
      echo "15672"  # Management interface
      ;;
    
    # Web applications
    gitea)
      echo "3000"
      ;;
    gitlab)
      echo "80"
      ;;
    nextcloud)
      echo "80"
      ;;
    vaultwarden)
      echo "80"
      ;;
    syncthing)
      echo "8384"
      ;;
    photoprism)
      echo "2342"
      ;;
    
    # DNS & networking
    pihole)
      echo "80"  # Admin interface
      ;;
    adguard)
      echo "3000"
      ;;
    
    *)
      # If no specific recommendation, return empty
      echo ""
      ;;
  esac
}
