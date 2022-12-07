#!/usr/bin/env bash

# this script is not used now (I think)
# use do_fio.sh and do_vdb.sh instead. And see do_over_fio_vdb.sh for sample cmdlines
echo "not used currently. not tested for a while. bye"
exit 1

SCR_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
cd $SCR_DIR
# arg1 oper (like read randread write randwrite)
# arg2 blk_sz (like 4k 1m)
# arg3 run_time (secs)
DSKS=(nvme0n1 nvme1n1 nvme2n1 nvme3n1 nvme4n1 nvme5n1 nvme6n1 nvme7n1)
DSKS_TOT=8
DSKS_USE=$DSKS_TOT
OPER=randread
BLK_SZ=4k
TM=3600
ITER="-1"
GOT_QUIT=0
# function called by trap
catch_signal() {
    printf "\rSIGINT caught      "
    GOT_QUIT=1
}
trap 'catch_signal' SIGINT

OPER=read
BLK_SZ=1m
TM=600
JOBS_IN=32
THRD_IN=32
BENCHMARK="fio"

while getopts "hvb:B:D:g:i:J:O:p:T:t:" opt; do
  case "${opt}" in
    b )
      BENCHMARK="$OPTARG"  # fio or vdb
      echo "$0.$LINENO blk_lst= $BLK_SZ"
      ;;
    B )
      BLK_SZ="$OPTARG"
      echo "$0.$LINENO blk_lst= $BLK_SZ"
      ;;
    D )
      DSKS_USE="$OPTARG"
      echo "$0.$LINENO dsks_use= $DSKS_USE"
      ;;
    g )
      GRP_IN="$OPTARG"  
      echo "$0.$LINENO grp_in= $GRP_IN"
      ;;
    i )
      ITER="$OPTARG"  # if -1 then infinite loop (waiting on stop file or pkill -2 -f fio_multi.sh) else do for ((i=0; i < ITER; i++)) iterations
      echo "$0.$LINENO iter= $ITER"
      ;;
    J )
      JOBS_IN="$OPTARG"  
      echo "$0.$LINENO jobs= $JOBS_IN"
      ;;
    O )
      OPER="$OPTARG"
      echo "$0.$LINENO oper= $OPER"
      ;;
    p )
      PERF_IN="$(echo "$OPTARG" | sed 's/,/ /g')"  # -p 1 -> run perf
      ;;
    T )
      THRD_IN="$OPTARG"  
      echo "$0.$LINENO threads= $THRD_IN"
      ;;
    t )
      TM=$OPTARG
      echo "$0.$LINENO tm= $TM"
      ;;
    v )
      VRB=$((VRB+1))
      ;;
    h )
      echo "$0 run fio or vdbench"
      echo "Usage: $0 [-h] [-v] [-b fio|vdb]  [-B \"block_lst\"] [-g group_id] [-i number_of_iterations] [-O read|write|randread|randwrite|precondition] [-t tm_in_secs]"
      echo "   tbd#-x project_dir"
      echo "     by default the host results dir name $PROJ_DIR"
      echo "     If you specify a project dir the benchmark results are looked for"
      echo "     under /project_dir/"
      echo "   #-x spin.x_run_time_in_secs  spin.x uses all cpus. Default is 1 sec. spin.x does 3 different runs so -l 10 secs can take all cpus for 30 seconds"
      echo "      the default is 1 second/run. -l 0 skips spin.x which is recommended for production boxes"
      echo "   #-x prefix subdir name 'sysinfo' with timestamp YY-MM-DD_HHMMSS_. Default is don't prefix it"
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
shift $((OPTIND -1))
#echo "$0.$LINENO bye"
#exit 1
PID_ARR=()

if [[ "$BENCHMARK" != "fio" ]] && [[ "$BENCHMARK" != "vdb" ]]; then
  echo "$0.$LINENO benchmark must be 'fio' or 'vdb' (for vdbench). Got -b \"$BENCHMARK\". bye."
  exit 1
fi
STOP_FL="${BENCHMARK}_multi.stop"
if [ -e $STOP_FL ]; then
  rm $STOP_FL
fi
GRP_FL="${BENCHMARK}_multi.group"

if [ ! -e $GRP_FL ]; then
  echo -1 > $GRP_FL
fi
GRP=$(cat $GRP_FL)
GRP=$((GRP+1))
if [ "$GRP_IN" != "" ]; then
  GRP=$GRP_IN
fi
echo $GRP > $GRP_FL

FIOM_DIR=${BENCHMARK}_multi
if [ ! -d $FIOM_DIR ]; then
  mkdir -p $FIOM_DIR
fi
OPT_PERF=
if [ "$PERF_IN" == "1" ]; then
  OPT_PERF="-p 1"
fi

k=0
while (( ITER == -1 || k < ITER )); do
  dsks=0
  for ((i=0; i < $DSKS_TOT; i++)); do
    SFX=$(printf "_g%.3d_i%.3d_prec%.2d" $GRP $k $i)
    OFL="$FIOM_DIR/tmp_multi${SFX}.txt"
    echo "$SCR_DIR/do_${BENCHMARK}.sh $OPT_PERF -f 0 -D 1 -L ${DSKS[$i]}  -O "$OPER" -B "$BLK_SZ" -r 1 -t $TM  -R 0 -J $JOBS_IN -T $THRD_IN -s $SFX > $OFL &" > $OFL
          $SCR_DIR/do_${BENCHMARK}.sh $OPT_PERF -f 0 -D 1 -L ${DSKS[$i]}  -O "$OPER" -B "$BLK_SZ" -r 1 -t $TM  -R 0 -J $JOBS_IN -T $THRD_IN -s $SFX >> $OFL &
          PID_ARR[$i]=$!
    dsks=$((dsks+1))
    if [[ "$dsks" -ge "$DSKS_USE" ]]; then
      break
    fi
  done
  wait
  if [[ -e $STOP_FL ]]; then
    echo "$0.$LINENO got $STOP_FL. bye"
    rm $STOP_FL
    exit 1
  fi
  if [[ "$GOT_QUIT" == "1" ]]; then
    echo "$0.$LINENO got quit. bye"
    exit 1
  fi
  k=$((k+1))
done


