#!/bin/bash
set -e

# =======================
# CONFIGURATION
# =======================
GIT_EMAIL="your@email.com"                          # Set your Git email here
GIT_SSH_URL="git@github.com:yourorg/odoo10_kp3.git" # Set your SSH git URL here

NGINX_OD00_PORT=8069
NGINX_LONGPOLL_PORT=8072

# =======================
# STEP 1: GENERATE SSH KEY FOR GITHUB
# =======================
SSH_KEY_PATH="$HOME/.ssh/id_ed25519"

echo "Generating SSH key for user $USER..."
if [ ! -f "$SSH_KEY_PATH" ]; then
    ssh-keygen -t ed25519 -C "$GIT_EMAIL" -f "$SSH_KEY_PATH" -N ""
    echo "SSH key generated at $SSH_KEY_PATH"
else
    echo "SSH key already exists at $SSH_KEY_PATH"
fi

echo "Starting the SSH agent and adding the key..."
eval "$(ssh-agent -s)"
ssh-add "$SSH_KEY_PATH"

echo "The public key for $USER is shown below:"
echo "-------------------------------------------------"
cat "$SSH_KEY_PATH.pub"
echo "-------------------------------------------------"
echo "Please add this public key as a deploy key to your GitHub repository with read access."

# Prompt and pause until user replies with y/Y
while true; do
    read -p "Have you added the key to GitHub and want to continue? (y/n): " yn
    case $yn in
        [Yy]* ) break;;
        [Nn]* ) echo "Please add the key to GitHub and then continue...";;
        * ) echo "Please answer y or n.";;
    esac
done

# =======================
# STEP 1b: CLONE THE REPOSITORY
# =======================
REPO_NAME=$(basename -s .git "$GIT_SSH_URL")
if [ ! -d "$REPO_NAME/.git" ]; then
    echo "Cloning repository $GIT_SSH_URL into $REPO_NAME..."
    git clone "$GIT_SSH_URL"
else
    echo "Repository $REPO_NAME already exists, skipping clone."
fi

# =======================
# STEP 2: INSTALL DOCKER & NGINX
# =======================
echo "Removing any old/conflicting Docker or container packages..."
for pkg in docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc; do
    sudo apt-get remove -y $pkg || true
done

echo "Installing Docker Engine and Nginx..."
sudo apt-get update
sudo apt-get install -y ca-certificates curl nginx
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo \"\${UBUNTU_CODENAME:-\$VERSION_CODENAME}\") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update

sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

echo "Verifying Docker installation..."
sudo systemctl is-active --quiet docker && echo "Docker service is running."
sudo docker version && echo "Docker CLI is working."
sudo docker run --rm hello-world

if systemctl is-active --quiet nginx; then
    echo "Nginx service is running."
else
    echo "Nginx failed to start. Please check logs." >&2
    exit 1
fi

# =======================
# STEP 3: CREATE NGINX CONFIG FOR ODOO
# =======================
echo "Creating Nginx config for Odoo..."

sudo tee /etc/nginx/sites-available/odoo > /dev/null <<EOF
server {
    listen 80;

    server_tokens off;  # Security: hide nginx version

    proxy_set_header Host \$host;
    # Add Headers for odoo proxy mode
    proxy_set_header X-Forwarded-Host \$host;
    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto \$scheme;
    proxy_set_header X-Real-IP \$remote_addr;
    add_header X-Frame-Options "SAMEORIGIN";
    add_header X-XSS-Protection "1; mode=block";
    proxy_set_header X-Client-IP \$remote_addr;
    proxy_set_header HTTP_X_FORWARDED_HOST \$remote_addr;

    access_log  /var/log/nginx/odoo-access.log;
    error_log   /var/log/nginx/odoo-error.log;

    proxy_buffers       16  64k;
    proxy_buffer_size   128k;

    proxy_read_timeout 900s;
    proxy_connect_timeout 900s;
    proxy_send_timeout 900s;

    proxy_next_upstream error timeout invalid_header http_500 http_502 http_503;

    types {
        text/less less;
        text/scss scss;
    }

    gzip                on;
    gzip_min_length     1100;
    gzip_buffers        4   32k;
    gzip_types          text/css text/less text/plain text/xml application/xml application/json application/javascript application/pdf image/jpeg image/png;
    gzip_vary           on;
    client_header_buffer_size 4k;
    large_client_header_buffers 4 64k;
    client_max_body_size 0;

    location / {
        proxy_pass    http://127.0.0.1:$NGINX_OD00_PORT;
        proxy_redirect off;
    }

    location /longpolling {
        proxy_pass http://127.0.0.1:$NGINX_LONGPOLL_PORT;
    }

    location ~* \.(js|css|png|jpg|jpeg|gif|ico)\$ {
        expires 2d;
        proxy_pass http://127.0.0.1:$NGINX_OD00_PORT;
        add_header Cache-Control "public, no-transform";
    }

    location ~ /[a-zA-Z0-9_-]*/static/ {
        proxy_cache_valid 200 302 60m;
        proxy_cache_valid 404      1m;
        proxy_buffering    on;
        expires 864000;
        proxy_pass    http://127.0.0.1:$NGINX_OD00_PORT;
    }
}
EOF

sudo ln -sf /etc/nginx/sites-available/odoo /etc/nginx/sites-enabled/odoo
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t && sudo systemctl reload nginx

# =======================
# STEP 4: CREATE update-odoo.sh SCRIPT
# =======================
sudo tee /home/ubuntu/update-odoo.sh > /dev/null <<EOF
#!/bin/bash
set -e

echo -e "\\n---- Pull from repo ----"
cd "$REPO_NAME"
git pull

echo -e "\\n---- Rebuild odoo container ----"
docker compose build web

echo -e "\\n---- Restart odoo container ----"
docker compose -f docker-compose.yml -f production.yml restart

echo -e "\\n---- Done ----"
EOF

sudo chmod +x /home/ubuntu/update-odoo.sh
sudo chown ubuntu:ubuntu /home/ubuntu/update-odoo.sh

echo "-------------------------------------------------"
echo "INSTALLATION COMPLETE"
echo "Update script created at /home/ubuntu/update-odoo.sh for repo: $REPO_NAME"
echo "Nginx config created at /etc/nginx/sites-available/odoo"
echo "-------------------------------------------------"
