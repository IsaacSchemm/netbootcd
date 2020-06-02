#!/bin/sh
set -e
## disksplit 1.3 - Make a Linux kernel/initrd bootable from floppy with FreeDOS
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
## <http://www.gnu.org/copyleft/gpl.html> or on the CD itself.

KERNEL="$1"
INITRD="$2"
CAT="/tmp/disksplit"
TMPDIR="/tmp/splitfiles"
DONE=$(pwd)/done/floppy

if [ ! -f $KERNEL ] || [ ! -f $INITRD ];then
	echo "Could not find both $KERNEL and $INITRD"
	exit 1
fi
if [ -d $DONE ];then
	rm -r $DONE
fi
mkdir $DONE

if [ -d $TMPDIR ];then
	umount $TMPDIR/* 2> /dev/null || true
	rm -r $TMPDIR
fi
mkdir $TMPDIR

mkdir $TMPDIR/1

tar -xvf dosfiles.tar.gz -C $TMPDIR/1
cp grldr $TMPDIR/1
echo "default 0
timeout 10

title Chainload FreeDOS -> Core 5.4 -> NetbootCD 9.0
chainloader (fd0)/kernel.sys" > $TMPDIR/1/menu.lst
echo "DEVICE=HIMEMX.EXE
LASTDRIVE=Z" > $TMPDIR/1/fdconfig.sys
echo "@ECHO OFF
XMSDSK.EXE 49152 T: /Y
COPY TINYCORE.NOT T:\TINYCORE.BAT
T:\TINYCORE.BAT" > $TMPDIR/1/autoexec.bat

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
echo $NUM_DISKS
if [ $(($FILESIZE%1457644)) -gt $(($(du -b $TMPDIR/1 | tail -n 1 | awk '{print $1}')+1024)) ];then
	echo extradisk
	EXTRADISK="true"
	NUM_DISKS=$(($NUM_DISKS+1))
else
	echo no extradisk
	EXTRADISK="false"
fi
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
CHUNK.EXE /S${BIGGER_SIZE} NBCD4.CAT FILE
LINLD.COM image=FILE.001 initrd=FILE.000 cl=@KERNELCL.TXT
" >> $TMPDIR/1/tinycore.not
echo "quiet kernelurl=http://lakora.nfshost.com/netbootcd/downloads/9.0/vmlinuz initrdurl=http://lakora.nfshost.com/netbootcd/downloads/9.0/nbinit4.gz" > $TMPDIR/1/kernelcl.txt

dd if=/dev/zero bs=1474560 count=1 of=$TMPDIR/1.img
mkdosfs -n NetbootCD1 $TMPDIR/1.img
./bootlace.com --floppy $TMPDIR/1.img
mkdir $TMPDIR/a1
mount -o loop $TMPDIR/1.img $TMPDIR/a1
cp $TMPDIR/1/* $TMPDIR/a1/
df -h $TMPDIR/a1
sleep 0.2;umount $TMPDIR/a1
rmdir $TMPDIR/a1
mv $TMPDIR/1.img ${DONE}/1.img
for i in $(seq 2 $NUM_DISKS);do
	dd if=/dev/zero bs=1474560 count=1 of=$TMPDIR/$i.img
	mkdosfs -n NetbootCD$i $TMPDIR/$i.img
	mkdir $TMPDIR/a$i
	mount -o loop $TMPDIR/$i.img $TMPDIR/a$i
	cp -v $TMPDIR/$i/* $TMPDIR/a$i/
	sleep 0.2;umount $TMPDIR/a$i
	rmdir $TMPDIR/a$i
	mv $TMPDIR/$i.img ${DONE}/$i.img
done
