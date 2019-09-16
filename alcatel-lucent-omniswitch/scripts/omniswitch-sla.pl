#!/usr/bin/perl 
use strict;
use warnings;
use Net::SNMP;
use Net::SNMP::Util;
use Data::Dumper;
use POSIX;
use File::Copy;
use File::Path qw(make_path);

# This requires access to a memory ramdisk to keep a buffer of 3 previous reads to detect when a probe has failed
# This reduces the reliance on NTP time synchronization between server and client
my $ramdisk = '/dev/shm/';

my $ip          = $ARGV[0];
my $community   = $ARGV[1];
my $snmpversion = $ARGV[2];
my $get         = $ARGV[3];
my $function    = $ARGV[4] || undef;
my $key         = $ARGV[5] || undef;
my $direction   = undef;

if($get eq 'index'){
    $get = 'query';
    $function = 'justIndex';
}

#print STDERR "DBG: get: $get, function: $function, key: $key\n";


if( $get eq 'get'){
    #actual polling
    my $oid = undef;
#    $key=~/^[0-9]+\.(.*)$/;
#    my $keyOID = "";
    if($function eq 'l3pktsent'){
	$oid = "1.3.6.1.4.1.6486.800.1.2.1.55.1.1.3.1.1.2.".$key.".1";
    }
    if($function eq 'l3pktrcvd'){
	$oid = "1.3.6.1.4.1.6486.800.1.2.1.55.1.1.3.1.1.3.".$key.".1";
    }
    if($function eq 'l3result'){
	$oid = "1.3.6.1.4.1.6486.800.1.2.1.55.1.1.3.1.1.5.".$key.".1";
    }
    if($function eq 'l3minRTT'){
	$oid = "1.3.6.1.4.1.6486.800.1.2.1.55.1.1.3.1.1.8.".$key.".1";
    }
    if($function eq 'l3avgRTT'){
	$oid = "1.3.6.1.4.1.6486.800.1.2.1.55.1.1.3.1.1.9.".$key.".1";
    }
    if($function eq 'l3maxRTT'){
	$oid = "1.3.6.1.4.1.6486.800.1.2.1.55.1.1.3.1.1.10.".$key.".1";
    }
    if($function eq 'l3minJitter'){
	$oid = "1.3.6.1.4.1.6486.800.1.2.1.55.1.1.3.1.1.11.".$key.".1";
    }
    if($function eq 'l3avgJitter'){
	$oid = "1.3.6.1.4.1.6486.800.1.2.1.55.1.1.3.1.1.12.".$key.".1";
    }
    if($function eq 'l3maxJitter'){
	$oid = "1.3.6.1.4.1.6486.800.1.2.1.55.1.1.3.1.1.13.".$key.".1";
    }
    if($function eq 'l2pktsent'){
	$oid = "1.3.6.1.4.1.6486.800.1.2.1.55.1.1.6.1.1.2.".$key.".1";
    }
    if($function eq 'l2pktrcvd'){
	$oid = "1.3.6.1.4.1.6486.800.1.2.1.55.1.1.6.1.1.3.".$key.".1";
    }
    if($function eq 'l2minRTT'){
	$oid = "1.3.6.1.4.1.6486.800.1.2.1.55.1.1.6.1.1.8.".$key.".1";
    }
    if($function eq 'l2avgRTT'){
	$oid = "1.3.6.1.4.1.6486.800.1.2.1.55.1.1.6.1.1.9.".$key.".1";
    }
    if($function eq 'l2maxRTT'){
	$oid = "1.3.6.1.4.1.6486.800.1.2.1.55.1.1.6.1.1.10.".$key.".1";
    }
    if($function eq 'l2minJitter'){
	$oid = "1.3.6.1.4.1.6486.800.1.2.1.55.1.1.6.1.1.11.".$key.".1";
    }
    if($function eq 'l2avgJitter'){
	$oid = "1.3.6.1.4.1.6486.800.1.2.1.55.1.1.6.1.1.12.".$key.".1";
    }
    if($function eq 'l2maxJitter'){
	$oid = "1.3.6.1.4.1.6486.800.1.2.1.55.1.1.6.1.1.13.".$key.".1";
    }

#    print STDERR "Going to poll $oid for $function\n";
    #do the actual measurement
    if(defined $oid){
#	print "DBG: $oid\n";
	my $isValid=1;
	my $isFailed=0;
	my $failedValue=0;
	my $tooAggressive=0;
	my $timeOID = "";
	my $runResultOID = "";
	if($function=~/^l2/){
	    #we need to check the probe's last run time
	    $timeOID = "1.3.6.1.4.1.6486.800.1.2.1.55.1.1.6.1.1.7.".$key;
	    $runResultOID = "1.3.6.1.4.1.6486.800.1.2.1.55.1.1.6.1.1.5.".$key;
	}
	else{
	    $timeOID = "1.3.6.1.4.1.6486.800.1.2.1.55.1.1.3.1.1.7.".$key;
	    $runResultOID = "1.3.6.1.4.1.6486.800.1.2.1.55.1.1.3.1.1.5.".$key;
	}
#	    print STDERR "Polling OID $timeOID\n";
	    my $runtime = pollOid($timeOID.".1");
	    my $status = pollOid($runResultOID.".1");
	    if($status == 0 || $status == 3){
		print STDERR "probe is unknown/aborted: $status\n";
		$isFailed = 1;
		$failedValue = 0;
	    }
	    if($status == 2){
		print STDERR "probe is failed: $status\n";
		$isFailed = 1;
		# for a failed probe we will assume it is able to send the packets but not receive them
		# return the last reported sent packets count
		if($function=~/pktsent/){
			$isFailed = 0; #we let the probe poll the value
		}
		if($function=~/pktrcvd/){
			$failedValue = 0;
		}
	    }
#	    my $runtime2 = pollOid($timeOID.".2");
	    #runtime looks like 07 E0 0A 1A 0F 00 04 00 -> 2016-10-26,15:00:04.0
	    my $lastTime = decodeTime($runtime);
	    
	    #if the time is older than the current time - 2 minutes, disregard the reading as being too old. Return 0 instead.
	    my $currentTime = time();
#    if(abs($lastTime - $currentTime) > 120){
#	$isValid=0;
#    }
	    print STDERR "probe time $lastTime, currentTime $currentTime, difference is ".(abs($lastTime - $currentTime))."\n";
	    
	    #determine if the probe results are stale. They are stale if the previous two readings are identical to this reading
	    if(-f "$ramdisk/$ip/$oid/old/1" && -f "$ramdisk/$ip/$oid/oldest/1"){
		#we have old data, see if it's stale
		my %values;
		foreach my $time ('old', 'oldest'){
		    open FILE, "$ramdisk/$ip/$oid/$time/1" or die $!;
		    $values{$time} = <FILE>;
		    close FILE;
		}
		
		print STDERR "Runtime =  $runtime [".decodeTime($runtime)."], old =  $values{'old'} [".decodeTime($values{'old'})."], oldest = $values{'oldest'} [".decodeTime($values{'oldest'})."]\n";
		if($runtime eq $values{'old'} && $runtime eq $values{'oldest'}){
		    #if the timestamps for these files are from the same minute as this reading it means cacti is polling this item more often then we expect. Return the correct value
		    my $epoch_timestamp = (stat("$ramdisk/$ip/$oid/old/1"))[9];
		    if(time - $epoch_timestamp < 60){
			print STDERR "Warning: Read is too aggressive!\n";
			$tooAggressive=1;
			$isValid=1;
		    }
		    else{
		    	#old data - discard
		    	print STDERR "Discarding old data - $runtime == $values{'old'} == $values{'oldest'}\n";
		    	$isValid=0;
		    	$tooAggressive=1; #don't move the files around - it's the same timestamp
		    }
		}
		else{
		    $isValid=1;
		}
	    }
	    
	    #directories may not exist yet - create them
	    if(-f "$ramdisk/$ip/$oid/old/1"){
		#target exists?
		if(! -f "$ramdisk/$ip/$oid/oldest/1"){
		    #create target
		    make_path("$ramdisk/$ip/$oid/oldest") or die $!;
		    chmod 0777, "$ramdisk/$ip/$oid/oldest";
		}
		if(!$tooAggressive){
		    #copy the older value
		    copy("$ramdisk/$ip/$oid/old/1", "$ramdisk/$ip/$oid/oldest/1") or die $!;
		    #save the current value
		    open FILE, ">$ramdisk/$ip/$oid/old/1" or die $!;
		    print FILE $runtime;
		    close FILE;
		}
		else{
		    print STDERR "Skipping copying older timestamps\n";
		}
	    }
	    else{
		make_path("$ramdisk/$ip/$oid/old") or die $!;
		chmod 0777, "$ramdisk/$ip/$oid/old";
		open FILE, ">$ramdisk/$ip/$oid/old/1" or die $!;
		print FILE $runtime;
		close FILE;
	    }
	
	if($isValid){
	    if($isFailed){
		print "$failedValue\n";
	    }
	    else{
    	    	print pollOid($oid)."\n";
	    }
    	}
    	else{
    	    print "0\n";
    	}
    }
}


