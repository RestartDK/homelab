#!/bin/bash
install_dokploy() {
    if [ "$(id -u)" != "0" ]; then
        echo "This script must be run as root" >&2
        exit 1
    fi
 
    # check if is Mac OS
    if [ "$(uname)" = "Darwin" ]; then
        echo "This script must be run on Linux" >&2
        exit 1
    fi
 
    # check if is running inside a container
    if [ -f /.dockerenv ]; then
        echo "This script must be run on Linux" >&2
        exit 1
    fi
 
    # check if something is running on port 80
    if ss -tulnp | grep ':80 ' >/dev/null; then
        echo "Error: something is already running on port 80" >&2
        exit 1
    fi
 
    # check if something is running on port 443
    if ss -tulnp | grep ':443 ' >/dev/null; then
        echo "Error: something is already running on port 443" >&2
        exit 1
    fi
 
    command_exists() {
      command -v "$@" > /dev/null 2>&1
    }
 
    # Path to SELinux policy source for docker socket access
    POLICY_TE="/opt/homelab/selinux/docker-socket.te"

        if command_exists docker; then
      echo "Docker already installed"
    else
      curl -sSL https://get.docker.com | sh
    fi

    # Add SELinux policy setup for Docker
    echo "Setting up SELinux policy for Docker..."
    
    # Check if SELinux is enabled
    if command_exists sestatus; then
        if sestatus | grep -q "enabled"; then
            echo "SELinux is enabled, attempting to create policy module..."
            
            # Get the hostname for the policy name
            HOSTNAME=$(hostname)
            
            # Check if policy already exists
            if ! semodule -l | grep -q "^${HOSTNAME}$"; then
                echo "Generating SELinux policy for '${HOSTNAME}'..."
                
                # Try to generate policy, but don't fail if MLS errors occur
                # Generate policy and capture any errors
                POLICY_OUTPUT=$(ausearch -c 'node' --raw 2>/dev/null | audit2allow -M "${HOSTNAME}" 2>&1)
                POLICY_EXIT_CODE=$?
                
                # Check if policy file was created successfully
                if [ -f "${HOSTNAME}.pp" ]; then
                    # Try to install the policy
                    if semodule -X 300 -i "${HOSTNAME}.pp" >/dev/null 2>&1; then
                        echo "SELinux policy module '${HOSTNAME}' installed successfully"
                    else
                        echo "Warning: Policy generated but installation failed"
                        echo "This is usually safe to ignore with targeted SELinux policy"
                    fi
                else
                    # Policy generation failed, but this is often due to MLS constraints
                    # which are just warnings and can be safely ignored
                    echo "Note: SELinux policy generation had issues (likely MLS-related warnings)"
                    echo "This is normal with targeted policy and Docker will work fine"
                    echo "Continuing with installation..."
                fi
                
                # Note: Traefik policy will be created after the container runs
                echo "Traefik SELinux policy will be created after container startup..."
            else
                echo "SELinux policy module '${HOSTNAME}' already exists"
            fi
        else
            echo "SELinux is disabled, skipping policy setup"
        fi
    else
        echo "SELinux tools not available, skipping policy setup"
    fi

    docker swarm leave --force 2>/dev/null
 
    get_ip() {
        local ip=""
        
        # Try IPv4 first
        # First attempt: ifconfig.io
        ip=$(curl -4s --connect-timeout 5 https://ifconfig.io 2>/dev/null)
        
        # Second attempt: icanhazip.com
        if [ -z "$ip" ]; then
            ip=$(curl -4s --connect-timeout 5 https://icanhazip.com 2>/dev/null)
        fi
        
        # Third attempt: ipecho.net
        if [ -z "$ip" ]; then
            ip=$(curl -4s --connect-timeout 5 https://ipecho.net/plain 2>/dev/null)
        fi
 
        # If no IPv4, try IPv6
        if [ -z "$ip" ]; then
            # Try IPv6 with ifconfig.io
            ip=$(curl -6s --connect-timeout 5 https://ifconfig.io 2>/dev/null)
            
            # Try IPv6 with icanhazip.com
            if [ -z "$ip" ]; then
                ip=$(curl -6s --connect-timeout 5 https://icanhazip.com 2>/dev/null)
            fi
            
            # Try IPv6 with ipecho.net
            if [ -z "$ip" ]; then
                ip=$(curl -6s --connect-timeout 5 https://ipecho.net/plain 2>/dev/null)
            fi
        fi
 
        if [ -z "$ip" ]; then
            echo "Error: Could not determine server IP address automatically (neither IPv4 nor IPv6)." >&2
            echo "Please set the ADVERTISE_ADDR environment variable manually." >&2
            echo "Example: export ADVERTISE_ADDR=<your-server-ip>" >&2
            exit 1
        fi
 
        echo "$ip"
    }
 
    advertise_addr="${ADVERTISE_ADDR:-$(get_ip)}"
    echo "Using advertise address: $advertise_addr"
 
    docker swarm init --advertise-addr $advertise_addr
    
     if [ $? -ne 0 ]; then
        echo "Error: Failed to initialize Docker Swarm" >&2
        exit 1
    fi
 
    echo "Swarm initialized"
 
    docker network rm -f dokploy-network 2>/dev/null
    docker network create --driver overlay --attachable dokploy-network
 
    echo "Network created"
 
    mkdir -p /etc/dokploy
 
    chmod 777 /etc/dokploy

    # Ensure SELinux labels allow containers to write to /etc/dokploy
    if command -v semanage > /dev/null 2>&1; then
        semanage fcontext -a -t container_file_t "/etc/dokploy(/.*)?" 2>/dev/null || true
    fi
    restorecon -Rv /etc/dokploy 2>/dev/null || true
 
    docker service create \
    --name dokploy-postgres \
    --constraint 'node.role==manager' \
    --network dokploy-network \
    --env POSTGRES_USER=dokploy \
    --env POSTGRES_DB=dokploy \
    --env POSTGRES_PASSWORD=amukds4wi9001583845717ad2 \
    --mount type=volume,source=dokploy-postgres-database,target=/var/lib/postgresql/data \
    postgres:16
 
    docker service create \
    --name dokploy-redis \
    --constraint 'node.role==manager' \
    --network dokploy-network \
    --mount type=volume,source=redis-data-volume,target=/data \
    redis:7
 
    docker pull traefik:v3.1.2
    docker pull dokploy/dokploy:latest
 
    # Installation
    docker service create \
      --name dokploy \
      --replicas 1 \
      --network dokploy-network \
      --mount type=bind,source=/var/run/docker.sock,target=/var/run/docker.sock \
      --mount type=bind,source=/etc/dokploy,target=/etc/dokploy \
      --mount type=volume,source=dokploy-docker-config,target=/root/.docker \
      --publish published=3000,target=3000,mode=host \
      --update-parallelism 1 \
      --update-order stop-first \
      --constraint 'node.role == manager' \
      -e ADVERTISE_ADDR=$advertise_addr \
      dokploy/dokploy:latest

 
    docker run -d \
        --name dokploy-traefik \
        --network dokploy-network \
        --restart always \
        --security-opt label=disable \
        -v /etc/dokploy/traefik/traefik.yml:/etc/traefik/traefik.yml:z \
        -v /etc/dokploy/traefik/dynamic:/etc/dokploy/traefik/dynamic:z \
        -v /var/run/docker.sock:/var/run/docker.sock:z \
        -p 80:80/tcp \
        -p 443:443/tcp \
        -p 443:443/udp \
        traefik:v3.1.2
 
    # Apply SELinux policy from $POLICY_TE to allow containers to connect to docker.sock
    echo "Installing SELinux dockersock policy module from ${POLICY_TE}..."
    if command -v checkmodule > /dev/null 2>&1 && command -v semodule_package > /dev/null 2>&1 && [ -f "${POLICY_TE}" ]; then
        echo "Applying policy to system"
        checkmodule -M -m -o /tmp/dockersock.mod "${POLICY_TE}" >/dev/null 2>&1 || true
        semodule_package -o /tmp/dockersock.pp -m /tmp/dockersock.mod >/dev/null 2>&1 || true
        semodule -i /tmp/dockersock.pp >/dev/null 2>&1 || true
        rm -f /tmp/dockersock.mod /tmp/dockersock.pp
    else
        echo "Warning: checkmodule/semodule_package not found or ${POLICY_TE} missing; skipping dockersock policy install"
    fi

    # Optional: Use docker service create instead of docker run
    #   docker service create \
    #     --name dokploy-traefik \
    #     --constraint 'node.role==manager' \
    #     --network dokploy-network \
    #     --mount type=bind,source=/etc/dokploy/traefik/traefik.yml,target=/etc/traefik/traefik.yml \
    #     --mount type=bind,source=/etc/dokploy/traefik/dynamic,target=/etc/dokploy/traefik/dynamic \
    #     --mount type=bind,source=/var/run/docker.sock,target=/var/run/docker.sock \
    #     --publish mode=host,published=443,target=443 \
    #     --publish mode=host,published=80,target=80 \
    #     --publish mode=host,published=443,target=443,protocol=udp \
    #     traefik:v3.1.2
 
    GREEN="\033[0;32m"
    YELLOW="\033[1;33m"
    BLUE="\033[0;34m"
    NC="\033[0m" # No Color
 
    format_ip_for_url() {
        local ip="$1"
        if echo "$ip" | grep -q ':'; then
            # IPv6
            echo "[${ip}]"
        else
            # IPv4
            echo "${ip}"
        fi
    }
 
    formatted_addr=$(format_ip_for_url "$advertise_addr")
    echo ""
    printf "${GREEN}Congratulations, Dokploy is installed!${NC}\n"
    printf "${BLUE}Wait 15 seconds for the server to start${NC}\n"
    printf "${YELLOW}Please go to http://${formatted_addr}:3000${NC}\n\n"
}
 
update_dokploy() {
    echo "Updating Dokploy..."
    
    # Pull the latest image
    docker pull dokploy/dokploy:latest
 
    # Update the service
    docker service update --image dokploy/dokploy:latest dokploy
 
    echo "Dokploy has been updated to the latest version."
}
 
# Main script execution
if [ "$1" = "update" ]; then
    update_dokploy
else
    install_dokploy
fi