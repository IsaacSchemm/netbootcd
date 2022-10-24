#!/bin/sh
set -e
## nbscript.sh - Download netboot images and launch them with kexec
## Copyright (C) 2022 Isaac Schemm <isaacschemm@gmail.com>
## Devuan added by Jonathan A. Wingo Oct 2022 <spcwingo1@gmail.com>
##
## This program is free software; you can redistribute it and/or
## modify it under the terms of the GNU General Public License
## as published by the Free Software Foundation; either version 2
## of the License, or (at your option) any later version.
##
## This program is distributed in the hope that it will be useful,
## but WITHOUT ANY WARRANTY; without even the implied warranty of
## MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
## GNU General Public License for more details.
##
## You should have received a copy of the GNU General Public License
## along with this program; if not, write to the Free Software
## Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
##
## The full text of the GNU GPL, versions 2 or 3, can be found at
## <http://www.gnu.org/copyleft/gpl.html>, on the NetbootCD site at
## <http://netbootcd.tuxfamily.org>, or on the CD itself.

TITLE="NetbootCD Script 11.1.4 - May 23, 2022"

getversion ()
{
	#This function reads the version the user selected from /tmp/nb-version and stores it in the VERSION variable, then deletes /tmp/nb-version.
	VERSION=$(cat /tmp/nb-version)
	if [ $VERSION = "Manual" ];then
		dialog --backtitle "$TITLE" --inputbox "Specify your preferred version here.\nFor Ubuntu and Debian, use the codename. For other distributions, use the version number." 11 54 2>/tmp/nb-version
		VERSION=$(cat /tmp/nb-version)
	fi
	rm /tmp/nb-version
}


askforopts ()
{
#Extra kernel options can be useful in some cases; i.e. hardware problems, Debian preseeding, or maybe you just want to utilise your whole 1280x1024 monitor (use: vga=794).
dialog --backtitle "$TITLE" --inputbox "Would you like to pass any extra kernel options?\n(Note: it is OK to leave this field blank)" 9 64 2>/tmp/nb-custom
}

probe_and_provision () {
provisionpath=""
provisionscript="nbprovision.sh"
mntpath="/mnt/cdrom"

skip_probe=$(cat /proc/cmdline|grep 'nb_noprobe=1')
if [ "$skip_probe" == "" ]; then
mkdir -p $mntpath
for dev in /dev/cd* /dev/sc* /dev/sg* /dev/sr*; do
	mountable=$(blkid $dev)
	mounted=$(cat /proc/mounts |grep "$mntpath")
	if [ "$mountable" != "" ] && [ "$mounted" = "" ]; then
		mount $dev $mntpath
		if [ -f $mntpath/$provisionscript ]; then
			provisionpath=$mntpath/$provisionscript
			break
		fi
		umount -f $mntpath
	fi
done

if [ "$provisionpath" != "" ]; then
	echo "Starting provisioning from local disk..."
	sh $provisionpath
	umount -f $mntpath
fi
# skip_probe
fi
}


downloadandrun ()
{
if wget -O /tmp/nbscript.sh $1;then
	chmod +x /tmp/nbscript.sh
	exec /tmp/nbscript.sh
else
	rm /tmp/nbscript.sh
	echo "Downloading the new script was not successful."
	return 1
fi

}