if ( $function eq 'justIndex' ) {
#    print STDERR "Calling getIndex()";
    my %items = getIndex();
    foreach my $key (sort keys %items){
	print "$key\n";
    }
}

#get indexes for the web interface
if ( $function eq 'index' ) {
#    print STDERR "Calling getIndex()";
    my %items = getIndex();
    foreach my $key (sort keys %items){
	print "$key!$items{$key}\n";
    }
}
if ($function eq 'type'){
    my %items = getType();
    foreach my $key (sort keys %items){
	print "$key!$items{$key}\n";
    }
}
if ($function eq 'description'){
    my %items = getDescription();
    foreach my $key (sort keys %items){
	my $descr = "$key!$items{$key}";
	$descr=~s/\r|\n//g;
	$descr=~s/[\x00-\x1F]+//g;
	print "$descr\n";
    }
}
if ($function eq 'srcMep'){
    my %items = getSrcMep();
    foreach my $key (sort keys %items){
	print "$key!$items{$key}\n";
    }
}
if ($function eq 'dstMep'){
    my %items = getDstMep();
    foreach my $key (sort keys %items){
	print "$key!$items{$key}\n";
    }
}

sub getIndex{
    my %items = ();
    my %resultList = generateKeys();
#    foreach my $keys ( keys %resultList ) {
#	#keep the ifindex from the list
#	$keys=~/^([0-9]+)\./;
#	$items{$keys} = $1;
#    }
    return %resultList;
}

