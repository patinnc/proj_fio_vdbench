            #awk -v per_drv="$PER_DRV" -v num_cpus="$NUM_CPUS" -v sfx_in="$SFX" -v tm_dff="$TM_DFF" -v drvs="$DRVS" -v sz="$BLK_SZ" -v threads="$THREADS" -v procs="$JOBS" -v rdwr="$OPER" -v fio_fl="$FIO_FL" -v tm="$TM_RUN" -v iost_fl="$IO_FL" '
              BEGIN{
                szb = sz+0;
                tm += 0;
                #got_lat = 0;
                if (sfx_in == "") { sfx_in = "null";}
              }
              /^__cmd / {
                ++rn;
                fl[rn] = FILENAME;
                printf("fl[%d]= %s\n", rn, fl[rn]);
              }
              /^__threads / { sv[rn, "threads"] = $2; }
              /^__jobs / { sv[rn, "procs"] = $2; }
              /^__drives / { sv[rn, "drvs"] = $2; }
              /^__blk_sz / { sv[rn, "sz"] = $2; }
              /^__drv / { sv[rn, "drv"] = $2; }
              /^__elap_secs / { sv[rn, "tm"] = $2; }
              /issued rwt: total=|issued rwts: total=/ {
                #issued rwt: total=0,571176,0, short=0,0,0, dropped=0,0,0
                n = split(substr($3, index($3,"=")+1), arr, ",");
                v = (arr[1] == "0" ? arr[2] : arr[1])+0;
                sv[rn, "ios"] = v;
                busy_str = "unk";
                if (idle > 0 && idle_n > 0) {
                  sv[rn, "busy"] = 100 - (idle/idle_n);
                  sv[rn, "busy_str"] = sprintf("%.3f", sv[rn, "busy"]);
                }
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
                  printf("tsc= %.0f mperf= %.0f  aperf= %.0f tsc_frq= %f cpu_frq= %f unhalted_rate= %f unhTL= %f\n", tsc, mperf, aperf, tsc_freq_ghz, cpu_freq_ghz, unhalted_ratio, unhaltedTL) > "/dev/stderr";
                  # str below needs to start and end with space
                  unhalted_str = sprintf(" %%unhalted= %.3f unhaltedTL= %.3f cpu_freqGHz= %.3f ", 100 * unhalted_ratio, unhaltedTL, cpu_freq_ghz);
                }
              }
              $1 == "lat" && got_lat[rn] == "" {
                 #      lat (usec): min=24, max=22870, avg=782.89, stdev=1886.33
                 got_lat[rn] = 1;
                 lat_unit = $2;
                 n = split($5, arr, "=");
                 lat = arr[2];
                 fctr = 0;
                 if (index(lat_unit, "msec") > 0) { fctr= 0.001;}
                 else if (index(lat_unit, "usec") > 0) { fctr= 1e-6;}
                 else if (index(lat_unit, "nsec") > 0) { fctr= 1e-9;}
                 sv[rn,"lat_ms"] = 1000 * fctr * lat;
              }
              /Run status group/ {
#  WRITE: bw=3532MiB/s (3703MB/s), 3532MiB/s-3532MiB/s (3703MB/s-3703MB/s), io=60.0GiB (64.4GB), run=17397-17397msec
                #printf("got Run status group= %s\n", $0) > "/dev/stderr";
                getline;
                sv_run_ln= $0;
                #printf("line after Run status group= %s\n", $0) > "/dev/stderr";
                for (i=1; i <= NF; i++) {
                  if (index($i, "run=") == 1) {
                    n = split($i, arr, "=");
                    fctr = 1;
                    if (index(arr[2], "msec") > 0) { fctr = 0.001;}
                    n = split(arr[2], brr, "-");
                    sv[rn,"tm_act"] = brr[1] * fctr;
                  }
                }
              }
              /avg-cpu:.* %user.* %nice.* %system.* %iowait.* %steal.*%idle/ {
                getline;
                idle += $NF;
                idle_n++;
              }
              END{
                for (i=1; i <= rn; i++) {
                sz = sv[i,"sz"];
                szb = sz+0;
                if (index(sz, "k") > 0) { szb *= 1024;}
                if (index(sz, "m") > 0) { szb *= 1024*1024;}
                tm = sv[i,"tm"];
                tm_act = sv[i,"tm_act"];
                if (tm == -1 && tm_act > 0) { tm = tm_act; }
                if (unhalted_str == "") { my_unhalted_str = " ";} else { my_unhalted_str = unhalted_str;}
                #printf("v= %s tm= %s szb= %s tm_act= %s sv_ln= %s\n", v, tm, szb, tm_act, sv_run_ln) > "/dev/stderr";
                drvs = sv[i,"drvs"];
                threads = sv[i,"threads"];
                procs = sv[i,"procs"];
                busy_str = sv[i,"busy_str"];
                lat_ms = sv[i,"lat_ms"];
                drv = sv[i,"drv"];
                v = sv[i,"ios"];
                printf("qq drives= %d oper= %s sz= %s IOPS(k)= %.3f bw(MB/s)= %.3f szKiB= %d iodepth= %d procs= %d tm_act_secs= %.4f %%busy= %s lat_ms= %f sfx= %s%sdrv= %s work= fio iostat= %s fio_fl= %s\n",
                 drvs, rdwr, sz, 0.001 * v/tm, 1e-6 * v * szb / tm, szb/1024, threads, procs, tm_act, busy_str, lat_ms, sfx_in, my_unhalted_str, drv, iost_fl, fl[i]);
                printf("\n");
                }
              }
              #' $PRF_FL $IO_FL $OFL >> $RES_FL
