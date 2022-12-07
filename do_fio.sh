#!/usr/bin/env bash

# MIT License
# 
# Copyright (c) 2022 Patrick Fay
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

SCR_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
#if [ "$1" != "" ]; then
#  EXT_SFX="$1"
#fi
# do fio on raw raid dev
# ./do_fio.sh  -f 0 -D 1 -L "md127" -J 16 -T 32 -O "randread" -B 4k --raw  -t 20  -R md127
# do fio on raw 4 devices
# ./do_fio.sh  -f 0 -D 4 -L "nvme1n1 nvme2n1 nvme3n1 nvme4n1" -J 16 -T 32 -O "randread" -B 4k --raw  -t 60  -R 0
# do fio on raid with file system mounted at /mnt/disk
# ./raid_setup.sh -d 1 -f 1 -m /mnt/disk -R /dev/md127 # setup raw raid, with filesystem
# ./do_fio.sh  -f 1 -D 1 -L "md127" -J 16 -T 32 -O "randread" -B 4k --raw  -t 20  -R md127 -m /mnt/disk/

STOP_FL="do_fio.stop"
if [ -e $STOP_FL ]; then
  rm $STOP_FL
fi

GOT_QUIT=0
# function called by trap
catch_signal() {
    printf "\rSIGINT caught      "
    GOT_QUIT=1
}

trap 'catch_signal' SIGINT

ck_last_rc() {
   local RC=$1
   local FROM=$2
   if [ $RC -gt 0 ]; then
      echo "$0: got non-zero RC=$RC at $LINENO. called from line $FROM" >&2
      exit $RC
   fi
}

cd $SCR_DIR


USE_RAID=
USE_FS=1
USE_FS=
RAW=
USE_MNT=

DRY=0  # dry_run false, run everything
DRY=1  # dry_run true, don't run fio, don't run iostat, but dirs and output files ok.
DRY=  # force specifying on cmdline
TM_RUN=60
VRB=0

#fio --filename=/dev/md0 --direct=1 --size=100% --log_avg_msec=10000 --filename=fio_test_file --ioengine=libaio --name disk_fill --rw=write --bs=256k --iodepth=8

