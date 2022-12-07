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

# these scripts are very dangerous, they can wipe out the data on the drives
# so know what you are doing.
# I have checks to make sure that the raid doesn't already exist
# and the disks can't get mounted already.
# I don't do anything unless '-d 1' is passed... otherwise just display what the script would have done
#
# ./raid_setup.sh -d 0 -f 0 -m /mnt/disk -R /dev/md127 # see what cmds would be executed to setup raw raid
# ./raid_setup.sh -d 1 -f 0 -m /mnt/disk -R /dev/md127 # setup raw raid, no filesystem
# ./raid_setup.sh -d 1 -f 0 -m /mnt/disk -R /dev/md127 -z # del the raw raid
# ./raid_setup.sh -d 1 -f 0 -m /mnt/disk -R /dev/md127 # setup raw raid, no filesystem
# ./raid_setup.sh -d 1 -f 1 -m /mnt/disk -R /dev/md127 # setup raw raid, with filesystem
# setup raid0 with all not used nvme drives
# only actually do it if arg1 == 1
# arg1 == 1 then actually setup the raid, otherwise just show what we would have done
ADD_FS=1 # add ext4 filesystem to raid
ADD_FS=
USE_MNT=
DEL_RAID=
DRY=


#while getopts "hv-:B:c:d:D:f:J:L:m:O:R:r:p:t:T:" opt; do
#while getopts "hv-:c:d:D:f:L:m:R:r:z" opt; do
while getopts "hvy-:f:L:m:R:r:z" opt; do
  case "${opt}" in
    - )
            case "${OPTARG}" in
                dry_run)
                    val="${!OPTIND}"; OPTIND=$(( OPTIND + 1 ))
                    #echo "Parsing option: '--${OPTARG}', value: '${val}'" >&2;
                    #echo "Parsing option: '--${OPTARG}', value: '${val}'" >&2;
                    DRY=$val
                    echo "$0.$LINENO got \"--dry_run $val\""
                    if [[ "$DRY" != "0" ]] && [[ "$DRY" != "1" ]]; then
                      echo "$0.$LINENO you must do '--dry_run 0' (actually do it) or '--dry_run 1' (just show cmds, don't do fio). got \"--dry_run $DRY\". bye"
                      exit 1
                     fi
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
#    c )
#      CHNK_SZ_IN="$OPTARG"
#      ;;
#    D )
#      DRVS_LST_IN="$OPTARG"
#      echo "$0.$LINENO DRVS_LST_IN= $DRVS_LST_IN"
#      ;;
    f )
      ADD_FS=$OPTARG
      echo "$0.$LINENO ADD_FS= $ADD_FS"
      ;;
    L )
      LST_DEVS_IN="$(echo "$OPTARG" | sed 's/,/ /g')"
      ;;
    m )
      USE_MNT=$OPTARG
      ;;
    r )
      RAW=$OPTARG
      ;;
    R )
      RAID_DEV=$OPTARG
      ;;
    v )
      VRB=$((VRB+1))
      ;;
    y )
      ACCEPT_LICENSE="y"
      ;;
    z )
      DEL_RAID=1
      ;;
    h )
      echo "$0 create (or destroy) raid with or without ext4 filesystem or just show the cmds without doing anything (--dry_run 1)"
      echo "Usage: $0 [-h] [-v] --dry_run 0|1 [-f 0|1] -L nvmedrv1,nvmedr2[,..]  [--raw|-r 0|1] [-R /dev/mdXX] [-m mount_pt] [-z]"
      echo "   -y     accept license and acknowledge you may wipe out disks"
      exit
      ;;
    : )
      echo "$0.$LINENO Invalid option: $OPTARG requires an argument" 1>&2
      ;;
    \? )
      echo "$0.$LINENO Invalid option: $OPTARG" 1>&2
      ;;
  esac
done
shift $((OPTIND -1))

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

