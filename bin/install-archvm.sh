#!/bin/bash
set -euo pipefail
disk=$1
hostname=${disk%%.*}
if [ ! -f $disk ]; then
  echo 'Disk file not found!'
  exit 1
fi
sudo modprobe nbd max_part=16
sudo qemu-nbd -c /dev/nbd0 $disk --cache=unsafe --discard=unmap
sudo parted /dev/nbd0 mklabel gpt
sudo parted /dev/nbd0 mkpart BOOT fat32 0% 200MiB
sudo parted /dev/nbd0 set 1 esp on
sudo parted /dev/nbd0 mkpart ROOT ext4 200MiB 100%
sudo parted /dev/nbd0 print

sudo mkfs.fat -F32 /dev/nbd0p1
sudo mkfs.ext4 /dev/nbd0p2

mkdir -p /tmp/mnt
sudo mount /dev/nbd0p2 /tmp/mnt
sudo mkdir /tmp/mnt/boot
sudo mount /dev/nbd0p1 /tmp/mnt/boot

sudo pacstrap /tmp/mnt base linux linux-firmware openssh bash-completion networkmanager vi net-tools curl htop tree
sudo tee -a /tmp/mnt/etc/fstab << EOF
/dev/vda2 / ext4 rw,noatime 0 1
/dev/vda1 /boot vfat rw,noatime,fmask=0022,dmask=0022,codepage=437,iocharset=ascii,shortname=mixed,utf8,errors=remount-ro 0 2
EOF

sudo arch-chroot /tmp/mnt ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
sudo arch-chroot /tmp/mnt hwclock --systohc
sudo arch-chroot /tmp/mnt sed -i 's/#en_US.UTF/en_US.UTF/' /etc/locale.gen
sudo arch-chroot /tmp/mnt locale-gen
sudo arch-chroot /tmp/mnt bash -c 'echo LANG=en_US.UTF-8 > /etc/locale.conf'
sudo arch-chroot /tmp/mnt bash -c "echo $hostname > /etc/hostname"

sudo arch-chroot /tmp/mnt bash -c "echo 127.0.0.1 localhost >> /etc/hosts"
sudo arch-chroot /tmp/mnt bash -c "echo ::1 localhost >> /etc/hosts"
sudo arch-chroot /tmp/mnt bash -c "echo 127.0.1.1 $hostname.localdomain $hostname >> /etc/hosts"

sudo arch-chroot /tmp/mnt sed -i 's/MODULES=()/MODULES=(virtio virtio_blk virtio_pci virtio_net)/' /etc/mkinitcpio.conf
sudo arch-chroot /tmp/mnt mkinitcpio -P

sudo arch-chroot /tmp/mnt systemctl enable NetworkManager sshd
sudo arch-chroot /tmp/mnt mkdir /root/.ssh
cat ~/.ssh/id_rsa.pub | sudo tee /tmp/mnt/root/.ssh/authorized_keys

sudo arch-chroot /tmp/mnt mkdir -p /boot/EFI/BOOT
sudo arch-chroot /tmp/mnt cp /usr/lib/systemd/boot/efi/systemd-bootx64.efi /boot/EFI/BOOT/BOOTX64.EFI
sudo cp -r loader /tmp/mnt/boot/

sudo umount -R /tmp/mnt
sudo qemu-nbd -d /dev/nbd0
