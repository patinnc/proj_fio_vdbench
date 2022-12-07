#!/bin/bash

# this script is called by any of the other scripts currently
# I had it a one time working to to got by the snia "find steady state" procedure
# but I didn't save the "here is the fio cmdline that generates the data for the script" script
# So now I just have it for reference in case I want to incorporate it again.

if [ "$1" == "" ]; then
  echo "need to pass dir name with fio files"
  exit 1
fi

DIR=$1
if [ ! -d $DIR ]; then
   echo "did not find dir $DIR"
   exit 1
fi
# assumes files are named blah_blah_fio.txt and blah_blah_iostat.txt
FILES=`find $DIR -name "*nvme*_fio.txt" |sort`
if [ "$FILES" == "" ]; then
  FILES=`find $DIR -name "*nvme*.txt" |sort`
else
  FILES_IO=`find $DIR -name "*nvme*_iostat.txt" |sort`
  echo "got iostat files" > /dev/stderr
fi
#echo "files:"
#echo "$FILES"

VERBOSE=1

awk -v vrb=$VERBOSE ' 
#  
# linear regression awk code
# from http://www2.geog.ucl.ac.uk/~plewis/bpms/bin/csh/linear.regress.awk
#
#	see e.g. Clark, W.A.V. and Hosking, P.L.,
#	Statistical Methods for Geographers
#	Wiley, 1986. pp300-304
#	for appropriate theory
#

############# AMENDED VERSION: Mat Wed Aug 19 15:31:59 BST 1998 ############
#__nvme_list
#Node             SN                   Model                                    Namespace Usage                      Format           FW Rev
#---------------- -------------------- ---------------------------------------- --------- -------------------------- ---------------- --------
#/dev/nvme0n1     Z9NF7235FY3L         KXG60ZNV256G TOSHIBA                     1         256.06  GB / 256.06  GB    512   B +  0 B   AGGA4104
#/dev/nvme1n1     PHLJ948003EN4P0DGN   INTEL SSDPE2KX040T8      
# iostat
#Device:         rrqm/s   wrqm/s     r/s     w/s    rkB/s    wkB/s avgrq-sz avgqu-sz   await r_await w_await  svctm  %util
#nvme1n1           0.00     0.00    0.15 16146.03     1.11 167469.81    20.74     2.83    0.10    0.12    0.10   0.01  16.99

{
    flnm = ARGV[ARGIND];
    if (index(flnm, "_iostat.txt") > 0) {
      ref = iostat_lkup[flnm];
      #printf("got ref= %s iostat file= %s\n", ref, flnm) > "/dev/stderr";
      if (ref == "") {
         printf("missed find matching fio results file for %s\n", flnm);
         nextfile;
      }
      if ($1 != "Device:") {
         next;
      }
      if (hdr_lkup[ref] == "") {
        #if (vrb) {
        #  printf("got iostat file= %s\n", flnm) > "/dev/stderr";
        #}
        for (i=1; i <= NF; i++) {
          if ($i == "Drive:") { hdr[ref,$i] = i; }
          if ($i == "rrqm/s") { hdr[ref,$i] = i; }
          if ($i == "wrqm/s") { hdr[ref,$i] = i; }
          if ($i == "r/s")    { hdr[ref,$i] = i; }
          if ($i == "w/s")    { hdr[ref,$i] = i; }
          if ($i == "rkB/s")  { hdr[ref,$i] = i; }
          if ($i == "wkB/s")  { hdr[ref,$i] = i; }
          if ($i == "avgrq-sz") { hdr[ref,$i] = i; }
          if ($i == "avgqu-sz") { hdr[ref,$i] = i; }
          if ($i == "await")   { hdr[ref,$i] = i; }
          if ($i == "r_await") { hdr[ref,$i] = i; }
          if ($i == "w_await") { hdr[ref,$i] = i; }
          if ($i == "svctm")   { hdr[ref,$i] = i; }
          if ($i == "%util")   { hdr[ref,$i] = i; }
          hdr_list[ref,i] = $i;
        }
        hdr[ref,"mx"] = NF;
      }
      getline;
      if ($0 == "") {next;}
      hdr_lkup[ref]++;
      j = hdr_lkup[ref];
      for (i=1; i <= NF; i++) {
        io_data[ref,j,i] = $i;
      }
      next;
    }
}



