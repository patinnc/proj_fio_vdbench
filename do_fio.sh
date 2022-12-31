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
PER_DRV=0

DRY=0  # dry_run false, run everything
DRY=1  # dry_run true, don't run fio, don't run iostat, but dirs and output files ok.
DRY=  # force specifying on cmdline
TM_RUN=60
VRB=0
WORK_LST_IN="fio"

#fio --filename=/dev/md0 --direct=1 --size=100% --log_avg_msec=10000 --filename=fio_test_file --ioengine=libaio --name disk_fill --rw=write --bs=256k --iodepth=8

while getopts "hvy-:B:c:D:f:J:L:m:n:O:P:p:R:r:s:t:T:W:x:" opt; do
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
    n )
      USE_NUMA=$OPTARG
      ;;
    O )
      OPER_IN="$(echo "$OPTARG" | sed 's/,/ /g')"
      ;;
    p )
      PERF_IN="$(echo "$OPTARG" | sed 's/,/ /g')"
      ;;
    P )
      PER_DRV=$OPTARG
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
    W )
      WORK_LST_IN="$(echo "$OPTARG" | sed 's/,/ /g')"
      ;;
    x )
      XTRA_OPT="$OPTARG"
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
      echo "      For vdbench you can add the number of jvms to start by adding {x} to start x number of jvms."
      echo "      For vdbench the 1st 'number' is the number of regions for each drive"
      echo "      and the 2nd number is the number of jvms to start. The vdb default is to start jvms == regions."
      echo "   -L devices_list  like nvme0n1,nvme1n1[,...]   is the fio --numjobs= parameter"
      echo "   -m mount_point   like /mnt/disk or /disk/1    assumes the devices are mounted to this mount point and assumes -f 1 (use file system)"
      echo "   -n 0|1  use numa if 1. default is 0. If 1 then lookup the node for the drive and pin the job to that node. Need 1 drive or -P 1"
      echo "   -O operation_list  like op1[,op2[,...]]    like randread randwrite read write or precondition. fio -rw parameter"
      echo "   -p 0|1  run 'perf stat' on fio job(s) if '-p 1'. Default is 0 (don't run perf stat)"
      echo "   -P 0|1  generate 1 set of job(s) per drive if '-P 1'. Default is generate feed all the selected drives to 1 set of jobs"
      echo "   -R raid_dev   use the raid device like md0 or md127 (checked against /proc/mdstat). operations will be against this device instead of nvme0n1 etc."
      echo "   -r raw1_or_no0  1 means use raw device (wipe out file system"
      echo "   -s suffix_to_add_to_filenames   a string that will be added to file names"
      echo "   -t time_in_secs                 time for each operation. fio --runtime= parameter"
      echo "   -T thread_list    like 1[,2[,...]]  threads per job. fio --iodepth= parameter"
      echo "   -W work_typ_list  like fio[,vdb]  default is fio."
      echo "   -v     verbose"
      echo "   -x \"fio options\"    options passed to fio"
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
  if [[ "$USE_FS" == "1" ]]; then
    echo "$0.$LINENO got RAW == 1 so setting USE_FS= 0"
    USE_FS=0
  fi
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

sudo $SCR_DIR/../60secs/set_freq.sh -g performance
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
    for i in `echo $VDBENCHDEVICES`; do 
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
  WRITABLE_DEVICES=$(for i in `echo $VDBENCHDEVICES`; do 
     lsblk $i -bnp -o MOUNTPOINT -J | jq '.blockdevices[].mountpoint' | sed 's/"//g'
  done | sort | uniq)
  CK_NULL=$(echo "$WRITABLE_DEVICES")
  if [[ "$USE_FS" == "0" ]] && [[ "$CK_NULL" != "null" ]]; then
    echo "$0.$LINENO for raw IO the disks can't be mounted. got mountpoints:"
    for i in `echo $VDBENCHDEVICES`; do 
      lsblk $i -bnp -o MOUNTPOINT -J | jq '.blockdevices[].mountpoint' | sed 's/"//g'
    done
    exit 1
  fi
  if [[ "$USE_FS" == "1" ]] && [[  "$CK_NULL" == "null" ]]; then
    for i in `echo $VDBENCHDEVICES`; do 
      lsblk $i -bnp -o MOUNTPOINT -J | jq '.blockdevices[].mountpoint' | sed 's/"//g'
    done
    echo "$0.$LINENO got use_fs= $USE_FS and no mount point"
    exit 1
  fi
