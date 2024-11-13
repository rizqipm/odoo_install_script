# odoo-install-config.sh

# User and Directory Variables
OE_USER="odoo"
OE_HOME="/home/$OE_USER"
OE_HOME_EXT="$OE_HOME/odoo"

# Odoo Configuration Variables
OE_VERSION="16.0"
OE_SUPERADMIN="admin"
OE_CONFIG="${OE_USER}-server"
OE_PORT="8069"
LONGPOLLING_PORT="8072"

# Custom Add-ons Repository
CUSTOM_ADDONS_REPO="git@github.com:yourusername/odoo16_eform.git" # Ensure this is the SSH URL
GIT_EMAIL="odoo@example.com"


# Optional Domain and Email for Caddy SSL
DOMAIN="${DOMAIN:-}"
EMAIL="${EMAIL:-}"
