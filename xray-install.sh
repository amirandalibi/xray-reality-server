#!/bin/bash
mkdir -p /usr/local/share/xray/
echo "
+------------------------------------------------------+
|         Installing packages and service              |
|    sit tight, this will take a couple of minutes     |
+------------------------------------------------------+
"
sudo apt update
sudo apt -y install unzip qrencode

# optimise 'sysctl.conf' file for better performance
sudo echo "net.ipv4.tcp_keepalive_time = 90
net.ipv4.ip_local_port_range = 1024 65535
net.ipv4.tcp_fastopen = 3
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
fs.file-max = 65535000" >> /etc/sysctl.conf

# optimise 'limits.conf' file for better performance
sudo echo "* soft     nproc          655350
* hard     nproc          655350
* soft     nofile         655350
* hard     nofile         655350
root soft     nproc          655350
root hard     nproc          655350
root soft     nofile         655350
root hard     nofile         655350" >> /etc/security/limits.conf

# apply the changes
sudo sysctl -p

# generate the service file
sudo echo "[Unit]
Description=XTLS Xray-Core a VMESS/VLESS Server
After=network.target nss-lookup.target
[Service]
User=root
Group=root
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
NoNewPrivileges=true
ExecStart=/usr/local/bin/xray run -config /usr/local/share/xray/config.json
Restart=on-failure
RestartPreventExitStatus=23
StandardOutput=journal
LimitNPROC=100000
LimitNOFILE=1000000
[Install]
WantedBy=multi-user.target" > /etc/systemd/system/xray.service

# download latest geoasset file for blocking iranian websites
wget -P "/usr/local/share/xray" https://github.com/bootmortis/iran-hosted-domains/releases/latest/download/iran.dat

# download xray 1.8.3
wget https://github.com/XTLS/Xray-core/releases/download/v1.8.3/Xray-linux-64.zip

unzip Xray-linux-64.zip -d "/usr/local/bin" -x LICENSE README.md && \
     rm Xray-linux-64.zip && \
     mv /usr/local/bin/*.dat /usr/local/share/xray

# generate a random secret for generating a random uuid
secret=$(openssl rand -base64 10)

# generate uuid
export generateduuid=$(/usr/local/bin/xray uuid -i "$secret")

# enerate public and private keys and temporary save them
keypairs=$(/usr/local/bin/xray x25519)

# extract private key
export privatekey=$(echo "$keypairs" | awk NR==1'{print $3}')

# extract public key
publickey=$(echo "$keypairs" | awk NR==2'{print $3}')

# generate a short id
export shortid=$(openssl rand -hex 8)

# restart the service and enable auto-start
sudo systemctl daemon-reload && sudo systemctl enable xray

configfile=/usr/local/share/xray/config.json
touch $configfile

echo $(curl -L https://raw.githubusercontent.com/amirandalibi/xray-reality-server/main/config.json) | envsubst > $configfile

# start xray service
sudo systemctl start xray && sudo systemctl status xray

# server ip
vpsip=$(hostname -I | awk '{ print $1}')

# vps name
hostname=$('hostname')

echo "
+----------------------------------------+
|   Jot this info down for your record   |
+----------------------------------------+
"
# show connection information
echo "
REMARKS : $hostname
ADDRESS : $vpsip
PORT : 443
ID : $generateduuid
FLOW : xtls-rprx-vision
ENCRYPTION : none
NETWORK : tcp
HEAD TYPE : none
TLS : reality
SNI : www.google-analytics.com
FINGERPRINT : randomized
PUBLIC KEY : $publickey
SHORT ID : $shortid
==========
PRIVATE KEY : $privatekey
"

echo "
+----------------------+
|    config QR code    |
+----------------------+
"

serverconfig="vless://$generateduuid@$vpsip:443?security=reality&encryption=none&pbk=$publickey&headerType=none&fp=randomized&type=tcp&flow=xtls-rprx-vision&sni=www.google-analytics.com&sid=$shortid#$hostname"

# We output a qrcode to ease connection
qrencode -t ansiutf8 "$serverconfig"