installmenu ()
{
#Ask the user to choose a distro, save the choice to /tmp/nb-distro
dialog --backtitle "$TITLE" --menu "Choose a distribution:" 20 70 13 \
ubuntu64 " (amd64) Ubuntu [d-i]" \
ubuntu "  (i386) Ubuntu [d-i]" \
debian64 " (amd64) Debian GNU/Linux" \
debian "  (i386) Debian GNU/Linux" \
debiandaily64 " (amd64) Debian GNU/Linux - daily installers" \
debiandaily "  (i386) Debian GNU/Linux - daily installers" \
devuan "  (i386) Devuan GNU/Linux" \
devuan64 " (amd64) Devuan GNU/Linux" \
fedora64 "(x86_64) Fedora" \
opensuse64 "(x86_64) openSUSE" \
opensuse "  (i386) openSUSE" \
mageia64 "(x86_64) Mageia" \
mageia "  (i386) Mageia" \
rhel-type-8-64 "(x86_64) AlmaLinux 8 / CentOS 8 / Rocky Linux 8" \
rhel-type-7-64 "(x86_64) CentOS 7 and Scientific Linux 7" \
rhel-type-6-64 "(x86_64) CentOS 6 and Scientific Linux 6" \
rhel-type-6 "  (i386) CentOS 6 and Scientific Linux 6" \
slackware "         Slackware" 2>/tmp/nb-distro
#Read their choice, save it, and delete the old file
DISTRO=$(cat /tmp/nb-distro)
rm /tmp/nb-distro
#Now to check which distro the user picked.
if [ $DISTRO = "ubuntu" ];then
	#Ask about version
	dialog --menu "Choose a system to install:" 20 70 13 \
	bionic "Ubuntu 18.04 LTS" \
	xenial "Ubuntu 16.04 LTS" \
	Manual "Manually enter a version to install" 2>/tmp/nb-version
	#Run the getversion() function above
	getversion

	#Set the URL to download the kernel and initrd from. The server used here is archive.ubuntu.com.
	KERNELURL="http://archive.ubuntu.com/ubuntu/dists/$VERSION-updates/main/installer-i386/current/images/netboot/ubuntu-installer/i386/linux"
	INITRDURL="http://archive.ubuntu.com/ubuntu/dists/$VERSION-updates/main/installer-i386/current/images/netboot/ubuntu-installer/i386/initrd.gz"
	# Test if distro-updates exists
	if ! wget --spider -q $KERNELURL; then # fallback to known distro
		KERNELURL="http://archive.ubuntu.com/ubuntu/dists/$VERSION/main/installer-i386/current/images/netboot/ubuntu-installer/i386/linux"
		INITRDURL="http://archive.ubuntu.com/ubuntu/dists/$VERSION/main/installer-i386/current/images/netboot/ubuntu-installer/i386/initrd.gz"
	fi
	#These options are good for all Ubuntu installers.
	echo -n 'vga=normal quiet '>>/tmp/nb-options
	#If the user wants a command-line install, then add some more kernel arguments. The CLI install is akin to "standard system" in Debian.
	if dialog --yesno "Would you like to install language packs?\n(Choose no for a command-line system.)" 7 43;then
		#These arguments appear to just prevent the system from installing language packs. Not sure if they work, but Ubuntu's mini.iso has them.
		echo -n 'tasks=standard pkgsel/language-pack-patterns= pkgsel/install-language-support=false'>>/tmp/nb-options
	fi
fi
if [ $DISTRO = "ubuntu64" ];then
	#Ask about version
	dialog --menu "Choose a system to install:" 20 70 13 \
	focal "Ubuntu 20.04 LTS" \
	bionic "Ubuntu 18.04 LTS" \
	xenial "Ubuntu 16.04 LTS" \
	Manual "Manually enter a version to install" 2>/tmp/nb-version
	#Run the getversion() function above
	getversion

	#Set the URL to download the kernel and initrd from. The server used here is archive.ubuntu.com.
	KERNELURL="http://archive.ubuntu.com/ubuntu/dists/$VERSION-updates/main/installer-amd64/current/images/netboot/ubuntu-installer/amd64/linux"
	INITRDURL="http://archive.ubuntu.com/ubuntu/dists/$VERSION-updates/main/installer-amd64/current/images/netboot/ubuntu-installer/amd64/initrd.gz"
	# Test if distro-updates exists
	if ! wget --spider -q $KERNELURL; then # fallback to known distro
		KERNELURL="http://archive.ubuntu.com/ubuntu/dists/$VERSION/main/installer-amd64/current/images/netboot/ubuntu-installer/amd64/linux"
		INITRDURL="http://archive.ubuntu.com/ubuntu/dists/$VERSION/main/installer-amd64/current/images/netboot/ubuntu-installer/amd64/initrd.gz"
	fi
	if ! wget --spider -q $KERNELURL; then # try new path
		KERNELURL="http://archive.ubuntu.com/ubuntu/dists/$VERSION/main/installer-amd64/current/legacy-images/netboot/ubuntu-installer/amd64/linux"
		INITRDURL="http://archive.ubuntu.com/ubuntu/dists/$VERSION/main/installer-amd64/current/legacy-images/netboot/ubuntu-installer/amd64/initrd.gz"
	fi
	#These options are good for all Ubuntu installers.
	echo -n 'vga=normal quiet '>>/tmp/nb-options
	#If the user wants a command-line install, then add some more kernel arguments. The CLI install is akin to "standard system" in Debian.
	if dialog --yesno "Would you like to install language packs?\n(Choose no for a command-line system.)" 7 43;then
		echo -n 'tasks=standard pkgsel/language-pack-patterns= pkgsel/install-language-support=false'>>/tmp/nb-options
	fi
fi
if [ $DISTRO = "debian" ];then
	dialog --backtitle "$TITLE" --menu "Choose a system to install:" 20 70 13 \
	bullseye "Debian 11" \
	buster "Debian 10" \
	stretch "Debian 9" \
	jessie "Debian 8" \
	stable "Debian stable" \
	testing "Debian testing" \
	Manual "Manually enter a version to install" 2>/tmp/nb-version
	getversion
	KERNELURL="http://http.us.debian.org/debian/dists/$VERSION/main/installer-i386/current/images/netboot/debian-installer/i386/linux"
	INITRDURL="http://http.us.debian.org/debian/dists/$VERSION/main/installer-i386/current/images/netboot/debian-installer/i386/initrd.gz"
	echo -n 'vga=normal quiet '>>/tmp/nb-options
	#Testing and unstable use the same kernel. See: https://wiki.debian.org/DebianUnstable#How_do_I_install_Sid.3F
fi
if [ $DISTRO = "debian64" ];then
	dialog --backtitle "$TITLE" --menu "Choose a system to install:" 20 70 13 \
	bullseye "Debian 11" \
	buster "Debian 10" \
	stretch "Debian 9" \
	jessie "Debian 8" \
	stable "Debian stable" \
	testing "Debian testing" \
	Manual "Manually enter a version to install" 2>/tmp/nb-version
	getversion
	KERNELURL="http://http.us.debian.org/debian/dists/$VERSION/main/installer-amd64/current/images/netboot/debian-installer/amd64/linux"
	INITRDURL="http://http.us.debian.org/debian/dists/$VERSION/main/installer-amd64/current/images/netboot/debian-installer/amd64/initrd.gz"
	echo -n 'vga=normal quiet" '>>/tmp/nb-options
fi
if [ $DISTRO = "debiandaily" ];then
	dialog --backtitle "$TITLE" --menu "Choose a priority level:" 20 70 13 \
	high "Default" \
	medium "Show installation menu" \
	low "Expert mode" 2>/tmp/nb-version
	getversion
	KERNELURL="http://d-i.debian.org/daily-images/i386/daily/netboot/debian-installer/i386/linux"
	INITRDURL="http://d-i.debian.org/daily-images/i386/daily/netboot/debian-installer/i386/initrd.gz"
	echo -n 'vga=normal quiet '>>/tmp/nb-options
	echo -n "priority=$VERSION ">>/tmp/nb-options
fi
if [ $DISTRO = "debiandaily64" ];then
	dialog --backtitle "$TITLE" --menu "Choose a system to install:" 20 70 13 \
	high "Default" \
	medium "Show installation menu" \
	low "Expert mode" 2>/tmp/nb-version
	getversion
	KERNELURL="http://d-i.debian.org/daily-images/amd64/daily/netboot/debian-installer/amd64/linux"
	INITRDURL="http://d-i.debian.org/daily-images/amd64/daily/netboot/debian-installer/amd64/initrd.gz"
	echo -n 'vga=normal quiet '>>/tmp/nb-options
	echo -n "priority=$VERSION ">>/tmp/nb-options
fi
if [ $DISTRO = "devuan" ];then
	dialog --backtitle "$TITLE" --menu "Choose a system to install:" 20 70 13 \
	chimaera "Devuan chimaera" \
	ceres "Devuan ceres" \
	Manual "Manually enter a version to install" 2>/tmp/nb-version
	getversion
	KERNELURL="https://pkgmaster.devuan.org/devuan/dists/$VERSION/main/installer-i386/current/images/netboot/debian-installer/i386/linux"
	INITRDURL="https://pkgmaster.devuan.org/devuan/dists/$VERSION/main/installer-i386/current/images/netboot/debian-installer/i386/initrd.gz"
	echo -n 'vga=normal quiet '>>/tmp/nb-options
fi
if [ $DISTRO = "devuan64" ];then
	dialog --backtitle "$TITLE" --menu "Choose a system to install:" 20 70 13 \
	chimaera "Devuan chimaera" \
	ceres "Devuan ceres"\
	Manual "Manually enter a version to install" 2>/tmp/nb-version
	getversion
	KERNELURL="https://pkgmaster.devuan.org/devuan/dists/$VERSION/main/installer-amd64/current/images/netboot/debian-installer/amd64/linux"
	INITRDURL="https://pkgmaster.devuan.org/devuan/dists/$VERSION/main/installer-amd64/current/images/netboot/debian-installer/amd64/initrd.gz"
	echo -n 'vga=normal quiet" '>>/tmp/nb-options
fi
if [ $DISTRO = "fedora64" ];then
	dialog --backtitle "$TITLE" --menu "Choose a system to install:" 20 70 13 \
	releases/36/Server "Fedora 36" \
	releases/35/Server "Fedora 35" \
	releases/34/Server "Fedora 34" \
	development/rawhide "Rawhide" \
	Manual "Manually enter a version to install" 2>/tmp/nb-version
	getversion
	#Ask the user which server to use (the installer doesn't have a built-in list like Ubuntu and Debian do.)
	dialog --inputbox "Where do you want to install Fedora from?" 8 70 "http://mirrors.kernel.org/fedora/$VERSION/x86_64/os/" 2>/tmp/nb-server
	KERNELURL="$(cat /tmp/nb-server)/images/pxeboot/vmlinuz"
	INITRDURL="$(cat /tmp/nb-server)/images/pxeboot/initrd.img"
	echo -n "inst.stage2=$(cat /tmp/nb-server)" >>/tmp/nb-options
	rm /tmp/nb-server
fi
if [ $DISTRO = "opensuse" ];then
	dialog --backtitle "$TITLE" --menu "Choose a system to install:" 20 70 13 \
	tumbleweed "openSUSE Tumbleweed" \
	Manual "Manually enter a version to install" 2>/tmp/nb-version
	getversion
	#All versions of openSUSE are in the "distribution" folder, except for factory/tumbleweed.
	if [ $VERSION != "tumbleweed" ];then
		VERSION=distribution/$VERSION
	fi
	KERNELURL="http://download.opensuse.org/$VERSION/repo/oss/boot/i386/loader/linux"
	INITRDURL="http://download.opensuse.org/$VERSION/repo/oss/boot/i386/loader/initrd"
	#These options are common to openSUSE.
	echo -n 'splash=silent showopts '>>/tmp/nb-options
	#Ask the user which server to use (the installer doesn't have a built-in list like Ubuntu and Debian do.)
	dialog --inputbox "Where do you want to install openSUSE from?" 8 70 http://download.opensuse.org/$VERSION/repo/oss 2>/tmp/nb-server
	echo -n "install=$(cat /tmp/nb-server)" >>/tmp/nb-options
	rm /tmp/nb-server
fi
if [ $DISTRO = "opensuse64" ];then
	dialog --backtitle "$TITLE" --menu "Choose a system to install:" 20 70 13 \
	tumbleweed "openSUSE Tumbleweed" \
	leap/15.3 "openSUSE Leap 15.3" \
	Manual "Manually enter a version to install" 2>/tmp/nb-version
	getversion
	#All versions of openSUSE are in the "distribution" folder, except for factory/tumbleweed.
	if [ $VERSION != "tumbleweed" ];then
		VERSION=distribution/$VERSION
	fi
	KERNELURL="http://download.opensuse.org/$VERSION/repo/oss/boot/x86_64/loader/linux"
	INITRDURL="http://download.opensuse.org/$VERSION/repo/oss/boot/x86_64/loader/initrd"
	#These options are common to openSUSE.
	echo -n 'splash=silent showopts '>>/tmp/nb-options
	#Ask the user which server to use (the installer doesn't have a built-in list like Ubuntu and Debian do.)
	dialog --inputbox "Where do you want to install openSUSE from?" 8 70 http://download.opensuse.org/$VERSION/repo/oss 2>/tmp/nb-server
	echo -n "install=$(cat /tmp/nb-server)" >>/tmp/nb-options
	rm /tmp/nb-server
fi
if [ $DISTRO = "mageia" ];then
	dialog --backtitle "$TITLE" --menu "Choose a system to install:" 20 70 13 \
	8 "Mageia 8" \
	cauldron "Mageia cauldron" \
	Manual "Manually enter a version to install" 2>/tmp/nb-version
	getversion
	KERNELURL="http://mirrors.kernel.org/mageia/distrib/$VERSION/i586/isolinux/i386/vmlinuz"
	INITRDURL="http://mirrors.kernel.org/mageia/distrib/$VERSION/i586/isolinux/i386/all.rdz"
	echo -n 'automatic=method:http' >>/tmp/nb-options
fi
if [ $DISTRO = "mageia64" ];then
	dialog --backtitle "$TITLE" --menu "Choose a system to install:" 20 70 13 \
	8 "Mageia 8" \
	cauldron "Mageia cauldron" \
	Manual "Manually enter a version to install" 2>/tmp/nb-version
	getversion
	KERNELURL="http://mirrors.kernel.org/mageia/distrib/$VERSION/x86_64/isolinux/x86_64/vmlinuz"
	INITRDURL="http://mirrors.kernel.org/mageia/distrib/$VERSION/x86_64/isolinux/x86_64/all.rdz"
	echo -n 'automatic=method:http' >>/tmp/nb-options
fi
if [ $DISTRO = "rhel-type-8-64" ];then
	dialog --backtitle "$TITLE" --menu "Choose a system to install:" 20 70 13 \
	a_8 "Latest version of AlmaLinux 8" \
	c_8 "Latest version of CentOS 8" \
	r_8 "Latest version of Rocky Linux 8" \
	Manual "Manually enter a version to install (prefix with a_, c_, or r_)" 2>/tmp/nb-version
	getversion
	TYPE=$(echo $VERSION|head -c 1)
	VERSION=$(echo $VERSION|tail -c +3)
	#Ask the user which server to use (the installer doesn't have a built-in list like Ubuntu and Debian do.)
	if [ $TYPE = a ];then
		dialog --inputbox "Where do you want to install AlmaLinux OS from?" 8 70 "http://repo.almalinux.org/almalinux/$VERSION/BaseOS/x86_64/os" 2>/tmp/nb-server
	elif [ $TYPE = c ];then
		dialog --inputbox "Where do you want to install CentOS from?" 8 70 "http://mirrors.kernel.org/centos/$VERSION/BaseOS/x86_64/os" 2>/tmp/nb-server
	elif [ $TYPE = r ];then
		dialog --inputbox "Where do you want to install Rocky Linux from?" 8 70 "http://download.rockylinux.org/pub/rocky/$VERSION/BaseOS/x86_64/os" 2>/tmp/nb-server
	else
		dialog --inputbox "Where do you want to install this distribution from?" 8 70 "" 2>/tmp/nb-server
	fi
	SERVER=$(cat /tmp/nb-server)
	KERNELURL="$SERVER/isolinux/vmlinuz"
	INITRDURL="$SERVER/isolinux/initrd.img"
	echo -n "nomodeset inst.repo=$(cat /tmp/nb-server)" >>/tmp/nb-options
	rm /tmp/nb-server
	askforopts
fi
if [ $DISTRO = "rhel-type-7-64" ];then
	dialog --backtitle "$TITLE" --menu "Choose a system to install:" 20 70 13 \
	c_7 "Latest version of CentOS 7" \
	s_7x "Latest version of Scientific Linux 7" \
	Manual "Manually enter a version to install (prefix with s_ or c_)" 2>/tmp/nb-version
	getversion
	TYPE=$(echo $VERSION|head -c 1)
	VERSION=$(echo $VERSION|tail -c +3)
	#Ask the user which server to use (the installer doesn't have a built-in list like Ubuntu and Debian do.)
	if [ $TYPE = s ];then
		dialog --inputbox "Where do you want to install Scientific Linux from?" 8 70 "ftp://linux1.fnal.gov/linux/scientific/$VERSION/x86_64/os" 2>/tmp/nb-server
	else
		dialog --inputbox "Where do you want to install CentOS from?" 8 70 "http://mirrors.kernel.org/centos/$VERSION/os/x86_64" 2>/tmp/nb-server
	fi
	SERVER=$(cat /tmp/nb-server)
	KERNELURL="$SERVER/isolinux/vmlinuz"
	INITRDURL="$SERVER/isolinux/initrd.img"
	echo -n "xdriver=vesa nomodeset repo=$(cat /tmp/nb-server)" >>/tmp/nb-options
	rm /tmp/nb-server
	askforopts
fi
if [ $DISTRO = "rhel-type-6" ];then
	dialog --backtitle "$TITLE" --menu "Choose a system to install:" 20 70 13 \
	c_6 "Latest version of CentOS 6" \
	s_6x "Latest version of Scientific Linux 6" \
	Manual "Manually enter a version to install (prefix with s_ or c_)" 2>/tmp/nb-version
	getversion
	TYPE=$(echo $VERSION|head -c 1)
	VERSION=$(echo $VERSION|tail -c +3)
	#Ask the user which server to use (the installer doesn't have a built-in list like Ubuntu and Debian do.)
	if [ $TYPE = s ];then
		dialog --inputbox "Where do you want to install Scientific Linux from?" 8 70 "ftp://linux1.fnal.gov/linux/scientific/$VERSION/i386/os" 2>/tmp/nb-server
	else
		dialog --inputbox "Where do you want to install CentOS from?" 8 70 "http://mirrors.kernel.org/centos/$VERSION/os/i386" 2>/tmp/nb-server
	fi
	SERVER=$(cat /tmp/nb-server)
	KERNELURL="$SERVER/isolinux/vmlinuz"
	INITRDURL="$SERVER/isolinux/initrd.img"
	echo -n "ide=nodma method=$(cat /tmp/nb-server)" >>/tmp/nb-options
	rm /tmp/nb-server
	askforopts
fi
if [ $DISTRO = "rhel-type-6-64" ];then
	dialog --backtitle "$TITLE" --menu "Choose a system to install:" 20 70 13 \
	c_6 "Latest version of CentOS 6" \
	s_6x "Latest version of Scientific Linux 6" \
	Manual "Manually enter a version to install (prefix with s_ or c_)" 2>/tmp/nb-version
	getversion
	TYPE=$(echo $VERSION|head -c 1)
	VERSION=$(echo $VERSION|tail -c +3)
	#Ask the user which server to use (the installer doesn't have a built-in list like Ubuntu and Debian do.)
	if [ $TYPE = s ];then
		dialog --inputbox "Where do you want to install Scientific Linux from?" 8 70 "ftp://linux1.fnal.gov/linux/scientific/$VERSION/x86_64/os" 2>/tmp/nb-server
	else
		dialog --inputbox "Where do you want to install CentOS from?" 8 70 "http://mirrors.kernel.org/centos/$VERSION/os/x86_64" 2>/tmp/nb-server
	fi
	SERVER=$(cat /tmp/nb-server)
	KERNELURL="$SERVER/isolinux/vmlinuz"
	INITRDURL="$SERVER/isolinux/initrd.img"
	echo -n "ide=nodma method=$(cat /tmp/nb-server)" >>/tmp/nb-options
	rm /tmp/nb-server
	askforopts
fi
if [ $DISTRO = "slackware" ];then
	dialog --backtitle "$TITLE" --menu "Choose a system to install:" 20 70 13 \
	slackware-15.0 "Slackware 15.0 (32-bit)" \
	slackware64-15.0 "Slackware 15.0 (64-bit)" \
	slackware-14.2 "Slackware 14.2 (32-bit)" \
	slackware64-14.2 "Slackware 14.2 (64-bit)" \
	slackware-current "Slackware current (32-bit)" \
	slackware64-current "Slackware current (64-bit)" \
	Manual "Manually enter a version to install" 2>/tmp/nb-version
	getversion
	dialog --backtitle "$TITLE" --menu "Choose a kernel type:" 20 70 13 \
	huge.s "" \
	hugesmp.s "" 2>/tmp/nb-kerntype
	KERNTYPE=$(cat /tmp/nb-kerntype)
	rm /tmp/nb-kerntype
	KERNELURL="http://slackware.cs.utah.edu/pub/slackware/$VERSION/kernels/$KERNTYPE/bzImage"
	INITRDURL="http://slackware.cs.utah.edu/pub/slackware/$VERSION/isolinux/initrd.img"
	echo -n "load_ramdisk=1 prompt_ramdisk=0 rw SLACK_KERNEL=$KERNTYPE" >>/tmp/nb-options
fi
#Now download the kernel and initrd.
wget $KERNELURL -O /tmp/nb-linux
wget $INITRDURL -O /tmp/nb-initrd
}

