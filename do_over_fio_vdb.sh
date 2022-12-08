#!/usr/bin/env bash

if [ "$1" == "y" ]; then
 ACCEPT_LICENSE="y"
fi

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
# this is for a system with lots of nvme drives and lots of cpus.
# sweep over both fio and vdbench
# pretty long run (600 secs). Assumes the drives have been preconditioned
# just do 4k rand read/write and 1m seq read write
# do over 1, 4, 8 drives
TM=600
TM=20
TM_TST=20 # time for the "ck_working" tests
DEVS=nvme0n1,nvme1n1,nvme2n1,nvme3n1,nvme4n1,nvme5n1,nvme6n1,nvme7n1
DEVS=nvme1n1,nvme2n1
NUM_DEVS=$(echo $DEVS | sed 's/,/ /g' | wc -w)
echo "$0.$LINENO num_devs= $NUM_DEVS"
OPERS_RND=randread,randwrite
OPERS_SEQ=read,write

TYP_WORK="sweep"
TYP_WORK="ck_working"
TYP_WORK_SUB="precond_short precond_full raw_1 raw_all raw_raid fs_raid"
TYP_WORK_SUB="raw_1 raw_all raw_raid"
TYP_WORK_SUB="raw_1"
TYP_WORK_SUB="precond_full"
TYP_WORK_SUB="raid_delete raid_create_raw raid_create_fs"
TYP_WORK_SUB="raid_create_raw"
TYP_WORK_SUB="raid_delete"
OPERS_RND=randread
OPERS_SEQ=
RAID=md127
MNT_PT="/mnt/disk0"

if [ "$ACCEPT_LICENSE" != "y" ]; then
  echo "$0.$LINENO these scripts will wipe out nvme drives: $DEVS"
  echo "$0.$LINENO only remove the line below if you accept the MIT license"
  echo "$0.$LINENO or have arg1 be \"y\" "
  exit 1
fi
OPT_LIC=" -y "

ck_last_rc() {
   local RC=$1
   local FROM=$2
   if [ $RC -gt 0 ]; then
      echo "$0: got non-zero RC=$RC at $LINENO. called from line $FROM" >&2
      exit $RC
   fi
}

ck_raid_stat() {
 local raid=$1
 local got=$2
 local miss=$3
 echo "$0.$LINENO raid= $raid got= $got miss= $miss"
awk -v got_rc=$got -v miss_rc=$miss -v raid="$raid" '
  /active/ {
   printf("raid found: %s\n", $0);
   if ($1 == raid) {got_raid=raid;}
  }
  END{
    if(got_raid != raid){
      printf("missed raid device %s\n", raid);
      exit(miss_rc);
    } else {
      printf("got raid device %s\n", raid);
      exit(got_rc);
    }
  }
 ' /proc/mdstat
 local rc=$?
 echo "$0.$LINENO rc= $rc"
 return $rc
}

