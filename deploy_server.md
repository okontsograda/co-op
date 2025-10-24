# Server Deployment Guide

## 1. Create a VPS/Cloud Server

### Recommended Providers:
- **DigitalOcean**: $5/month, 1GB RAM, 1 CPU
- **AWS EC2**: Free tier (t2.micro)
- **Linode**: $5/month, 1GB RAM, 1 CPU
- **Vultr**: $2.50/month, 512MB RAM, 1 CPU

### Server Requirements:
- **OS**: Ubuntu 20.04 LTS or newer
- **RAM**: 512MB minimum (1GB recommended)
- **CPU**: 1 core minimum
- **Storage**: 10GB minimum

## 2. Connect to Your Server

```bash
# Replace with your server's IP address
ssh root@YOUR_SERVER_IP
```

## 3. Install Godot Headless

```bash
# Update system
apt update && apt upgrade -y

# Install dependencies
apt install -y wget unzip

# Download Godot headless (replace with latest version)
wget https://downloads.tuxfamily.org/godotengine/4.2.2/Godot_v4.2.2-stable_linux.x86_64.zip

# Extract
unzip Godot_v4.2.2-stable_linux.x86_64.zip
mv Godot_v4.2.2-stable_linux.x86_64 /usr/local/bin/godot
chmod +x /usr/local/bin/godot

# Test installation
godot --version
```

## 4. Upload Your Game

### Method A: Using SCP
```bash
# From your local machine
scp -r coop/ root@YOUR_SERVER_IP:/home/
scp project.godot root@YOUR_SERVER_IP:/home/
scp -r icon.* root@YOUR_SERVER_IP:/home/
```

### Method B: Using Git
```bash
# On the server
git clone YOUR_REPOSITORY_URL
cd your-repo-name
```

## 5. Configure Firewall

```bash
# Allow port 42069 (and 42070 as backup)
ufw allow 42069
ufw allow 42070
ufw enable
```

## 6. Run the Server

```bash
# Navigate to your game directory
cd /home/coop

# Run the dedicated server
godot --headless --main-pack dedicated_server.pck
```

## 7. Keep Server Running (Optional)

### Using screen:
```bash
# Install screen
apt install screen -y

# Start a screen session
screen -S gameserver

# Run your server
godot --headless --main-pack dedicated_server.pck

# Detach from screen (Ctrl+A, then D)
# Reattach later with: screen -r gameserver
```

### Using systemd service:
```bash
# Create service file
nano /etc/systemd/system/gameserver.service
```

Add this content:
```ini
[Unit]
Description=Game Server
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/home/coop
ExecStart=/usr/local/bin/godot --headless --main-pack dedicated_server.pck
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

Enable and start:
```bash
systemctl enable gameserver
systemctl start gameserver
systemctl status gameserver
```

## 8. Update Client Configuration

Update `coop/scripts/network_handler.gd`:
```gdscript
const IP_ADDRESS: String = "YOUR_SERVER_IP"  # Replace with your server's IP
```

## 9. Export and Distribute Clients

1. Export your client for Windows/Linux/Mac
2. Distribute the executable files
3. Players can now connect to your server!