while getopts "hvy-:B:c:D:f:J:L:m:O:p:R:r:s:t:T:" opt; do
  case "${opt}" in
    - )
            case "${OPTARG}" in
                dry_run)
                    val="${!OPTIND}"; OPTIND=$(( OPTIND + 1 ))
                    #OPTIND=$(( OPTIND + 1 ))
                    #val="${!OPTIND}"; # OPTIND=$(( OPTIND + 1 ))
                    #val=${OPTARG#*=}
                    #echo "Parsing option: '--${OPTARG}', value: '${val}'" >&2;
                    DRY=$val
                    echo "$0.$LINENO got --dry_run $DRY"
                    ;;
                raw)
                    #val="${!OPTIND}"; #OPTIND=$(( $OPTIND + 1 ))
                    #echo "Parsing option: '--${OPTARG}', value: '${val}'" >&2;
                    #echo "Parsing option: '--${OPTARG}', value: '${val}'" >&2;
                    echo "$0.$LINENO got raw=1"
                    RAW=1
                    ;;
                #dry_run)
                #    val="${!OPTIND}"; OPTIND=$(( $OPTIND + 1 ))
                #    echo "Parsing option: '--${OPTARG}', value: '${val}'" >&2;
                #    echo "$0.$LINENO got dry-run=1"
                #    ;;
                loglevel=*)
                    val=${OPTARG#*=}
                    opt=${OPTARG%=$val}
                    echo "$0.$LINENO Parsing option: '--${opt}', value: '${val}'" >&2
                    ;;
                *)
                    if [ "$OPTERR" = 1 ] && [ "${optspec:0:1}" != ":" ]; then
                        echo "$0.$LINENO Unknown option --${OPTARG}" >&2
                        exit 1
                    fi
                    ;;
            esac;;
    B )
      BLK_LST_IN="$(echo "$OPTARG" | sed 's/,/ /g')"
      ;;
    c )
      COUNT_BLKS_IN="$(echo "$OPTARG" | sed 's/,/ /g')"
      ;;
    D )
      DRVS_LST_IN="$(echo "$OPTARG" | sed 's/,/ /g')"
      echo "$0.$LINENO DRVS_LST_IN= $DRVS_LST_IN"
      ;;
    f )
      USE_FS=$OPTARG
      ;;
    J )
      JOBS_LST_IN="$(echo "$OPTARG" | sed 's/,/ /g')"
      ;;
    L )
      LST_DEVS_IN="$(echo "$OPTARG" | sed 's/,/ /g')"
      ;;
    m )
      USE_MNT=$OPTARG
      ;;
    O )
      OPER_IN="$(echo "$OPTARG" | sed 's/,/ /g')"
      ;;
    p )
      PERF_IN="$(echo "$OPTARG" | sed 's/,/ /g')"
      ;;
    R )
      USE_RAID=$OPTARG  # like md0 or md127  or 0 for don't use raid (the default)
      ;;
    r )
      RAW=$OPTARG
      ;;
    s )
      SFX_IN=$OPTARG  # add to filename "like -s _m0" to avoid multiple jobs with same filenames
      ;;
    t )
      TM_RUN=$OPTARG
      ;;
    T )
      THRD_LST_IN="$(echo "$OPTARG" | sed 's/,/ /g')"
      ;;
    v )
      VRB=$((VRB+1))
      ;;
    y )
      ACCEPT_LICENSE="y"
      ;;
    h )
      echo "$0 run fio... loop over cmdline  parameters"
      echo "Usage: $0 [-h] do fio with parameters"
      echo "  does loop over:"
      echo "    for MAX_DRIVES in drives_list_to_use"
      echo "      for JOBS in jobs_list"
      echo "        for JOBS in thread_list"
      echo "          for BLK_SZ in block_list"
      echo "            for OPER in operation_list"
      echo "              fio cmd..."
      echo "   --dry_run 0|1  if 1 then don't run fio or iostat but show cmds. Also displays count of fio cmds that will be run. default is 1"
      echo "   --raw      write to raw device. Will destroy any file system on the devices"
      echo "   -B block_list  like 4k[,16k,1m etc. fio -bs= parameter"
      echo "   -c precondition_size_to_use    default is 100% but you can do 100g to shorten/test preconditioning logic. fio --size= paramter"
      echo "     If you specify a project dir the benchmark results are looked for"
      echo "     under /project_dir/"
      echo "   -D drives_list_to_use like 1,2,4,8 to use 1 drive in the list devices, then 1st 2 drives in list, etc. (see -L device_list)"
      echo "   -f file_system_use   0 to not use file system or 1 to use file system."
      echo "   -h     this help info"
      echo "   -J jobs_list  like 1,2,16  start X jobs. This is the fio --numjobs= parameter"
      echo "   -L devices_list  like nvme0n1,nvme1n1[,...]   is the fio --numjobs= parameter"
      echo "   -m mount_point   like /mnt/disk or /disk/1    assumes the devices are mounted to this mount point and assumes -f 1 (use file system)"
      echo "   -O operation_list  like op1[,op2[,...]]    like randread randwrite read write or precondition. fio -rw parameter"
      echo "   -R raid_dev   use the raid device like md0 or md127 (checked against /proc/mdstat). operations will be against this device instead of nvme0n1 etc."
      echo "   -r raw1_or_no0  1 means use raw device (wipe out file system"
      echo "   -s suffix_to_add_to_filenames   a string that will be added to file names"
      echo "   -t time_in_secs                 time for each operation. fio --runtime= parameter"
      echo "   -T thread_list    like 1[,2[,...]]  threads per job. fio --iodepth= parameter"
      echo "   -v     verbose"
      echo "   -y     accept license and acknowledge you may wipe out disks"
      echo " "
      exit 1
      ;;
    : )
      echo "$0.$LINENO Invalid option: $OPTARG requires an argument" 1>&2
      exit 1
      ;;
    \? )
      echo "$0.$LINENO Invalid option: $OPTARG" 1>&2
      exit 1
      ;;
  esac
done
echo "$0.$LINENO cmdline $0 $@"
shift $((OPTIND -1))
echo "$0.$LINENO bye. oper_in= $OPER_IN DRY= $DRY"

if [ "$LST_DEVS_IN" == "" ]; then
  echo "$0.$LINENO you must specify the nvme drives to be used for example -L nvme1n1,nvme2n2[,...] bye."
  exit 1
fi
if [ "$ACCEPT_LICENSE" != "y" ]; then
  echo "$0.$LINENO these scripts will wipe out nvme drives: $LST_DEVS_IN"
  echo "$0.$LINENO only remove the line below if you accept the MIT license"
  echo "$0.$LINENO or add -y option to indicate you agree to the license and potential loss of disk data"
  exit 1
fi

#exit 1
if [[ "$USE_FS" == "1" ]] && [[ "$RAW" == "1" ]]; then
  echo "$0.$LINENO USE_FS= $USE_FS and RAW= $RAW. Both can't be set. you have \"-f 1 -r 1|--raw\"  bye"
  exit 1
fi
if [[ "$USE_FS" != "1" ]] &&  [[ "$RAW" != "1" ]]; then
  echo "$0.$LINENO USE_FS != 1 and RAW != 1. One of them must be set. Must do \"-f 1\" or \"-r 1\". bye"
  exit 1
fi
if [[ "$USE_FS" == "1" ]]; then
  echo "$0.$LINENO got USE_FS == 1 so setting RAW= 0"
  RAW=0
fi
if [[ "$RAW" == "1" ]]; then
  echo "$0.$LINENO got RAW == 1 so setting USE_FS= 0"
  USE_FS=0
fi

