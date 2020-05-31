#!/bin/sh
#Floppy.sh 9.0 for netbootcd

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
## <http://www.gnu.org/copyleft/gpl.html> or on the CD itself.

set -e
PATH=$PATH:/sbin
WORK=$(pwd)/work
DONE=$(pwd)/done
NBINIT2=${WORK}/nbinit2 #for floppy

FDIR=$(pwd)

#Set to false to not build floppy images
FLOPPY=true
NBCDVER=11.1

if [ ! -f old.vmlinuz ];then
	wget -O old.vmlinuz http://tinycorelinux.net/7.x/x86/release/distribution_files/vmlinuz
fi

if [ ! -f old.core.gz ];then
	wget -O old.core.gz http://tinycorelinux.net/7.x/x86/release/distribution_files/core.gz
fi

NO=0
for i in old.vmlinuz old.core.gz \
nbscript.sh tc-config.diff kexec.tgz \
disksplit.sh;do
	if [ ! -e $i ];then
		echo "Couldn't find $i!"
		NO=1
	fi
done
if $FLOPPY && [ ! -e blank-bootable-1440-floppy.gz ];then
	echo "Couldn't find blank-bootable-1440-floppy.gz!"
	NO=1
fi
for i in zip;do
	if ! which $i > /dev/null;then
		echo "Please install $i!"
		NO=1
	fi
done
if [ $NO = 1 ];then
	exit 1
fi

#make sure we are root
if [ $(whoami) != "root" ];then
	echo "Please run as root."
	exit 1
fi

if [ -d ${WORK} ];then
	rm -r ${WORK}
fi
if [ -d ${DONE} ];then
	rm -r ${DONE}
fi

mkdir -p ${WORK} ${DONE}

#Make the floppy disk version of the initrd.
mkdir ${NBINIT2}
cd ${NBINIT2}
gzip -cd "${FDIR}/old.core.gz" | cpio -id
cd -

#write wrapper script
cat > ${NBINIT2}/usr/bin/netboot << "EOF"
#!/bin/sh
if [ $(whoami) != "root" ];then
	exec sudo $0 $*
fi

echo "Waiting for internet connection (will keep trying indefinitely)"
echo -n "Testing example.com"
[ -f /tmp/internet-is-up ]
while [ $? != 0 ];do
	sleep 1
	echo -n "."
	wget --spider http://www.example.com &> /dev/null
done
echo > /tmp/internet-is-up

wget -O /tmp/nb-linux http://lakora.nfshost.com/netbootcd/downloads/9.0/vmlinuz
wget -O /tmp/nb-initrd http://lakora.nfshost.com/netbootcd/downloads/9.0/nbinit4.gz

if ! (sha1sum /tmp/nb-linux | grep 6b91a5385d8a92768817a5c14038c2ca9a3e1704);then
	echo "kernel downloaded from lakora.nfshost.com did not match checksum"
elif ! (sha1sum /tmp/nb-initrd | grep b38a84302873bbded3b4104a34c5669081b17075);then
	echo "initrd downloaded from lakora.nfshost.com did not match checksum"
else
	kexec -l /tmp/nb-linux --initrd=/tmp/nb-initrd
	kexec -e
fi
EOF
chmod +x ${NBINIT2}/usr/bin/netboot
cd ${NBINIT2}/etc/init.d
patch -p0 < ${FDIR}/tc-config.diff
cd -

#copy nbscript
cp -v nbscript.sh ${NBINIT2}/usr/bin

tar -C ${NBINIT2} -xvf kexec.tgz

#NetbootCD > .profile
echo "netboot" >> ${NBINIT2}/etc/skel/.profile
cd ${NBINIT2}
find . | cpio -o -H 'newc' | gzip -c > ${DONE}/nbflop4.gz
cd -
if which advdef 2> /dev/null;then
	advdef -z ${DONE}/nbflop4.gz #extra compression
fi
#rm -r ${NBINIT2}
echo "Made floppy initrd:" $(wc -c ${DONE}/nbflop4.gz)

#Split up the kernel and floppy initrd for several disks
./disksplit.sh old.vmlinuz ${DONE}/nbflop4.gz
cd done/floppy
cp 1.img ../NetbootCD-$NBCDVER-floppy.img
zip ../NetbootCD-$NBCDVER-floppy-set.zip *.img
cd -
ln -s ${DONE}/NetbootCD-$NBCDVER-floppy.img ${DONE}/NetbootCD-floppy.img
ln -s ${DONE}/NetbootCD-$NBCDVER-floppy-set.zip ${DONE}/NetbootCD-floppy-set.zip

chown -R 1000.1000 $DONE
