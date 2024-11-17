#!/bin/bash

# Source configuration variables
source ./odoo-install-config.sh

# Extract the repository name from the URL
REPO_NAME=$(basename -s .git "$CUSTOM_ADDONS_REPO")
CUSTOM_ADDONS_DIR="$OE_HOME/$REPO_NAME" # Set dynamically based on the repo name

# Ensure the odoo user has the correct permissions on its home directory
echo -e "\n---- Setting permissions for the $OE_USER home directory ----"
sudo chown -R $OE_USER:$OE_USER $OE_HOME
sudo chmod -R 755 $OE_HOME

# Clone the custom add-ons repository to the odoo user's home directory
echo -e "\n---- Cloning Custom Add-ons Repository ----"
sudo -u $OE_USER git clone $CUSTOM_ADDONS_REPO $CUSTOM_ADDONS_DIR

# Determine domain or IP for Caddy configuration
if [[ -z "$DOMAIN" || -z "$EMAIL" ]]; then
    # Fallback to server IP address if DOMAIN or EMAIL is not set
    SERVER_IP=":80"
    CADDY_ADDRESS="$SERVER_IP"
    TLS_CONFIG=""
    echo "Using IP address $SERVER_IP for Caddy configuration."
else
    CADDY_ADDRESS="$DOMAIN"
    TLS_CONFIG="tls $EMAIL"
    echo "Using domain $DOMAIN with email $EMAIL for Caddy configuration."
fi

# Update Server and install PostgreSQL
echo -e "\n---- Update Server ----"
sudo apt update
sudo apt install -y postgresql postgresql-client

# Create PostgreSQL User and Database
echo -e "\n---- Setting up PostgreSQL User and Database ----"
sudo -u postgres createuser -d -R -S $OE_USER
sudo -u postgres createdb $OE_USER

# Install wkhtmltopdf
echo -e "\n---- Installing wkhtmltopdf ----"
wget https://github.com/wkhtmltopdf/packaging/releases/download/0.12.6.1-3/wkhtmltox_0.12.6.1-3.jammy_amd64.deb
sudo apt install -y ./wkhtmltox_0.12.6.1-3.jammy_amd64.deb

# Create Odoo system user
echo -e "\n---- Creating Odoo System User ----"
sudo adduser --system --home=$OE_HOME --group $OE_USER

# Clone Odoo and Custom Add-ons
echo -e "\n---- Cloning Odoo and Custom Add-ons Repositories ----"
sudo git clone --depth 1 --branch $OE_VERSION https://github.com/odoo/odoo.git $OE_HOME_EXT
sudo -u $OE_USER git clone $CUSTOM_ADDONS_REPO $CUSTOM_ADDONS_DIR

# Install Odoo Dependencies
echo -e "\n---- Installing Odoo Dependencies ----"
cd $OE_HOME_EXT
sudo ./setup/debinstall.sh

# Create Odoo configuration file
echo -e "\n---- Creating Odoo Configuration File ----"
sudo touch /etc/${OE_CONFIG}.conf
sudo su root -c "printf '[options]\n' >> /etc/${OE_CONFIG}.conf"
sudo su root -c "printf 'admin_passwd = ${OE_SUPERADMIN_PASS}\n' >> /etc/${OE_CONFIG}.conf"
sudo su root -c "printf 'db_user = $OE_USER\n' >> /etc/${OE_CONFIG}.conf"
sudo su root -c "printf 'addons_path = ${OE_HOME_EXT}/addons,${CUSTOM_ADDONS_DIR}/addons\n' >> /etc/${OE_CONFIG}.conf"
sudo su root -c "printf 'logfile = /var/log/${OE_CONFIG}.log\n' >> /etc/${OE_CONFIG}.conf"
sudo su root -c "printf 'http_port = ${OE_PORT}\n' >> /etc/${OE_CONFIG}.conf"
sudo su root -c "printf 'longpolling_port = ${LONGPOLLING_PORT}\n' >> /etc/${OE_CONFIG}.conf"

# Set permissions for the configuration file
sudo chown $OE_USER:$OE_USER /etc/${OE_CONFIG}.conf
sudo chmod 640 /etc/${OE_CONFIG}.conf

# Create systemd service file for Odoo
echo -e "\n---- Creating systemd Service File ----"
sudo bash -c "cat <<EOF > /etc/systemd/system/$OE_CONFIG.service
[Unit]
Description=Odoo 16 Service
After=network.target

[Service]
Type=simple
User=$OE_USER
ExecStart=/usr/bin/python3 $OE_HOME_EXT/odoo-bin -c /etc/${OE_CONFIG}.conf
Restart=always

[Install]
WantedBy=multi-user.target
EOF"

# Set permissions for the systemd service file
sudo chmod 755 /etc/systemd/system/$OE_CONFIG.service

# Start and enable the Odoo service
echo -e "\n---- Starting and Enabling Odoo Service ----"
sudo systemctl daemon-reload
sudo systemctl start $OE_CONFIG
sudo systemctl enable $OE_CONFIG

# Install Caddy
echo -e "\n---- Installing Caddy ----"
sudo apt install -y debian-keyring debian-archive-keyring apt-transport-https
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | sudo gpg --dearmor -o /usr/share/keyrings/caddy-archive-keyring.gpg
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | sudo tee /etc/apt/sources.list.d/caddy-stable.list
sudo apt update
sudo apt install -y caddy

# Configure Caddyfile for Odoo reverse proxy
echo -e "\n---- Configuring Caddy ----"
sudo bash -c "cat <<EOF > /etc/caddy/Caddyfile
$CADDY_ADDRESS {
    reverse_proxy 127.0.0.1:$OE_PORT
    reverse_proxy /longpolling 127.0.0.1:$LONGPOLLING_PORT
    log {
        output file /var/log/caddy/odoo-access.log
    }
}
EOF"

# Ensure log directory exists and restart Caddy
sudo mkdir -p /var/log/caddy
sudo chown caddy:caddy /var/log/caddy
sudo systemctl restart caddy

# Create update script in ubuntu's home directory
echo -e "\n---- Creating Update Script in Ubuntu's Home Directory ----"
sudo bash -c "cat <<EOF > /home/ubuntu/update-odoo.sh
#!/bin/bash
###############################################
# Script for updating Odoo
###############################################
echo 'Pulling updates from custom add-ons repository'
sudo -u $OE_USER -H sh -c 'cd $CUSTOM_ADDONS_DIR; git pull origin main'

echo 'Restarting Odoo service'
sudo systemctl restart $OE_CONFIG.service
echo 'Update complete'
EOF"

# Make the update script executable
sudo chmod +x /home/ubuntu/update-odoo.sh
sudo chown ubuntu:ubuntu /home/ubuntu/update-odoo.sh

echo "-----------------------------------------------------------"
echo "Odoo 16 installation completed and is running as a service."
echo "Caddy is installed and configured as a reverse proxy."
echo "Caddyfile location: /etc/caddy/Caddyfile"
echo "Odoo Configuration file: /etc/${OE_CONFIG}.conf"
echo "Service management: sudo systemctl {start|stop|status} ${OE_CONFIG}"
echo "Update script: /home/ubuntu/update-odoo.sh"
echo "-----------------------------------------------------------"
