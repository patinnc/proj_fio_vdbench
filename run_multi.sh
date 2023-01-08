#!/usr/bin/env bash

# 4 x 4 x 4 x 7 x 2
DRV_LST="1,2,4,7"
OPER_LST="read,write,randread,randwrite"
JOB_LST="1,2,4,8"
BLK_LST="4k,16k,32k,64k,128k,256k,1m"
WRK_LST="fio,vdb"
DRVS="nvme0n1,nvme1n1,nvme2n1,nvme3n1,nvme4n1,nvme5n1,nvme6n1,nvme7n1"
DRVS="nvme0n1,nvme1n1,nvme2n1,nvme3n1,nvme4n1,nvme5n1,nvme6n1"
TM=60
THRDS=64

if [ 1 == 2 ]; then
JOB_LST=8
DRV_LST=3
#JOB_LST=10
OPER_LST=randread
BLK_LST=4k
WRK_LST=vdb
TM=10
WRK_LST="vdb"
PER_DRV=0
USE_NUMA=1
DRV_LST=4
DRVS="nvme0n1,nvme1n1,nvme2n1,nvme3n1" # ,nvme4n1,nvme5n1,nvme7n1"
DRV_LST=3
DRVS="nvme4n1,nvme5n1,nvme7n1"
DRV_LST=4
DRV_LST=7
DRVS="nvme0n1,nvme1n1,nvme2n1,nvme3n1,nvme4n1,nvme5n1,nvme6n1"
#DRVS="nvme4n1,nvme5n1,nvme7n1"
fi

#THRDS=32
USE_NUMA=1


WRK_LST="fio"
PER_DRV=1
./do_fio.sh -y  --dry_run 0 -L $DRVS -f 0  -n $USE_NUMA -O $OPER_LST -p 1 -P $PER_DRV -t $TM -J $JOB_LST -T $THRDS -r 1 -B $BLK_LST -W $WRK_LST -D $DRV_LST
WRK_LST="vdb"
PER_DRV=0
./do_fio.sh -y  --dry_run 0 -L $DRVS -f 0  -n $USE_NUMA -O $OPER_LST -p 1 -P $PER_DRV -t $TM -J $JOB_LST -T $THRDS -r 1 -B $BLK_LST -W $WRK_LST -D $DRV_LST

#./do_fio.sh -y  --dry_run 0 -L nvme0n1,nvme1n1,nvme2n1,nvme3n1,nvme4n1,nvme5n1,nvme6n1,nvme7n1 -f 0  -n 1 -O randread -p 1 -P 1 -t 10 -J 4 -T 64 -r 1 -B 4k -W fio,vdb -D 4