utilsmenu ()
{
#Ask the user to choose a distro, save the choice to /tmp/nb-distro
dialog --backtitle "$TITLE" --menu "Choose a utility:" 20 70 13 \
slitaz64 "SliTaz (64-bit)" \
slitaz32 "SliTaz (32-bit)" \
slitaz "SliTaz (historical)" \
core64 "Core (64-bit)" \
core32 "Core (32-bit)" 2>/tmp/nb-distro
#Read their choice, save it, and delete the old file
DISTRO=$(cat /tmp/nb-distro)
rm /tmp/nb-distro
#What version?
if [ $DISTRO = "slitaz64" ] || [ $DISTRO = "slitaz32" ];then
#	dialog --backtitle "$TITLE" --menu "Choose the boot mode:" 20 70 13 \
#	core "SliTaz core Live" \
#	gtkonly "SliTaz gtkonly Live" \
#	justx "SliTaz justx Live" \
#	base "SliTaz base Live" 2>/tmp/nb-version
#	getversion
	VERSION=core
elif [ $DISTRO = "slitaz" ];then
	dialog --backtitle "$TITLE" --menu "Choose a version to download:" 20 70 13 \
	4.0-httpfs "SliTaz 4.0 (GUI mode, mounted over HTTP)" \
	4.0-full "SliTaz 4.0 (GUI mode, download and copy to RAM)" \
	4.0-text "SliTaz 4.0 (text mode, first initrd only)" \
	tiny "Tiny SliTaz (see tiny.slitaz.org)" \
	fbvnc "VNC client" 2>/tmp/nb-version
	getversion
else
	dialog --backtitle "$TITLE" --menu "Choose a version to download:" 20 70 13 \
	13.x "Core 13.x" \
	12.x "Core 12.x" \
	11.x "Core 11.x" \
	Manual "Manually enter a version to install" 2>/tmp/nb-version
	getversion
fi
if [ $DISTRO != "grub4dos" ];then
	askforopts
fi
#Now for downloading.
if [ $DISTRO = "slitaz64" ] || [ $DISTRO = "slitaz32" ];then
	sudo -u tc tce-load -wi xz
	wget http://mirror.slitaz.org/iso/rolling/slitaz-rolling-core-5in1.iso -O /tmp/slitaz.iso
	mkdir /tmp/slitaz
	mount -o loop /tmp/slitaz.iso /tmp/slitaz
	if [ $DISTRO = "slitaz64" ];then
		ln -s /tmp/slitaz/boot/bzImage64 /tmp/nb-linux
	else
		ln -s /tmp/slitaz/boot/bzImage /tmp/nb-linux
	fi
	if [ -f /tmp/nb-initrd ];then
		rm /tmp/nb-initrd
	fi
	cat /tmp/slitaz/boot/rootfs5.gz | /usr/local/bin/xz --single-stream -cd >> /tmp/nb-initrd
	if [ $VERSION == "core" ] || [ $VERSION == "gtkonly" ] || [ $VERSION == "justx" ];then
		cat /tmp/slitaz/boot/rootfs4.gz | /usr/local/bin/xz --single-stream -cd >> /tmp/nb-initrd
	fi
	if [ $VERSION == "core" ] || [ $VERSION == "gtkonly" ];then
		cat /tmp/slitaz/boot/rootfs3.gz | /usr/local/bin/xz --single-stream -cd >> /tmp/nb-initrd
	fi
	if [ $VERSION == "core" ];then
		cat /tmp/slitaz/boot/rootfs2.gz | /usr/local/bin/xz --single-stream -cd >> /tmp/nb-initrd
	fi
	cat /tmp/slitaz/boot/rootfs1.gz | /usr/local/bin/xz --single-stream -cd >> /tmp/nb-initrd
	echo -n "root=/dev/null video=-32 autologin" >>/tmp/nb-options
elif [ $DISTRO = "slitaz" ];then
	if [ "$VERSION" = "tiny" ];then
		wget http://mirror.slitaz.org/pxe/tiny/bzImage.gz -O /tmp/nb-linux
		wget http://mirror.slitaz.org/pxe/tiny/rootfs.gz -O /tmp/nb-initrd
	elif [ "$VERSION" = "4.0-full" ];then
		sudo -u tc tce-load -wi xz
		wget http://mirror.slitaz.org/boot/4.0/bzImage -O /tmp/nb-linux
		if [ -f /tmp/nb-initrd ];then
			rm /tmp/nb-initrd
		fi
		for i in 4 3 2 1;do
			wget http://mirror.slitaz.org/boot/4.0/rootfs$i.gz -O - | /usr/local/bin/xz -cd >> /tmp/nb-initrd
		done
		echo -n "rw root=/dev/null vga=normal autologin" >>/tmp/nb-options
	elif [ "$VERSION" = "4.0-text" ];then
		wget http://mirror.slitaz.org/boot/4.0/bzImage -O /tmp/nb-linux
		wget http://mirror.slitaz.org/boot/4.0/rootfs4.gz -O /tmp/nb-initrd
		echo -n "rw root=/dev/null vga=normal autologin" >>/tmp/nb-options
	elif [ "$VERSION" = "4.0-httpfs" ];then
		wget http://mirror.slitaz.org/boot/4.0/bzImage -O /tmp/nb-linux
		wget http://mirror.slitaz.org/boot/4.0/rootfstiny.gz -O /tmp/nb-initrd
		echo -n "rw root=/dev/null vga=normal autologin" >>/tmp/nb-options
	elif [ "$VERSION" = "fbvnc" ];then
		wget http://mirror.slitaz.org/pxe/tiny/vnc/bzImage.gz -O /tmp/nb-linux
		wget http://mirror.slitaz.org/pxe/tiny/vnc/rootfs.gz -O /tmp/nb-initrd
		echo -n "vga=ask" >>/tmp/nb-options
	fi
elif [ $DISTRO = "core64" ];then
	wget http://tinycorelinux.net/$VERSION/x86_64/release/distribution_files/vmlinuz64 -O /tmp/nb-linux
	wget http://tinycorelinux.net/$VERSION/x86_64/release/distribution_files/corepure64.gz -O /tmp/nb-initrd
elif [ $DISTRO = "core32" ];then
	wget http://tinycorelinux.net/$VERSION/x86/release/distribution_files/vmlinuz -O /tmp/nb-linux
	wget http://tinycorelinux.net/$VERSION/x86/release/distribution_files/core.gz -O /tmp/nb-initrd
fi
}
# Do not display menu if nb_provisionurl or local provisioning
# script was provided. Exception: nb_noprobe=1
for param in $(cat /proc/cmdline); do
    url=$(echo $param|egrep '^nb_provisionurl'|sed 's/nb_provisionurl=//g')
    if [ "$url" != "" ]; then
        downloadandrun $url
        exit 0
    fi
