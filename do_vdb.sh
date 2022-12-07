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
#SFX=
#if [ "$1" != "" ]; then
#  SFX=$1
#  if [ "${SFX:0:1}" != "_" ]; then
#    SFX="_$1"
#  fi
#fi

DEV=/dev/sda1
DEV=/dev/md0
VDB_CMD=$SCR_DIR/../vdbench50407/vdbench
if [ ! -e "$VDB_CMD" ]; then
  echo "$0.$LINENO can't find vdbench script. Tried $VDB_CMD. Bye"
  exit 1
fi

STOP_FL="do_vdb.stop"
if [ -e $STOP_FL ]; then
  rm $STOP_FL
fi
echo "$0.$LINENO STOP_FL= $STOP_FL"
GOT_QUIT=0
# function called by trap
catch_signal() {
    printf "\rSIGINT caught      "
    GOT_QUIT=1
}

trap 'catch_signal' SIGINT


FILE_SZ=500m
FILE_SZ=10g
ELAP_SECS=600
ELAP_SECS=60
DRY=1
DRY=
USE_MNT=

RAW=0 # use filesystem
RAW=1 # no filesystem
RAW=

while getopts "hvy-:B:D:f:J:L:m:O:p:R:r:s:t:T:" opt; do
  case "${opt}" in
    - )
            case "${OPTARG}" in
                dry_run)
                    val="${!OPTIND}"; OPTIND=$(( $OPTIND + 1 ))
                    #echo "Parsing option: '--${OPTARG}', value: '${val}'" >&2;
                    DRY=$val
                    echo "$0.$LINENO got \"--dry_run $DRY\""
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
      USE_RAID=$OPTARG  # like /dev/md0 or /dev/md127  or 0 for don't use raid (the default)
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
      echo "$0 run vdbench ... loop over cmdline  parameters"
      echo "Usage: $0 [-h] do vdbench with parameters"
      echo "  does loop over:"
      echo "    for MAX_DRIVES in drives_list_to_use"
      echo "      for JOBS in jobs_list"
      echo "        for JOBS in thread_list"
      echo "          for BLK_SZ in block_list"
      echo "            for OPER in operation_list"
      echo "              vdbench cmd..."
      echo "   --dry_run 0|1  if 1 then don't run vdbench or iostat but show cmds. Also displays count of vdbench cmds that will be run. default is 1"
      echo "   --raw      write to raw device. Will destroy any file system on the devices"
      echo "   -B block_list  like 4k[,16k[,1m]] etc. vdbench xfersize parameter"
      echo "   -D drives_list_to_use like 1,2,4,8 to use 1 drive in the list devices, then 1st 2 drives in list, etc. (see -L device_list)"
      echo "   -f file_system_use   0 to not use file system or 1 to use file system."
      echo "   -h     this help info"
      echo "   -J jobs_list  like 1,2,16  start X jobs. This is the vdbench -m number_of_jvms parameter"
      echo "   -L devices_list  like nvme0n1,nvme1n1[,...]   is used in vdbench lun= parameter"
      echo "   -m mount_point   like /mnt/disk or /disk/1    assumes the devices are mounted to this mount point and assumes -f 1 (use file system)"
      echo "      used in the vdbench anchor= parameter"
      echo "   -O operation_list  like op1[,op2[,...]]    like randread randwrite read write."
      echo "      this gets used to set (for raw) forrdpct seekpct or (for use fs) fileio foroperations"
      echo "   -R raid_dev   use the raid device like md0 or md127 (checked against /proc/mdstat). operations will be against this device instead of nvme0n1 etc."
      echo "   -r raw1_or_no0  1 means use raw device (wipe out file system"
      echo "   -s suffix_to_add_to_filenames   a string that will be added to file names"
      echo "   -t time_in_secs                 time for each operation. vdbench elapsed= parameter"
      echo "   -T thread_list    like 1[,2[,...]]  threads per job. this is the vdbench threads= parameter"
      echo "   -v     verbose"
      echo "   -y     accept license and acknowledge you may wipe out disks"
      echo " "
      echo "   I need to clean up the raw vs use_file_system. They are mutually exclusive."
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
#echo "$0.$LINENO bye. oper_in= $OPER_IN dry_run= $DRY"
#exit 1
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
if [[ "$DRY" != "0" ]] && [[ "$DRY" != "1" ]]; then
  echo "$0.$LINENO you must do '--dry_run 0' (actually do it) or '--dry_run 1' (just show cmds, don't do vdbench). got \"--dry_run $DRY\". bye"
  exit 1