if [[ "$VRB" -gt "0" ]]; then
  echo "$0.$LINENO dry= $DRY"
  echo "$0.$LINENO raw= $RAW"
  echo "$0.$LINENO BLK_LST_IN= $BLK_LST_IN"
  echo "$0.$LINENO COUNT_BLKS_IN= $COUNT_BLKS_IN"
  echo "$0.$LINENO DRVS_LST_IN= $DRVS_LST_IN "
  echo "$0.$LINENO USE_FS= $USE_FS "
  echo "$0.$LINENO JOBS_LST_IN= $JOBS_LST_IN "
  echo "$0.$LINENO LST_DEVS_IN= $LST_DEVS_IN "
  echo "$0.$LINENO USE_MNT= $USE_MNT "
  echo "$0.$LINENO OPER_IN= $OPER_IN "
  echo "$0.$LINENO PERF_IN= $PERF_IN "
  echo "$0.$LINENO USE_RAID= $USE_RAID "
  echo "$0.$LINENO SFX_IN= $SFX_IN "
  echo "$0.$LINENO TM_RUN= $TM_RUN "
  echo "$0.$LINENO THRD_LST_IN= $THRD_LST_IN "
  echo "$0.$LINENO VRB= $VRB "
fi

$SCR_DIR/../60secs/set_freq.sh -g performance
ulimit -Sn 500000

if [[ "$DRY" != "0" ]] && [[ "$DRY" != "1" ]]; then
  echo "$0.$LINENO you must do '--dry_run 0' (actually do it) or '--dry_run 1' (just show cmds, don't do fio). got \"--dry_run $DRY\". bye"
  exit 1
fi

VDBENCHDEVICES=$(lsblk -dnp -oNAME | grep nvme | sort)
if [[ "$USE_RAID" != "" ]]; then
  RAID_DEV=$(cat /proc/mdstat | awk -v rd="$USE_RAID" '$1 == rd {print "/dev/"$1;}')
  echo "$0.$LINENO RAID_DEV= $RAID_DEV"
  USE_RAID=1
  #echo "$0.$LINENO bye"
  #exit 1
fi
#  echo "$0.$LINENO bye use_raid= $USE_RAID raid_dev= $RAID_DEV"
#  exit 1

if [ "$RAW" == "1" ]; then
  # now find data mountpoints
  if [ "$LST_DEVS_IN" != "" ]; then
    NEW_LST=
    SEP=
    for i in `echo $VDBENCHDEVICES`;do 
      for j in $LST_DEVS_IN; do
        if [[ "$i" == "$j" ]] || [[ "$i" == "/dev/$j" ]]; then
          got_it=1
          NEW_LST="${NEW_LST}${SEP}$i"
          SEP=" "
          break
        fi
      done
    done
    if [[ "$USE_RAID" == "1" ]] && [[ "$RAID_DEV" != "" ]]; then
      NEW_LST="$RAID_DEV"
    else
      if [ "$NEW_LST" == "" ]; then
        echo "$0.$LINENO problem: list of devices= $VDBENCHDEVICES"
        echo "$0.$LINENO you entered a device list using -L \"$LST_DEVS_IN\" but none of the -D list drives found in list of devices above. bye"
        echo "$0.$LINENO dont need to prefix -L devices with /dev/"
        exit 1
      fi
    fi
    VDBENCHDEVICES=$NEW_LST
  fi
  WRITABLE_DEVICES=$(for i in `echo $VDBENCHDEVICES`;do 
     lsblk $i -bnp -o MOUNTPOINT -J | jq '.blockdevices[].mountpoint' | sed 's/"//g'
  done | sort | uniq)
  CK_NULL=$(echo "$WRITABLE_DEVICES")
  if [[ "$USE_FS" == "0" ]] && [[ "$CK_NULL" != "null" ]]; then
    echo "$0.$LINENO for raw IO the disks can't be mounted. got mountpoints:"
    for i in `echo $VDBENCHDEVICES`;do 
      lsblk $i -bnp -o MOUNTPOINT -J | jq '.blockdevices[].mountpoint' | sed 's/"//g'
    done
    exit 1
  fi
  if [[ "$USE_FS" == "1" ]] && [[  "$CK_NULL" == "null" ]]; then
    for i in `echo $VDBENCHDEVICES`;do 
      lsblk $i -bnp -o MOUNTPOINT -J | jq '.blockdevices[].mountpoint' | sed 's/"//g'
    done
    echo "$0.$LINENO got use_fs= $USE_FS and no mount point"
    exit 1
  fi