if [ "$TYP_WORK" == "ck_working" ]; then
# tests 
#  raid create w/wo fs, destroy
#  fio predcond w/wo size limit
#  fio+vdb
#   raw     1 disk, raw 2 disks, raw all disks, raid
#   filesys raid_mount_point
# delete the raid if it exists
for TWS in $TYP_WORK_SUB; do
  if [[ "$TWS" == "raid_delete" ]] || [[ "$TWS" == "raid_create_raw" ]] || [[ "$TWS" == "raid_create_fs" ]]; then
  if [ "$TWS" == "raid_delete" ]; then
    echo "$0.$LINENO ========= test delete raid =========="
    $SCR_DIR/raid_setup.sh  -L $DEVS $OPT_LIC --dry_run 0 --raw  -R /dev/$RAID -f 0 -z > tmp.txt
    ck_raid_stat $RAID 0 1
    RC=$?
    if [ "$RC" == "0" ]; then
      cat tmp.txt
      cat /proc/mdstat
      echo "$0.$LINENO got raid but expected to not have raid... error"
      echo "$0.$LINENO ========= test delete raid fail ========="
      exit 1
    else
      echo "$0.$LINENO seems raid not found, RC= $RC... okay"
      echo "$0.$LINENO ========= test delete raid okay ========="
      cat /proc/mdstat
    fi
  fi
    
  if [ "$TWS" == "raid_create_raw" ]; then
    # create raid without filesystem
    echo "$0.$LINENO ========= test create raid =========="
    $SCR_DIR/raid_setup.sh  -L $DEVS $OPT_LIC --dry_run 0 --raw  -R /dev/$RAID -f 0 > tmp.txt
    ck_raid_stat $RAID 0 1
    RC=$?
    if [ "$RC" == "1" ]; then
      cat tmp.txt
      cat /proc/mdstat
      echo "$0.$LINENO didn't find raid $RAID, RC= $RC. error"
      echo "$0.$LINENO ========= test create raid fail ====="
      exit 1
    else
      echo "$0.$LINENO got raid $RAID, RC= $RC. okay"
      echo "$0.$LINENO ========= test create raid okay ====="
      cat /proc/mdstat
    fi
  fi
  if [ "$TWS" == "raid_create_fs" ]; then
    # create raid without filesystem
    echo "$0.$LINENO ========= test create raid with filesystem =========="
    $SCR_DIR/raid_setup.sh  -L $DEVS $OPT_LIC --dry_run 0 --raw  -R /dev/$RAID -f 0 -z > tmp1.txt # first delete the raid
    $SCR_DIR/raid_setup.sh  -L $DEVS $OPT_LIC --dry_run 0 -f 1 -R /dev/$RAID -m $MNT_PT | tee tmp2.txt
    ck_raid_stat $RAID 0 1
    RC=$?
    if [ "$RC" == "1" ]; then
      cat tmp2.txt
      cat /proc/mdstat
      echo "$0.$LINENO didn't find raid $RAID, RC= $RC. error"
      echo "$0.$LINENO ========= test create raid RAID with filesystem mount_point= $MNT_PT fail ====="
      exit 1
    else
      echo "$0.$LINENO got raid $RAID, RC= $RC. okay"
      echo "$0.$LINENO ========= test create raid $RAID with filesystem mount_point= $MNT_PT okay ====="
      cat /proc/mdstat
    fi
    RD_LINES=$(lsblk | grep $RAID | grep raid0 | grep "$MNT_PT")
    NUM_LINES=$(echo "$RD_LINES" | grep raid0 | wc -l)
    if [[ "$NUM_LINES" -lt "1" ]]; then
      echo "$0.$LINENO ========= test create raid $RAID with filesystem mount_point= $MNT_PT fail 2 ====="
      echo "$0.$LINENO didn't find any lines in lsblk output for a raid0 named $RAID and mount point= $MNT_PT. error"
      echo "$0.$LINENO RD_LINES= $RD_LINES"
      lsblk
      exit 1
    else
      echo "$0.$LINENO ========= test create raid $RAID with filesystem mount_point= $MNT_PT okay 2 ====="
    fi
  fi
  fi
  if [ "$TWS" == "precond_short" ]; then
    echo "$0.$LINENO ========= test preconditioning, delete raid if present ======"
    #delete the raid
    $SCR_DIR/raid_setup.sh  -L $DEVS $OPT_LIC --dry_run 0 --raw  -R /dev/$RAID -f 0 -z > tmp.txt
    ck_raid_stat $RAID 0 1
    RC=$?
    if [ "$RC" == "0" ]; then
      cat tmp.txt
      cat /proc/mdstat
      echo "$0.$LINENO got raid but expected to not have raid... error"
      echo "$0.$LINENO ========= test delete raid fail ========="
      exit 1
    else
      echo "$0.$LINENO seems raid not found, RC= $RC... okay"
      echo "$0.$LINENO ========= test delete raid okay ========="
      cat /proc/mdstat
    fi
    echo "$0.$LINENO ========= test preconditioning short ======"
    $SCR_DIR/do_fio.sh $OPT_LIC  --dry_run 0 -r 1 -B 1m -O precondition -D $NUM_DEVS -L $DEVS -J 8 -T 32 -c 32g | tee tmp.txt
    ck_last_rc $? $LINENO
    QQ_LINES=$(grep "^qq " tmp.txt)
    echo "$0.$LINENO qq_lines= $QQ_LINES"
    V=$(echo "$QQ_LINES" | grep "^qq " | wc -l)
    if [[ "$V" -gt "0" ]]; then
      echo "$0.$LINENO ========= test preconditioning short okay ======"
    else
      cat tmp.txt
      echo "$0.$LINENO ========= test preconditioning short fail no qq lines in tmp.txt ======"
      exit 1
    fi
  fi
  if [ "$TWS" == "precond_full" ]; then
    echo "$0.$LINENO ========= test preconditioning full ======"
    $SCR_DIR/do_fio.sh $OPT_LIC  --dry_run 0 -r 1 -B 1m -O precondition -D $NUM_DEVS -L $DEVS -J 64 -T 32 -c 100% | tee tmp.txt
    ck_last_rc $? $LINENO
    QQ_LINES=$(grep "^qq " tmp.txt)
    echo "$0.$LINENO qq_lines= $QQ_LINES"
    V=$(echo "$QQ_LINES" | grep "^qq " | wc -l)
    if [[ "$V" -gt "0" ]]; then
      echo "$0.$LINENO ========= test preconditioning full okay ======"
    else
      cat tmp.txt
      echo "$0.$LINENO ========= test preconditioning full fail ======"
      exit 1
    fi
  fi
  if [[ "$TWS" == "raw_1" ]] || [[ "$TWS" == "raw_all" ]] || [[ "$TWS" == "raw_raid" ]] ; then
    if [ "$TWS" == "raw_1" ]; then
      USE_DISKS=1
    fi
    if [ "$TWS" == "raw_all" ]; then
      USE_DISKS=$NUM_DEVS
    fi
    OPT_RAID=
    if [ "$TWS" == "raw_raid" ]; then
      USE_DISKS=1
      OPT_RAID="-R $RAID"
      #$SCR_DIR/do_fio.sh $OPT_LIC --dry_run 0 --raw -B 4k -O randread -D 1 -L $DEVS -R md127 -f 0 -J 256 -T 8 -r 1 -t $TM -p 1 
      #$SCR_DIR/do_fio.sh $OPT_LIC -v --dry_run 0 -B 4k -O randread  -D 1 -L $DEVS -f 1 -J 256 -T 32 -t $TM -p 1  -m $MNT_PT
      ck_raid_stat $RAID 0 1
      RC=$?
      if [ "$RC" == "0" ]; then
        echo "$0.$LINENO got raid. okay"
      else
        echo "$0.$LINENO no raid. set it up without filesystem"
        $SCR_DIR/raid_setup.sh  -L $DEVS $OPT_LIC --dry_run 0 --raw  -R /dev/$RAID -f 0 > tmp.txt
        ck_raid_stat $RAID 0 1
        RC=$?
        if [ "$RC" != "0" ]; then
          echo "$0.$LINENO ========= error, doing raw_raid tests but raid not found. fail ============"
          exit 1
        fi
      fi
    fi
    for OPER in $OPERS_SEQ $OPERS_RND; do
      echo "$0.$LINENO ========= test fio raw 1 disk, oper $OPER, $OPT_RAID  ======"
      $SCR_DIR/do_fio.sh $OPT_LIC --dry_run 0 --raw -B 4k -O $OPER -D $USE_DISKS -L $DEVS -J 32 -T 32 -r 1 -t $TM -p 1 $OPT_RAID | tee tmp.txt
      ck_last_rc $? $LINENO
      QQ_LINES=$(grep "^qq " tmp.txt)
      echo "$0.$LINENO qq_lines= $QQ_LINES"
      V=$(echo "$QQ_LINES" | grep "^qq " | wc -l)
      if [[ "$V" -gt "0" ]]; then
        echo "$0.$LINENO ========= test fio raw 1 disk, oper $OPER, $OPT_RAID. okay ======"
      else
        cat tmp.txt
        echo "$0.$LINENO ========= test fio raw 1 disk. oper $OPER, $OPT_RAID. fail ======"
        exit 1
      fi
      echo "$0.$LINENO ========= test vdb raw 1 disk, oper $OPER, $OPT_RAID ======"
      $SCR_DIR/do_vdb.sh $OPT_LIC --dry_run 0 --raw -B 4k -O $OPER -D $USE_DISKS -L $DEVS -J 32 -T 32 -r 1 -t $TM -p 1 $OPT_RAID | tee tmp.txt
      QQ_LINES=$(grep "^qq " tmp.txt)
      echo "$0.$LINENO qq_lines= $QQ_LINES"
      V=$(echo "$QQ_LINES" | grep "^qq " | wc -l)
      if [[ "$V" -gt "0" ]]; then
        echo "$0.$LINENO ========= test vdb raw 1 disk, oper $OPER, $OPT_RAID. okay ======"
      else
        cat tmp.txt
        echo "$0.$LINENO ========= test vdb raw 1 disk, oper $OPER, $OPT_RAID. fail ======"
        exit 1
      fi
    done
  fi
