#!/bin/bash

# Source configuration variables
source ./odoo-install-config.sh

# SSH Key Path
SSH_KEY_PATH="$OE_HOME/.ssh/id_ed25519"

# Step 1: Create the odoo user with a home directory
echo "Creating the $OE_USER user with a home directory..."
sudo adduser --system --home $OE_HOME --shell /bin/bash --group $OE_USER
sudo mkdir -p $OE_HOME/.ssh
sudo chown -R $OE_USER:$OE_USER $OE_HOME
echo "User $OE_USER created successfully."

# Step 2: Generate SSH key for the odoo user
echo "Generating SSH key for the $OE_USER user..."
sudo -u $OE_USER ssh-keygen -t ed25519 -C "$GIT_EMAIL" -f $SSH_KEY_PATH -N ""
echo "SSH key generated at $SSH_KEY_PATH"

echo "Starting the SSH agent and adding the key..."
sudo -u $OE_USER bash -c "eval \"\$(ssh-agent -s)\" && ssh-add $SSH_KEY_PATH"

# Step 3: Display the public key and prompt the user to add it as a GitHub deploy key
echo "The public key for the $OE_USER user is shown below:"
echo "-------------------------------------------------"
sudo cat $SSH_KEY_PATH.pub
echo "-------------------------------------------------"
echo "Please add this public key as a deploy key to your GitHub repository with read access."
echo "Once you have added the key, proceed with the next script to complete the installation."
