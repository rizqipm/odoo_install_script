# Odoo 16 Installation Script with Caddy Reverse Proxy

This guide will walk you through setting up an SSH key, adding it to your custom Odoo add-ons repository, and running the Odoo installation script.

## Prerequisites

- **Ubuntu server** with `wget`, `curl`, and `git` installed.
- Access to your **custom Odoo add-ons repository** on GitHub to add an SSH deploy key.

## Steps

### 1. Generate an SSH Key

Source: https://docs.github.com/en/authentication/connecting-to-github-with-ssh/generating-a-new-ssh-key-and-adding-it-to-the-ssh-agent?platform=linux

First, you’ll need to create an SSH key to access the custom add-ons repository.

```bash
# Generate an SSH key (leave the passphrase empty if preferred)
ssh-keygen -t ed25519 -C "your_email@example.com"
```

When you're prompted to "Enter a file in which to save the key", you can press Enter to accept the default file location.

When you're prompted to "Enter passphrase (empty for no passphrase):", you can press Enter so we don't use passphrase

This will generate a new SSH key pair:

    Public key: ~/.ssh/id_ed25519.pub
    Private key: ~/.ssh/id_ed25519

### 2. Add the SSH Key as a Deploy Key on GitHub

1. Open the GitHub repository for your custom add-ons (e.g., odoo16_eform).

2. Go to Settings > Deploy keys > Add deploy key.

3. Copy the public key to your clipboard:

```bash
cat ~/.ssh/id_ed25519.pub
```

4. In GitHub, paste the key into the Key field.

5. Give it a title like "Odoo Server Deploy Key" and Enable read-only access.

6. Click Add key.


### 3. Download the Installation Script

Use wget to download the installation script from your GitHub repository.

```bash
# Replace <your-repo> and <branch> with your repository details
wget https://github.com/rizqipm/odoo_install_script/raw/main/odoo-install.sh -O odoo-install.sh
```

### 4. Set Execute Permissions

Set the script as executable.
```bash
chmod +x odoo-install.sh
```

### 5. Run the Installation Script

Now you can execute the script to install Odoo, PostgreSQL, and Caddy as a reverse proxy. The script will also configure an update script in the ubuntu user’s home directory.

```bash
sudo ./odoo-install.sh
```

### 6. Post-Installation Information

After the installation completes, you’ll see details such as:

    The location of the Odoo configuration file.
    Instructions for managing the Odoo service with systemctl.
    Path to the Caddy configuration file.
    Location of the update script for pulling updates to custom add-ons.

## Additional Commands

    To manage the Odoo service:

```bash
sudo systemctl {start|stop|restart|status} odoo-server
```

To run the update script:

```bash
/home/ubuntu/update-odoo.sh
```
This installation sets up Odoo 16 as a service, reverse-proxied through Caddy with optional HTTPS, and includes a script for updating custom add-ons.