/__nvme_list/{
  got_it = 0;
  got_loop = 0;
  while(1) {
    getline;
    if (index($0, "__") == 1) { break; }
    if (index($0, "----") == 1) {
      got_it = 1;
      off = 0;
      ext = 0;
      for (i=1; i <= 3; i++) {
         cur_len = length($i);
         if (i < 3) {
           off += length($i);
           off += ext;
         }
         ext = 1;
      }
      continue;
    }
    if (got_it != 1) { continue;}
    ++drvs;
    mkr[ARGIND,drvs,1] = $1;
    v = substr($0, off, cur_len);
    n = split(v, arr, " ");
    v = "";
    dlm = "";
    for (i=1; i <= n; i++) {
      v = v dlm arr[i];
      dlm = " ";
    }
    v = tolower(v);
    mkr[ARGIND,drvs,2] = v;
    m = "";
    nl=0;
    nvme_list[++nl] = "toshiba";
    nvme_list[++nl] = "micron";
    nvme_list[++nl] = "ssstc";
    nvme_list[++nl] = "intel";
    for (i=1; i <= nl; i++) {
      if (index(v, nvme_list[i]) > 0) {
        m = nvme_list[i];
        break;
      }
    }
    mkr[ARGIND,drvs,3] = m;
    typ = m;
    if (!(typ in typ_list)) {
      typ_list[typ] = ++typ_mx;
      typ_lkup[typ_mx] = typ;
      printf("typ[%d]= %s, line= %s\n", typ_mx, typ, $0);
    }
    if (!(m in mkr_list)) {
      mkr_list[m] = ++mkr_mx;
      mkr_lkup[mkr_mx] = m;
    }
      
    #printf("%s %s off=%s, cur_len= %d\n", mkr[ARGIND,drvs,1], mkr[ARGIND,drvs,2], off, cur_len);
  }
}
/__loop drive /{
  got_loop = 1;
  #__loop drive nvme1n1 rw randwrite bs 4k i 0 depth 4 numjobs 1
  #__loop drive nvme4n1 rw randread bs 4k i 0 depth 512
  loop_line = $0;
  drv = $3;
  rw  = $5;
  if (!(rw in rw_list)) {
    rw_list[rw] = ++rw_mx;
    rw_lkup[rw_mx] = rw;
  }
  bs  = $7;
  if (!(bs in bs_list)) {
    bs_list[bs] = ++bs_mx;
    bs_lkup[bs_mx] = bs;
  }
  if (index(bs, "k") != length(bs)) {
    printf("expected to see block size ending with \"k\", got %s. Script only handles k sizes. Not sure what is going on.\nmessed up in loop_line= %s of file %s\n", bs, loop_line, ARGV[ARGIND]);
  }
  sz = bs * 1024;
  idx = $9;
  iod = $11;
  nj = $13;
  if (!(iod in iod_list)) {
    iod_list[iod] = ++iod_mx;
    iod_lkup[iod_mx] = iod;
  }
  if (file_mx != ARGIND) {
    for (i=1; i <= drvs; i++) {
      if (index(mkr[ARGIND,i,1], drv) > 1) {
        udrv = i;
        #printf("drv= %s typ= %s rw= %s bs= %s iod= %s\n", drv, mkr[ARGIND,i,2], rw, bs, iod);
        break;
      }
    }
    file_mx = ARGIND;
    flnm = ARGV[ARGIND];
    gsub("_fio.txt", "_iostat.txt", flnm);
    iostat_lkup[flnm] = ARGIND;
    cfg[ARGIND,"drv"] = drv;
    cfg[ARGIND,"rw"] = rw;
    cfg[ARGIND,"bs"] = bs;
    cfg[ARGIND,"sz"] = sz;
    cfg[ARGIND,"iod"] = iod;
    cfg[ARGIND,"typ"] = typ;
    cfg[ARGIND,"numjobs"] = nj;
  }
}
/^Disk stats .read\/write.:/{
  if (got_loop == 0) { next; }
  getline;
  #nvme1n1: ios=63/6529354, merge=0/0, ticks=4/1018352, in_queue=808828, util=95.93%
  v = drv ":";
  if (v != $1) {
    printf("expected to see %s, got %s. Not sure what is going on.\nmessed up in loop_line= %s of file %s\n", v, $1, loop_line, ARGV[ARGIND]);
  } else {
    n = split($2, arr, "=");
    n = split(arr[2], arr2, "/");
    ios[ARGIND,idx,"rd"] = arr2[1]+0;
    ios[ARGIND,idx,"wr"] = arr2[2]+0;
    #printf("rd/wr= %d/%d\n", arr2[1], arr2[2]);
    tm = runtime[ARGIND,idx];
    sz = cfg[ARGIND,"sz"];
    if (rw == "randread") {
       metric[ARGIND,idx,"val"] = (tm > 0 ? 0.001 * arr2[1]/tm : 0);
       metric[ARGIND,idx,"unit"] = "kIOPS";
    } else if (rw == "randwrite") {
       metric[ARGIND,idx,"val"] = (tm > 0 ? 0.001 * arr2[2]/tm : 0);
       metric[ARGIND,idx,"unit"] = "kIOPS";
    } else if (rw == "read") {
       metric[ARGIND,idx,"val"] = (tm > 0 ? 1.0e-6 * sz * arr2[1]/tm : 0);
       metric[ARGIND,idx,"unit"] = "MB/s";
    } else if (rw == "write") {
       metric[ARGIND,idx,"val"] = (tm > 0 ? 1.0e-6 * sz * arr2[2]/tm : 0);
       metric[ARGIND,idx,"unit"] = "MB/s";
    }
    #printf("rw= %s metric[%s,%s,%s]= %f %s\n", rw, ARGIND, idx, "val", metric[ARGIND,idx,"val"], metric[ARGIND,idx,"unit"]);
  }
}
#   iops        : min=460422, max=484704, avg=479151.59, stdev=4431.33, samples=599
/ iops /{
  if (got_loop == 0) { next; }
   if (1==2){printf("%s\n", $0);}
   gsub(",", "", $0);
   for (i=1; i <= NF; i++) {
     n = split($i, arr, "=");
     if (arr[1] == "avg") {
        avg = arr[2];
        ln[ARGIND,idx] = avg;
        ln_mx[ARGIND] = idx;
        break;
     }
   }
}
#Run status group 0 (all jobs):
#  WRITE: bw=2722MiB/s (2854MB/s), 2722MiB/s-2722MiB/s (2854MB/s-2854MB/s), io=797GiB (856GB), run=300002-300002msec
/^Run status group 0 .all jobs.:/ {
  if (got_loop == 0) { next; }
   getline;
   if (index($0, " run=") == 0) {
    printf("expected to see \" run=\" in line= \"%s\". Not sure what is going on.\nmessed up in loop_line= %s of file %s\n", $0, loop_line, ARGV[ARGIND]);
   } else {
     gsub(",", "", $0);
     for (i=1; i <= NF; i++) {
       n = split($i, arr, "=");
       if (arr[1] == "run") {
          if (index(arr[2], "-") > 0) {
            n = split(arr[2], arr2, "-");
            arr[2] = arr2[2];
          }
          fctr = 1.0; # is time unit always msecs ?
          if (index(arr[2], "msec") > 0) {
            fctr = 0.001;
          }
          runtime[ARGIND,idx] = fctr * arr[2];
          #printf("runtm= %.3f secs\n", runtime[ARGIND,idx]);
          break;
       }
     }
   }
}
{
        if(1==2&& $1 != "#" && NF > 1){
                sumX += $1;
                sumY += $2;
                sumXX += $1*$1;
                sumXY += $1*$2;
                y[++N]=$2;
                x[N]=$1;
                 
        m = (N*sumXY - sumX*sumY)/(N*sumXX - sumX*sumX);
        c = (sumY - m*sumX)/N;
# giving y = m*x +c
        #print "# y =",m,"* x +",c;
        meanX=sumX/N;
        meanY=sumY/N;
        }
}
END {
  # abc
  printf("typ_mx= %d, rw_mx= %d, file_mx= %d, iod_mx= %d\n", typ_mx, rw_mx, file_mx, iod_mx);

  j = hdr[1,"mx"];
  if (j > -1) {
    str = hdr_list[1,1];
    for (i=2; i <= j; i++) {
      str = str " " hdr_list[1,i];
    }
    printf("iostat_hdr= %s\n", str);
  }
  for (r=1; r <= rw_mx; r++) {
    for (m=1; m <= typ_mx; m++) {
      for (d=1; d <= iod_mx; d++) {
        for (f=1; f <= file_mx; f++) {
          iod = cfg[f,"iod"];
          if (iod != iod_lkup[d]) { continue; }
          typ = cfg[f,"typ"];
          if (typ != typ_lkup[m]) { continue; }
          rw = cfg[f,"rw"];
          if (rw != rw_lkup[r]) { continue; }
          last_ok = "";
          first_val = 0.0;
          last_val = 0.0;
          for (j=1; j < (ln_mx[f]-4); j++) {
            n = 0;
            sum = 0.0;
            unit = "unk";
            min_y = 0.0;
            max_y = 0.0;
                       
            sumX = 0.0;
            sumY = 0.0;
            sumXX = 0.0;
            sumXY = 0.0;
            N = 0;
            for (i=j; i < (j+5); i++) {
               v = metric[f,i,"val"];
               sumX += i;
               sumY += v;
               sumXX += i*i;
               sumXY += i*v;
               ++N;
               x[N]= i;
               y[N]= v;
               if (i==j || min_y > v) { min_y = v; }
               if (i==j || max_y < v) { max_y = v; }
               sum += v;
               unit = metric[f,i,"unit"];
               n++;
            }
            if (n > 0) {
              drv = cfg[f,"drv"];
              rw  = cfg[f,"rw"];
              bs  = cfg[f,"bs"];
              nj  = cfg[f,"numjobs"];
      
              io_nf  = hdr[f,"mx"];
              io_lns = hdr_lkup[f];
              io_str = "";l
              if (io_nf != "") {
                io_str = " io";
                io_end = io_lns-1;
                io_beg = io_end-6;
                if (io_beg < 1) { io_beg = 1;}
                for (io_i=2; io_i <= io_nf; io_i++) {
                  io_arr[io_i] = 0.0;
                  io_n[io_i] = 0;
                }
                for (io_j=io_beg; io_j <= io_end; io_j++) {
                  for (io_i=1; io_i <= io_nf; io_i++) {
                    io_arr[io_i] += io_data[f,io_j,io_i];
                    io_n[io_i]++;
                    printf("io_data[%d,%d,%d]= %s, n= %d h= %s\n", f,io_j,io_i,io_data[f,io_j,io_i], io_n[io_i], hdr_list[f,io_i]);
                  }
                }
                io_str = " io";
                for (io_i=1; io_i <= io_nf; io_i++) {
                  v = 0.0;
                  if (io_n[io_i] > 0) {
                    v = io_arr[io_i]/io_n[io_i];
                  }
                  io_str = io_str " " sprintf("%.2f", v);
                }
              }
              avg = sum/n;
              a20 = .2 * avg;
              ap5 = 1.05 * avg;
              am5 = 0.95 * avg;
              mx_mn_dff = max_y - min_y;
              if (a20 > mx_mn_dff) {
                dff_ok = 1;
              } else {
                dff_ok = 0;
              }
              slope = (N*sumXY - sumX*sumY)/(N*sumXX - sumX*sumX);
              const = (sumY - slope*sumX)/N;
              y0 = slope*X[1] + const;
              y1 = slope*X[N] + const;
              y_dff = y1 - y0;
              if (y_dff < 0.0) { y_diff *= -1.0; }
              if (y0 >= am5 && y0 <= ap5 && y1 >= am5 && y1 <= ap5) {
                trnd_ok = 1;
              } else {
                trnd_ok = 0;
              }
              if (dff_ok == 1 && trnd_ok == 1) {
                last_ok = sprintf("%s %s %s %s %s %s %.2f %s%s", typ, drv, rw, bs, iod, nj, avg, unit, io_str);
                if (first_val == 0.0) { first_val = avg; first_idx= i; }
                last_val = avg;
                last_idx = i;
              }
              if (vrb > 0) {
                printf("%s %s %s %s %s %s %.2f %s %d %d %d\n", typ, drv, rw, bs, iod, nj,  avg, unit, dff_ok, trnd_ok, N);
              }
            }
          }
          if (last_ok == "") {
              last_ok = sprintf("%s %s %s %s %s %s %.2f %s%s", typ, drv, rw, bs, iod, nj,  0.0, unit, io_str);
          }
          if (vrb > 0 && last_val > 0.0) {
             printf("pct 1-1st_valid[%d]/last_valid[%d] = % 8.4f%%\n", first_idx, last_idx, 100.0*(1.0-first_val/last_val));
          }
          printf("%s\n", last_ok);
        }
      }
    }
  }
  exit;
#  from micron file:///Users/pfay1/disks_specs/micron_brief_ssd_performance_measure.pdf
#  Steady State
#  We use the steady sate performance definition from the SNIA Solid State Storage Initiative’s Performance Test
#  Specification, Enterprise:
#   Max(y) - Min(y) within the measurement window is no more than 20% of the Ave(y) within the measurement
#  window, AND
#   [Max(y) as defined by the linear curve fit of the data with the measurement window] - [Max(y) as defined by the
#  linear curve fit of the data with the measurement window] is within 10% of the average within the measurement
#  window.
#  Stated simply, when an SSD is in the steady state performance region, its performance does not vary significantly
#  with time. Again, for additional background, see the Micron white paper “SSD Performance States” on our website.
# linear regression model
  m = (N*sumXY - sumX*sumY)/(N*sumXX - sumX*sumX);
  c = (sumY - m*sumX)/N;
# giving y = m*x +c
  print "# y =",m,"* x +",c;

  meanX=sumX/N;
  meanY=sumY/N;

  for(i=1;i<=N;i++){
    Y[i] = m*x[i]+c;
    EY = Y[i] - y[i];
    SSEY += EY*EY;

# for coefficient of correlation

    SX_MINUS_MEANX_SQUARED += (x[i] - meanX)^2;
    SY_MINUS_MEANY_SQUARED += (y[i] - meanY)^2;

    SX_MINUS_MEANXY_MINUS_MEANY += ((x[i]-meanX)*(y[i]-meanY));
  }


  stddevX=sqrt(SX_MINUS_MEANX_SQUARED/(N-1.0));
  stddevY=sqrt(SY_MINUS_MEANY_SQUARED/(N-1.0));

# variance = SD^2

  varianceX=stddevX^2;
  varianceY=stddevY^2;

# covariance

  covarianceXY=SX_MINUS_MEANXY_MINUS_MEANY/(N-1.0);

# correlation coefficient - can be calc. several ways:

  r = SX_MINUS_MEANXY_MINUS_MEANY/(sqrt(SX_MINUS_MEANX_SQUARED*SY_MINUS_MEANY_SQUARED))

# NB correlation coefficient can vary between -1 and 1. HOWEVER r^2, the coefficient of
# determination can also be calculated. This can be thought of as the proportion of the
# variance of one variable explained  by variation in the other (see Shaw and Wheeler, 
# Stat. Techn. in Geog. Anal., p 181).

  print "# SSE(y):",SSEY;
  print "# Variance(x):",varianceX, "Variance(y):", varianceY;
  print "# Standard deviation (x):",stddevX,"Standard deviation (y):",stddevY;
  print "# Mean(y):",sumY/N, "Mean(x):",sumX/N;
  print "# covariance:", covarianceXY;
  print "# correlation coefficient (r):", r;
  print "# coefficient of determination (r^2):" , r^2;
  for(i=1;i<=N;i++){
    print x[i],Y[i];
  }
}
' $FILES  $FILES_IO
