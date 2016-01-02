#!/bin/sh
set -e
## nbscript.sh 6.4.1 - Download netboot images and launch them with kexec
## Copyright (C) 2016 Isaac Schemm <isaacschemm@gmail.com>
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

TITLE="NetbootCD Script 6.4.1 - January 1, 2016"

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
dialog --backtitle "$TITLE" --inputbox "Would you like to pass any extra kernel options?\n(Note: it is OK to leave this field blank)\nUse the syntax: --append=option1=asdf --append=option2=hi" 9 64 2>/tmp/nb-custom
CUSTOM=$(cat /tmp/nb-custom)
rm /tmp/nb-custom
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
fi

}

installmenu ()
{
#Ask the user to choose a distro, save the choice to /tmp/nb-distro
dialog --backtitle "$TITLE" --menu "Choose a distribution:" 20 70 13 \
ubuntu64 " (amd64) Ubuntu" \
ubuntu "  (i386) Ubuntu" \
debian64 " (amd64) Debian GNU/Linux" \
debian "  (i386) Debian GNU/Linux" \
debiandaily64 " (amd64) Debian GNU/Linux - daily installers" \
debiandaily "  (i386) Debian GNU/Linux - daily installers" \
fedora64 "(x86_64) Fedora" \
fedora "  (i386) Fedora" \
opensuse64 "(x86_64) openSUSE" \
opensuse "  (i386) openSUSE" \
mageia64 "(x86_64) Mageia" \
mageia "  (i386) Mageia" \
rhel-type-6-64 "(x86_64) CentOS 6 and Scientific Linux 6" \
rhel-type-6 "  (i386) CentOS 6 and Scientific Linux 6" \
rhel-type-5-64 "(x86_64) CentOS 5 and Scientific Linux 5" \
rhel-type-5 "  (i386) CentOS 5 and Scientific Linux 5" \
slackware "Slackware" 2>/tmp/nb-distro
#Read their choice, save it, and delete the old file
DISTRO=$(cat /tmp/nb-distro)
rm /tmp/nb-distro
#Now to check which distro the user picked.
if [ $DISTRO = "ubuntu" ];then
	#Ask about version
	dialog --menu "Choose a system to install:" 20 70 13 \
	wily "Ubuntu 15.10" \
	vivid "Ubuntu 15.04" \
	trusty "Ubuntu 14.04 LTS" \
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
	echo -n '--append=vga=normal --append=quiet '>>/tmp/nb-options
	#If the user wants a command-line install, then add some more kernel arguments. The CLI install is akin to "standard system" in Debian.
	if ! dialog --yesno "Would you like to install language packs?\n(Choose no for a command-line system.)" 6 43;then
		#These arguments appear to just prevent the system from installing language packs. Not sure if they work, but Ubuntu's mini.iso has them.
		echo -n '--append=tasks=standard --append=pkgsel/language-pack-patterns= --append=pkgsel/install-language-support=false'>>/tmp/nb-options
	fi
fi
if [ $DISTRO = "ubuntu64" ];then
	#Ask about version
	dialog --menu "Choose a system to install:" 20 70 13 \
	wily "Ubuntu 15.10" \
	vivid "Ubuntu 15.04" \
	trusty "Ubuntu 14.04 LTS" \
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
	#These options are good for all Ubuntu installers.
	echo -n '--append=vga=normal --append=quiet '>>/tmp/nb-options
	#If the user wants a command-line install, then add some more kernel arguments. The CLI install is akin to "standard system" in Debian.
	if ! dialog --yesno "Would you like to install language packs?\n(Choose no for a command-line system.)" 6 43;then
		echo -n '--append=tasks=standard --append=pkgsel/language-pack-patterns= --append=pkgsel/install-language-support=false'>>/tmp/nb-options
	fi
fi
if [ $DISTRO = "debian" ];then
	dialog --backtitle "$TITLE" --menu "Choose a system to install:" 20 70 13 \
	stable "Debian stable" \
	testing "Debian testing" \
	Manual "Manually enter a version to install" 2>/tmp/nb-version
	getversion
	KERNELURL="http://http.us.debian.org/debian/dists/$VERSION/main/installer-i386/current/images/netboot/debian-installer/i386/linux"
	INITRDURL="http://http.us.debian.org/debian/dists/$VERSION/main/installer-i386/current/images/netboot/debian-installer/i386/initrd.gz"
	echo -n '--append=vga=normal --append=quiet '>>/tmp/nb-options
	#Testing and unstable use the same kernel. See: https://wiki.debian.org/DebianUnstable#How_do_I_install_Sid.3F
fi
if [ $DISTRO = "debian64" ];then
	dialog --backtitle "$TITLE" --menu "Choose a system to install:" 20 70 13 \
	stable "Debian stable" \
	testing "Debian testing" \
	Manual "Manually enter a version to install" 2>/tmp/nb-version
	getversion
	KERNELURL="http://http.us.debian.org/debian/dists/$VERSION/main/installer-amd64/current/images/netboot/debian-installer/amd64/linux"
	INITRDURL="http://http.us.debian.org/debian/dists/$VERSION/main/installer-amd64/current/images/netboot/debian-installer/amd64/initrd.gz"
	echo -n '--append=vga=normal --append=quiet" '>>/tmp/nb-options
fi
if [ $DISTRO = "debiandaily" ];then
	dialog --backtitle "$TITLE" --menu "Choose a system to install:" 20 70 13 \
	testing "Debian testing" \
	testing-expert "Debian testing/unstable (expert mode)" \
	Manual "Manually enter a version to install" 2>/tmp/nb-version
	getversion
	KERNELURL="http://d-i.debian.org/daily-images/i386/daily/netboot/debian-installer/i386/linux"
	INITRDURL="http://d-i.debian.org/daily-images/i386/daily/netboot/debian-installer/i386/initrd.gz"
	echo -n '--append=vga=normal --append=quiet '>>/tmp/nb-options
	if [ $VERSION = "testing-expert" ];then
		echo -n '--append=priority=low '>>/tmp/nb-options
	fi
fi
if [ $DISTRO = "debiandaily64" ];then
	dialog --backtitle "$TITLE" --menu "Choose a system to install:" 20 70 13 \
	testing "Debian testing" \
	testing-expert "Debian testing/unstable (expert mode)" \
	Manual "Manually enter a version to install" 2>/tmp/nb-version
	getversion
	KERNELURL="http://d-i.debian.org/daily-images/amd64/daily/netboot/debian-installer/amd64/linux"
	INITRDURL="http://d-i.debian.org/daily-images/amd64/daily/netboot/debian-installer/amd64/initrd.gz"
	echo -n '--append=vga=normal --append=quiet '>>/tmp/nb-options
	if [ $VERSION = "testing-expert" ];then
		echo -n '--append=priority=low '>>/tmp/nb-options
	fi
fi
if [ $DISTRO = "fedora" ];then
	dialog --backtitle "$TITLE" --menu "Choose a system to install:" 20 70 13 \
	releases/23/Server "Fedora 23" \
	releases/22/Server "Fedora 22" \
	releases/21/Server "Fedora 21" \
	development/rawhide "Rawhide" \
	Manual "Manually enter a version to install" 2>/tmp/nb-version
	getversion
	#Ask the user which server to use (the installer doesn't have a built-in list like Ubuntu and Debian do.)
	dialog --inputbox "Where do you want to install Fedora from?" 8 70 "http://mirrors.kernel.org/fedora/$VERSION/i386/os/" 2>/tmp/nb-server
	KERNELURL="$(cat /tmp/nb-server)/images/pxeboot/vmlinuz"
	INITRDURL="$(cat /tmp/nb-server)/images/pxeboot/initrd.img"
	echo -n "--append=inst.stage2=$(cat /tmp/nb-server)" >>/tmp/nb-options
	rm /tmp/nb-server
fi
if [ $DISTRO = "fedora64" ];then
	dialog --backtitle "$TITLE" --menu "Choose a system to install:" 20 70 13 \
	releases/23/Server "Fedora 23" \
	releases/22/Server "Fedora 22" \
	releases/21/Server "Fedora 21" \
	development/rawhide "Rawhide" \
	Manual "Manually enter a version to install" 2>/tmp/nb-version
	getversion
	#Ask the user which server to use (the installer doesn't have a built-in list like Ubuntu and Debian do.)
	dialog --inputbox "Where do you want to install Fedora from?" 8 70 "http://mirrors.kernel.org/fedora/$VERSION/x86_64/os/" 2>/tmp/nb-server
	KERNELURL="$(cat /tmp/nb-server)/images/pxeboot/vmlinuz"
	INITRDURL="$(cat /tmp/nb-server)/images/pxeboot/initrd.img"
	echo -n "--append=inst.stage2=$(cat /tmp/nb-server)" >>/tmp/nb-options
	rm /tmp/nb-server
fi
if [ $DISTRO = "opensuse" ];then
	dialog --backtitle "$TITLE" --menu "Choose a system to install:" 20 70 13 \
	tumbleweed "openSUSE Tumbleweed" \
	leap/42.1 "openSUSE Leap 42.1" \
	13.2 "openSUSE 13.2" \
	13.1 "openSUSE 13.1" \
	12.3 "openSUSE 12.3" \
	Manual "Manually enter a version to install" 2>/tmp/nb-version
	getversion
	#All versions of openSUSE are in the "distribution" folder, except for factory/tumbleweed.
	if [ $VERSION != "tumbleweed" ];then
		VERSION=distribution/$VERSION
	fi
	KERNELURL="http://download.opensuse.org/$VERSION/repo/oss/boot/i386/loader/linux"
	INITRDURL="http://download.opensuse.org/$VERSION/repo/oss/boot/i386/loader/initrd"
	#These options are common to openSUSE.
	echo -n '--append=splash=silent --append=showopts '>>/tmp/nb-options
	#Ask the user which server to use (the installer doesn't have a built-in list like Ubuntu and Debian do.)
	dialog --inputbox "Where do you want to install openSUSE from?" 8 70 http://download.opensuse.org/$VERSION/repo/oss 2>/tmp/nb-server
	echo -n "--append=install=$(cat /tmp/nb-server)" >>/tmp/nb-options
	rm /tmp/nb-server
fi
if [ $DISTRO = "opensuse64" ];then
	dialog --backtitle "$TITLE" --menu "Choose a system to install:" 20 70 13 \
	tumbleweed "openSUSE Tumbleweed" \
	leap/42.1 "openSUSE Leap 42.1" \
	13.2 "openSUSE 13.2" \
	13.1 "openSUSE 13.1" \
	12.3 "openSUSE 12.3" \
	Manual "Manually enter a version to install" 2>/tmp/nb-version
	getversion
	#All versions of openSUSE are in the "distribution" folder, except for factory/tumbleweed.
	if [ $VERSION != "tumbleweed" ];then
		VERSION=distribution/$VERSION
	fi
	KERNELURL="http://download.opensuse.org/$VERSION/repo/oss/boot/x86_64/loader/linux"
	INITRDURL="http://download.opensuse.org/$VERSION/repo/oss/boot/x86_64/loader/initrd"
	#These options are common to openSUSE.
	echo -n '--append=splash=silent --append=showopts '>>/tmp/nb-options
	#Ask the user which server to use (the installer doesn't have a built-in list like Ubuntu and Debian do.)
	dialog --inputbox "Where do you want to install openSUSE from?" 8 70 http://download.opensuse.org/$VERSION/repo/oss 2>/tmp/nb-server
	echo -n "--append=install=$(cat /tmp/nb-server)" >>/tmp/nb-options
	rm /tmp/nb-server
fi
if [ $DISTRO = "mageia" ];then
	dialog --backtitle "$TITLE" --menu "Choose a system to install:" 20 70 13 \
	5 "Mageia 5" \
	4 "Mageia 4" \
	3 "Mageia 3" \
	cauldron "Mageia cauldron" \
	Manual "Manually enter a version to install" 2>/tmp/nb-version
	getversion
	KERNELURL="http://mirrors.kernel.org/mageia/distrib/$VERSION/i586/isolinux/i386/vmlinuz"
	INITRDURL="http://mirrors.kernel.org/mageia/distrib/$VERSION/i586/isolinux/i386/all.rdz"
	echo -n '--append=automatic=method:http' >>/tmp/nb-options
fi
if [ $DISTRO = "mageia64" ];then
	dialog --backtitle "$TITLE" --menu "Choose a system to install:" 20 70 13 \
	5 "Mageia 5" \
	4 "Mageia 4" \
	3 "Mageia 3" \
	cauldron "Mageia cauldron" \
	Manual "Manually enter a version to install" 2>/tmp/nb-version
	getversion
	KERNELURL="http://mirrors.kernel.org/mageia/distrib/$VERSION/x86_64/isolinux/x86_64/vmlinuz"
	INITRDURL="http://mirrors.kernel.org/mageia/distrib/$VERSION/x86_64/isolinux/x86_64/all.rdz"
	echo -n '--append=automatic=method:http' >>/tmp/nb-options
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
	echo -n "--append=ide=nodma --append=method=$(cat /tmp/nb-server)" >>/tmp/nb-options
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
	echo -n "--append=ide=nodma --append=method=$(cat /tmp/nb-server)" >>/tmp/nb-options
	rm /tmp/nb-server
	askforopts
fi
if [ $DISTRO = "rhel-type-5" ];then
	dialog --backtitle "$TITLE" --menu "Choose a system to install:" 20 70 13 \
	c_5 "Latest version of CentOS 5" \
	s_5x "Latest version of Scientific Linux 5" \
	Manual "Manually enter a version to install (prefix with s_ or c_)" 2>/tmp/nb-version
	getversion
	TYPE=$(echo $VERSION|head -c 1)
	VERSION=$(echo $VERSION|tail -c +3)
	#Ask the user which server to use (the installer doesn't have a built-in list like Ubuntu and Debian do.)
	if [ $TYPE = s ];then
		VERSION=$(echo $VERSION|sed -e 's/\.//g')
		dialog --inputbox "Where do you want to install Scientific Linux from?" 8 70 "http://linux1.fnal.gov/linux/scientific/$VERSION/i386" 2>/tmp/nb-server
	else
		dialog --inputbox "Where do you want to install CentOS from?" 8 70 "http://mirrors.kernel.org/centos/$VERSION/os/i386" 2>/tmp/nb-server
	fi
	SERVER=$(cat /tmp/nb-server)
	KERNELURL="$SERVER/isolinux/vmlinuz"
	INITRDURL="$SERVER/isolinux/initrd.img"
	echo -n "--append=method=$(cat /tmp/nb-server)" >>/tmp/nb-options
	rm /tmp/nb-server
fi
if [ $DISTRO = "rhel-type-5-64" ];then
	dialog --backtitle "$TITLE" --menu "Choose a system to install:" 20 70 13 \
	c_5 "Latest version of CentOS 5" \
	s_5x "Latest version of Scientific Linux 5" \
	Manual "Manually enter a version to install (prefix with s_ or c_)" 2>/tmp/nb-version
	getversion
	TYPE=$(echo $VERSION|head -c 1)
	VERSION=$(echo $VERSION|tail -c +3)
	#Ask the user which server to use (the installer doesn't have a built-in list like Ubuntu and Debian do.)
	if [ $TYPE = s ];then
		VERSION=$(echo $VERSION|sed -e 's/\.//g')
		dialog --inputbox "Where do you want to install Scientific Linux from?" 8 70 "http://linux1.fnal.gov/linux/scientific/$VERSION/x86_64" 2>/tmp/nb-server
	else
		dialog --inputbox "Where do you want to install CentOS from?" 8 70 "http://mirrors.kernel.org/centos/$VERSION/os/x86_64" 2>/tmp/nb-server
	fi
	SERVER=$(cat /tmp/nb-server)
	KERNELURL="$SERVER/isolinux/vmlinuz"
	INITRDURL="$SERVER/isolinux/initrd.img"
	echo -n "--append=method=$(cat /tmp/nb-server)" >>/tmp/nb-options
	rm /tmp/nb-server
fi
if [ $DISTRO = "slackware" ];then
	SLACKASK="Slackware can't be installed from a web server.\nContinue?"
	if ! dialog --yesno "$SLACKASK" 0 0;then exec $0 $*;fi #Go back to main menu if no
	dialog --backtitle "$TITLE" --menu "Choose a system to install:" 20 70 13 \
	slackware-14.1 "Slackware 14.1 (32-bit)" \
	slackware64-14.1 "Slackware 14.1 (64-bit)" \
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
	echo -n "--append=load_ramdisk=1 --append=prompt_ramdisk=0 --append=rw --append=SLACK_KERNEL=$KERNTYPE" >>/tmp/nb-options
fi
OPTIONS=$(cat /tmp/nb-options)
rm /tmp/nb-options
#Now download the kernel and initrd.
wget $KERNELURL -O /tmp/nb-linux
wget $INITRDURL -O /tmp/nb-initrd
}

