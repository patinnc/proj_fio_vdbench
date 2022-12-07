#!/usr/bin/env bash

# arg1 dev like nvme1n1 or eth0
# arg2 if 1 then verbose (print each file in dirs traversed)
#
DEV="$1"
if [ "$DEV" == "" ]; then
  echo "$0.$LINENO you must enter device like nvme1n1 or eth0. /dev/eth0 okay too. bye"
  exit 1
fi
VRB=$2

DEV="$(echo "$DEV" | sed 's!/dev/!!')"
PCI_STR="$(find /sys/devices -name $DEV | wc -l)"
if [ "$PCI_STR" != "1" ]; then
  echo "$0.$LINENO lookup of device retured 0 or more than 1 device for dev= $DEV. got below. bye"
  echo "find /sys/devices -name $DEV"
        find /sys/devices -name $DEV
  exit 1
fi
PCI_STR="$(find /sys/devices -name $DEV)"
echo "$0.$LINENO pci /sys/devices str= $PCI_STR"
ARR=($(echo "$PCI_STR" | sed 's!/!\n!g'))
echo "$0.$LINENO arr sz= ${#ARR[@]}"
CLS=
for ((i=2; i < ${#ARR[@]}; i++)); do
  if [[ "${ARR[$i]}" == *":"* ]]; then
    continue # pci address
  fi
  CLS="$CLS/${ARR[$i]}"
done
echo "$0.$LINENO cls= $CLS"
CLS_DIR="/sys/class${CLS}"
if [ ! -d "$CLS_DIR" ]; then
  echo "$0.$LINENO failed to find pci dev= $DEV /sys/class dir. tried $CLS_DIR. bye"
  exit 1
fi
echo "$0.$LINENO cls_dir=  $CLS_DIR"
echo "$0.$LINENO ls $CLS_DIR"
ls $CLS_DIR
CLS_DIR_DEV="$CLS_DIR/device"
CLS_DIR_DEV_DEV="$CLS_DIR/device/device"
echo "$0.$LINENO ls $CLS_DIR_DEV"
ls $CLS_DIR_DEV
CUR_DIR="$(pwd)"
prt_files_in_dir() {
  if [ "$VRB" != "1" ]; then
    return 0
  fi
  local i
  local j
  local TYP
  local V
  for i in *; do
  TYP=$(file $i)
  if [[ "$TYP" == *": data" ]] || [[ ! -r $i ]]; then
    continue
  fi
  V="$(cat $i 2> /dev/null)"
  if [ "$V" == "" ]; then
    continue
  fi
  local marr=()
  readarray -t marr < <(cat $i 2> /dev/null)
  for ((j=0; j < ${#marr[@]}; j++)); do
    local v1=$i
    if [ "$j" != "0" ]; then
      v1="."
    fi
    printf "%30s %s\n" $v1 "${marr[$j]}"
  done
  done
}
if [ -d $CLS_DIR_DEV ]; then
  cd $CLS_DIR_DEV
  echo "$0.$LINENO ls $CLS_DIR_DEV"
  prt_files_in_dir
fi
if [ -d $CLS_DIR_DEV_DEV ]; then
  cd $CLS_DIR_DEV_DEV
  echo "$0.$LINENO ls $CLS_DIR_DEV_DEV"
  prt_files_in_dir
fi
cd "$CUR_DIR"
get_bw() {
  local spd="$1"
  local wd="$2"
  local bw_MBps
  #echo $0.$LINENO do awk -v spd="$spd" -v wd="$wd" >&2
  bw_MBps=$(awk -v spd="$spd" -v wd="$wd" '
  BEGIN{
    n = split(spd, arr, " ");
    fctr = 1;
    if (arr[2] == "GT/s") { fctr = 1000;}
    if (arr[2] == "MT/s") { fctr = 1;}
    bw = fctr * arr[1] * wd / 8;
    printf("%.3f", bw);
    exit(0);
  }')
  echo "$bw_MBps"
}
#            current_link_speed 8.0 GT/s PCIe
#            current_link_width 4
if [ -e $CLS_DIR_DEV_DEV/current_link_speed ]; then
  SPD_DIR=$CLS_DIR_DEV_DEV
else
  SPD_DIR=$CLS_DIR_DEV
fi
CUR_SPEED="$(cat $SPD_DIR/current_link_speed)"
CUR_WIDTH="$(cat $SPD_DIR/current_link_width)"
MAX_SPEED="$(cat $SPD_DIR/max_link_speed)"
MAX_WIDTH="$(cat $SPD_DIR/max_link_width)"
cur_bw_MBps=$(get_bw "$CUR_SPEED" $CUR_WIDTH)
max_bw_MBps=$(get_bw "$MAX_SPEED" $MAX_WIDTH)
echo "$0.$LINENO cur_bw MB/s= $cur_bw_MBps"
echo "$0.$LINENO max_bw MB/s= $max_bw_MBps"