if [[ "$DRY" != "0" ]] && [[ "$DRY" != "1" ]]; then
  echo "$0.$LINENO you must do '--dry_run 0' (actually do it) or '--dry_run 1' (just show cmds, don't do fio). got \"--dry_run $DRY\". bye"
  exit 1
fi
#echo "$0.$LINENO bye"
#exit 1
RD=
if [ -e /proc/mdstat ]; then
  echo "$0.$LINENO /proc/mdstat already exists"
  cat /proc/mdstat
  #exit
else
  apt-get -y install mdadm
  apt-get -y install nvme-cli
fi

NVME=$(lsblk)
#echo "nvme= $NVME"

if [[ "$ADD_FS" != "0" ]] && [[ "$ADD_FS" != "1" ]]; then
  echo "$0.$LINENO you have to specify -f 0 (don't add ext4 filesystem) or -f 1 (add ext4 file system). got ADD_FS=\"$ADD_FS\". bye"
  exit 1
fi
if [[ "$ADD_FS" == "1" ]] && [[ "$USE_MNT" == "" ]]; then
  echo "$0.$LINENO you specified add filesystem (-f 1) but you didn't specify -m mount_dir_to_use like /disk/1 or /mnt/disk .  bye"
  exit 1
fi
if [[ "$RAID_DEV" == "" ]] || [[ "$RAID_DEV" != "/dev/"* ]]; then
  echo "$0.$LINENO you need to specify -R raid_dev like /dev/md0 or /dev/md127  . bye"
  exit 1
fi