done
echo "$0.$LINENO all tests passed"
exit
#$SCR_DIR/raid_setup.sh  -L $DEVS $OPT_LIC --dry_run 0 --raw  -R /dev/md127 -f 0 -z
#$SCR_DIR/raid_setup.sh  -L $DEVS $OPT_LIC --dry_run 0 --raw  -R /dev/md127 -f 1 -m $MNT_PT
#$SCR_DIR/do_fio.sh $OPT_LIC -v --dry_run 0 -B 4k -O randread  -D 1 -L $DEVS -f 1 -J 256 -T 32 -t $TM -p 1  -m $MNT_PT
#./do_vdb.sh $OPT_LIC -v --dry_run 0 -B 4k -O randread  -D 1 -L $DEVS -f 1 -J 128 -T 128 -t $TM -p 1  -m $MNT_PT
#$SCR_DIR/do_fio.sh $OPT_LIC --dry_run 0 --raw -B 4k -O randread -D 2 -L $DEVS -f 0 -J 256 -T 32 -r 1 -t $TM -p 1 
#$SCR_DIR/do_fio.sh $OPT_LIC --dry_run 0 --raw -B 4k -O randread -D 1 -L $DEVS -R md127 -f 0 -J 256 -T 8 -r 1 -t $TM -p 1 
exit
fi