sub getType{
    my %indexes = generateKeys();
    my %items = ();
    my %types = ();
    my $l3 = walkOid(".1.3.6.1.4.1.6486.800.1.2.1.55.1.1.1.1.1.5");
    foreach my $device(keys %{$l3}){
	foreach my $oid (keys %{$l3->{$device}}){
	    #print "DBG. $oid\n";
	    $types{$oid} = "L3";
	}
    }
    my $l2 = walkOid(".1.3.6.1.4.1.6486.800.1.2.1.55.1.1.5.1.1.3");
    foreach my $device(keys %{$l2}){
	foreach my $oid (keys %{$l2->{$device}}){
	    #print "DBG: $oid\n";
	    $types{$oid} = "L2";
	}
    }
    
#    print Dumper(\%types);
    foreach my $index ( keys %indexes ) {
	if(defined $types{$index}){
	    $items{$index}=$types{$index};
	}
	else{
	    $items{$index} = "Unknown";
	}
    }
    return %items;

}

sub getDescription{
    my %indexes = generateKeys();
    my %items = ();
    foreach my $index ( keys %indexes ) {
	$items{$index}=$indexes{$index};
	$items{$index}=~s/^USER//;
    }
    return %items;
}

sub getSrcMep{
    my %indexes = generateKeys();
    my %items = ();
    my $mep = walkOid(".1.3.6.1.4.1.6486.800.1.2.1.55.1.1.5.1.1.7");
    my %meps;
    foreach my $device (keys %{$mep}){
	foreach my $oid (keys %{$mep->{$device}}){
	    $meps{$oid} = $mep->{$device}{$oid};
	}
    }
    foreach my $index ( keys %indexes ) {
	if(defined $meps{$index}){
	    $items{$index} = $meps{$index};
	}
	else{
	    $items{$index}="N/A";
	}
    }
    return %items;
}

