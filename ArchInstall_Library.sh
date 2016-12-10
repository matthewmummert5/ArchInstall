#!/bin/bash

#########################################################################################################
# PARTITION SYSTEM & MOUNT
#########################################################################################################
Partition_and_Format_Disk ()
{
	#wipe and create partitions
	echo -e "o\nw\n" | fdisk /dev/sda
	echo -e "n\np\n1\n\n+100mb\na\n\nn\np\n\n\n\n\nw\n" | fdisk /dev/sda
	partprobe /dev/sda

	#format partitions
	mkfs.ext4 /dev/sda1
	mkfs.ext4 /dev/sda2

	#mount filesystem
	mount /dev/sda1 /mnt
	mkdir /mnt/boot
	mount /dev/sda2 /mnt/boot
	
	echo "Formatting Complete..."
}

#########################################################################################################
# INSTALL ARCH
#########################################################################################################
Install_Arch ()
{
	packages=$1
	
	#Install OS packages
	pacstrap /mnt $packages --noconfirm
	
	echo "Installation Complete..."
}

#########################################################################################################
# CONFIGURE ARCH
#########################################################################################################
Configure_Arch ()
{
	OS_name=$1
	locale=$2
	timezone_region=$3
	timezone_city=$4
	request_new_root_password=$5
	
	#Generate Fstab
	genfstab -U /mnt >> /mnt/etc/fstab
	
	#Chroot into new install
	arch-chroot /mnt
	
	#Set hostname
	echo "$1" > /etc/hostname
	
	#Set locale
	sed -i '/' "$locale" '/s/^#//g' /etc/locale.gen
	echo "LANG=$locale" > /etc/locale.conf
	locale-gen
	
	#Set timezone
	ln -s /usr/share/zoneinfo/$timezone_region/$timezone_city /etc/localtime
	hwclock --systohc
	
	#Create new root password
	if [ "$request_new_root_password" == "yes" ]; then
		clear
		echo "Please enter root password:"
		passwd root
	fi
	
	#Get wireless networking packages
	pacman -S iw wpa_supplicant dialog --noconfirm

	echo "Configuration Complete..."
}


#########################################################################################################
# CONFIGURE PACMAN
#########################################################################################################
Configure_Pacman ()
{
	#Arguments
	eval country="$1"
	eval protocol="$2"
	eval rank_by="$3"
	eval repository="$4"
	
	#Install both HTTP and HTTPS mirrorlists
	if [ "$protocol" == "all" ]; then
	
		if [ "$country" == "All" ]; then
			
			reflector --verbose --protocol http --protocol https --sort $rank_by --save /etc/pacman.d/mirrorlist
			
		else
		
			reflector --verbose --country "$country" --protocol http --protocol https --sort $rank_by --save /etc/pacman.d/mirrorlist
		
		fi
		
	else
	
		if [ "$country" == "All" ]; then
		
			reflector --verbose --protocol $protocol --sort $rank_by --save /etc/pacman.d/mirrorlist
		
		else
	
			reflector --verbose --country "$country" --protocol $protocol --sort $rank_by --save /etc/pacman.d/mirrorlist
		
		fi
		
	fi
		
	#Select Repository
	if [ "$repository" == "stable" ]; then
		sed -i "/\[core\]/,/Include/"'s/^#//' /etc/pacman.conf
		sed -i "/\[extra\]/,/Include/"'s/^#//' /etc/pacman.conf
		sed -i "/\[community\]/,/Include/"'s/^#//' /etc/pacman.conf
		sed -i "/\[multilib\]/,/Include/"'s/^#//' /etc/pacman.conf
		sed -i "/\[testing\]/,/Include/"'s/^/#/' /etc/pacman.conf
		sed -i "/\[community-testing\]/,/Include/"'s/^/#/' /etc/pacman.conf
		sed -i "/\[multilib-testing\]/,/Include/"'s/^/#/' /etc/pacman.conf
	
	elif [ "$repository" == "testing" ]; then
		sed -i "/\[core]/,/Include/"'s/^/#/' /etc/pacman.conf
		sed -i "/\[extra]/,/Include/"'s/^/#/' /etc/pacman.conf
		sed -i "/\[community]/,/Include/"'s/^/#/' /etc/pacman.conf
		sed -i "/\[multilib]/,/Include/"'s/^/#/' /etc/pacman.conf
		sed -i "/\[testing]/,/Include/"'s/^#//' /etc/pacman.conf
		sed -i "/\[community-testing]/,/Include/"'s/^#//' /etc/pacman.conf
		sed -i "/\[multilib-testing]/,/Include/"'s/^#//' /etc/pacman.conf
	
	else
		echo "Invalid repository selected: $repository"
		exit
	
	fi
	
	#Refresh and repopulate pacman
	pacman-key --init
	pacman-key --refresh-key
	pacman-key --populate archlinux
	pacman -Syy
	pacman -Syu --noconfirm
	
	echo "Finished configuring pacman"
}

#########################################################################################################
# INSTALL BOOTLOADER
#########################################################################################################
Bootloader ()
{
	pacman -S grub --noconfirm
	grub-install --recheck /dev/sda
	grub-mkconfig -o /boot/grub/grub.cfg
	
	echo "Finished installing bootloader"
}

#########################################################################################################
# SECURITY
#########################################################################################################
Secure_OS()
{
	install_antivirus=$1
	install_firewall=$2
	install_firejail=$3
	
	#Install Antivirus
	if [ $install_antivirus == "yes" ]; then
	
		pacman -S clamav --noconfirm
		freshclam
		systemctl enable clamd.service
		systemctl start clamd.service
	
	fi
	
	#Install Firewall
	if [ $install_firewall == "yes" ]; then
	
		pacman -S ufw --noconfirm
		ufw enable
		systemctl enable ufw
		systemctl start ufw
	
	fi
	
	#Install Firejail
	if [ $install_firewall == "yes" ]; then
	
		pacman -S firejail --noconfirm
	
	fi
	
	echo "Finished securing OS..."
}



#########################################################################################################
# CREATE USERS
#########################################################################################################
Create_Users()
{
	usernames=$1
	addToSudo=$2
	newUserPass=$4
	
	#Download sudo
	pacman -S sudo --noconfirm
	
	#Create users
	for username in $usernames; do
	
		#Create user
		useradd -m -G wheel -s /bin/bash $username
		
		#Create new user password
		if [ "$newUserPass" == "yes" ]; then
			clear
			echo "Please enter password for user $username:"
			passwd $username
		fi
	
	done
	
	#Create users
	for username in $addToSudo; do
	
		#Add user to sudo
		if [ "$addToSudo" == "yes" ]; then
		
			echo "$username  ALL=(ALL:ALL) ALL" >> /etc/sudoers
		
		fi
		
	done
	
	echo "Finished adding user"
}
