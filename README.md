## NOTES
Pastikan sudah menginstall agent-manager sebelum menginstall agent-nids<br>

## Pre-install
sudo apt get update<br>
sudo apt install git

## Clone Repository
git clone https://github.com/insidentil-id/agent-nids<br>
cd agent-nids<br>
chmod +x install.sh

## Change env File
Ubah semua komponen pada env file, sesuaikan dengan aset yang dimiliki<br>
nano .env

## Running installer dan tunggu hingga selesai
sudo su<br>
./install.sh

## Credit
Script By Cyber Threat Hunting Team<br>
Direktorat Operasi Keamanan Siber<br>
Special Thanks to Team: maNDayUGIikHSanNaLonAldAvIDSUBkHAnREndRAalSItAdAFi