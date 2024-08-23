#################### VM parameters ####################
#ISO_NAME="ubuntu-20.04.6-live-server-amd64.iso"
ISO_NAME="ubuntu-22.04.3-live-server-amd64.iso"
RAM="6384MiB"
CORE="4"
DISK="45GiB"
VM_NAME="web3-magma-orc8r"
TEMPLATE="Ubuntu Focal Fossa 20.04"
STORAGE="5a1d0031-7ab7-5e00-4025-26d9fbe53f84"
NETWORK_UUID="5da29e5b-3f0c-abaf-7094-f059083d8725"
########################################################

if [ $1 == "create" ]; then

    echo "Creating vm: ${RAM} of RAM | $CORE core | ${DISK} of disk"
    vm_uuid=$(xe vm-install template="$TEMPLATE" new-name-label="$VM_NAME" sr-uuid=$STORAGE)
    echo ""
    echo "VM uuid $vm_uuid"
    echo ""

    vm_disk_uuid=$(xe vm-disk-list uuid=$vm_uuid | grep 'uuid ( RO)' | awk 'NR==2 {print $NF}')
    #echo "VDI uuid $vm_disk_uuid"

    echo "ISO association..."
    xe vm-cd-add uuid=$vm_uuid cd-name=$ISO_NAME device=1

    echo "BIOS order..."
    xe vm-param-set HVM-boot-policy="BIOS order" uuid=$vm_uuid

    echo "Creating network interface..."
    int_uuid=$(xe vif-create vm-uuid=$vm_uuid network-uuid=$NETWORK_UUID device=0)
    int_uuid=$(xe vif-create vm-uuid=$vm_uuid network-uuid=$NETWORK_UUID device=1)

    echo "Setting RAM size..."
    xe vm-memory-limits-set dynamic-max=$RAM dynamic-min=$RAM static-max=$RAM static-min=512MiB uuid=$vm_uuid

    echo "Setting disk size..."
    xe vdi-resize uuid=$vm_disk_uuid disk-size=$DISK

    echo "Setting CPU core..."
    xe vm-param-set uuid=$vm_uuid VCPUs-max=$CORE

    xe vm-param-set uuid=$vm_uuid VCPUs-at-startup=$CORE

    echo "Starting up VM..."
    xe vm-start uuid=$vm_uuid

    ld=$(list_domains | grep $vm_uuid | awk '{print $1}')

    echo "VM started, please acess VNC console for SO installation. VNC:$ld"

    echo "ssh -f -N web3 -L  8889:localhost:9000"

    socat TCP-LISTEN:9000 UNIX-CONNECT:/var/run/xen/vnc-$ld

    xe vm-cd-eject uuid=$vm_uuid
    xe vm-cd-insert cd-name=guest-tools.iso uuid=$vm_uuid

    echo ""

    echo "Post-installation:"
    echo "#--------------------------------#"
    echo "Guest tools and disk full:"
    echo "sudo mount /dev/cdrom /mnt && sudo /mnt/Linux/install.sh && sudo lvextend -l +100%FREE /dev/ubuntu-vg/ubuntu-lv && sudo resize2fs /dev/ubuntu-vg/ubuntu-lv"
    echo "#--------------------------------#"

    echo ""
    echo "Done!"

elif [ $1 == "destroy" ]; then

    echo "Shutdown of VM with uuid: $2"
    xe vm-shutdown uuid=$2

    echo "Deleting VDI..."
    vm_disk_to_delete=$(xe vm-disk-list vm=$2 | grep 'uuid ( RO)' | awk 'NR==2 {print $NF}')

    xe vdi-destroy uuid=$vm_disk_to_delete

    echo "Destroying VM..."
    xe vm-destroy uuid=$2

    echo ""
    echo "Done!"

else
    echo "Invalid parameter"
fi
