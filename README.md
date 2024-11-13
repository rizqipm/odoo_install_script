Here’s the updated `README.md` with the new two-step script setup:


# Odoo 16 Installation Script with Caddy Reverse Proxy

This guide will walk you through setting up an SSH key, adding it to your custom Odoo add-ons repository, and running the Odoo installation script.

## Prerequisites

- **Ubuntu server** with `wget`, `curl`, and `git` installed.
- Access to your **custom Odoo add-ons repository** on GitHub to add an SSH deploy key.

## Steps

### 1. Download the Scripts and Configuration File

Use `wget` to download the required scripts and configuration file from your GitHub repository.

```bash
# Replace <your-repo> and <branch> with your repository details
wget https://github.com/yourusername/<your-repo>/raw/<branch>/create-odoo-user.sh
wget https://github.com/yourusername/<your-repo>/raw/<branch>/install-odoo.sh
wget https://github.com/yourusername/<your-repo>/raw/<branch>/odoo-install-config.sh
```

### 2. Edit the Configuration File

Before running the scripts, open the `odoo-install-config.sh` file to adjust the configuration variables as needed. Specifically, you may want to edit:

- **DOMAIN**: The domain name for your Odoo server (e.g., `odoo.yourdomain.com`). Leave blank to use the server’s IP address.
- **EMAIL**: Your email address for SSL certificate registration with Let's Encrypt.
- **CUSTOM_ADDONS_REPO**: URL to your custom add-ons repository.
- **OE_SUPERADMIN**: Set the Odoo super admin password, which will be used in the configuration file.
- Other variables as needed to customize the installation, such as Odoo version or ports.

Open the file in a text editor to make changes:

```bash
nano odoo-install-config.sh
```

### 3. Set Execute Permissions for the Scripts

Make both scripts executable.

```bash
chmod +x create-odoo-user.sh install-odoo.sh
```

### 4. Run the First Script to Create the Odoo User and SSH Key

Run the `create-odoo-user.sh` script to create the `odoo` user, generate an SSH key, and display the public key for use as a GitHub deploy key.

```bash
./create-odoo-user.sh
```

After running this script:
1. Copy the displayed public key.
2. Go to your custom add-ons GitHub repository.
3. Navigate to **Settings > Deploy keys > Add deploy key**.
4. Paste the public key into the **Key** field, give it a name (e.g., "Odoo Server Deploy Key"), and enable **Allow write access** if needed.
5. Click **Add key**.

### 5. Run the Second Script to Install Odoo and Configure the System

After adding the SSH deploy key, run the `install-odoo.sh` script to install Odoo, PostgreSQL, and Caddy as a reverse proxy. This script will also set up an update script in the `ubuntu` user’s home directory.

```bash
sudo ./install-odoo.sh
```

### 6. Post-Installation Information

After the installation completes, you’ll see details such as:

- The location of the **Odoo configuration file**.
- Instructions for managing the Odoo service with `systemctl`.
- Path to the **Caddy configuration file**.
- Location of the **update script** for pulling updates to custom add-ons.

## Additional Commands

To manage the Odoo service:

```bash
sudo systemctl {start|stop|restart|status} odoo-server
```

To run the update script:

```bash
/home/ubuntu/update-odoo.sh
```
