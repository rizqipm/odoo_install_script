#!/bin/bash

# Source configuration variables
source ./odoo-install-config.sh

# Extract the repository name from the URL
REPO_NAME=$(basename -s .git "$CUSTOM_ADDONS_REPO")
CUSTOM_ADDONS_DIR="$OE_HOME/$REPO_NAME" # Set dynamically based on the repo name

# Ensure the odoo user has the correct permissions on its home directory
# echo -e "\n---- Setting permissions for the $OE_USER home directory ----"
# sudo chown -R $OE_USER:$OE_USER $OE_HOME
# sudo chmod -R 755 $OE_HOME

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

# Install Nginx
echo -e "\n---- Installing Nginx ----"
sudo apt install -y nginx

# Configure Nginx for Odoo
echo -e "\n---- Configuring Nginx ----"
sudo bash -c "cat <<EOF > /etc/nginx/sites-available/odoo
server {
    listen 80;

    proxy_set_header Host $host;
    # Add Headers for odoo proxy mode
    proxy_set_header X-Forwarded-Host \$host;
    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto \$scheme;
    proxy_set_header X-Real-IP \$remote_addr;
    add_header X-Frame-Options "SAMEORIGIN";
    add_header X-XSS-Protection "1; mode=block";
    proxy_set_header X-Client-IP \$remote_addr;
    proxy_set_header HTTP_X_FORWARDED_HOST \$remote_addr;

    #   odoo    log files
    access_log  /var/log/nginx/odoo-access.log;
    error_log       /var/log/nginx/odoo-error.log;

    #   increase    proxy   buffer  size
    proxy_buffers   16  64k;
    proxy_buffer_size   128k;

    proxy_read_timeout 900s;
    proxy_connect_timeout 900s;
    proxy_send_timeout 900s;

    #   force   timeouts    if  the backend dies
    proxy_next_upstream error   timeout invalid_header  http_500    http_502
    http_503;

    types {
    text/less less;
    text/scss scss;
    }

    #   enable  data    compression
    gzip    on;
    gzip_min_length 1100;
    gzip_buffers    4   32k;
    gzip_types  text/css text/less text/plain text/xml application/xml application/json application/javascript application/pdf image/jpeg image/png;
    gzip_vary   on;
    client_header_buffer_size 4k;
    large_client_header_buffers 4 64k;
    client_max_body_size 0;

    location / {
        proxy_pass http://127.0.0.1:$OE_PORT;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    location /longpolling {
        proxy_pass http://127.0.0.1:$LONGPOLLING_PORT;
    }
}
EOF"

# Enable and restart Nginx
sudo ln -s /etc/nginx/sites-available/odoo /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl restart nginx


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
echo "Nginx is installed and configured as a reverse proxy."
echo "Nginx location: /etc/nginx/site-available/odoo"
echo "Odoo Configuration file: /etc/${OE_CONFIG}.conf"
echo "Service management: sudo systemctl {start|stop|status} ${OE_CONFIG}"
echo "Update script: /home/ubuntu/update-odoo.sh"
echo "-----------------------------------------------------------"