fi
if [ "$RAW" == "0" ]; then
  WRITABLE_DEVICES=$(for i in `echo $VDBENCHDEVICES`; do 
     lsblk $i -bnp -o MOUNTPOINT -J | jq '.blockdevices[].mountpoint' | sed 's/"//g'
  done | sort | uniq | grep -v null)
     #lsblk $i -bnp -o MOUNTPOINT -J | jq '.blockdevices[].mountpoint' | sed 's/"//g'
  #cat /tmp/writable_devices.log
  CK_NULL=$(echo "$WRITABLE_DEVICES")
  echo "$0.$LINENO ck_null= $CK_NULL"
  if [[ "$USE_FS" == "1" ]] && [[  "$CK_NULL" == "null" ]]; then
    for i in `echo $VDBENCHDEVICES`; do 
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
DO_SUDO=
if [[ "$RAW" == "1" ]] || [[ "$PERF_IN" == "1" ]]; then
  DO_SUDO="sudo"
fi
for WORK_TYP in $WORK_LST_IN; do
 if [ "$DRVS_LST" == "" ]; then
   echo "$0.$LINENO DRVS_LST is empty. check -D num_drives and -L drv0[,drv1...] otions. bye"
   exit 1
 fi
 if [ "$WORK_TYP" == "vdb" ]; then
   VDB_CMD=$SCR_DIR/../vdbench50407/vdbench
   if [ ! -e "$VDB_CMD" ]; then
     echo "$0.$LINENO can't find vdbench script. Tried $VDB_CMD. Bye"
     exit 1
   fi
 else
   if [ "$WORK_TYP" != "fio" ]; then
     echo "$0.$LINENO -W work_typ_list must be fio and vdb. got $WORK_TYP. bye"
     exit 1
   fi
 fi
 FIO_DIR="${WORK_TYP}_data"
 if [ ! -d "$FIO_DIR" ]; then
   mkdir -p "$FIO_DIR"
 fi

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
  if [ "$USE_RAID" == "" ]; then
    USE_RAID="0"
  fi

  OPT_FSZ=
  if [[ "$USE_FS" == "1" ]] && [[ "$MNT_PT" != "" ]]; then
   DRV="$MNT_PT/${WORK_TYP}_data"
   OPT_FSZ="--size 3072G"
   OPT_FSZ="--size 100G"
   DRVS=1
  fi
  echo "$0.$LINENO DRV= $DRV"


  #echo "$0.$LINENO DRV= $DRV"
  #exit 1
  #echo "$0.$LINENO IO_DSK_LST= $IO_DSK_LST"
  if [ "$JOBS_LST" == "" ]; then
    echo "$0.$LINENO JOBS_LST is empty. check -J num[,num2...] option . bye"
    exit 1
  fi
  for JOBS in $JOBS_LST; do
    VDB_JVMS=
    if [[ "$JOBS" == *"{"* ]]; then
      arr=($(echo "${JOBS}" | sed 's/{/ /;s/}//'))
      if [ "${#arr[@]}" != "2" ]; then
        echo "$0.$LINENO got { in $JOBS, arr#= ${#arr[@]}, arr0= ${arr[0]} arr1= ${arr[1]}. expected 2 entries. use arg like -J 4{2} for 4 jobs and 2 vdb jvms.bye"
        exit 1
      fi
      JOBS=${arr[0]}
      VDB_JVMS=${arr[1]}
    else
      if [ "$WORK_TYP" == "vdb" ]; then
        VDB_JVMS=${JOBS}
      fi
    fi
    #echo "$0.$LINENO jobs= $JOBS. bye"
    #exit 1
    if [ "$THRD_LST" == "" ]; then
      echo "$0.$LINENO THRD_LST is empty. check -T num[,num2...] option . bye"
      exit 1
    fi
    for THREADS in $THRD_LST; do
      if [ "$BLK_LST" == "" ]; then
        echo "$0.$LINENO BLK_LST is empty. check -B blk_sz1[,blk_sz2...] option . bye"
        exit 1
      fi
      for BLK_SZ in $BLK_LST; do
        if [ "$OPER_LST" == "" ]; then
          echo "$0.$LINENO OPER_LST is empty. check -O read[,oper2...] option . bye"
          exit 1
        fi
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
          OUT_FL=$(printf "%s/${WORK_TYP}%s_%.3djobs_%.3dthrds_%ddrvs_%draid_%draw_%dfs.txt" $FIO_DIR ${SFX} ${JOBS} ${THREADS} ${DRVS} ${USE_RAID} ${RAW} ${USE_FS})
          if [ -e $OUT_FL ]; then
            rm $OUT_FL
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
          DLST=$(echo "$DRV" | sed 's/:/ /g')
          kk=-1
          for jj in $DLST; do
            kk=$((kk+1))
          done
          PD_MAX=$kk
          OFL=$OUT_FL
          OFL_RT="$(echo "$OUT_FL" | sed 's/.txt$//')"
          if [[ "$OFL_RT" != "" ]] && [[ "$(ls -1 $OFL_RT* 2> /dev/null | wc -l)" -gt "0" ]]; then
            echo "$0.$LINENO rm $OFL_RT*"
                             rm $OFL_RT*
          fi

          # ===================== preconditioning beg ==============
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
            kk=-1
            for jj in $DLST; do
              kk=$((kk+1))
              echo $0.$LINENO start precond of drive $jj > $OFL.$kk
              echo sudo nvme format $jj -s 1
              echo sudo nvme format $jj -s 1 >> $OFL.$kk
                   sudo nvme format $jj -s 1 >> $OFL.$kk
            done
            PREC_SZ=" --size=100% "
            if [ "$COUNT_BLKS_IN" != "" ]; then
              PREC_SZ=" --size=$COUNT_BLKS_IN "
            fi
            PRECOND_OFILES=
            PRECOND_PIDS=
            kk=-1
            for jj in $DLST; do
            kk=$((kk+1))
            PRECOND_OFILES="$OFL.$kk $PRECOND_OFILES"
            echo __cmd sudo $FIO_BIN --filename=$jj $OPT_THR --direct=1 $OPT_REP --rw=write --bs=$PC_BLK_SZ --ioengine=libaio --iodepth=32 $PREC_SZ --numjobs=1 --group_reporting --name=precondition --eta-newline=1 --loops=2
            echo __cmd sudo $FIO_BIN --filename=$jj $OPT_THR --direct=1 $OPT_REP --rw=write --bs=$PC_BLK_SZ --ioengine=libaio --iodepth=32 $PREC_SZ --numjobs=1 --group_reporting --name=precondition --eta-newline=1 --loops=2 >> $OFL.$kk
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
                  sudo nohup $OPT_PERF $FIO_BIN --filename=$jj $OPT_THR --direct=1 $OPT_REP --rw=write --bs=$PC_BLK_SZ --ioengine=libaio --iodepth=32 $PREC_SZ --numjobs=1 --group_reporting --name=precondition --eta-newline=1 --loops=2 >> $OFL.$kk 2> $OFL.stderr.$kk &
                  PRECOND_PIDS="$! $PRECOND_PIDS"
            fi
            done
            GOT_PRECOND=2
            PRECOND_OFL_MAX=$kk
            if [ "$PRECOND_PIDS" != "" ]; then
              wait $PRECOND_PIDS
              sudo chmod go+rw $OFL*
            fi
            jobs
            echo "$0.$LINENO after doing preconditioning stdout files are below before concat into $OFL:"
            ls -l $OFL*
            #cat $PRECOND_OFILES > $OFL
            #echo "$0.$LINENO after doing preconditioning new $OFL"
            #cat $OFL
          fi
          # ===================== preconditioning end ==============

          # ===================== not preconditioning ==============
          TM_RUN=$SV_TM_RUN
          OPT_GEN=" --random_generator=lfsr "
          OPT_IOD_BATCH=
          OPT_XTRA=
          if [ "$XTRA_OPT" != "" ]; then
            OPT_XTRA=$XTRA_OPT
          fi
          PRF_FL=
          OFL=$SCR_DIR/$OUT_FL
          OFL_LST=
          if [ "$WORK_TYP" == "vdb" ]; then
            if [ "$PER_DRV" != "1" ]; then
              DLST="$DRV"
            fi
            # JVMS_IN_CFG: if 0 then use -m jvms vdbench cmd line option (doesn't help).
            # if 1 then do hd=default,jvms= jobs, again no help.
            # if 2 then split disk into jobs ranges. This helps.
            JVMS_IN_CFG=2
            kk=-1
            OFL_ARR=()
            RT_FL_CFG=vdb_gen.cfg
            V=$(find $SCR_DIR -maxdepth 1 -name "${RT_FL_CFG}*"|wc -l)
            if [[ "$V" -gt "0" ]]; then
              rm ${RT_FL_CFG}*
            fi
            for drv in $DLST; do
              kk=$((kk+1))
              V=
              if [ "$PER_DRV" == "1" ]; then
                V="$(echo $drv |sed 's!/dev/!!;s/n1$//')"
                #if [[ "$PD_MAX" -gt "0" ]]; then
                #  OFL="$(echo "$OUT_FL" | sed "s/.txt$/.$kk.txt/")"
                #fi
                FL_CFG=$SCR_DIR/${RT_FL_CFG}.$kk
              else
                FL_CFG=$SCR_DIR/${RT_FL_CFG}.$kk
              fi
            VDBENCHGBBUFFER=10
            SEP2=
            DRV_STR=
            if [ "$RAW" == "1" ]; then
              j=0
              #echo "ios_per_jvm=1000000,dedupratio=1" >> $FL_CFG
              #echo "ios_per_jvm=1000000" >> $FL_CFG
              #echo "messagescan=no" >> $FL_CFG
              if [ "$JVMS_IN_CFG" == "1" ]; then
                if [ "$JOBS" != "" ]; then
                  echo "hd=default,jvms=$JOBS" >> $FL_CFG
                fi
              fi
              IO_DSK_LST=
              for i in `echo $VDBENCHDEVICES`; do
                #echo sd=sd$SD,lun=$j/vdbench.data,size=$(($FILESYSTEMSIZE-$VDBENCHGBBUFFER))G
                DNUM=$(echo $i | sed 's/.*nvme//;s/n1$//')
                TRY_DEV="nvme${DNUM}c${DNUM}n1"
                if [ ! -e /sys/class/nvme/nvme${DNUM}/$TRY_DEV ]; then
                  TRY_DEV="nvme${DNUM}n1"
                fi
                echo "$0.$LINENO ck_drv $drv is == $i"
                if [[ "$drv" != *"$i"* ]]; then
                  continue
                fi
                echo "$0.$LINENO vdb use drv $i"
                IO_DSK_LST="${IO_DSK_LST}${SEP2}${TRY_DEV}"
                DRV_STR="$i${SEP2}${DRV_STR}"
                SEP2=","
                #IO_DSK_LST="$IO_DSK_LST nvme${j}c${j}n1"
                # nvme0c0n1
                if [ "$RAW" == "1" ]; then
                  SZ=$(nvme list -o json | awk -v drv="$i" -v vdb_buf="$VDBENCHGBBUFFER" '
                    /DevicePath/ {
                      if ($3 == "\""drv"\",") {
                        got_it=1;
                        #printf("got drv= %s\n", $0) > "/dev/stderr";
                      }
                    }
                    /UsedBytes/ {
                      if (got_it == 1) {
                        v = $3 + 0;
                        v /= (1024*1024*1024);
                        v -= vdb_buf;
                        printf("%.0f", v);
                        #printf("got_drv_size= %s line[%s]= %s\n", v, NR, $0) > "/dev/stderr";
                        exit(0);
                      }
                    }
                  ')
                  #echo "sd=sd${j},lun=$i,size=${SZ}g" >> $FL_CFG
                  if [ "$JVMS_IN_CFG" == "2" ]; then
                    awk -v j="$j" -v jobs="$JOBS" -v lun="$i" '
                    BEGIN{
                      rc = 0;
                      if ((jobs+0) <= 0) {
                        printf("jobs has to > 0. got jobs= \"%s\". Use -J jobs_list. bye\n", jobs) > "/dev/stderr";
                        rc = 1;
                        exit(rc);
                      }
                      rng_incr = 100/jobs;
                      printf("sd=sd%s jobs= %s lun=%s range_incr= %s\n", j, jobs, lun, rng_incr) > "/dev/stderr";
                      for (i=1; i <= jobs; i++) {
                        printf("sd=sd%s_%s,lun=%s,range=(%.0f,%.0f)\n", j, i, lun, (i-1)*rng_incr, i*rng_incr);
                      }
                      exit(rc);
                    }
                    END{ exit(rc); }' >> $FL_CFG
                    ck_last_rc $? $LINENO
                  else
                    echo "sd=sd${j},lun=$i" >> $FL_CFG
                  fi
                else
                  FILESYSTEMSIZE=$(df $i --output=avail -B G | tail -1 | sed 's/G//g')
                  echo "FILESYSTEMSIZE= $FILESYSTEMSIZE"
                  echo "sd=sd${j},lun=$i,size=$((FILESYSTEMSIZE-VDBENCHGBBUFFER))g" >> $FL_CFG
                fi
                #echo "sd=sd${j},lun=$i,size=$((FILESYSTEMSIZE-VDBENCHGBBUFFER))g" >> $FL_CFG
                j=$((j+1))
                if [[ "$j" -ge "$MAX_DRIVES" ]]; then
                  break
                fi
              done
              DRVS=$j
              #echo 'wd=wd1,sd=sd*,xfersize=$xfer_sz,seekpct=$seq_rnd
        #rd=rd1,wd=wd1,openflags=o_direct,forrdpct=(100,0),iorate=max,threads=$files_threads,elapsed=$elap_secs,interval=1' >> $FL_CFG
              echo 'wd=wd1,sd=sd*,xfersize=$xfer_sz,seekpct=$seq_rnd' >> $FL_CFG
              echo 'rd=rd1,wd=wd1,openflags=o_direct,forrdpct=($rdwr),iorate=max,threads=$files_threads,elapsed=$elap_secs,interval=1' >> $FL_CFG
            else
              echo 'fsd=fsd1,anchor=$use_mnt/vd_dir,depth=1,width=1,files=$files_threads,size=$file_sz' >> $FL_CFG
              echo 'fwd=fwd1,fsd=fsd1,xfersize=$xfer_sz,fileio=$seq_rnd,fileselect=random,threads=$files_threads' >> $FL_CFG
              echo 'rd=rd1,fwd=fwd1,openflags=o_direct,foroperations=($rdwr),fwdrate=max,format=yes,elapsed=$elap_secs,interval=1' >> $FL_CFG
            fi
            i="${BLK_SZ}_${OPER}"
            if [ "$RAW" == "1" ]; then
              if [[ "$OPER" == *"read"* ]]; then
                RDWR_STR="100"
              else
                RDWR_STR="0"
              fi
            else
              if [[ "$OPER" == *"read"* ]]; then
                RDWR_STR="read"
              else
                RDWR_STR="write"
              fi
            fi
            SZ=$BLK_SZ
            RS=sequential
            if [[ "${OPER}" == *"ran"* ]]; then
              RS=random
            fi
            if [ "$RAW" == "1" ]; then
              FL_SZ_STR=
            else
              FL_SZ_STR="file_sz=$FILE_SZ"
            fi
            echo sz= ${SZ} rs= ${RS}
            
            SFX="_${SZ}_${OPER}${SFX_IN}"
            ODIR=$SCR_DIR/vdb_data/vdb_out${SFX}
            if [ "$DRY" == "0" ]; then
              mkdir -p $ODIR
            fi
            done
            OPT_JOBS=
            if [ "$JVMS_IN_CFG" == "0" ]; then
              if [ "$JOBS" != "" ]; then
                OPT_JOBS="-m $JOBS"
              fi
            fi
            if [ "$VDB_JVMS" != "" ]; then
                OPT_JOBS="-m $VDB_JVMS"
            fi
          fi
          #echo "$0.$LINENO bye"
          #exit 1

          RUNS_IN_LOOP=$((RUNS_IN_LOOP+1))
          echo "$0.$LINENO ofl= $OFL"
          if [ "$GOT_PRECOND" == "0" ]; then
            if [ "$PER_DRV" != "1" ]; then
              DLST="$DRV"
            fi
            kk=-1
            OFL_ARR=()
            for drv in $DLST; do
              kk=$((kk+1))
              V=
              if [ "$PER_DRV" == "1" ]; then
                V="$(echo $drv |sed 's!/dev/!!;s/n1$//')"
                #if [[ "$PD_MAX" -gt "0" ]]; then
                  OFL="$(echo "$OUT_FL" | sed "s/.txt$/.$kk.txt/")"
                #fi
              fi
              OFL_ARR[$kk]="$OFL"
              OFL_LST="$OFL_LST $OFL"
              if [ "$WORK_TYP" == "vdb" ]; then
                echo "$VDB_CMD $OPT_JOBS -f $SCR_DIR/$RT_FL_CFG.$kk -o $ODIR $FL_SZ_STR $OPT_MNT files_threads=$THREADS seq_rnd=$RS xfer_sz=$SZ elap_secs=$TM_RUN rdwr=$RDWR_STR > $OFL"
                echo  __cmd $VDB_CMD $OPT_JOBS -f $SCR_DIR/$RT_FL_CFG.$kk -o $ODIR $FL_SZ_STR $OPT_MNT files_threads=$THREADS seq_rnd=$RS xfer_sz=$SZ elap_secs=$TM_RUN rdwr=$RDWR_STR > $OFL
                echo "__beg_cfg $SCR_DIR/$RT_FL_CFG.$kk" >> $OFL
                cat  $SCR_DIR/$RT_FL_CFG.$kk | awk '{printf("__cfg %s\n", $0);}' >> $OFL
                echo "__end_cfg $SCR_DIR/$RT_FL_CFG.$kk" >> $OFL
              else
                echo __cmd $FIO_BIN --filename=$drv $OPT_THR $OPT_GEN --direct=1 $OPT_REP --rw=$OPER --bs=$BLK_SZ --ioengine=libaio --iodepth=$THREADS $OPT_FSZ --runtime=$TM_RUN --numjobs=$JOBS --time_based --group_reporting --name=iops-test-job --eta-newline=1 $OPT_XTRA
                echo __cmd $FIO_BIN --filename=$drv $OPT_THR $OPT_GEN --direct=1 $OPT_REP --rw=$OPER --bs=$BLK_SZ --ioengine=libaio --iodepth=$THREADS $OPT_FSZ --runtime=$TM_RUN --numjobs=$JOBS --time_based --group_reporting --name=iops-test-job --eta-newline=1 $OPT_XTRA >> $OFL
              fi
              echo "__threads $THREADS" >> $OFL
              echo "__jobs $JOBS" >> $OFL
              echo "__raw $RAW" >> $OFL
              echo "__drives $DRVS" >> $OFL
              echo "__drv $drv" >> $OFL
              echo "__blk_sz $BLK_SZ" >> $OFL
              echo "__oper $OPER" >> $OFL
              if [ "$WORK_TYP" == "vdb" ]; then
                echo "__seq_rnd $RS" >> $OFL
              fi
              echo "__elap_secs $TM_RUN" >> $OFL
              echo "__per_drv $PER_DRV" >> $OFL
              echo "__size $COUNT_BLKS_IN" >> $OFL
              OPT_PERF=
              if [[ "$kk" == "0" ]] && [[ "$PERF_IN" == "1" ]]; then
                PRF_FL="$(echo "$OUT_FL" | sed 's/.txt$/_perf.txt/')"
                if [ "$WORK_TYP" == "vdb" ]; then
                  PRF_FL="$SCR_DIR/$PRF_FL"
                fi
                OPT_PERF="$PERF_BIN stat -o $PRF_FL -a -e msr/tsc/,msr/mperf/,msr/aperf/ -- "
                echo "__opt_perf= $OPT_PERF ${WORK_TYP}_cmd... >> $OFL" >> $OFL
              fi
              OPT_NUMA=
              if [[ "$USE_NUMA" == "1" ]] && [[ "$V" != "" ]]; then
                if [ -e /sys/class/nvme/$V/numa_node ]; then
                  NUMA_NODE="$(cat /sys/class/nvme/$V/numa_node 2> /dev/null)"
                  if [ "$NUMA_NODE" != "" ]; then
                    OPT_NUMA="numactl -m $NUMA_NODE -N $NUMA_NODE"
                  fi
                fi
              fi
              if [ "$DRY" == "0" ]; then
                if [ "$WORK_TYP" == "vdb" ]; then
                  UDO_SUDO=
                  if [ "$DO_SUDO" != "" ]; then
                    UDO_SUDO="sudo -u root -i "
                  fi
                  echo "$0.$LINENO vdb cmdline= $UDO_SUDO nohup $OPT_PERF $OPT_NUMA $VDB_CMD $OPT_JOBS -f $SCR_DIR/$RT_FL_CFG.$kk -o $ODIR $FL_SZ_STR $OPT_MNT files_threads=$THREADS seq_rnd=$RS xfer_sz=$SZ elap_secs=$TM_RUN rdwr=$RDWR_STR >> $OFL 2> $OFL.stderr.txt &" > $OFL.cmdline.txt
                  $UDO_SUDO nohup $OPT_PERF $OPT_NUMA $VDB_CMD $OPT_JOBS -f $SCR_DIR/$RT_FL_CFG.$kk -o $ODIR $FL_SZ_STR $OPT_MNT files_threads=$THREADS seq_rnd=$RS xfer_sz=$SZ elap_secs=$TM_RUN rdwr=$RDWR_STR >> $OFL 2> $OFL.stderr.txt &
                else
                  echo "$0.$LINENO $DO_SUDO nohup $OPT_PERF $OPT_NUMA $FIO_BIN --filename=$drv $OPT_THR $OPT_GEN --direct=1 $OPT_REP --rw=$OPER --bs=$BLK_SZ --ioengine=libaio --iodepth=$THREADS $OPT_FSZ --runtime=$TM_RUN --numjobs=$JOBS --time_based --group_reporting --name=iops-test-job --eta-newline=1 $OPT_XTRA >> $OFL 2> $OFL.stderr.txt &" >> $OFL
                                   $DO_SUDO nohup $OPT_PERF $OPT_NUMA $FIO_BIN --filename=$drv $OPT_THR $OPT_GEN --direct=1 $OPT_REP --rw=$OPER --bs=$BLK_SZ --ioengine=libaio --iodepth=$THREADS $OPT_FSZ --runtime=$TM_RUN --numjobs=$JOBS --time_based --group_reporting --name=iops-test-job --eta-newline=1 $OPT_XTRA >> $OFL 2> $OFL.stderr.txt &
                fi
                PD_PIDS="$! $PD_PIDS"
              fi
            done
          fi
          #echo "$0.$LINENO pd_pics= $PD_PIDS"
          if [ "$PD_PIDS" != "" ]; then
            #wait $PD_PIDS
            for ck_pid in $PD_PIDS; do
              wait $ck_pid
              RC=$?
              if [ "$RC" != "0" ]; then
                echo "$0.$LINENO $WORK_TYP rc= $RC for pid= $ck_pid ======================"
              fi
            done
          fi
          if [ "$IOS_PID" != "" ]; then
            kill -SIGTERM $IOS_PID
            IOS_PID=
          fi
          TM_CUR=$(date +"%s")
          TM_DFF=$((TM_CUR-TM_BEG))
          echo "$0.$LINENO secs_elapsed= $TM_DFF ofl= $OFL_LST"
          if [[ "$DO_SUDO" != "" ]]; then
              if [[ "$PRF_FL" != "" ]]; then
                echo "$0.$LINENO fix permission on perf output file: chmod og+w $PRF_FL"
                sudo chmod og+rw $PRF_FL
              fi
              if [[ "$WORK_TYP" == "vdb" ]]; then
                echo "$0.$LINENO fix permission on vdb output dir files: chmod og+w $ODIR"
                sudo chmod og+rw $ODIR/*
              fi
          fi
          if [ "$PRECOND_OFILES" != "" ]; then
            OFL="$PRECOND_OFILES"
          else
            OFL="$OFL_LST"
          fi
          RES_FL="f_res${SFX_IN}.txt"
          echo "$0.$LINENO OFL list= $OFL"
          cat $OFL | grep "^__" > $RES_FL
          if [ "$WORK_TYP" == "fio" ]; then
            awk -v per_drv="$PER_DRV" -v num_cpus="$NUM_CPUS" -v sfx_in="$SFX" -v tm_dff="$TM_DFF" -v drvs="$DRVS" -v sz="$BLK_SZ" -v threads="$THREADS" -v procs="$JOBS" -v rdwr="$OPER" -v fio_fl="$OFL" -v tm="$TM_RUN" -v iost_fl="$IO_FL" -f $SCR_DIR/do_${WORK_TYP}_rd_output.awk $PRF_FL $IO_FL $OFL >> $RES_FL
            ck_last_rc $? $LINENO
            cat $RES_FL
            if [ "$DRY" == "0" ]; then
              cat $RES_FL >> f_all.txt
              cat $RES_FL >> f_all${SFX}.txt
              cp  $RES_FL $OUT_FL
            fi
          else
            grep "^__" $OFL > v_res.txt
            awk '/Starting RD/ {
                printf("%s\n", $0);
                getline;
                getline;
                printf("%s\n", $0);
                getline;
                printf("%s\n", $0);
              }
              / avg_/ {
                printf("%s\n", $0);
              }
              END{ printf("\n");}
            ' $OFL >> v_res.txt
            udrv="$DRV_STR"
            if [ "$PER_DRV" == "1" ]; then
              udrv="$DRVS"
            fi
            echo "$0.$LINENO ofl_lst= $OFL_LST"
            USE_OFL=v_res.txt
            USE_OFL="$OFL_LST"
            echo vdb awk_cmd awk -v sfx="$SFX" -v num_cpus="$NUM_CPUS" -v perf_fl="$PRF_FL" -v tm_dff="$TM_RUN" -v drvs="$DRVS" -v sz="$SZ" -v threads="$THREADS" -v procs="$JOBS" -v rdwr="$OPER" -v fio_fl="$OFL" -v tm="$TM_RUN" -v iost_fl="$IO_FL" -v drv_str="$DRVS" -f $SCR_DIR/do_vdb_rd_output.awk $PRF_FL $IO_FL $USE_OFL _ v_res1.txt
            awk -v sfx="$SFX" -v num_cpus="$NUM_CPUS" -v perf_fl="$PRF_FL" -v tm_dff="$TM_RUN" -v drvs="$DRVS" -v sz="$SZ" -v threads="$THREADS" -v procs="$JOBS" -v rdwr="$OPER" -v fio_fl="$OFL" -v tm="$TM_RUN" -v iost_fl="$IO_FL" -v drv_str="$DRVS" -f $SCR_DIR/do_vdb_rd_output.awk $PRF_FL $IO_FL $USE_OFL > v_res1.txt
            ck_last_rc $? $LINENO
            cat v_res1.txt >> v_res.txt
            cat v_res.txt
            cat v_res.txt >> v_all.txt
            cat v_res.txt >> v_all_$i.txt
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
              echo "vim $OFL"
              echo "vim $IO_FL"
        done # OPER read write
      done # BLK_SZ
    done # THREADS
  done # JOBS 
 done # DRVS_LST
done # WORK_TYP in $WORK_LST_IN
echo "$0.$LINENO RUNS_IN_LOOP=$RUNS_IN_LOOP"
echo "qq done"
echo "qq done" >&2
exit 0