utilsmenu ()
{
#Ask the user to choose a distro, save the choice to /tmp/nb-distro
dialog --backtitle "$TITLE" --menu "Choose a utility:" 20 70 13 \
grub4dos "GRUB4DOS - a versitle bootloader that can be loaded from kexec" \
slitaz "SliTaz" \
core "Core 6.x" \
tinycore "Core 6.x (add TinyCore packages: Xvesa Xlibs Xprogs aterm flwm_topside wbar)" \
gparted "Core 6.x (above plus: gparted ntfsprogs dosfstools reiserfsprogs)" 2>/tmp/nb-distro
#Read their choice, save it, and delete the old file
DISTRO=$(cat /tmp/nb-distro)
rm /tmp/nb-distro
#What version?
if [ $DISTRO = "grub4dos" ];then
	dialog --backtitle "$TITLE" --menu "Choose a version to download:" 20 70 13 \
	0.4.6a-2015-12-16 "grub4dos-chenall fork (0.4.6a branch)" \
	0.4.5c-2015-12-24 "grub4dos-chenall fork (0.4.5c branch)" \
	0.4.4-2009-06-20 "Latest version of original - June 20, 2009" 2>/tmp/nb-version
	getversion
elif [ $DISTRO = "slitaz" ];then
	dialog --backtitle "$TITLE" --menu "Choose a version to download:" 20 70 13 \
	5.0-rc3 "SliTaz 5.0 rc3" \
	4.0-httpfs "SliTaz 4.0 (root filesystem mounted over HTTP)" \
	4.0-text "SliTaz 4.0 (text mode, first initrd only)" \
	tiny "Tiny SliTaz (see tiny.slitaz.org)" \
	fbvnc "VNC client" 2>/tmp/nb-version
	getversion
else
	dialog --backtitle "$TITLE" --menu "Choose a version to download:" 20 70 13 \
	32 "Core 6.x - 32-bit" \
	64 "Core 6.x - 64-bit" 2>/tmp/nb-version
	getversion
fi
if [ $DISTRO != "grub4dos" ];then
	askforopts
fi
#Now for downloading.
if [ $DISTRO = "grub4dos" ];then
	if [ "$VERSION" = "0.4.4-2009-06-20" ];then
		wget http://download.gna.org/grub4dos/grub4dos-$VERSION.zip -O /tmp/g4d.zip
		unzip /tmp/g4d.zip -d /tmp
		rm /tmp/g4d.zip
		mv /tmp/grub4dos-*/grub.exe /tmp/nb-linux
		rm -r /tmp/grub4dos-*
	else
		wget -O /tmp/nb-linux http://netbootcd.us/downloads/grub4dos/$VERSION/grub.exe
	fi
	true>/tmp/nb-initrd
elif [ $DISTRO = "slitaz" ];then
	if [ "$VERSION" = "tiny" ];then
		wget http://mirror.slitaz.org/pxe/tiny/bzImage.gz -O /tmp/nb-linux
		wget http://mirror.slitaz.org/pxe/tiny/rootfs.gz -O /tmp/nb-initrd
	elif [ "$VERSION" = "4.0-text" ];then
		wget http://mirror.slitaz.org/boot/4.0/bzImage -O /tmp/nb-linux
		wget http://mirror.slitaz.org/boot/4.0/rootfs4.gz -O /tmp/nb-initrd
		echo -n "--append=rw --append=root=/dev/null --append=vga=normal --append=autologin" >>/tmp/nb-options
	elif [ "$VERSION" = "4.0-httpfs" ];then
		wget http://mirror.slitaz.org/boot/4.0/bzImage -O /tmp/nb-linux
		wget http://mirror.slitaz.org/boot/4.0/rootfstiny.gz -O /tmp/nb-initrd
		echo -n "--append=rw --append=root=/dev/null --append=vga=normal --append=autologin" >>/tmp/nb-options
	elif [ "$VERSION" = "vnc" ];then
		wget http://mirror.slitaz.org/pxe/tiny/vnc/bzImage.gz -O /tmp/nb-linux
		wget http://mirror.slitaz.org/pxe/tiny/vnc/rootfs.gz -O /tmp/nb-initrd
		echo -n "--append=vga=ask" >>/tmp/nb-options
	elif [ "$VERSION" = "5.0-rc3" ];then
		wget http://mirror.slitaz.org/iso/5.0/slitaz-5.0-rc3.iso -O /tmp/slitaz.iso
		mkdir /tmp/slitaz
		mount -o loop /tmp/slitaz.iso /tmp/slitaz
		ln -s /tmp/slitaz/boot/vmlinuz* /tmp/nb-linux
		ln -s /tmp/slitaz/boot/rootfs.gz /tmp/nb-initrd
		echo -n "--append=rw --append=root=/dev/null --append=autologin" >>/tmp/nb-options
	fi
elif [ $DISTRO = "core" ] || [ $DISTRO = "tinycore" ] || [ $DISTRO = "gparted" ];then
	if [ "$VERSION" == "64" ];then
		wget http://distro.ibiblio.org/tinycorelinux/6.x/x86_64/release/distribution_files/vmlinuz64 -O /tmp/nb-linux
		wget http://distro.ibiblio.org/tinycorelinux/6.x/x86_64/release/distribution_files/corepure64.gz -O /tmp/nb-initrd
	else
		wget http://distro.ibiblio.org/tinycorelinux/6.x/x86/release/distribution_files/vmlinuz -O /tmp/nb-linux
		wget http://distro.ibiblio.org/tinycorelinux/6.x/x86/release/distribution_files/core.gz -O /tmp/nb-initrd
	fi
	if [ $DISTRO = "tinycore" ] || [ $DISTRO = "gparted" ];then
		mkdir -p /tmp/build
		cd /tmp/build
		gzip -cd /tmp/nb-initrd | cpio -id
		echo '#!/bin/sh
		echo "Waiting for internet connection (will keep trying indefinitely)"
		echo -n "Testing example.com"
		[ -f /tmp/internet-is-up ]
		while [ $? != 0 ];do
			sleep 0.1
			echo -n "."
			wget -q --spider http://www.example.com > /dev/null
		done
		echo > /tmp/internet-is-up' > script.sh
		for i in Xvesa Xlibs Xprogs aterm flwm_topside wbar;do # xbase.lst from CorePlus-6.1
			echo "tce-load -wi $i" >> script.sh
		done
		if [ $DISTRO = "gparted" ];then
			for i in gparted ntfsprogs dosfstools reiserfsprogs;do
				echo "tce-load -wi $i" >> script.sh
			done
		fi
		chmod +x script.sh
		echo "/script.sh && startx" >> etc/skel/.profile
		find . | cpio -o -H newc | gzip -c > /tmp/nb-initrd
		cd -
		rm -rf /tmp/build
	fi
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
if [ $MAINMENU = "download" ];then
	downloadandrun http://netbootcd.us/downloads/nbscript.sh
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
	echo kexec $ARGS
	kexec $ARGS
	sleep 5
	sync
	kexec -e
fi
