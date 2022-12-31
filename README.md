# proj_fio_vdbench

# Table of Contents
- [Introduction](#introduction)
- [Data collection](#data-collection)
- [Charting Data](#charting-data)

--------------------------------------------------------------------------------
## Introduction
- dependencies 
    - fio, vdbench (needs java), iostat, and perf (optional but recommended)
Run fio and/or vdbench. Mostly used on nvme drives.

Supports both fio and vdbench (so that we can get measurements 2 different ways).
But I use fio more and the do_fio.sh script has a few more parameters (currently).
Features of the code:
- do_fio.sh and do_vdb.sh have (more or less) the same cmdline options
   - You can just about change just './do_fio.sh' to './do_vdb.sh'
   - I find vdbench generally slower so I been using fio mostly.
   - scripts have check to try and make sure you aren't going to wipe out data but use at your own risk.
   - Not responsible for any loss of data or damage to drives.
   - supports raw IO or IO to file system, individual drives, collection of drives, raw raid, drives with file system or raid with file system..
   - do dry run (--dry_run 1)
   - operate on more than 1 drive
   - collect linux perf stat data and iostat data (-p 1)
        - there will only be 1 iostat and 1 perf file per run since they are monitoring the whole system.
        - In the qq lines below you'll note that the iostat filesce they are monitoring the whole system.
   - pass xtra options not built-in to the script
   - select 1 or more drives (-D num_drives) from the list of drives (-L nvme1[,...])
   - do "per drive" options (-P 1 does 1 fio cmd per drive if more than 1 drive). -P 0 does 1 fio cmd over all the drives.
   - puts output files in fio_data vdb_data or iostat_data subdirs.
   - appends high level data (like the 'qq' lines below in the files: f_all.txt (for fio) or v_all.txt (for vdbench)
   - sample cmdline to do raw IO to each drive (1 fio cmd per drive) randread 4k jobs=32 iodepth=32 using posixaio (just for demo)
```
./do_fio.sh -y --dry_run 0 --raw  -L nvme0n1,nvme1n1,nvme2n1,nvme3n1,nvme4n1,nvme5n1,nvme6n1,nvme7n1  -O randread -B 4k -t 20 -D 8 -J 32 -T 32 -p 1 -P 1 -x "--ioengine=posixaio"
```

I've since changed do_fio.sh to do either fio or vdbench. Here is an example. Option -W fio,vdb does the cmd over both fio and vbdbench.
See run_multi.sh for and example of doing over a list of disks, blocks, number of jobs, operators (read, randread, etc), and fio or vdbench.
```
./do_fio.sh -y  --dry_run 0 -D 1 -L nvme0n1,nvme1n1,nvme2n1,nvme3n1,nvme4n1,nvme5n1,nvme6n1,nvme7n1 -f 0  -n 1 -O randread -p 1 -P 1 -t 10 -J 4 -T 64 -r 1 -B 4k -W fio,vdb -D 1|grep qq
```
   - sample output below... shows IOPS= ~900K per drive and %busy ~92% (from fio) and %unhalted= 97% (from perf). The raw fio, iostat and perf data are given.
```
qq drives= 8 oper= randread sz= 4k IOPS(k)= 875.283 bw(MB/s)= 3585.159 szKiB= 4 iodepth= 32 procs= 32 tm_act_secs= 20.0020 %busy= 92.835 lat_ms= 1.168950 sfx= _4k_randread %unhalted= 97.368 unhaltedTL= 24926.140 cpu_freqGHz= 3.239 drv= /dev/nvme0n1 iostat= iostat_data/iostat_4k_randread_032jobs_032thrds_8drvs_1raid_0raw_0fs.txt fio_fl= fio_data/fio_4k_randread_032jobs_032thrds_8drvs_1raid_0raw_0fs.0.txt
qq drives= 8 oper= randread sz= 4k IOPS(k)= 679.895 bw(MB/s)= 2784.850 szKiB= 4 iodepth= 32 procs= 32 tm_act_secs= 20.0010 %busy= 92.835 lat_ms= 1.505320 sfx= _4k_randread %unhalted= 97.368 unhaltedTL= 24926.140 cpu_freqGHz= 3.239 drv= /dev/nvme1n1 iostat= iostat_data/iostat_4k_randread_032jobs_032thrds_8drvs_1raid_0raw_0fs.txt fio_fl= fio_data/fio_4k_randread_032jobs_032thrds_8drvs_1raid_0raw_0fs.1.txt
qq drives= 8 oper= randread sz= 4k IOPS(k)= 914.873 bw(MB/s)= 3747.318 szKiB= 4 iodepth= 32 procs= 32 tm_act_secs= 20.0020 %busy= 92.835 lat_ms= 1.118560 sfx= _4k_randread %unhalted= 97.368 unhaltedTL= 24926.140 cpu_freqGHz= 3.239 drv= /dev/nvme2n1 iostat= iostat_data/iostat_4k_randread_032jobs_032thrds_8drvs_1raid_0raw_0fs.txt fio_fl= fio_data/fio_4k_randread_032jobs_032thrds_8drvs_1raid_0raw_0fs.2.txt
qq drives= 8 oper= randread sz= 4k IOPS(k)= 925.198 bw(MB/s)= 3789.610 szKiB= 4 iodepth= 32 procs= 32 tm_act_secs= 20.0010 %busy= 92.835 lat_ms= 1.105990 sfx= _4k_randread %unhalted= 97.368 unhaltedTL= 24926.140 cpu_freqGHz= 3.239 drv= /dev/nvme3n1 iostat= iostat_data/iostat_4k_randread_032jobs_032thrds_8drvs_1raid_0raw_0fs.txt fio_fl= fio_data/fio_4k_randread_032jobs_032thrds_8drvs_1raid_0raw_0fs.3.txt
qq drives= 8 oper= randread sz= 4k IOPS(k)= 926.186 bw(MB/s)= 3793.659 szKiB= 4 iodepth= 32 procs= 32 tm_act_secs= 20.0020 %busy= 92.835 lat_ms= 1.104710 sfx= _4k_randread %unhalted= 97.368 unhaltedTL= 24926.140 cpu_freqGHz= 3.239 drv= /dev/nvme4n1 iostat= iostat_data/iostat_4k_randread_032jobs_032thrds_8drvs_1raid_0raw_0fs.txt fio_fl= fio_data/fio_4k_randread_032jobs_032thrds_8drvs_1raid_0raw_0fs.4.txt
qq drives= 8 oper= randread sz= 4k IOPS(k)= 861.162 bw(MB/s)= 3527.318 szKiB= 4 iodepth= 32 procs= 32 tm_act_secs= 20.0020 %busy= 92.835 lat_ms= 1.188290 sfx= _4k_randread %unhalted= 97.368 unhaltedTL= 24926.140 cpu_freqGHz= 3.239 drv= /dev/nvme5n1 iostat= iostat_data/iostat_4k_randread_032jobs_032thrds_8drvs_1raid_0raw_0fs.txt fio_fl= fio_data/fio_4k_randread_032jobs_032thrds_8drvs_1raid_0raw_0fs.5.txt
qq drives= 8 oper= randread sz= 4k IOPS(k)= 890.673 bw(MB/s)= 3648.197 szKiB= 4 iodepth= 32 procs= 32 tm_act_secs= 20.0030 %busy= 92.835 lat_ms= 1.148990 sfx= _4k_randread %unhalted= 97.368 unhaltedTL= 24926.140 cpu_freqGHz= 3.239 drv= /dev/nvme6n1 iostat= iostat_data/iostat_4k_randread_032jobs_032thrds_8drvs_1raid_0raw_0fs.txt fio_fl= fio_data/fio_4k_randread_032jobs_032thrds_8drvs_1raid_0raw_0fs.6.txt
qq drives= 8 oper= randread sz= 4k IOPS(k)= 981.021 bw(MB/s)= 4018.260 szKiB= 4 iodepth= 32 procs= 32 tm_act_secs= 20.0020 %busy= 92.835 lat_ms= 1.042670 sfx= _4k_randread %unhalted= 97.368 unhaltedTL= 24926.140 cpu_freqGHz= 3.239 drv= /dev/nvme7n1 iostat= iostat_data/iostat_4k_randread_032jobs_032thrds_8drvs_1raid_0raw_0fs.txt fio_fl= fio_data/fio_4k_randread_032jobs_032thrds_8drvs_1raid_0raw_0fs.7.txt
```

   - ./raid_setup.sh does some common raid tasks (create, destroy, with/without file system, with/without mount-point)

   - ./do_over_fio_vdb.sh has some commonly done tasks and is meant as a test of functionality.
       - create or destroy raid.
       - precondition drives (short test or full test). The short test does a fixed amount of writes. The full test does 2x writes to each drive (and it can take a while).
           - uses the pci max block size to write the devices
           - does 1 fio cmd per drive (so preconditions in parallel)
           - does 2 iterations of writes to whole device per SNIA prereconditions guidelines.
       - currently you have to edit the script and change the values to control the script... sorry.

   - ./get_pcie_bw.sh nvme0n1 [1] shows max bw by pci settings and, if verbose, various /sys/class /sys/device settings
       - takes drive (like nvme0n1) as required arg
       - option 2 arg (like 1) enables verbose mode which displays some of the /sys/class or /sys/device settings for the drive


--------------------------------------------------------------------------------
## Data Collection
- the f_all.txt (or v_all.txt) files have high level info
   - the qq lines (see above qq example lines) record the iostat and fio output files if you want more data).
   - the qq lines are not so spreadsheet friendly (the key= value key1= value etc) can be hard to read.
   - ./line_headers_to_columns.sh f_all.txt will recast the qq lines to a header and detail lines like below:
```
hdr drives oper sz IOPS(k) bw(MB/s) szKiB iodepth procs tm_act_secs %busy lat_ms sfx %unhalted unhaltedTL cpu_freqGHz drv iostat fio_fl
qq 8 randread 4k 875.283 3585.159 4 32 32 20.0020 92.835 1.168950 _4k_randread 97.368 24926.140 3.239 /dev/nvme0n1 iostat_data/iostat_4k_randread_032jobs_032thrds_8drvs_1raid_0raw_0fs.txt fio_data/fio_4k_randread_032jobs_032thrds_8drvs_1raid_0raw_0fs.0.txt
qq 8 randread 4k 679.895 2784.850 4 32 32 20.0010 92.835 1.505320 _4k_randread 97.368 24926.140 3.239 /dev/nvme1n1 iostat_data/iostat_4k_randread_032jobs_032thrds_8drvs_1raid_0raw_0fs.txt fio_data/fio_4k_randread_032jobs_032thrds_8drvs_1raid_0raw_0fs.1.txt
qq 8 randread 4k 914.873 3747.318 4 32 32 20.0020 92.835 1.118560 _4k_randread 97.368 24926.140 3.239 /dev/nvme2n1 iostat_data/iostat_4k_randread_032jobs_032thrds_8drvs_1raid_0raw_0fs.txt fio_data/fio_4k_randread_032jobs_032thrds_8drvs_1raid_0raw_0fs.2.txt
qq 8 randread 4k 925.198 3789.610 4 32 32 20.0010 92.835 1.105990 _4k_randread 97.368 24926.140 3.239 /dev/nvme3n1 iostat_data/iostat_4k_randread_032jobs_032thrds_8drvs_1raid_0raw_0fs.txt fio_data/fio_4k_randread_032jobs_032thrds_8drvs_1raid_0raw_0fs.3.txt
qq 8 randread 4k 926.186 3793.659 4 32 32 20.0020 92.835 1.104710 _4k_randread 97.368 24926.140 3.239 /dev/nvme4n1 iostat_data/iostat_4k_randread_032jobs_032thrds_8drvs_1raid_0raw_0fs.txt fio_data/fio_4k_randread_032jobs_032thrds_8drvs_1raid_0raw_0fs.4.txt
qq 8 randread 4k 861.162 3527.318 4 32 32 20.0020 92.835 1.188290 _4k_randread 97.368 24926.140 3.239 /dev/nvme5n1 iostat_data/iostat_4k_randread_032jobs_032thrds_8drvs_1raid_0raw_0fs.txt fio_data/fio_4k_randread_032jobs_032thrds_8drvs_1raid_0raw_0fs.5.txt
qq 8 randread 4k 890.673 3648.197 4 32 32 20.0030 92.835 1.148990 _4k_randread 97.368 24926.140 3.239 /dev/nvme6n1 iostat_data/iostat_4k_randread_032jobs_032thrds_8drvs_1raid_0raw_0fs.txt fio_data/fio_4k_randread_032jobs_032thrds_8drvs_1raid_0raw_0fs.6.txt
qq 8 randread 4k 981.021 4018.260 4 32 32 20.0020 92.835 1.042670 _4k_randread 97.368 24926.140 3.239 /dev/nvme7n1 iostat_data/iostat_4k_randread_032jobs_032thrds_8drvs_1raid_0raw_0fs.txt fio_data/fio_4k_randread_032jobs_032thrds_8drvs_1raid_0raw_0fs.7.txt
```

--------------------------------------------------------------------------------

