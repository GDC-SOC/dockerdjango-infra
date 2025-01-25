#!/bin/bash
set -e

# Helper function for printing status messages
function print_status {
    echo -e "\n========== $1 ==========\n"
}

print_status "Starting infrastructure setup..."

# Variables
PARTITION="/dev/nvme1n1"
MOUNT_POINT="/mnt/docker"

# 1. Update and upgrade the system
print_status "Updating and upgrading system packages"
sudo apt update && sudo apt upgrade -y

# 2. Install dependencies
print_status "Installing required packages (Docker, Git, Python3, etc.)"
sudo apt install -y python3 python3-pip git curl jq docker.io

# 3. Start and enable Docker service
print_status "Starting and enabling Docker service"
sudo systemctl enable docker
sudo systemctl start docker

# 4. Add default user to the Docker group
print_status "Adding the 'ubuntu' user to the Docker group"
sudo usermod -aG docker ubuntu

# 5. Format, mount, and configure Docker directory
print_status "Configuring Docker storage"

if [ -b "${PARTITION}" ]; then
    # Format the partition
    print_status "Formatting ${PARTITION} with ext4 filesystem"
    sudo mkfs.ext4 "${PARTITION}"

    # Mount the partition
    print_status "Mounting ${PARTITION} to ${MOUNT_POINT}"
    sudo mkdir -p "${MOUNT_POINT}"
    sudo mount "${PARTITION}" "${MOUNT_POINT}"

    # Make the mount persistent
    print_status "Adding ${PARTITION} to /etc/fstab"
    echo "${PARTITION} ${MOUNT_POINT} ext4 defaults,nofail 0 2" | sudo tee -a /etc/fstab

    # Stop Docker service
    print_status "Stopping Docker service for configuration"
    sudo systemctl stop docker || echo "Docker is not running, continuing setup."

    # Remove any existing symbolic link or directory
    print_status "Cleaning up and creating the correct directory structure"
    sudo rm -rf /var/lib/docker
    sudo mkdir -p "${MOUNT_POINT}/docker"
    sudo chown -R root:docker "${MOUNT_POINT}/docker"
    sudo chmod -R 755 "${MOUNT_POINT}/docker"

    # Create a symbolic link
    print_status "Creating symbolic link from /var/lib/docker to ${MOUNT_POINT}/docker"
    sudo ln -s "${MOUNT_POINT}/docker" /var/lib/docker

    # Start Docker service
    print_status "Starting Docker service"
    sudo systemctl start docker
else
    print_status "Partition ${PARTITION} not found. Skipping partition setup."
fi

# 6. Verify Docker setup
print_status "Verifying Docker configuration"
DOCKER_DIR=$(docker info | grep "Docker Root Dir" | awk '{print $NF}')

if [ "${DOCKER_DIR}" == "${MOUNT_POINT}/docker" ]; then
    echo "SUCCESS: Docker is now using ${DOCKER_DIR}"
else
    echo "ERROR: Docker is not using the expected directory (${MOUNT_POINT}/docker)."
    exit 1
fi

# 7. Test Docker installation
print_status "Running test container with Docker"
docker run --rm hello-world

print_status "Infrastructure setup completed successfully!"
