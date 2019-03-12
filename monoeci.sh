#!/bin/bash

################################################
# Original Script by FranÃ§ois YoYae GINESTE - 03/04/2018
# For monoeciCore V0.12.2.3
# Amended by Foz72 due to recent install errors - 12/03/19
################################################

LOG_FILE=/tmp/monoeci_install.log

decho () {
  echo `date +"%H:%M:%S"` $1
  echo `date +"%H:%M:%S"` $1 >> $LOG_FILE
}

error() {
  local parent_lineno="$1"
  local message="$2"
  local code="${3:-1}"
  echo "Error on or near line ${parent_lineno}; exiting with status ${code}"
  exit "${code}"
}
trap 'error ${LINENO}' ERR

clear

cat <<'FIG'
 __  __                             _
|  \/  | ___  _ __   ___   ___  ___(_)
| |\/| |/ _ \| '_ \ / _ \ / _ \/ __| |
| |  | | (_) | | | | (_) |  __/ (__| |
|_|  |_|\___/|_| |_|\___/ \___|\___|_|
FIG

# Check for systemd
systemctl --version >/dev/null 2>&1 || { decho "systemd is required. Are you using Ubuntu 16.04?"  >&2; exit 1; }

# Check if executed as root user
if [[ $EUID -ne 0 ]]; then
	echo -e "This script has to be run as \033[1mroot\033[0m user"
	exit 1
fi

#print variable on a screen
decho "Make sure you double check before hitting enter !"

read -e -p "User that will run Monoeci core /!\ case sensitive /!\ : " whoami
if [[ "$whoami" == "" ]]; then
	decho "WARNING: No user entered, exiting !!!"
	exit 3
fi
if [[ "$whoami" == "root" ]]; then
	decho "WARNING: user root entered? It is recommended to use a non-root user, exiting !!!"
	exit 3
fi
read -e -p "Server IP Address : " ip
if [[ "$ip" == "" ]]; then
	decho "WARNING: No IP entered, exiting !!!"
	exit 3
fi
read -e -p "Masternode Private Key (e.g. 3bsTPBdDf3USqoAAnHmfmSyHqZ4fACkUDNezE7ZVKQyxEKiy8MK # THE KEY YOU GENERATED EARLIER) : " key
if [[ "$key" == "" ]]; then
	decho "WARNING: No masternode private key entered, exiting !!!"
	exit 3
fi
read -e -p "(Optional) Install Fail2ban? (Recommended) [Y/n] : " install_fail2ban
read -e -p "(Optional) Install UFW and configure ports? (Recommended) [Y/n] : " UFW

decho "Looking for any previous installations"
#stopping any monoeci services
pkill monoecid &> /dev/null || true

#delete monoeci files from usr/bin
rm -f /usr/bin/monoeci-cli &> /dev/null || true
rm -f /usr/bin/monoecid &> /dev/null || true
rm -f /usr/bin/monoeci-tx &> /dev/null || true

#delete sentinel folder from user home dir
\rm -r /home/$whoami/sentinel/ &> /dev/null || true

decho "Updating system and installing required packages."   

# update package and upgrade Ubuntu
apt-get -y update >> $LOG_FILE 2>&1
# Add Berkely PPA
decho "Installing bitcoin PPA..."

apt-get -y install software-properties-common >> $LOG_FILE 2>&1
apt-add-repository -y ppa:bitcoin/bitcoin >> $LOG_FILE 2>&1
apt-get -y update >> $LOG_FILE 2>&1

# Install required packages
decho "Installing base packages and dependencies..."

apt-get -y install sudo >> $LOG_FILE 2>&1
apt-get -y install wget >> $LOG_FILE 2>&1
apt-get -y install git >> $LOG_FILE 2>&1
apt-get -y install unzip >> $LOG_FILE 2>&1
apt-get -y install virtualenv >> $LOG_FILE 2>&1
apt-get -y install python-virtualenv >> $LOG_FILE 2>&1
apt-get -y install pwgen >> $LOG_FILE 2>&1
apt-get -y install libzmq3-dev >> $LOG_FILE 2>&1
apt-get -y install libboost1.58-all-dev >> $LOG_FILE 2>&1
apt-get -y install libminiupnpc-dev >> $LOG_FILE 2>&1
apt-get -y install libdb4.8-dev libdb4.8++-dev >> $LOG_FILE 2>&1
apt-get -y install libevent-pthreads-2.0-5 >> $LOG_FILE 2>&1

if [[ ("$install_fail2ban" == "y" || "$install_fail2ban" == "Y" || "$install_fail2ban" == "") ]]; then
	decho "Optional installs : fail2ban"
	cd ~
	apt-get -y install fail2ban >> $LOG_FILE 2>&1
	systemctl enable fail2ban >> $LOG_FILE 2>&1
	systemctl start fail2ban >> $LOG_FILE 2>&1
fi

if [[ ("$UFW" == "y" || "$UFW" == "Y" || "$UFW" == "") ]]; then
	decho "Optional installs : ufw"
	apt-get -y install ufw >> $LOG_FILE 2>&1
	ufw allow ssh/tcp >> $LOG_FILE 2>&1
	ufw allow sftp/tcp >> $LOG_FILE 2>&1
	ufw allow 24156/tcp >> $LOG_FILE 2>&1
	ufw allow 24157/tcp >> $LOG_FILE 2>&1
	ufw default deny incoming >> $LOG_FILE 2>&1
	ufw default allow outgoing >> $LOG_FILE 2>&1
	ufw logging on >> $LOG_FILE 2>&1
	ufw --force enable >> $LOG_FILE 2>&1
fi

decho "Create user $whoami (if necessary)"
#desactivate trap only for this command
trap '' ERR
getent passwd $whoami > /dev/null 2&>1
usermod -aG sudo $whoami

if [ $? -ne 0 ]; then
	trap 'error ${LINENO}' ERR
	adduser --disabled-password --gecos "" $whoami >> $LOG_FILE 2>&1
else
	trap 'error ${LINENO}' ERR
fi

#Create monoeci.conf
decho "Setting up monoeci Core" 
#Generating Random Passwords
user=`pwgen -s 16 1`
password=`pwgen -s 64 1`

echo 'Creating monoeci.conf...'
mkdir -p /home/$whoami/.monoeciCore/
cat << EOF > /home/$whoami/.monoeciCore/monoeci.conf
rpcuser=$user
rpcpassword=$password
rpcallowip=127.0.0.1
listen=1
server=1
daemon=1
maxconnections=24
masternode=1
masternodeprivkey=$key
externalip=$ip
addnode=94.177.187.150
addnode=118.27.35.22
addnode=45.63.23.222
addnode=139.99.172.53
addnode=37.46.134.162
addnode=167.160.185.68
addnode=149.28.123.234
addnode=51.15.242.133
addnode=45.76.90.116
addnode=85.198.140.75
addnode=155.94.174.13
addnode=192.161.176.95
addnode=194.135.91.107
addnode=199.247.0.118
addnode=45.32.205.105
addnode=123.111.141.215
addnode=176.31.106.35
addnode=45.63.90.77
addnode=45.77.85.207
addnode=45.32.252.55
addnode=139.99.196.171
addnode=209.250.230.219
addnode=85.198.140.70
addnode=51.15.101.105
addnode=51.15.82.14
EOF
chown -R $whoami:$whoami /home/$whoami

## Download and Install new bin
echo "Downloading new core and installing it"
wget https://github.com/monacocoin-net/monoeci-core/releases/download/v0.12.2.3/monoeciCore-0.12.2.3-linux64.tar.gz >> $LOG_FILE 2>&1
sudo tar xvf monoeciCore-0.12.2.3-linux64.tar.gz >> $LOG_FILE 2>&1
sudo cp monoecid /usr/bin/ >> $LOG_FILE 2>&1
sudo cp monoeci-cli /usr/bin/ >> $LOG_FILE 2>&1
sudo cp monoeci-tx /usr/bin/ >> $LOG_FILE 2>&1
#rm -rf monoeciCore-0.12.2 >> $LOG_FILE 2>&1

#Run monoecid as selected user
sudo -H -u $whoami bash -c 'monoecid' >> $LOG_FILE 2>&1

echo 'Monoeci Core prepared and launched'

sleep 10

#Setting up coin

decho "Setting up sentinel"

decho 'Downloading sentinel...'
#Install Sentinel
git clone https://github.com/monacocoin-net/sentinel.git /home/$whoami/sentinel >> $LOG_FILE 2>&1
chown -R $whoami:$whoami /home/$whoami/sentinel >> $LOG_FILE 2>&1

cd /home/$whoami/sentinel
echo 'Setting up dependencies...'
sudo -H -u $whoami bash -c 'virtualenv ./venv' >> $LOG_FILE 2>&1
sudo -H -u $whoami bash -c './venv/bin/pip install -r requirements.txt' >> $LOG_FILE 2>&1

#Deploy script to keep daemon alive
cat << EOF > /home/$whoami/monoecidkeepalive.sh
until monoecid; do
    echo "Monoecid crashed with error $?.  Restarting.." >&2
    sleep 1
done
EOF

chmod +x /home/$whoami/monoecidkeepalive.sh
chown $whoami:$whoami /home/$whoami/monoecidkeepalive.sh

#Setup crontab
echo "@reboot sleep 30 && /home/$whoami/monoecidkeepalive.sh" >> newCrontab
echo "* * * * * cd /home/$whoami/sentinel && ./venv/bin/python bin/sentinel.py >/dev/null 2>&1" >> newCrontab
crontab -u $whoami newCrontab >> $LOG_FILE 2>&1
rm newCrontab >> $LOG_FILE 2>&1

clear
decho "Starting your masternode"
echo ""
echo "PLEASE COPY THESE INSTRUCTIONS BELOW THEN WORK THROUGH THEM STEP BY STEP: "
echo "Now, wait for approx 5 mins for the Monoeci core to start up and get connections to the network "
echo "then enter the command: monoeci-cli getinfo "
echo "you should see the figure on the "blocks" entry start to increase "
echo "Check on the block explorer here: https://insight.monoeci.io/insight/blocks "
echo "and wait for your "blocks" number to match the highest one in link above "
echo "Now, you need to finally start your masternode in the following order: "
echo "1- Go to your windows/mac wallet and modify masternode.conf as required, then restart and from the Masternode tab"
echo "2- Select the newly created masternode and then click on start-alias."
echo "3- Then you can try the command 'monoeci-cli masternode status' to get the masternode status."

#su $whoami
#cd

