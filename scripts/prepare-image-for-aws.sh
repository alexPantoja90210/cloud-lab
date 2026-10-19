#!/bin/bash
# CLOUD-38: prepare the rehost-src RHEL image for AWS (run inside the VM as root, after the Azure leg).
# Idempotent. Prints a verification block at the end. Does not touch the EFI partition: it only reports.
set -u

echo "== 1. cloud-init datasource: Azure -> EC2"
rm -f /etc/cloud/cloud.cfg.d/91-azure_datasource.cfg
printf 'datasource_list: [ Ec2, None ]\n' > /etc/cloud/cloud.cfg.d/90-aws-datasource.cfg
rm -f /etc/cloud/cloud-init.disabled

echo "== 2. Azure agent off"
systemctl disable waagent 2>&1 | tail -1

echo "== 3. NVMe and ENA drivers in the boot image"
printf 'add_drivers+=" nvme nvme_core ena "\n' > /etc/dracut.conf.d/aws.conf
dracut -f --kver "$(uname -r)"
echo "-- drivers found in the boot image:"
lsinitrd | grep -oE 'nvme[a-z_-]*|ena\b|hv_[a-z_]*' | sort -u

echo "== 4. EFI fallback binary (report only)"
ls -l /boot/efi/EFI/BOOT/ 2>&1

echo "== 5. state"
echo -n "cloud-init: "; systemctl is-enabled cloud-init
echo -n "waagent:    "; systemctl is-enabled waagent
cat /etc/cloud/cloud.cfg.d/90-aws-datasource.cfg
ls /etc/cloud/cloud.cfg.d/ | grep -c azure | sed 's/^/azure datasource files left: /'
echo "== done"