fi
if [ "$RAW" == "0" ]; then
  WRITABLE_DEVICES=$(for i in `echo $VDBENCHDEVICES`;do 
     lsblk $i -bnp -o MOUNTPOINT -J | jq '.blockdevices[].mountpoint' | sed 's/"//g'
  done | sort | uniq | grep -v null)
     #lsblk $i -bnp -o MOUNTPOINT -J | jq '.blockdevices[].mountpoint' | sed 's/"//g'
  #cat /tmp/writable_devices.log
  CK_NULL=$(echo "$WRITABLE_DEVICES")
  echo "$0.$LINENO ck_null= $CK_NULL"
  if [[ "$USE_FS" == "1" ]] && [[  "$CK_NULL" == "null" ]]; then
    for i in `echo $VDBENCHDEVICES`;do 
      lsblk $i -bnp -o MOUNTPOINT -J | jq '.blockdevices[].mountpoint' | sed 's/"//g'
    done
    echo "$0.$LINENO got use_fs= $USE_FS and no mount point"
    exit 1
  fi
  MNT_PT="$CK_NULL"
  if [[ "$USE_MNT" != "" ]]; then
    CK_MNT=$(echo "$CK_NULL" | grep "$USE_MNT")
    if [ "$CK_MNT" == "" ]; then
      echo "$0.$LINENO didn't find mount point $USE_MNT in mount point list: $CK_NULL. bye"
      exit 1
    fi
    MNT_PT=$USE_MNT
    echo "$0.$LINENO use mount point $MNT_PT"
  fi
fi
echo "$0.$LINENO writable_devices= $WRITABLE_DEVICES"

echo "$0.$LINENO vdbenchdevices= $VDBENCHDEVICES"

CK_IOST=$(which iostat)
if [ "$CK_IOST" == "" ]; then
  apt-get -y install sysstat
fi

OPT_THR="--thread"  # hangs for numjobs 512
OPT_THR=
FIO_BIN=fio # system fio
FIO_BIN=$SCR_DIR/fio
if [ ! -e $FIO_BIN ]; then
  WFIO=$(which fio)
  if [ "$WFIO" == "" ]; then
    echo "$0.$LINENO didn't find fio in $SCR_DIR nor in system path. bye"
    exit 1
  fi
  FIO_BIN=$WFIO
fi

#THREADS=16
#THREADS=128
#THREADS=64
#THREADS=32
#SZ=128k
#SZ=1m
#SZ=4k
#RS=read
#RS=randrdwr
#RS=randwrite
#RS=write
#RS=read
#RS=randread

echo "$0.$LINENO VDBENCHDEVICES= $VDBENCHDEVICES"
#DRV=$(echo "$VDBENCHDEVICES"|head -1)
#MAX_DRIVES=8
#OPER_LST="read write"
#echo "$0.$LINENO got to here"

RUNS_IN_LOOP=0
FIO_DIR="fio_data"
if [ ! -d "$FIO_DIR" ]; then
  mkdir -p "$FIO_DIR"
fi
IOSTAT_DIR="iostat_data"
if [ ! -d "$IOSTAT_DIR" ]; then
  mkdir -p "$IOSTAT_DIR"
fi

#echo "$0.$LINENO got to here"
TM_BEG=$(date +"%s")
#DRVS_LST="1 2 4 8"
#JOBS_LST="1 2 4 8"
#THRD_LST="16 32 64 128 256"
#BLK_LST="4k 16k 128k 256k 1m"
#OPER_LST="read write randread randwrite"

if [[ "$PERF_IN" == "1" ]]; then
  PERF_BIN="$SCR_DIR/../patrick_fay_bin/perf"
  if [ ! -e $PERF_BIN ]; then
    PERF_BIN=$(which perf)
    if [ "$PERF_BIN" == "" ]; then
      echo "$0.$LINENO you entered -p 1 (do perf) but didn't find perf in system path and not in $SCR_DIR/../patrick_fay_bin. bye"
      exit 1
    fi
  fi
fi
#echo "$0.$LINENO bye"
#exit 1
#echo "$0.$LINENO got to here"

#DRVS_LST="1 2 4 8"
#DRVS_LST="8"
#JOBS_LST="1024"
#THRD_LST="32"
#OPER_LST="randwrite"
#OPER_LST="read"
#BLK_LST="4k 16k 128k 256k 1m"
#OPER_LST="read write randread randwrite"
#
#DRVS_LST="1"
#OPER_LST="read write"
#BLK_LST="128k"
#OPER_LST="randwrite"
#OPER_LST="randread"
#BLK_LST="4k"
#echo "$0.$LINENO got to here"
if [ "$OPER_IN" != "" ]; then
  OPER_LST=$OPER_IN
fi
if [ "$BLK_LST_IN" != "" ]; then
  BLK_LST=$BLK_LST_IN
fi
if [ "$DRVS_LST_IN" != "" ]; then
  DRVS_LST=$DRVS_LST_IN
fi
if [ "$JOBS_LST_IN" != "" ]; then
  JOBS_LST=$JOBS_LST_IN
fi
if [ "$THRD_LST_IN" != "" ]; then
  THRD_LST=$THRD_LST_IN
fi
GOT_PRECOND=0
NUM_CPUS=$(grep -c processor /proc/cpuinfo)

