#!/bin/bash

# Check if the script is run as root
if [ "$EUID" -ne 0 ]; then
  echo "This script must be run as root. Please use sudo or run as root."
  exit 1
fi

# Update the system
apt-get update && apt-get upgrade -y

# Install essential packages
apt-get install -y git vim htop curl wget tmux

# Install development tools
apt-get install -y build-essential python3 python3-pip python3-venv

# Check if Docker is already installed
if ! command -v docker &> /dev/null
then
    echo "Docker is not installed. Installing Docker..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sh get-docker.sh
    rm get-docker.sh
    usermod -aG docker $SUDO_USER
else
    echo "Docker is already installed. Skipping Docker installation."
fi

# Install Docker Compose (this will update it if already installed)
apt-get install -y docker-compose

# Install LazyDocker using the recommended script
su - $SUDO_USER -c 'curl https://raw.githubusercontent.com/jesseduffield/lazydocker/master/scripts/install_update_linux.sh | bash'

# Install Oh My Zsh without prompt
su - $SUDO_USER -c 'RUNZSH=no CHSH=no sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"'

# Set Zsh as the default shell for the user
chsh -s $(which zsh) $SUDO_USER

# Install Zsh Plugins
git clone https://github.com/zsh-users/zsh-autosuggestions $ZSH_CUSTOM/plugins/zsh-autosuggestions
git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting

# Install additional software
apt-get install -y fail2ban mc curl wget rsync nano screen ffmpeg

# Enable and start services
systemctl enable docker
systemctl start docker
systemctl enable fail2ban
systemctl start fail2ban

# Enable SSH
systemctl enable ssh
systemctl start ssh

# Add SSH public key to authorized_keys
mkdir -p /home/$SUDO_USER/.ssh
echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDaHwyiLYbhQiDFUufXqp6R0liupHv0UYw5sIrRrriMf" >> /home/$SUDO_USER/.ssh/authorized_keys
chmod 600 /home/$SUDO_USER/.ssh/authorized_keys
chmod 700 /home/$SUDO_USER/.ssh
chown -R $SUDO_USER:$SUDO_USER /home/$SUDO_USER/.ssh

# Configure UFW (firewall)
#ufw allow OpenSSH
#ufw enable

# Set up Python virtual environment
mkdir /home/$SUDO_USER/pi_setup
cd /home/$SUDO_USER/pi_setup
python3 -m venv venv
source venv/bin/activate

# Install common Python packages
pip install numpy pandas flask

# Clone your git repository (if needed)
git clone https://github.com/obause/pi-docker.git #/home/$SUDO_USER/pi_setup

# Configure static IP for Ethernet and Wi-Fi
cat <<EOT >> /etc/dhcpcd.conf
# Static IP configuration for eth0
interface eth0
static ip_address=192.168.1.138/24
static routers=192.168.1.1
static domain_name_servers=192.168.1.1 8.8.8.8

# Static IP configuration for wlan0
interface wlan0
static ip_address=192.168.1.137/24
static routers=192.168.1.1
static domain_name_servers=192.168.1.1 8.8.8.8
EOT

# Restart dhcpcd service to apply network changes
systemctl restart dhcpcd

# Custom configurations (e.g., setting up .bashrc)
echo "alias ll='ls -la'" >> /home/$SUDO_USER/.zshrc
echo "cd ~/my_project" >> /home/$SUDO_USER/.zshrc

# Reboot to apply changes
reboot