ck_get_nvme() {
 local want=$1 # 0 means free nvme devs, 1 means used devs
 #echo "want= $want"
local UNS_ARR=($(echo "$NVME" | awk -v want="$want" '
  {
    if (substr($1, 1, 4) == "nvme") {
      #printf("got line= %s\n", $0) > "/dev/stderr";
      dev = substr($1, 1, 7);
      if (!(dev in dev_list)) {
        dev_list[dev] = ++dev_mx;
        dev_lkup[dev_mx] = dev;
        dev_data[dev_mx, "used"] = 0;
        dev_data[dev_mx, "line"] = FNR;
        #printf("got dev[%d]= %s\n", dev_mx, dev_lkup[dev_mx]) > "/dev/stderr";
      }
      dev_i = dev_list[dev];
    } else {
      for (i=1; i <= dev_mx; i++) {
        if (dev_data[i, "used"] == 0) {
          if ((dev_data[i, "line"]+1) == FNR) {
            dev_data[dev_mx, "used"] = 1;
            #printf("used dev= %s\n", dev_lkup[i]) > "/dev/stderr";
            continue;
          }
          devp = dev_lkup[i] "p";
          if (index($0, devp) > 0) {
            #printf("used dev= %s\n", dev_lkup[i]) > "/dev/stderr";
            dev_data[dev_mx, "used"] = 1;
          }
        }
      }
    }
  }
  END{
      #printf("not used nvme devices:\n");
      str = "";
      for (i=1; i <= dev_mx; i++) {
        if (dev_data[i, "used"] == want) {
          printf("/dev/%s\n", dev_lkup[i]);
        }
      }
      #printf("%s\n", str);
  }'))
  ARR=($(echo ${UNS_ARR[@]} | sed 's/ /\n/g' |sort))
  #echo bef want= $want ${UNS_ARR[@]}
  #echo aft want= $want ${ARR[@]}
}

ck_get_nvme 1
echo "$0.$LINENO used nvme devs:  ${ARR[@]}"
UARR=()
for ((j=0; j < ${#ARR[@]}; j++)); do
  UARR+=(${ARR[$j]})
done
LST_USED="${FARR[@]}"
ck_get_nvme 0
if [ "$LST_DEVS_IN" != "" ]; then
  FARR=()
  for ((j=0; j < ${#ARR[@]}; j++)); do
    FARR[$j]=${ARR[$j]};
  done
  ARR=()
  for i in $LST_DEVS_IN; do
    for ((j=0; j < ${#FARR[@]}; j++)); do
      if [[ "${FARR[$j]}" == "$i" ]] || [[ "${FARR[$j]}" == "/dev/$i" ]]; then
        ARR+=(${FARR[$j]})
      fi
    done
  done
fi
echo "$0.$LINENO free nvme devs:  ${ARR[@]}"
LST_FREE="${ARR[@]}"
if [[ "${#ARR[@]}" == "0" ]] && [[ "$DEL_RAID" == "0" ]]; then
  echo "$0.$LINENO you want to create a raid but the list of free drives doesn't overlap with the input list (-L ...)  of drives. bye"
  echo "$0.$LINENO free drives= ${FARR[@]}"
  echo "$0.$LINENO input drives= ${LST_DEVS_IN}"
  exit 1
fi

  CM=(echo "")
  IEND=${#CM[@]}
  if [ "$DRY" == "1" ]; then
    IEND=1
  fi

if [ "$DEL_RAID" == "1" ]; then
if [ "$LST_DEVS_IN" != "" ]; then
  TARR=()
  k=0
  for i in $LST_DEVS_IN; do
    k=$((k+1))
    for ((j=0; j < ${#UARR[@]}; j++)); do
      if [[ "${UARR[$j]}" == "$i" ]] || [[ "${UARR[$j]}" == "/dev/$i" ]]; then
        TARR+=(${UARR[$j]})
      fi
    done
  done
if [[ "${#TARR[@]}" != "$k" ]] && [[ "$DEL_RAID" == "1" ]]; then
  echo "$0.$LINENO you want to delete a raid (and wipe out the data) but the list of used drives doesn't equal the input list (-L ...)  of drives. bye"
  echo "$0.$LINENO used drives= ${UARR[@]}"
  echo "$0.$LINENO input drives= ${LST_DEVS_IN}"
  exit 1
fi
fi
  echo "got del raid"
  USED_RAID_DEVS=($(mdadm -D $RAID_DEV | grep '/dev/' | sed 's/://g' | sed 's!.*/dev/!/dev/!'))
  echo "$0.$LINENO USED_RAID_DEVS= ${USED_RAID_DEVS[@]}"
  if [ "${USED_RAID_DEVS[0]}" != "$RAID_DEV" ]; then
    echo "$0.$LINENO problem, didn't find your raid -m $RAID_DEV in output of mdadm -D $RAID_DEV. fix code"
    exit 1
  fi
  RD_D=("${USED_RAID_DEVS[@]:1}")
  if [[ "${#USED_RAID_DEVS[@]}" -lt 2 ]]; then
    echo "$0.$LINENO raid = ${USED_RAID_DEVS[0]}"
    echo "$0.$LINENO raid devs= ${RD_D[0]}"
    exit 1
  fi
  echo "$0.$LINENO raid = ${USED_RAID_DEVS[0]}"
  echo "$0.$LINENO raid devs= ${RD_D[@]}"
  for ((i=0; i < ${IEND}; i++)); do
    ${CM[$i]} umount $RAID_DEV  # md0 from above 'cat /proc/mdstat' cmd
    ${CM[$i]} mdadm --stop $RAID_DEV
    ${CM[$i]} mdadm --remove $RAID_DEV
    ${CM[$i]} mdadm --zero-superblock ${RD_D[@]}
    ${CM[$i]} cat /proc/mdstat  # should show no raid now
  done
  echo "$0.$LINENO bye"
  exit 1
  #mdadm --stop /dev/md0
  #mdadm --remove /dev/md0
  ## do mdadm cmd below and include all the devices in raid (from cat /proc/mdstat output above)
  #mdadm --zero-superblock /dev/nvme0n1 /dev/nvme1n1 /dev/nvme2n1 /dev/nvme3n1  /dev/nvme4n1 /dev/nvme5n1 /dev/nvme6n1 /dev/nvme7n1
  #cat /proc/mdstat  # should show no raid now
fi
if [ -e /proc/mdstat ]; then
  MD=$(cat /proc/mdstat | grep nvme)
  if [[ "$MD" != "" ]]; then
    echo "$0.$LINENO raid already setup"
    exit 0
  fi
fi
  #exit

  N_DISKS=${#ARR[@]}
  for ((i=0; i < ${IEND}; i++)); do
    if [[ "$N_DISKS" -gt "1" ]]; then
      #if [ "$i" == "0" ]; then
        ${CM[$i]} mdadm --create --verbose $RAID_DEV --level=0 --raid-devices=${#ARR[@]} ${LST_FREE}
      #fi
      if [ "$ADD_FS" == "1" ]; then
        ${CM[$i]} mkfs.ext4  $RAID_DEV
        ${CM[$i]} mkdir –p $USE_MNT
        ${CM[$i]} mount $RAID_DEV $USE_MNT
        if [ "${CM[$i]}" != "echo" ]; then
          CK_LINES=$(grep -c "$RAID_DEV" /etc/fstab)
          if [ "$CK_LINES" == "0" ]; then
            echo "you might want do below cmd to add mount point to /etc/fstab"
            echo "echo \"$RAID_DEV $USE_MNT ext4 defaults,nofail,discard 0 0\" >> /etc/fstab"
            #echo "$RAID_DEV $USE_MNT ext4 defaults,nofail,discard 0 0" >> /etc/fstab
          else
            echo "already have an entry for $RAID_DEV in /etc/fstab"
            grep  "$RAID_DEV" /etc/fstab
          fi
        else
          echo "echo \"$RAID_DEV $USE_MNT ext4 defaults,nofail,discard 0 0\" >> /etc/fstab"
        fi
      fi
    else
      if [ "$ADD_FS" == "1" ]; then
        ${CM[$i]} mkfs.ext4  ${LST_FREE}
        ${CM[$i]} mkdir –p $USE_MNT
        ${CM[$i]} mount ${LST_FREE} $USE_MNT
        if [ "${CM[$i]}" != "echo" ]; then
          CK_LINES=$(grep -c "$LST_FREE" /etc/fstab)
          if [ "$CK_LINES" == "0" ]; then
            echo "you might want do below cmd to add mount point to /etc/fstab"
            echo "echo \"${LST_FREE} $USE_MNT ext4 defaults,nofail,discard 0 0\" >> /etc/fstab"
          else
            echo "already have an entry for $LST_FREE in /etc/fstab"
            grep  "$LST_FREE" /etc/fstab
          fi
        else
          echo "echo \"$LST_FREE $USE_MNT ext4 defaults,nofail,discard 0 0\" >> /etc/fstab"
        fi
      fi
    fi
  done
      
exit 0

# below is how to remove raid and destroy all data on the drives
lsblk
# do below to get device name of raid (like md0) and devices in raid (like nvme0n1)
cat /proc/mdstat
umount /dev/md0  # md0 from above 'cat /proc/mdstat' cmd
mdadm --stop /dev/md0
mdadm --remove /dev/md0
# do mdadm cmd below and include all the devices in raid (from cat /proc/mdstat output above)
mdadm --zero-superblock /dev/nvme0n1 /dev/nvme1n1 /dev/nvme2n1 /dev/nvme3n1  /dev/nvme4n1 /dev/nvme5n1 /dev/nvme6n1 /dev/nvme7n1
cat /proc/mdstat  # should show no raid now
lsblk  # should just show the devices

or 
umount /dev/md0; mdadm --stop /dev/md0; mdadm --remove /dev/md0; mdadm --zero-superblock /dev/nvme0n1 /dev/nvme1n1 /dev/nvme2n1 /dev/nvme3n1  /dev/nvme4n1 /dev/nvme5n1 /dev/nvme6n1 /dev/nvme7n1