#echo "$0.$LINENO got to here"
#if [[ "$USE_RAID" == "1" ]]; then
#  DRVS_LST="8"
#fi
echo "$0.$LINENO DRVS_LST= $DRVS_LST"
echo "$0.$LINENO JOBS_LST= $JOBS_LST"
echo "$0.$LINENO THRD_LST= $THRD_LST"
echo "$0.$LINENO BLK_LST= $BLK_LST"
echo "$0.$LINENO OPER_LST= $OPER_LST"
for MAX_DRIVES in $DRVS_LST; do
  j=0
  DRV=
  SEP=
  SEP2=
  IO_DSK_LST=
  for i in $VDBENCHDEVICES; do
    DRV="${DRV}${SEP}${i}"
    DNUM=$(echo $i | sed 's/.*nvme//;s/n1$//')
#nvme0n1
#nvme0c0n1
    TRY_DEV="nvme${DNUM}c${DNUM}n1"
    if [ ! -e /sys/class/nvme/nvme${DNUM}/$TRY_DEV ]; then
      TRY_DEV="nvme${DNUM}n1"
    fi
    IO_DSK_LST="${IO_DSK_LST}${SEP2}${TRY_DEV}"
    #IO_DSK_LST="$IO_DSK_LST /dev/nvme${j}c${j}n1"
    j=$((j+1))
    if [[ "$j" -ge "$MAX_DRIVES" ]]; then
      break
    fi
    SEP=","
    SEP2=","
    SEP=":"
  done
  echo "$0.$LINENO IO_DSK_LST= $IO_DSK_LST"
  #IO_DSK_LST="ALL"
  #IO_DSK_LST=$(lsblk |grep -E "nvme.*n1 |-md1"|sed 's/.*nvme/nvme/;s/.*md1/md1/' |sort|uniq|awk 'BEGIN{sep="";}{v=v sep "/dev/"$1; sep=",";}END{print v;}')
  DRVS=$j
  echo "$0.$LINENO DRV= $DRV"

  if [[ "$RAW" == "1" ]] && [[  "$USE_RAID" == "1" ]]; then
    IO_DSK_LST="$RAID_DEV $IO_DSK_LST"
    DRVS=1
    DRV=$RAID_DEV
  fi
  echo "$0.$LINENO DRV= $DRV"

  OPT_FSZ=
  if [[ "$USE_FS" == "1" ]] && [[ "$MNT_PT" != "" ]]; then
   DRV="$MNT_PT/fio_data"
   OPT_FSZ="--size 3072G"
   OPT_FSZ="--size 100G"
   DRVS=1
  fi
  echo "$0.$LINENO DRV= $DRV"


  #echo "$0.$LINENO DRV= $DRV"
  #exit 1
  #echo "$0.$LINENO IO_DSK_LST= $IO_DSK_LST"
  for JOBS in $JOBS_LST; do
    for THREADS in $THRD_LST; do
      for BLK_SZ in $BLK_LST; do
        for OPER in $OPER_LST; do
          SFX="_${BLK_SZ}_${OPER}${SFX_IN}"
          OFL="f_rep${SFX}.txt"
          if [ -e $OFL ]; then
            rm $OFL
          fi
          OPT_REP=
          #if [[ "$OPER" == *"rand"* ]]; then
            #OPT_REP="--randrepeat 0"
            OPT_REP="--norandommap --randrepeat 0"
          #fi
          
          IO_FL=$(printf "%s/iostat%s_%.3djobs_%.3dthrds_%ddrvs_%draid_%draw_%dfs.txt" $IOSTAT_DIR ${SFX} ${JOBS} ${THREADS} ${DRVS} ${USE_RAID} ${RAW} ${USE_FS})
          FIO_FL=$(printf "%s/fio%s_%.3djobs_%.3dthrds_%ddrvs_%draid_%draw_%dfs.txt" $FIO_DIR ${SFX} ${JOBS} ${THREADS} ${DRVS} ${USE_RAID} ${RAW} ${USE_FS})
          if [ -e $FIO_FL ]; then
            rm $FIO_FL
          fi
          SV_TM_RUN=$TM_RUN
          if [[ "$OPER" == "precondition" ]] && [[ "$GOT_PRECOND" == "0" ]]; then
            TM_RUN=36000 # 10 hours? it will get killed below
          fi
          echo "iostat -c -d -p $IO_DSK_LST -x 1 $TM_RUN > $IO_FL" > $IO_FL
          #exit 1
          if [ "$DRY" == "0" ]; then
            #echo "$0.$LINENO IO_DSK_LST= $IO_DSK_LST"
            #iostat -c -d -p $IO_DSK_LST -x 1 $TM_RUN >> $IO_FL &
            iostat -c -d -p $IO_DSK_LST -x 1 $TM_RUN >> $IO_FL &
            IOS_PID=$!
          fi
          echo $IO_FL > iostat_file_cur.txt

          # ===================== preconditioning ==============
          if [[ "$OPER" == "precondition" ]] && [[ "$GOT_PRECOND" == "0" ]] && [[ "$RAW" == "1" ]] && [[ "$USE_RAID" == "" ]]; then
            GOT_PRECOND=1
            OPT_COUNT=
            if [ "$COUNT_BLKS_IN" != "" ]; then
              OPT_COUNT=" count=$COUNT_BLKS_IN "
            fi
            PC_BLK_SZ=1m # breaks up reqs into smaller size
            PC_BLK_SZ=128k
            PC_BLK_SZ=512k # breaks up reqs into smaller size
            PC_BLK_SZ=256k
            #echo "$0.$LINENO start 2 dd zeros of $DRV > $OFL"
            DLST=$(echo "$DRV" | sed 's/:/ /g')
            for jj in $DLST; do
              V="$(echo $jj |sed 's!/dev/!!')"
              V_MS=$(cat /sys/class/block/$V/queue/max_segments)
              V_SZ=$(awk -v v_ms="$V_MS" 'BEGIN{ sz = v_ms * 4; sz1 = int(sz/4)*4; printf("%d\n", sz1);exit(0);}')
              ck_last_rc $? $LINENO
              break
            done
            if [ "$V_SZ" == "" ]; then
              V_SZ=256
            fi
            echo "$0.$LINENO precond mx size= ${V_SZ}k"
            PC_BLK_SZ="${V_SZ}k"
            #PC_BLK_SZ=1m # breaks up reqs into smaller size
            #exit 1
            OFL=$FIO_FL
            if [[ "$OFL" != "" ]] && [[ -e $OFL* ]]; then
              rm $OFL*
            fi
            kk=-1
            for jj in $DLST; do
              kk=$((kk+1))
              echo $0.$LINENO start precond of drive $jj > $OFL.$kk
              echo nvme format $jj -s 1
              echo nvme format $jj -s 1 >> $OFL.$kk
                   nvme format $jj -s 1 >> $OFL.$kk
            done
            PREC_SZ=" --size=100% "
            if [ "$COUNT_BLKS_IN" != "" ]; then
              PREC_SZ=" --size=$COUNT_BLKS_IN "
            fi
            kk=-1
            PRECOND_OFILES=
            PRECOND_PIDS=
            for jj in $DLST; do
            kk=$((kk+1))
            PRECOND_OFILES="$OFL.$kk $PRECOND_OFILES"
            echo __cmd $FIO_BIN --filename=$jj $OPT_THR --direct=1 $OPT_REP --rw=write --bs=$PC_BLK_SZ --ioengine=libaio --iodepth=32 $PREC_SZ --numjobs=1 --group_reporting --name=precondition --eta-newline=1 --loops=2
            echo __cmd $FIO_BIN --filename=$jj $OPT_THR --direct=1 $OPT_REP --rw=write --bs=$PC_BLK_SZ --ioengine=libaio --iodepth=32 $PREC_SZ --numjobs=1 --group_reporting --name=precondition --eta-newline=1 --loops=2 >> $OFL.$kk
            echo "__threads $THREADS" >> $OFL.$kk
            echo "__jobs 1" >> $OFL.$kk
            echo "__raw 1" >> $OFL.$kk
            echo "__drives 1" >> $OFL.$kk
            echo "__drv $jj" >> $OFL.$kk
            echo "__blk_sz $PC_BLK_SZ" >> $OFL.$kk
            echo "__seq_rnd write" >> $OFL.$kk
            echo "__elap_secs -1" >> $OFL.$kk
            echo "__size $COUNT_BLKS_IN" >> $OFL.$kk
            RUNS_IN_LOOP=$((RUNS_IN_LOOP+1))
            if [ "$DRY" == "0" ]; then
                  nohup $OPT_PERF $FIO_BIN --filename=$jj $OPT_THR --direct=1 $OPT_REP --rw=write --bs=$PC_BLK_SZ --ioengine=libaio --iodepth=32 $PREC_SZ --numjobs=1 --group_reporting --name=precondition --eta-newline=1 --loops=2 >> $OFL.$kk 2> $OFL.stderr.$kk &
                  PRECOND_PIDS="$! $PRECOND_PIDS"
            fi
            done
            GOT_PRECOND=2
            PRECOND_OFL_MAX=$kk
            if [ "$PRECOND_PIDS" != "" ]; then
              wait $PRECOND_PIDS
            fi
            jobs
            echo "$0.$LINENO after doing preconditioning stdout files are below before concat into $OFL:"
            ls -l $OFL*
            #cat $PRECOND_OFILES > $OFL
            #echo "$0.$LINENO after doing preconditioning new $OFL"
            #cat $OFL
          fi

          # ===================== not preconditioning ==============
          TM_RUN=$SV_TM_RUN
          OPT_XTR=" --random_generator=lfsr "
          OFL=$FIO_FL
          echo "$0.$LINENO ofl= $OFL"
          if [ "$GOT_PRECOND" == "0" ]; then
            echo __cmd $FIO_BIN --filename=$DRV $OPT_THR $OPT_XTR --direct=1 $OPT_REP --rw=$OPER --bs=$BLK_SZ --ioengine=libaio --iodepth=$THREADS $OPT_FSZ --runtime=$TM_RUN --numjobs=$JOBS --time_based --group_reporting --name=iops-test-job --eta-newline=1
            echo __cmd $FIO_BIN --filename=$DRV $OPT_THR $OPT_XTR --direct=1 $OPT_REP --rw=$OPER --bs=$BLK_SZ --ioengine=libaio --iodepth=$THREADS $OPT_FSZ --runtime=$TM_RUN --numjobs=$JOBS --time_based --group_reporting --name=iops-test-job --eta-newline=1 >> $OFL
            echo "__threads $THREADS" >> $OFL
            echo "__jobs $JOBS" >> $OFL
            echo "__raw $RAW" >> $OFL
            echo "__drives $DRVS" >> $OFL
            echo "__drv $DRV" >> $OFL
            echo "__blk_sz $BLK_SZ" >> $OFL
            echo "__seq_rnd $OPER" >> $OFL
            echo "__elap_secs $TM_RUN" >> $OFL
            echo "__size $COUNT_BLKS_IN" >> $OFL
          fi
          RUNS_IN_LOOP=$((RUNS_IN_LOOP+1))
          PRF_FL=
          if [ "$PERF_IN" == "1" ]; then
            PRF_FL="$(echo "$FIO_FL" | sed 's/.txt$/_perf.txt/')"
            OPT_PERF="$PERF_BIN stat -o $PRF_FL -a -e msr/tsc/,msr/mperf/,msr/aperf/ -- "
            echo "__opt_perf= $OPT_PERF" >> $OFL
          fi
          #echo "$0.$LINENO drv $DRV"
          #exit 1
          if [ "$DRY" == "0" ]; then
            if [ "$GOT_PRECOND" == "0" ]; then
               $OPT_PERF $FIO_BIN --filename=$DRV $OPT_THR $OPT_XTR --direct=1 $OPT_REP --rw=$OPER --bs=$BLK_SZ --ioengine=libaio --iodepth=$THREADS $OPT_FSZ --runtime=$TM_RUN --numjobs=$JOBS --time_based --group_reporting --name=iops-test-job --eta-newline=1 | tee -a $OFL
            fi
          fi
          if [ "$IOS_PID" != "" ]; then
            kill -SIGTERM $IOS_PID
            IOS_PID=
          fi
          TM_CUR=$(date +"%s")
          TM_DFF=$((TM_CUR-TM_BEG))
          echo "$0.$LINENO secs_elapsed= $TM_DFF ofl= $OFL"
          if [ "$PRECOND_OFILES" != "" ]; then
            OFL="$PRECOND_OFILES"
          fi
          RES_FL="f_res${SFX_IN}.txt"
            cat $OFL | grep "^__" > $RES_FL
            awk -v num_cpus="$NUM_CPUS" -v sfx_in="$SFX" -v tm_dff="$TM_DFF" -v drvs="$DRVS" -v sz="$BLK_SZ" -v threads="$THREADS" -v procs="$JOBS" -v rdwr="$OPER" -v fio_fl="$FIO_FL" -v tm="$TM_RUN" -v iost_fl="$IO_FL" '
              BEGIN{
                szb = sz+0;
                tm += 0;
                #got_lat = 0;
                if (sfx_in == "") { sfx_in = "null";}
              }
              /^__cmd / {
                ++rn;
                fl[rn] = FILENAME;
              }
              /^__threads / { sv[rn, "threads"] = $2; }
              /^__jobs / { sv[rn, "procs"] = $2; }
              /^__drives / { sv[rn, "drvs"] = $2; }
              /^__blk_sz / { sv[rn, "sz"] = $2; }
              /^__drv / { sv[rn, "drv"] = $2; }
              /^__elap_secs / { sv[rn, "tm"] = $2; }
              /issued rwt: total=|issued rwts: total=/ {
                #issued rwt: total=0,571176,0, short=0,0,0, dropped=0,0,0
                n = split(substr($3, index($3,"=")+1), arr, ",");
                v = (arr[1] == "0" ? arr[2] : arr[1])+0;
                busy_str = "unk";
                if (idle > 0 && idle_n > 0) {
                  sv[rn, "busy"] = 100 - (idle/idle_n);
                  sv[rn, "busy_str"] = sprintf("%.3f", sv[rn, "busy"]);
                }
              }
              /msr\/tsc\// {
                if ($2 == "msr/tsc/") { v=$1; gsub(/,/, "", v); tsc = v+0;}
              }
              /msr\/mperf\// {
                if ($2 == "msr/mperf/") { v=$1; gsub(/,/, "", v); mperf = v+0;}
              }
              /msr\/aperf\// {
                if ($2 == "msr/aperf/") { v=$1; gsub(/,/, "", v); aperf = v+0;}
              }
              / seconds time elapsed/ {
                gsub(/,/, "", $1);
                perf_elapsed_secs = $1+0;
                if (tsc > 0 && mperf > 0 && num_cpus > 0) {
                  tsc_freq_ghz = 1e-9 * tsc/perf_elapsed_secs/num_cpus;
                  cpu_freq_ghz = tsc_freq_ghz * aperf / mperf;
                  unhalted_ratio = mperf / tsc;
                  unhaltedTL = unhalted_ratio * 100 * num_cpus;
                  printf("tsc= %.0f mperf= %.0f  aperf= %.0f tsc_frq= %f cpu_frq= %f unhalted_rate= %f unhTL= %f\n", tsc, mperf, aperf, tsc_freq_ghz, cpu_freq_ghz, unhalted_ratio, unhaltedTL) > "/dev/stderr";
                  # str below needs to start and end with space
                  unhalted_str = sprintf(" %%unhalted= %.3f unhaltedTL= %.3f cpu_freqGHz= %.3f ", 100 * unhalted_ratio, unhaltedTL, cpu_freq_ghz);
                }
              }
              $1 == "lat" && got_lat[rn] == "" {
                 #      lat (usec): min=24, max=22870, avg=782.89, stdev=1886.33
                 got_lat[rn] = 1;
                 lat_unit = $2;
                 n = split($5, arr, "=");
                 lat = arr[2];
                 fctr = 0;
                 if (index(lat_unit, "msec") > 0) { fctr= 0.001;}
                 else if (index(lat_unit, "usec") > 0) { fctr= 1e-6;}
                 else if (index(lat_unit, "nsec") > 0) { fctr= 1e-9;}
                 sv[rn,"lat_ms"] = 1000 * fctr * lat;
              }
              /Run status group/ {
#  WRITE: bw=3532MiB/s (3703MB/s), 3532MiB/s-3532MiB/s (3703MB/s-3703MB/s), io=60.0GiB (64.4GB), run=17397-17397msec
                #printf("got Run status group= %s\n", $0) > "/dev/stderr";
                getline;
                sv_run_ln= $0;
                #printf("line after Run status group= %s\n", $0) > "/dev/stderr";
                for (i=1; i <= NF; i++) {
                  if (index($i, "run=") == 1) {
                    n = split($i, arr, "=");
                    fctr = 1;
                    if (index(arr[2], "msec") > 0) { fctr = 0.001;}
                    n = split(arr[2], brr, "-");
                    sv[rn,"tm_act"] = brr[1] * fctr;
                  }
                }
              }
              /avg-cpu:.* %user.* %nice.* %system.* %iowait.* %steal.*%idle/ {
                getline;
                idle += $NF;
                idle_n++;
              }
              END{
                for (i=1; i <= rn; i++) {
                sz = sv[i,"sz"];
                szb = sz+0;
                if (index(sz, "k") > 0) { szb *= 1024;}
                if (index(sz, "m") > 0) { szb *= 1024*1024;}
                tm = sv[i,"tm"];
                tm_act = sv[i,"tm_act"];
                if (tm == -1 && tm_act > 0) { tm = tm_act; }
                if (unhalted_str == "") { my_unhalted_str = " ";} else { my_unhalted_str = unhalted_str;}
                #printf("v= %s tm= %s szb= %s tm_act= %s sv_ln= %s\n", v, tm, szb, tm_act, sv_run_ln) > "/dev/stderr";
                drvs = sv[i,"drvs"]; threads = sv[i,"threads"]; procs = sv[i,"procs"]; busy_str = sv[i,"busy_str"];
                lat_ms = sv[i,"lat_ms"];
                drv = sv[i,"drv"];
                printf("qq drives= %d oper= %s sz= %s IOPS(k)= %.3f bw(MB/s)= %.3f szKiB= %d iodepth= %d procs= %d tm_act_secs= %.4f %%busy= %s lat_ms= %f sfx= %s%sdrv= %s iostat= %s fio_fl= %s\n",
                 drvs, rdwr, sz, 0.001 * v/tm, 1e-6 * v * szb / tm, szb/1024, threads, procs, tm_act, busy_str, lat_ms, sfx_in, my_unhalted_str, drv, iost_fl, fl[i]);
                printf("\n");
                }
              }
              ' $PRF_FL $IO_FL $OFL >> $RES_FL
              ck_last_rc $? $LINENO
              cat $RES_FL
          if [ "$DRY" == "0" ]; then
              cat $RES_FL >> f_all.txt
              cat $RES_FL >> f_all${SFX}.txt
              cp  $RES_FL $FIO_FL
          fi
              if [ "$GOT_QUIT" != "0" ]; then
                if [ "$IOS_PID" != "" ]; then
                  kill -SIGTERM $IOS_PID
                  IOS_PID=
                fi
                echo "$0.$LINENO got quit. bye"
                exit 1
              fi
              if [ -e "$STOP_FL" ]; then
                if [ "$IOS_PID" != "" ]; then
                  kill -SIGTERM $IOS_PID
                  IOS_PID=
                fi
                rm $STOP_FL
                echo "$0.$LINENO got stop file $STOP_FL. bye"
                exit 1
              fi
              #echo "$0.$LINENO bye"
              #exit 1
        done # read write
      done # BLK_SZ
    done # THREADS
  done # JOBS 
done # DRVS_LST
echo "$0.$LINENO RUNS_IN_LOOP=$RUNS_IN_LOOP"
echo "qq done"
echo "qq done" >&2
exit 0

