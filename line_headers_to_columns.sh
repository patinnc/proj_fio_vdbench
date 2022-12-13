#!/usr/bin/env bash

#read input file like below and looks for key/value pairs on line and switch to key1 key2\nval1 val2
#qq	drives=	1	oper=	randread	sz=	4k	IOPS(k)=	1189.251	bw(MB/s)=	4871.174	szKiB=	4	iodepth=	32	procs=	32	tm_act_secs=	600.002	%busy=	12.022	lat_ms=	0.86076	sfx=	_4k_randread	%unhalted=	12.37	unhaltedTL=	3166.785	cpu_freqGHz=	3.243	iostat=	iostat_data/iostat_4k_randread_032jobs_032thrds_1drvs_0raid_1raw_0fs.txt	fio_fl=	fio_data/fio_4k_randread_032jobs_032thrds_1drvs_0raid_1raw_0fs.txt

INF=$1
if [[ "$INF" == "" ]] || [[ ! -e "$INF" ]]; then
  echo "$0.$LINENO need input file name. arg1= \"$INF\" not found"
  exit 1
fi

awk '
  /^qq /{
    if (NF==0) {printf("\n"); next; }
    #printf("%s", $1);
    if ($1 != "qq") { next;}
    if ($2 == "done") { next;}
    ln++;
    j = 0;
      key[ln,++j] = "hdr";
      val[ln,j] = $1;
    #for (i=2; i <= NF; i+=2) {
    i = 2;
    while (i <= NF) {
      incr = 2;
      # check for missing value (field i+1 ends in =)
      if (substr($(i+1), length($(i+1)), 1) == "=") {
        incr = 1;
      }
      key[ln,++j] = $i;
      if (incr == 2) {
        val[ln,j] = $(i+1);
      } else {
        val[ln,j] = "-1";
      }
      i += incr;
    }
    sv_mx_j[ln] = j;
    mx_j = j;
  }
  END{
    for (m=1; m <= ln; m++) {
      mx_j = sv_mx_j[m];
      hdr_str = sprintf("%s", key[m,1]);
      #if (m==1) {
        for (j=2; j <= mx_j; j++) {
          v = key[m,j]
          gsub(/=/, "", v);
          hdr_str = hdr_str "" sprintf(" %s", v);
        }
        #hdr_str = hdr_str "" sprintf("\n");
      #}
      if (hdr_str != hdr_str_prev) {
        printf("%s\n", hdr_str);
        hdr_str_prev = hdr_str;
      }
      printf("%s", val[m,1]);
      for (j=2; j <= mx_j; j++) {
        printf(" %s", val[m,j]);
      }
      printf("\n");
    }
  }' $INF
      
