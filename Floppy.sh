#!/bin/sh
##Floppy.sh 11.1.4 for netbootcd
## Copyright (C) 2022 Isaac Schemm <isaacschemm@gmail.com>
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
## <http://www.gnu.org/copyleft/gpl.html> or on the CD itself.

set -e
PATH=$PATH:/sbin
WORK=$(pwd)/work
DONE=$(pwd)/flopdone
NBINIT2=${WORK}/nbinit2 #for floppy

FDIR=$(pwd)

#Set to false to not build floppy images
NBCDVER=11.1.4

wget -O old.vmlinuz http://tinycorelinux.net/5.x/x86/release/distribution_files/vmlinuz
wget -O old.core.gz http://tinycorelinux.net/5.x/x86/release/distribution_files/core.gz

NO=0
for i in old.vmlinuz old.core.gz tc-config.diff kexec.tgz;do
	if [ ! -e $i ];then
		echo "Couldn't find $i!"
		NO=1
	fi
done
if [ ! -e blank-bootable-1440-floppy.gz ];then
	echo "Couldn't find blank-bootable-1440-floppy.gz!"
	NO=1
fi
for i in zip advdef;do
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

wget -O /tmp/nb-linux $(cat /proc/cmdline | grep -o -e 'kernelurl=[^ ]*' | sed -e 's/^kernelurl=//g')
wget -O /tmp/nb-initrd $(cat /proc/cmdline | grep -o -e 'initrdurl=[^ ]*' | sed -e 's/^initrdurl=//g')

kexec -l /tmp/nb-linux --initrd=/tmp/nb-initrd
kexec -e
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

KERNEL=old.vmlinuz
INITRD="${DONE}/nbflop4.gz"
CAT="/tmp/disksplit"
TMPDIR="/tmp/splitfiles"

if [ ! -f $KERNEL ] || [ ! -f $INITRD ];then
	echo "Could not find both $KERNEL and $INITRD"
	exit 1
fi

