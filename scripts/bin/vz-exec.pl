#!/usr/bin/perl

$numarg=@ARGV;
if ( $numarg < 2) {
  print "Usage: vz_exec.pl \"cmd to exec\" ds.host1 [ds.host2] ... \n\r";
  exit;
};
$cmd=$ARGV[0];

for ($i=1; $i<$numarg; $i++) {
  $host=$ARGV[$i];
  print "====== $host ======\n\r";
  open (REP,"ssh -o StrictHostKeyChecking=no -t $host sudo -s /usr/sbin/vzlist |");
  while (<REP>) {
    if ( /.*running.*/ ) {
     @t=split /\s+/;
     $vz_num=$t[1];
     $result=`ssh -t $host sudo -s /usr/sbin/vzctl exec $vz_num $cmd`;
     $result=~s/\n/\n\r/gm;
     print "====== $t[5] ======\n\r";
     print $result."\n\r";
    }
  };
  close REP;
};