sub getDstMep{
    my %indexes = generateKeys();
    my %items = ();
    my $mep = walkOid(".1.3.6.1.4.1.6486.800.1.2.1.55.1.1.5.1.1.5");
    my %meps;
    foreach my $device (keys %{$mep}){
	foreach my $oid (keys %{$mep->{$device}}){
	    $meps{$oid} = $mep->{$device}{$oid};
	}
    }
    foreach my $index ( keys %indexes ) {
	if(defined $meps{$index}){
	    $items{$index} = $meps{$index};
	}
	else{
	    $items{$index}="N/A";
	}
    }
    return %items;
}


sub pollOid {
    my @oids = @_;
    my ( $session, $error ) = Net::SNMP->session( -hostname => $ip, -version => $snmpversion, -timeout => 3, -community => $community );
    my $result = undef;
    if ( !defined $session ) {
        print STDERR "SNMP error on $ip: $error";
    }
    else {
        $result = $session->get_request( -varbindlist => \@oids );
    }
    if ( defined $result ) {
        return $result->{ $oids[0] };
    }
    else {
        die "Unable to get a result while getting oid $oids[0]\n";
    }
}

sub walkOid {
    my @oids = @_;
#    my ( $session, $error ) = Net::SNMP->session( -hostname => $ip, -version => $snmpversion, -timeout => 3, -community => $community );
    my ($result, $error) = snmpwalk(hosts => $ip, oids => $oids[0], snmp => { -version => $snmpversion, -community => $community });
#    my $result = undef;
#    if ( !defined $session ) {
#        print STDERR "SNMP error on $ip: $error";
#    }
#    else {
#        #$result = $session->get_table( -baseoid => $oids[0] );
#        $result = $session->get_bulk_request( -varbindlist => $oids[0] );
#    }
    if ( defined $result ) {
#	print Dumper(\$result);
        return $result;
    }
    else {
        die "Unable to get a result while walking oid $oids[0]\n";
    }
}

sub generateKeys {
    my %indexList;
    
    #get a list of indexes
    #for each ifindex, calculate the string equivalent
    my $probes = walkOid('.1.3.6.1.4.1.6486.800.1.2.1.55.1.1.1.1.1.4');
    foreach my $device (keys %{$probes}){
	foreach my $oid (keys %{$probes->{$device}}){
	    #$oid=~/1\.3\.6\.1\.4\.1\.6486\.800\.1\.2\.1\.55\.1\.1\.1\.1\.1\.4\.4\.(.*)/;
	    #$oid looks like 4.85.83.69.82.26.76.51.95.83.65.65.95.66.95.68.82.66.95.79.76.84.95.77.65.53.54.48.48.84.95.49
	    $oid=~/^4\.(.*)/; #cut the leading 4 - it's hardcoded
	    my $probeOID = $1;
	
	    my $string = join("", map(chr, split(/\./,$probeOID)));
	    $indexList{$oid} = $string;
	}
    }
    

#    print Dumper(\%indexList);
    return %indexList;
}

sub decodeTime{
    my $time = shift;
    my $readableTime = 0;
#    print STDERR "time: $time\n";
    if($time=~/0x([0-9A-Fa-f]{4})([0-9A-Fa-f]{2})([0-9A-Fa-f]{2})([0-9A-Fa-f]{2})([0-9A-Fa-f]{2})([0-9A-Fa-f]{2})([0-9A-Fa-f]{2})/){
	my $year = hex($1);
	my $month= hex($2);
	my $day  = hex($3);
	my $hour = hex($4);
	my $minute = hex($5);
	my $second = hex($6);
	
#	print STDERR "$year-$month-$day $hour:$minute:$second\n";
	$readableTime = mktime($second, $minute, $hour, $day, ($month-1), ($year-1900));
	
    }
    return $readableTime;

}