if [ "$TYP_WORK" == "sweep" ]; then
  $SCR_DIR/do_fio.sh $OPT_LIC --dry_run 0 --raw -B 4k -O $OPERS_RND -D 1 -L $DEVS -f 0 -J 32 -T 32 -r 1 -t $TM -p 1
  ck_last_rc $? $LINENO
  $SCR_DIR/do_fio.sh $OPT_LIC --dry_run 0 --raw -B 1m -O $OPERS_SEQ -D 1 -L $DEVS -f 0 -J 32 -T 32 -r 1 -t $TM -p 1
  ck_last_rc $? $LINENO
   
  $SCR_DIR/do_vdb.sh $OPT_LIC --dry_run 0 --raw -B 4k -O $OPERS_RND -D 1 -L $DEVS -f 0 -J 8 -T 128 -r 1 -t $TM -p 1
  ck_last_rc $? $LINENO
  $SCR_DIR/do_vdb.sh $OPT_LIC --dry_run 0 --raw -B 1m -O $OPERS_SEQ -D 1 -L $DEVS -f 0 -J 8 -T 128 -r 1 -t $TM -p 1
  ck_last_rc $? $LINENO
  
  $SCR_DIR/do_fio.sh $OPT_LIC --dry_run 0 --raw -B 4k -O $OPERS_RND -D 4 -L $DEVS -f 0 -J 128 -T 32 -r 1 -t $TM -p 1 
  ck_last_rc $? $LINENO
  $SCR_DIR/do_fio.sh $OPT_LIC --dry_run 0 --raw -B 1m -O $OPERS_SEQ -D 4 -L $DEVS -f 0 -J 128 -T 32 -r 1 -t $TM -p 1
  ck_last_rc $? $LINENO
  $SCR_DIR/do_fio.sh $OPT_LIC --dry_run 0 --raw -B 4k -O $OPERS_RND -D 8 -L $DEVS -f 0 -J 256 -T 32 -r 1 -t $TM -p 1 
  ck_last_rc $? $LINENO
  $SCR_DIR/do_fio.sh $OPT_LIC --dry_run 0 --raw -B 1m -O $OPERS_SEQ -D 8 -L $DEVS -f 0 -J 256 -T 32 -r 1 -t $TM -p 1 
  ck_last_rc $? $LINENO
  
  $SCR_DIR/do_vdb.sh $OPT_LIC --dry_run 0 --raw -B 4k -O $OPERS_RND -D 4 -L $DEVS -f 0 -J 64 -T 128 -r 1 -t $TM -p 1 
  ck_last_rc $? $LINENO
  $SCR_DIR/do_vdb.sh $OPT_LIC --dry_run 0 --raw -B 1m -O $OPERS_SEQ -D 4 -L $DEVS -f 0 -J 64 -T 128 -r 1 -t $TM -p 1 
  ck_last_rc $? $LINENO
  $SCR_DIR/do_vdb.sh $OPT_LIC --dry_run 0 --raw -B 1m -O $OPERS_SEQ -D 8 -L $DEVS -f 0 -J 128 -T 128 -r 1 -t $TM -p 1  
  ck_last_rc $? $LINENO
  $SCR_DIR/do_vdb.sh $OPT_LIC --dry_run 0 --raw -B 4k -O $OPERS_RND -D 8 -L $DEVS -f 0 -J 128 -T 128 -r 1 -t $TM -p 1 
  ck_last_rc $? $LINENO
fi