done

# Required to handle blkid and grep
set +e
probe_and_provision
set -e

# Proceed with interactive menu
dialog --backtitle "$TITLE" --menu "What would you like to do?" 16 70 9 \
install "Install a Linux system" \
utils "Download and run boot-time utilities" \
download "Get newest script from the NetbootCD website" \
ipaddr "View/release IP address" \
provision "Download and run custom provisioning script" \
quit "Quit to prompt (do not reboot)" 2>/tmp/nb-mainmenu

MAINMENU=$(cat /tmp/nb-mainmenu)
rm /tmp/nb-mainmenu
if [ $MAINMENU = quit ];then
	exit 1
fi
#We are going to need /tmp/nb-options empty later.
true>/tmp/nb-options
true>/tmp/nb-custom
if [ $MAINMENU = "download" ];then
	su -c "tce-load -wi openssl" tc
	downloadandrun https://raw.githubusercontent.com/IsaacSchemm/netbootcd/master/nbscript.sh
fi
if [ $MAINMENU = "utils" ];then
	utilsmenu
fi
if [ $MAINMENU = "install" ];then
	installmenu
fi
if [ $MAINMENU = "provision" ]; then
  url=""
  while [ "$url" == "" ]; do
    dialog --inputbox "Remote provision url:" 8 30 "" 2>/tmp/nb-interface
    url="$(cat /tmp/nb-interface)"
    if [ "$url" != "" ]; then
        downloadandrun $url
    fi
  done
  exit
