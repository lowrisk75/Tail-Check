# Tail-Check

<div align="center">
    <h2>Connected Secure</h2>
    <p>The ultimate resource for IT, networking, and renewable energy solutions</p>
    
    <a href="https://www.youtube.com/@connectedsecure">
        <img src="https://img.shields.io/badge/YouTube-Subscribe-FF0000?style=for-the-badge&logo=youtube&logoColor=white" alt="YouTube Channel" width="250"/>
    </a>
    &nbsp;&nbsp;&nbsp;
    <a href="https://x.com/SecureConnected">
        <img src="https://img.shields.io/badge/Twitter-Follow-1DA1F2?style=for-the-badge&logo=twitter&logoColor=white" alt="Twitter" width="220"/>
    </a>
</div>

---

## Overview
Tail-Check is a comprehensive, script-based utility meticulously designed to streamline Tailscale management across Proxmox VE containers. Developed by Kevin from Connected Secure, this tool addresses the complexity of maintaining Tailscale installations and configurations across multiple containers by providing an intuitive management interface that automates the entire process from scanning to configuration.

## Detailed Features

### Container Management
- **Intelligent Container Discovery**: Utilizes Proxmox APIs to detect all LXC containers regardless of their running state or network configuration
- **Deep Status Analysis**: Performs multi-level checks for Tailscale installation, service status, connection state, and authentication
- **Granular Batch Operations**: Execute precise operations on filtered container sets based on status, OS type, or custom selection criteria
- **Error Handling**: Implements robust error detection and reporting for failed operations with detailed logs

### Advanced Tailscale Integration
- **Smart Installation Process**: Detects container OS and selects appropriate installation method (apt, yum, dnf, etc.)
- **Authentication Management**: Supports multiple authentication methods including:
  - Pre-auth keys with customizable expiration and permissions
  - Interactive authentication with QR code generation
  - Auth key rotation and management
- **Network Configuration**: Automated configuration of subnet routing, exit nodes, and access controls
- **Serve Configuration Wizard**: Interactive wizard to expose HTTP, TCP, and UDP services with hostname mapping

### Comprehensive Network Monitoring
- **Real-time Status Updates**: Continuously monitors Tailscale connection status with configurable refresh intervals
- **Detailed IP Management**: Tracks IPv4/IPv6 assignments, peer connections, and traffic statistics
- **Service Health Checks**: Performs periodic health checks on exposed services with alerting capabilities
- **Network Visualization**: Generates network topology maps showing connections between nodes

### Enterprise-Ready Dashboard Integration
- **Homepage.io Integration**: Generates complete YAML configurations for Homepage dashboard with service grouping
- **Service Metadata**: Automatically extracts and includes service descriptions, versions, and health status
- **Custom Icons**: Maps detected services to appropriate icons for visual identification
- **Dynamic Updates**: Provides mechanisms to update dashboard configurations when services change

## Installation

### Prerequisites
- Proxmox VE 7.0+ 
- Root access to Proxmox host
- Internet connectivity for package downloads
- Tailscale account
- SSH access configured for containers (optional, but recommended)

### Detailed Installation Steps
```bash
# 1. Connect to your Proxmox host via SSH
ssh root@your-proxmox-host

# 2. Clone the repository
git clone https://github.com/lowrisk75/Tail-Check.git

# 3. Navigate to the directory
cd Tail-Check

# 4. Make the script executable
chmod +x tail-check.sh

# 5. Run the script
./tail-check.sh
```

### Configuration Options
The tool can be configured through the interactive menu or by editing the `config.json` file:

```json
{
  "tailscaleVersion": "latest",
  "scanInterval": 300,
  "defaultPreAuthTags": "tag:server,tag:proxmox",
  "homepageConfig": {
    "enabled": true,
    "path": "/opt/homepage/config",
    "serviceGroup": "Proxmox"
  }
}
```

## Detailed Usage Guide

### Main Menu Options
1. **Scan Containers**: Performs a comprehensive scan of all containers
   - Checks container status (running/stopped)
   - Verifies Tailscale installation
   - Tests Tailscale connectivity
   - Maps IP addresses and hostnames

2. **Tailscale Management**: Comprehensive Tailscale operations
   - Install Tailscale on selected containers
   - Update existing installations
   - Configure authentication
   - Set up subnet routers or exit nodes

3. **Service Configuration**: 
   - Configure Tailscale Serve for HTTP(S) services
   - Set up TCP/UDP port forwarding
   - Configure custom hostnames
   - Set up load balancing across multiple containers

4. **Dashboard Integration**:
   - Generate Homepage configuration files
   - Create service groups based on container purpose
   - Configure service icons and metadata
   - Set up health check monitoring

5. **Reporting & Monitoring**:
   - Generate detailed status reports
   - Export network maps in various formats
   - Configure automated email reports
   - Set up alerting for service disruptions

### Example Workflows

#### Basic Setup
```bash
# Start the tool
./tail-check.sh

# 1. Scan all containers to discover current state
# 2. Select containers without Tailscale and install
# 3. Authenticate each container with your Tailscale account
# 4. Generate basic Homepage configuration
```

#### Advanced Configuration
```bash
# 1. Scan containers for specific services
# 2. Configure Tailscale Serve for web applications
# 3. Set up subnet routing between container groups
# 4. Configure advanced Homepage dashboard with service groups
# 5. Set up monitoring and alerts for critical services
```

## Troubleshooting Guide

### Common Issues and Solutions

#### Installation Problems
- **Issue**: Unable to install on specific containers
  - **Solution**: Verify container has internet access and correct repositories enabled
  - **Command**: `tail-check.sh --check-connectivity CONTAINER_ID`

#### Authentication Failures
- **Issue**: Containers fail to authenticate with Tailscale
  - **Solution**: Verify pre-auth keys are valid and have appropriate permissions
  - **Command**: `tail-check.sh --validate-auth-keys`

#### Performance Concerns
- **Issue**: Script runs slowly on large deployments
  - **Solution**: Enable parallel operations mode
  - **Configuration**: Set `"parallelOperations": true` in config.json

## Contributing
Contributions to Tail-Check are welcome and appreciated! Here's how you can contribute:

1. **Fork the repository**
2. **Create a feature branch**: `git checkout -b feature/amazing-feature`
3. **Commit your changes**: `git commit -m 'Add some amazing feature'`
4. **Push to the branch**: `git push origin feature/amazing-feature`
5. **Open a Pull Request**

### Development Guidelines
- Follow shell script best practices
- Include comments for complex functions
- Add tests for new features
- Update documentation when adding features

## License
This project is licensed under the MIT License - see the LICENSE file for details.

## Author
Created by Kevin from [Connected Secure](https://www.youtube.com/@connectedsecure), where you can find more content about IT, networking, and renewable energy.

## Support & Community
If you find this tool useful, consider supporting the developer:
- Subscribe to [Connected Secure on YouTube](https://www.youtube.com/@connectedsecure)
- Follow on [Twitter/X](https://x.com/SecureConnected)
- Join our community Discord server for discussions and support
- Share your experience and use cases in the discussions section

---

*Tail-Check is not affiliated with Tailscale Inc. or Proxmox Server Solutions GmbH.*
