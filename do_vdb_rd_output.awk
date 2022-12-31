#            awk -v sfx="$SFX" -v num_cpus="$NUM_CPUS" -v perf_fl="$PRF_FL" -v tm_dff="$ELAP_SECS" -v drvs="$DRVS" -v sz="$SZ" -v threads="$THREADS" -v procs="$JOBS" -v rdwr="$OPER" -v fio_fl="$OFL" -v tm="$ELAP_SECS" -v iost_fl="$IO_FL" -v drv_str="$DRV_STR" '
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
              /^__cmd / {
                ++rn;
                fl[rn] = FILENAME;
                printf("fl[%d]= %s\n", rn, fl[rn]);
              }
                /^__drives / { sv[rn, "drvs"] = $2; drvs= $2;}
                /^__drv / { sv[rn, "drv"] = $2; drv= $2; }
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
                  printf("qq drives= %d oper= %s sz= %s IOPS(k)= %.3f bw(MB/s)= %.3f szKiB= %d iodepth= %d procs= %d tm_dff_secs= %d %%busy= %s lat_ms= %f sfx= %s%sdrv= %s work= vdb iostat= %s fio_fl= %s\n",
                   drvs, rdwr, sz, kiops, MBps, szb/1024, threads, procs, tm_dff, busy_str, lat_ms, sfx, my_unhalted_str, sv[rn, "drv"], iost_fl, fio_fl);
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
#            ' $PRF_FL $IO_FL v_res.txt > v_res1.txt
