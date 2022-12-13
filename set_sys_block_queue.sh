#!/usr/bin/env bash

DRV=$1
ACT=$2

Q_DIR="/sys/class/block/$DRV/queue"
if [[ "$DRV" == "" ]] || [[ ! -e $Q_DIR ]]; then
  echo "$0.$LINENO didn't get arg1 drive= \"$DRV\" or didn't find queue dir $Q_DIR. bye"
  exit 1
fi

if [[ "$ACT" == "" ]]; then
  ACT="set"
fi
if [[ "$ACT" != "reset" ]] && [[ "$ACT" != "set" ]]; then
  echo "$0.$LINENO arg2 must be set or reset. bye"
  exit 1
fi

# from https://marc.info/?l=linux-kernel&m=140313968523237&w=2
#* block layer queue parameters:
#  nr_requests=1011, add_random=0
#  nomerges=2, rq_affinity=2, max_sectors_kb=max_hw_sectors_kb

CUR_DIR=$(pwd)
SV_FL="$CUR_DIR/sv_drv_q_settings_${DRV}.txt"
cd $Q_DIR
if [ ! -e $SV_FL ]; then
  echo "files_in_dir $Q_DIR" > $SV_FL
  for i in *; do
    printf "%s %s\n" $i "$(cat $i 2> /dev/null)" >> $SV_FL
  done
fi

#-rw-r--r-- 1 root root 4096 Nov 12 00:41 add_random
WRTABLE=($(ls -l | grep '^-rw-' | awk '{print $NF;}'))
echo "writeable files= ${WRTABLE[@]}"
if [ "$ACT" == "reset" ]; then
for j in ${WRTABLE[@]}; do
  V=$(grep "^$j " $SV_FL | sed "s/^$j //")
  CUR="$(cat $j 2> /dev/null)"
  if [[ "$V" != "" ]] && [[ "$CUR" != "$V" ]]; then
    echo "$0.$LINENO reset $j cur_val= \"$CUR\" def_val= \"$V\""
    echo $V > $j
  fi
done
fi
if [ "$ACT" == "set" ]; then
#  nr_requests=1011, add_random=0
#  nomerges=2, rq_affinity=2, max_sectors_kb=max_hw_sectors_kb
  echo 64 > nr_requests
  echo $0.$LINENO rc= $?
  echo 0 > add_random
  echo $0.$LINENO rc= $?
  echo 2 > nomerges
  echo $0.$LINENO rc= $?
  echo 2 > rq_affinity
  echo $0.$LINENO rc= $?
  echo 4 > read_ahead_kb
  echo $0.$LINENO rc= $?
fi

cd $CUR_DIR


exit 0

                    add_random 0
                 chunk_sectors 0
                           dax 0
           discard_granularity 512
             discard_max_bytes 2199023255040
          discard_max_hw_bytes 2199023255040
           discard_zeroes_data 0
                           fua 0
                hw_sector_size 512
                       io_poll 0
                 io_poll_delay 0
                       iostats 0
            logical_block_size 512
          max_discard_segments 256
             max_hw_sectors_kb 1024
        max_integrity_segments 0
                max_sectors_kb 1024
              max_segment_size 4294967295
                  max_segments 127
               minimum_io_size 512
                      nomerges 0
                   nr_requests 128
                      nr_zones 0
               optimal_io_size 512
           physical_block_size 512
                 read_ahead_kb 128
                    rotational 0
                   rq_affinity 0
                     scheduler none
                  wbt_lat_usec 
                   write_cache write
                       through 
          write_same_max_bytes 0
        write_zeroes_max_bytes 1048576
                         zoned none


