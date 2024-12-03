# Linux Proxy configuration
# Once a proxy is deployed it can be shutdown and templated for quicker onboarding

### Get OS version info which adds the $ID and $VERSION_ID variables
source /etc/os-release

### Download Microsoft signing key and repository
wget https://packages.microsoft.com/config/$ID/$VERSION_ID/packages-microsoft-prod.deb -O packages-microsoft-prod.deb

### Install Microsoft signing key and repository
sudo dpkg -i packages-microsoft-prod.deb

### Clean up
rm packages-microsoft-prod.deb

### Update packages
sudo apt update

### Block access to Ubuntu repository via upgrade ( Veeam KB 4658)
sudo sed -i '/^Unattended-Upgrade::Package-Blacklist {/a\        "dotnet-";' /etc/apt/apt.conf.d/50unattended-upgrades

### Install the runtime
sudo apt-get install -y dotnet-runtime-8.0
