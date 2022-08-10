#!/bin/bash
set -euo pipefail
check_root() {
	echo "---Mengecek Sistem Root---"
	if [[ $EUID -ne 0 ]]; 
    then
	   echo "[Error Step 1] Jalankan Script dengan Root (sudo su)"
	   exit 1
	else
       echo "[Step 1] Checking Root Access Complete"
    fi
	echo ""
	echo ""
}

check_update() {
	sudo apt update
	export $(cat .env | xargs)
}

check_iface() {
	echo "---Mengecek Interface Perangkat---"
	IfaceAll=$(ip --oneline link show up | grep -v "lo" | awk '{print $2}' | cut -d':' -f1 | cut -d'@' -f1)
	CountIface=$(wc -l <<< "${IfaceAll}")
	if [[ $CountIface -eq 1 ]]; then
		echo "[Step 2] Selected interface: "$IfaceAll
		LIFACE=$IfaceAll
	else
		echo "Terdapat Beberapa Interface yang tersedia, Mohon Pilih salah satu"
		for iface in $IfaceAll
		do 
			echo "[-] Daftar Interface: "$iface
		done
		echo "Silahkan ketik interface yang tersedia (contoh: eth0)"
		read -p "Interface: " LIFACE
		echo "[Step 2] Selected interface: "$LIFACE
	fi
	echo ""
	echo ""
}

install_suricata() {
	echo "---Melakukan Instalasi Suricata---"
	# install dependencies
	sudo apt -y install libpcre3 libpcre3-dbg libpcre3-dev build-essential autoconf automake libtool libpcap-dev \
	libnet1-dev libyaml-0-2 libyaml-dev zlib1g zlib1g-dev libmagic-dev libcap-ng-dev libjansson4 libjansson-dev pkg-config \
	rustc cargo libnetfilter-queue-dev geoip-bin geoip-database geoipupdate apt-transport-https libnetfilter-queue-dev \
        libnetfilter-queue1 libnfnetlink-dev tcpreplay

	# install with ubuntu package
	sudo add-apt-repository -y ppa:oisf/suricata-stable
	sudo apt update
	sudo apt -y install suricata suricata-dbg 
	
	# stop suricata
	sudo systemctl stop suricata

	echo "[Step 3] Berhasil menginstall Suricata"
	echo ""
	echo ""
}

conf_suricata(){
	echo "---Melakukan Konfigurasi Suricata---"
	# config suricata
	sudo mv /etc/suricata/suricata.yaml /etc/suricata/suricata.yaml.bak
	sudo cp conf/suricata.yaml /etc/suricata/
	sed -i "s/CHANGE-IFACE/$LIFACE/g" /etc/suricata/suricata.yaml
	# add support for cloud server type
	PUBLIC=$(curl -s ifconfig.me)
	LOCAL=$(hostname -I | cut -d' ' -f1)
	DEFIP="192.168.0.0/16,10.0.0.0/8,172.16.0.0/12"
	LOCIP="$LOCAL/24"

	if [[ $LOCAL = $PUBLIC ]];then
		sed -i "s~IP-ADDRESS~$LOCIP~" /etc/suricata/suricata.yaml
	else
		sed -i "s~IP-ADDRESS~$DEFIP~" /etc/suricata/suricata.yaml
	fi
	
	# update suricata rules with 'suricata-update' command
	# currently using rules source from 'Emerging Threats Open Ruleset'
	# -D command to specify directory from default value '/var/lib/suricata' to '/etc/suricata/'
	sudo suricata-update -D /etc/suricata/ enable-source et/open
	sudo suricata-update -D /etc/suricata/ update-sources
	# --no-merge command 'Do not merge the rules into a single rule file'
	# Detail on suricata-update command 'https://suricata-update.readthedocs.io/en/latest/update.html'
	sudo suricata-update -D /etc/suricata/ --no-merge
	sudo systemctl enable suricata
	sudo systemctl start suricata
	suricata -V
	echo "[Step 4] Berhasil Melakukan Konfigurasi Suricata"
	echo ""
	echo ""
}


install_filebeat(){
	echo "---Melakukan Instalasi Filebeat---"
	if [ -x "$(command -v filebeat)" ]; 
	then
		echo "[Step 5] Berhasil Menginstall Filebeat"
	else
		curl -L -O https://artifacts.elastic.co/downloads/beats/filebeat/filebeat-${ELASTICSEARCH_VERSION}-amd64.deb
		sudo dpkg -i filebeat-${ELASTICSEARCH_VERSION}-amd64.deb
		sudo cp /etc/filebeat/filebeat.yml /etc/filebeat/filebeat.yml.bak
		sudo rm filebeat-${ELASTICSEARCH_VERSION}-amd64.deb
		echo "[Step 5] Berhasil Menginstall Filebeat"
	fi
	echo ""
	echo ""
}

conf_filebeat(){
	echo "---Melakukan Konfigurasi Filebeat---"
	sudo cp conf/suricata.yml.disabled /etc/filebeat/modules.d/suricata.yml.disabled
	sudo filebeat modules enable suricata
	sudo cp /etc/filebeat/filebeat.yml /etc/filebeat/filebeat.yml.bak
	sudo cp conf/filebeat.yml /etc/filebeat/filebeat.yml
	sed -i "s/ELASTICSEARCH_HOST_PORT/$ELASTICSEARCH_HOST_PORT/g" /etc/filebeat/filebeat.yml
	sed -i "s/ELASTICSEARCH_USERNAME/$ELASTICSEARCH_USERNAME/g" /etc/filebeat/filebeat.yml
	sed -i "s/ELASTICSEARCH_PASSWORD/$ELASTICSEARCH_PASSWORD/g" /etc/filebeat/filebeat.yml
	sed -i "s/KIBANA_HOST_PORT/$KIBANA_HOST_PORT/g" /etc/filebeat/filebeat.yml
	sed -i "s/KIBANA_USERNAME/$KIBANA_USERNAME/g" /etc/filebeat/filebeat.yml
	sed -i "s/KIBANA_PASSWORD/$KIBANA_PASSWORD/g" /etc/filebeat/filebeat.yml
	systemctl restart filebeat
	echo "[Step 6] Berhasil Melakukan Konfigurasi Filebeat"
	echo ""
	echo ""
}

main(){
	check_root
	check_iface
	check_update
	install_suricata
	conf_suricata
	install_filebeat
	conf_filebeat
}

main()