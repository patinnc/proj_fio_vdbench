#!/bin/bash

# this script goes with the nvme_find_steady_state.sh and I'm not using it now
# provided for my reference in case I want to incorporate nvme_find_steady_state.sh at some point again

IDIR=archive_nvme_seq_128k_v04
IDIR=archive_nvme_seq_1024k_v03
if [ "$1" != "" ]; then
 IDIR=$1
fi

FILES=`find $IDIR -name "*.txt"|sort`
FILESW=`echo "$FILES"|grep write`
FILESR=`echo "$FILES"|grep read`

awk '
  function prt_it() {
    if (idx > 0) {
       sum = 0.0;
       n = 0;
       end_idx = idx - 5;
       if (end_idx < 1) { end_idx = 1; }
       for (i=idx; i > 0 && i > end_idx; i--) {
         sum += iops[i];
         n++;
       }
       printf("%-6s %s %-9s %s %3.0f %6.0f\n", mkr, drv, rw, bs, iod, sum/n);
    }
  }
  { if (ARGIND != prv_file) {
      got_beg = 0;
      if (idx > 0) {
         prt_it();
      }
    }
    mkr = "unk";
    if (index(ARGV[ARGIND], "intel") > 0) {
      mkr = "intel";
    }
    if (index(ARGV[ARGIND], "micron") > 0) {
      mkr = "micron";
    }
    prv_file = ARGIND;
  }
  /__loop begin / {
    got_beg = 1;
    disk = $3;
    idx = 0;
  }
  { 
    if (got_beg == 0) {
     next;
    }
  }
  /^mytest: .*, iodepth=/ {
    #mytest: (g=0): rw=randwrite, bs=4K-4K/4K-4K/4K-4K, ioengine=libaio, iodepth=64
    gsub(",", "", $0);
    for (i=1; i <= NF; i++) {
      n = split($i, arr, "=");
      if (arr[1] == "iodepth") {
         iod = arr[2];
      }
    }
  }
  /__loop drive / {
    #__loop drive nvme1n1 rw randwrite bs 4k i 0
    drv = $3;
    rw  = $5;
    bs  = $7;
  }
  /, iops=/ {
    gsub(",", "", $0);
    for (i=1; i <= NF; i++) {
      n = split($i, arr, "=");
      if ((rw == "randwrite" || rw == "randread") && arr[1] == "iops") {
         iops[++idx] = arr[2]+0;
      }
      if ((rw == "write" || rw == "read") && arr[1] == "bw") {
         iops[++idx] = arr[2]+0;
      }
    }
  }
  END{
    if (idx > 0) {
       prt_it();
    }
  }
  ' $FILESW $FILESR

exit