fi
if [ $MAINMENU = "ipaddr" ];then
  dialog --inputbox "Network interface:" 8 30 "eth0" 2>/tmp/nb-interface
  ifconfig $(cat /tmp/nb-interface)
  answer="invalid"
  while [ $? == 0 ];do
    read -p "Release IP address with \"killall -SIGUSR2 udhcpc\"? (Y/n) " answer
    if [ "$answer" == y ] || [ "$answer" == "" ];then
      killall -SIGUSR2 udhcpc
      echo "Released IP address."
      break
    elif [ "$answer" == n ];then
      break
    fi
  done
  exit
fi
#This is what we will tell kexec.
if [ $DISTRO != "grub4dos" ];then
	ARGS="-l /tmp/nb-linux --initrd=/tmp/nb-initrd $OPTIONS $CUSTOM"
else
	ARGS="-l /tmp/nb-linux $OPTIONS $CUSTOM"
fi
if [ $DISTRO = "rhel-type-5" ];then
	ARGS=$ARGS" --args-linux"
fi
#This checks to make sure you are indeed on a TCB system.
if [ -d /home/tc ];then
	echo kexec $ARGS --command-line="$(cat /tmp/nb-options) $(cat /tmp/nb-custom)"
	kexec $ARGS --command-line="$(cat /tmp/nb-options) $(cat /tmp/nb-custom)"
	sleep 5
	sync
	kexec -e
fi