fi
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

MAX_DRIVES=8

if [ "$DRVS_LST_IN" != "" ]; then
  DRVS_LST=$DRVS_LST_IN
fi
if [ "$JOBS_LST_IN" != "" ]; then
  JVMS_LST=$JOBS_LST_IN
fi
if [ "$THRD_LST_IN" != "" ]; then
  THRD_LST=$THRD_LST_IN
fi
if [ "$TM_RUN" != "" ]; then
  ELAP_SECS=$TM_RUN
fi
if [ "$BLK_LST_IN" != "" ]; then
  BLK_LST=$BLK_LST_IN
fi
if [ "OPER_IN" != "" ]; then
  OPER_LST=$OPER_IN
fi
RUNS=0
if [[ "$USE_RAID" != "" ]]; then
  RAID_DEV=$(cat /proc/mdstat | awk -v rd="$USE_RAID" '$1 == rd {print "/dev/"$1;}')
  echo "$0.$LINENO RAID_DEV= $RAID_DEV"
  USE_RAID=1
  #echo "$0.$LINENO bye"
  #exit 1
fi
echo "DRVS_LST= $DRVS_LST"
echo "JMVS_LST= $JVMS_LST"
echo "THRD_LST= $THRD_LST"
echo "BLK_LST= $BLK_LST"
echo "OPER_LST= $OPER_LST"
for MAX_DRIVES in $DRVS_LST; do
  for JVMS in $JVMS_LST; do
    for THREADS in $THRD_LST; do
    
    VDBENCHDEVICES=$(lsblk -dnp -oNAME | grep nvme | sort)
    
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
        if [[ "$RAID_DEV" != "" ]]; then
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
      if [ "$CK_NULL" != "null" ]; then
        echo "$0.$LINENO for raw IO the disks can't be mounted. got mountpoints:"
        for i in `echo $VDBENCHDEVICES`;do 
          lsblk $i -bnp -o MOUNTPOINT -J | jq '.blockdevices[].mountpoint' | sed 's/"//g'
        done
        exit 1
      fi
    fi
    #echo "$0.$LINENO VDBENCHDEVICES= $VDBENCHDEVICES"
    NUM_CPUS=$(grep -c processor /proc/cpuinfo)
    
    
    #cat $FL_CFG
    #echo "$0.$LINENO bye"
    #exit 1
    
    
      for ii in $BLK_LST; do
        for OPER in $OPER_LST; do
          if [ "$OPER" == "precondition" ]; then
            echo "$0.$LINENO this script doesn't support oper= $OPER. bye"
            exit 1
          fi
          FL_CFG=vdb_gen.cfg
          if [ -e "$FL_CFG" ]; then
            rm $FL_CFG
          fi
          VDBENCHGBBUFFER=10
          SEP2=
          DRV_STR=
          if [ "$RAW" == "1" ]; then
            j=0
            IO_DSK_LST=
            for i in `echo $VDBENCHDEVICES`;do 
              #echo sd=sd$SD,lun=$j/vdbench.data,size=$(($FILESYSTEMSIZE-$VDBENCHGBBUFFER))G
              DNUM=$(echo $i | sed 's/.*nvme//;s/n1$//')
              TRY_DEV="nvme${DNUM}c${DNUM}n1"
              if [ ! -e /sys/class/nvme/nvme${DNUM}/$TRY_DEV ]; then
                TRY_DEV="nvme${DNUM}n1"
              fi
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
                echo "sd=sd${j},lun=$i" >> $FL_CFG
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
    echo 'wd=wd1,sd=sd*,xfersize=$xfer_sz,seekpct=$seq_rnd