if [ -d $TMPDIR ];then
	umount $TMPDIR/* 2> /dev/null || true
	rm -r $TMPDIR
fi
mkdir $TMPDIR

mkdir $TMPDIR/1

cp -v dos/* $TMPDIR/1

KERNEL_SIZE=$(wc -c $KERNEL|awk '{print $1}')
INITRD_SIZE=$(wc -c $INITRD|awk '{print $1}')
if [ $INITRD_SIZE -lt $KERNEL_SIZE ];then
	BIGGER="kernel"
	BIGGER_SIZE=$KERNEL_SIZE
	cat $KERNEL $INITRD > $CAT
else
	BIGGER="initrd"
	BIGGER_SIZE=$INITRD_SIZE
	cat $INITRD $KERNEL > $CAT
fi
FILESIZE=$(wc -c $CAT|awk '{print $1}')
NUM_DISKS=$(( $FILESIZE / 1457644 + 1))
EXTRADISK="false"
for i in $(seq 2 $NUM_DISKS);do
	if [ -d $TMPDIR/$i ];then
		rm -r $TMPDIR/$i
	fi
	mkdir -p $TMPDIR/$i
done
split -b 1457644 $CAT $TMPDIR/PART
if ! $EXTRADISK;then
	echo "Moving $(ls -r $TMPDIR/P*|head -n 1) to lastpart"
	mv $(ls -r $TMPDIR/P*|head -n 1) $TMPDIR/lastpart
fi
ls -l $TMPDIR
NUM=2
for i in $(echo $TMPDIR/PART*);do
	if [ $(($NUM-2)) -lt 10 ];then
		EXT=00$(($NUM-2))
	else
		EXT=0$(($NUM-2))
	fi
	echo "Copying $i to PART.$EXT on disk $NUM"
	cp $i $TMPDIR/$NUM/PART.$EXT
	NUM=$(($NUM+1))
done
if [ $(($NUM_DISKS-1)) -lt 10 ];then
	EXT=00$(($NUM_DISKS-1))
else
	EXT=0$(($NUM_DISKS-1))
fi
if ! $EXTRADISK;then
	echo "Copying lastpart to PART.$EXT"
	cp $TMPDIR/lastpart $TMPDIR/1/PART.$EXT
fi

echo "
@ECHO OFF
REM PART.000 is on Disk 2, PART.001 on Disk 3, etc

ECHO This is disk 1 of a 1440KB $NUM_DISKS-disk set.
COPY A:\CHUNK.EXE T:\\
COPY A:\LINLD.COM T:\\
COPY A:\KERNELCL.TXT T:\\
" > $TMPDIR/1/tinycore.not
if ! $EXTRADISK;then
	echo "
	IF EXIST A:\PART.$EXT GOTO DISK1IN
	:DISK1
	ECHO Please insert disk 1 and press ENTER.
	PAUSE
	IF NOT EXIST A:\PART.$EXT GOTO DISK1
	:DISK1IN
	COPY A:\PART.$EXT T:\\
	" >> $TMPDIR/1/tinycore.not
fi
for i in $(seq 2 $NUM_DISKS);do
	if [ $(($i-2)) -lt 10 ];then
		EXT=00$(($i-2))
	else
		EXT=0$(($i-2))
	fi
	LETTER="$(echo $i | tr 23456789 abcdefgh)"
	echo ":DISK${i}
	ECHO Please insert disk ${i} and press ENTER.
	PAUSE
	IF NOT EXIST A:\PART.$EXT GOTO DISK${i}
	COPY A:\PART.$EXT T:\\
	" >> $TMPDIR/1/tinycore.not
done
echo "ECHO You may now remove the floppy disk from the drive.
T:
CHUNK.EXE /C PART NBCD4.CAT
DEL PART.*
CHUNK.EXE /S${BIGGER_SIZE} NBCD4.CAT FILE
LINLD.COM image=FILE.001 initrd=FILE.000 cl=@KERNELCL.TXT
" >> $TMPDIR/1/tinycore.not
echo "quiet kernelurl=http://lakora.nfshost.com/netbootcd/downloads/$NBCDVER/vmlinuz initrdurl=http://lakora.nfshost.com/netbootcd/downloads/$NBCDVER/nbinit4.gz" > $TMPDIR/1/kernelcl.txt

BATCH_FILE_SIZE=$(wc -c $TMPDIR/1/tinycore.not|awk '{print $1}')
NEEDED_RAMDISK=20160
echo "DEVICE=HIMEMX.EXE
LASTDRIVE=Z" > $TMPDIR/1/fdconfig.sys
echo "@ECHO OFF
XMSDSK.EXE $NEEDED_RAMDISK T: /Y
COPY TINYCORE.NOT T:\TINYCORE.BAT
T:\TINYCORE.BAT" > $TMPDIR/1/autoexec.bat

gzip -cd freedos.img.gz > $TMPDIR/1.img
mkdir $TMPDIR/a1
mount -o loop $TMPDIR/1.img $TMPDIR/a1
cp $TMPDIR/1/* $TMPDIR/a1/
df -h $TMPDIR/a1
sleep 0.2;umount $TMPDIR/a1
rmdir $TMPDIR/a1
if [ -d ${DONE}/floppy ];then
	rm -r ${DONE}/floppy
fi
mkdir ${DONE}/floppy
mv $TMPDIR/1.img ${DONE}/floppy/1.img
for i in $(seq 2 $NUM_DISKS);do
	dd if=/dev/zero bs=1474560 count=1 of=$TMPDIR/$i.img
	mkdosfs -n NetbootCD$i $TMPDIR/$i.img
	mkdir $TMPDIR/a$i
	mount -o loop $TMPDIR/$i.img $TMPDIR/a$i
	cp -v $TMPDIR/$i/* $TMPDIR/a$i/
	sleep 0.2;umount $TMPDIR/a$i
	rmdir $TMPDIR/a$i
	mv $TMPDIR/$i.img ${DONE}/floppy/$i.img
done

cd $DONE/floppy
cp 1.img ../NetbootCD-$NBCDVER-floppy.img
zip ../NetbootCD-$NBCDVER-floppy-set.zip *.img
cd -
ln -s ${DONE}/NetbootCD-$NBCDVER-floppy.img ${DONE}/NetbootCD-floppy.img
ln -s ${DONE}/NetbootCD-$NBCDVER-floppy-set.zip ${DONE}/NetbootCD-floppy-set.zip

chown -R 1000.1000 $DONE