rd=rd1,wd=wd1,openflags=o_direct,forrdpct=($rdwr),iorate=max,threads=$files_threads,elapsed=$elap_secs,interval=1' >> $FL_CFG
          else
   echo 'fsd=fsd1,anchor=$use_mnt/vd_dir,depth=1,width=1,files=$files_threads,size=$file_sz
fwd=fwd1,fsd=fsd1,xfersize=$xfer_sz,fileio=$seq_rnd,fileselect=random,threads=$files_threads
rd=rd1,fwd=fwd1,openflags=o_direct,foroperations=($rdwr),fwdrate=max,format=yes,elapsed=$elap_secs,interval=1' >> $FL_CFG
          fi
          i="${ii}_${OPER}"
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
      
      
          arr=(${i//_/ })
          #SZ=${arr[0]}
          SZ=$ii
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
          #continue
          
          SFX="_${SZ}_${OPER}${SFX_IN}"
          ODIR=vdb_data/vdb_out${SFX}
          if [ "$DRY" == "0" ]; then
            mkdir -p $ODIR
            IO_FL=$ODIR/iostat1_$i.log
            #nohup iostat -c -d -p $DEV 1 3600 > $IO_FL 2> $ODIR/iostat2_$i.log &
            nohup iostat -c -d -p $IO_DSK_LST -x 1 $TM_RUN > $IO_FL 2> $ODIR/iostat2_$i.log &
            IOS_PID=$!
          fi
          RTOFL="v_rep${SFX}"
          OFL="$ODIR/$RTOFL.txt"
          #OFL="vdb_rep.txt"
          #OFL="v_rep${SFX}.txt"
          if [ -e $OFL ]; then
            rm $OFL
          fi
          OPT_JVMS=
          if [ "$JVMS" != "" ]; then
            OPT_JVMS="-m $JVMS"
          fi
          OPT_PERF=
          PRF_FL=
          if [ "$PERF_IN" == "1" ]; then
            PRF_FL="$ODIR/v_prf${SFX}.txt"
            OPT_PERF="$PERF_BIN stat -o $PRF_FL -a -e msr/tsc/,msr/mperf/,msr/aperf/ -- "
          fi
          OPT_MNT=
          if [ "$USE_MNT" != "" ]; then
            OPT_MNT="use_mnt=$USE_MNT"
          fi
          echo "$VDB_CMD $OPT_JVMS -f $FL_CFG -o $ODIR $FL_SZ_STR $OPT_MNT files_threads=$THREADS seq_rnd=$RS xfer_sz=$SZ elap_secs=$ELAP_SECS rdwr=$RDWR_STR > $OFL"
          if [ "$DRY" == "0" ]; then
            echo  __cmd $VDB_CMD $OPT_JVMS -f $FL_CFG -o $ODIR $FL_SZ_STR $OPT_MNT files_threads=$THREADS seq_rnd=$RS xfer_sz=$SZ elap_secs=$ELAP_SECS rdwr=$RDWR_STR > $OFL
            echo "__beg_cfg $FL_CFG" >> $OFL
            cat  $FL_CFG | awk '{printf("__cfg %s\n", $0);}' >> $OFL
            echo "__end_cfg $FL_CFG" >> $OFL
            echo "__threads $THREADS" >> $OFL
            echo "__jvms $JVMS" >> $OFL
            echo "__raw $RAW" >> $OFL
            echo "__drives $DRVS" >> $OFL
            echo "__drv $DRV_STR" >> $OFL
            echo "__blk_sz $SZ" >> $OFL
            echo "__seq_rnd $RS" >> $OFL
            echo "__oper $OPER" >> $OFL
            echo "__elap_secs $ELAP_SECS" >> $OFL
            $OPT_PERF $VDB_CMD $OPT_JVMS -f $FL_CFG -o $ODIR $FL_SZ_STR $OPT_MNT files_threads=$THREADS seq_rnd=$RS xfer_sz=$SZ elap_secs=$ELAP_SECS rdwr=$RDWR_STR >> $OFL
            pkill -SIGTERM iostat
            cp $OFL $ODIR/
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
            awk -v sfx="$SFX" -v num_cpus="$NUM_CPUS" -v perf_fl="$PRF_FL" -v tm_dff="$ELAP_SECS" -v drvs="$DRVS" -v sz="$SZ" -v threads="$THREADS" -v procs="$JVMS" -v rdwr="$OPER" -v fio_fl="$OFL" -v tm="$ELAP_SECS" -v iost_fl="$IO_FL" -v drv_str="$DRV_STR" '
                BEGIN{
                  szb = sz+0;
                  if (index(sz, "k") > 0) { szb *= 1024;}
                  if (index(sz, "m") > 0) { szb *= 1024*1024;}
                  tm += 0;
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
                    # str below needs to start and end with space
                    unhalted_str = sprintf(" %%unhalted= %.3f unhaltedTL= %.3f cpu_freqGHz= %.3f ", 100 * unhalted_ratio, unhaltedTL, cpu_freq_ghz);
                  }
                }
  
                /^__seq_rnd /{ if ($2 == "100" || $2 == "random") { oper_rand_seq = "rand"; } else { oper_rand_seq = ""; }}
                /Starting RD=/{ 
                  for (i=2; i <= NF; i++) {
                    if (index($i, "=") > 0) {
                      n = split($i, arr, "=");
                      if (arr[1] == "rdpct") {
                        if (arr[2] == "100") { oper_rw = "read"; } else {oper_rw = "write";}
                      }
                      if (arr[1] == "threads") {
                        threads = arr[2];
                      }
                    }
                  }
                  rdwr = oper_rand_seq "" oper_rw;
                }
                / avg_2-/{ 
                  kiops= 0.001* $3;
                  MBps= $4 * (1024*1024)/(1000*1000);
                  busy= $14; # cpu%
                  busy_str= $14; # cpu%
                  lat_ms = $7;
                  if (unhalted_str == "") { my_unhalted_str = " ";} else { my_unhalted_str = unhalted_str;}
                  printf("qq drives= %d oper= %s sz= %s IOPS(k)= %.3f bw(MB/s)= %.3f szKiB= %d iodepth= %d procs= %d tm_dff_secs= %d %%busy= %s lat_ms= %f sfx= %s%sdrv= %s iostat= %s fio_fl= %s\n",
                   drvs, rdwr, sz, kiops, MBps, szb/1024, threads, procs, tm_dff, busy_str, lat_ms, sfx, my_unhalted_str, drv_str, iost_fl, fio_fl);
                }
                /issued rwt: total=|issued rwts: total=/ {
                  #issued rwt: total=0,571176,0, short=0,0,0, dropped=0,0,0
                  n = split(substr($3, index($3,"=")+1), arr, ",");
                  v = (arr[1] == "0" ? arr[2] : arr[1])+0;
                  busy_str = "unk";
                  if (idle > 0 && idle_n > 0) {
                    busy = 100 - (idle/idle_n);
                    busy_str = sprintf("%.3f", busy);
                  }
                  printf("qq drives= %d oper= %s sz= %s IOPS(k)= %.3f bw(MB/s)= %.3f szKiB= %d iodepth= %d procs= %d tm_dff_secs= %d %%busy= %s drv= %s iostat= %s fio_fl= %s\n",
                   drvs, rdwr, sz, 0.001 * v/tm, 1e-6 * v * szb / tm, szb/1024, threads, procs, tm_dff, busy_str, drv_str, iost_fl, fio_fl);
                }
                /avg-cpu:.* %user.* %nice.* %system.* %iowait.* %steal.*%idle/ {
                  getline;
                  idle += $NF;
                  idle_n++;
                }
                END{ printf("\n");}
            ' $PRF_FL $IO_FL v_res.txt > v_res1.txt
            cat v_res1.txt >> v_res.txt
            cat v_res.txt
            cat v_res.txt >> v_all.txt
            cat v_res.txt >> v_all_$i.txt
          fi
          wait
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
          RUNS=$((RUNS+1))
        done # OPER_LST
      done # BLK_LST
    done # THREADS in THRD_LST
  done # JVMS in JVMS_LST
done # MAX_DRIVES in DRVS_LST
echo "qq done"
echo "qq done" >&2
echo "$0.$LINENO runs= $RUNS"
exit 0

