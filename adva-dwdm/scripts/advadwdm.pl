#!/usr/bin/perl 
use strict;
use warnings;
use Net::SNMP;
use Data::Dumper;

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

my %cardType = (
    'OLDRAM 1510' => { 'oprosc' => '1.3.6.1.4.1.6908.1.7.4.10.1.7',
		       'ratio' =>  10 },
    'VG3520 1510' => { 'oprosc' => '1.3.6.1.4.1.6908.1.7.4.11.1.17',
			'ratio' => 100 },
    'OLDUEV20 1310' => { 'oprosc' => '1.3.6.1.4.1.6908.1.7.4.8.1.14',
			'ratio' => 10 },
    'OLDLEV13 1310' => { 'oprosc' => '1.3.6.1.4.1.6908.1.7.4.8.1.14',
			'ratio' => 10 },
    'OLDUEV 1310' => { 'oprosc' => '1.3.6.1.4.1.6908.1.7.4.8.1.14',
			'ratio' => 10 },
);


if( $get eq 'get'){
    #actual polling
    my $oid = undef;
    my $rackShelfSlotPort = "";
    $key=~/^[0-9]+\.(.*)$/;
    $rackShelfSlotPort = $1;
    $rackShelfSlotPort=~/[0-9]+\.([0-9]+\.[0-9]+)\.[0-9]+/;
    my $shelfSlot = $1;
    my $card;
    
    if($function eq 'oprosc'){
	#need to get card type
	$card = pollOid("1.3.6.1.4.1.6908.1.4.4.1.25.".$shelfSlot.".0");
	#lookup card type in static hash
#	warn("Found card: $card for shelfslot $shelfSlot\n");
	my $baseOPROSCOID = $cardType{$card}{'oprosc'};
#	warn("Using baseOID: $baseOPROSCOID\n");
	#build oid
	$oid = $baseOPROSCOID.".".$rackShelfSlotPort;
	
    }
    if($function eq 'opr'){
	$oid = "1.3.6.1.4.1.6908.1.7.5.11.1.5.$rackShelfSlotPort.1";
    }
    if($function eq 'opt'){
	$oid = "1.3.6.1.4.1.6908.1.7.5.11.1.2.$rackShelfSlotPort.1";
    }
    if($function eq 'section_es'){
	$oid = "1.3.6.1.4.1.6908.1.7.8.1.1.2.$rackShelfSlotPort.1";
    }
    if($function eq 'section_ses'){
	$oid = "1.3.6.1.4.1.6908.1.7.8.1.1.4.$rackShelfSlotPort.1";
    }
    if($function eq 'section_sefs'){
	$oid = "1.3.6.1.4.1.6908.1.7.8.1.1.6.$rackShelfSlotPort.1";
    }
    if($function eq 'section_cv'){
	$oid = "1.3.6.1.4.1.6908.1.7.8.1.1.8.$rackShelfSlotPort.1";
    }
    if($function eq 'path_es'){
	$oid = "1.3.6.1.4.1.6908.1.7.8.7.1.2.$rackShelfSlotPort.1";
    }
    if($function eq 'path_ses'){
	$oid = "1.3.6.1.4.1.6908.1.7.8.7.1.4.$rackShelfSlotPort.1";
    }
    if($function eq 'path_cv'){
	$oid = "1.3.6.1.4.1.6908.1.7.8.7.1.6.$rackShelfSlotPort.1";
    }
    if($function eq 'path_uas'){
	$oid = "1.3.6.1.4.1.6908.1.7.8.7.1.8.$rackShelfSlotPort.1";
    }
    if($function eq 'path_fc'){
	$oid = "1.3.6.1.4.1.6908.1.7.8.7.1.10.$rackShelfSlotPort.1";
    }
    if($function eq 'fec_corrected_bits'){
	$oid = "1.3.6.1.4.1.6908.1.7.8.23.1.2.$rackShelfSlotPort";
    }
    if($function eq 'fec_corrected_ones'){
	$oid = "1.3.6.1.4.1.6908.1.7.8.23.1.6.$rackShelfSlotPort";
    }
    if($function eq 'fec_corrected_zeros'){
	$oid = "1.3.6.1.4.1.6908.1.7.8.23.1.8.$rackShelfSlotPort";
    }
    if($function eq 'fec_uncorrected_bytes'){
	$oid = "1.3.6.1.4.1.6908.1.7.8.23.1.4.$rackShelfSlotPort";
    }

    
    
    
#    print STDERR "Going to poll $oid for $function\n";
    #do the actual measurement
    if(defined $oid){
	if($function eq 'oprosc'){
	    #get the value, and if lower than -4000, normalize to -4000. Also, divide by the factor
	    my $value = pollOid($oid);
	    $value = -4000 if($value < -4000);
	    $value = $value/$cardType{$card}{'ratio'};
	    print $value."\n";
	}
	else{
		print pollOid($oid)."\n";
	}
    }
}


if ( $function eq 'justIndex' ) {
    my %items = getIfIndex();
    foreach my $key (sort keys %items){
	print "$key\n";
    }
}

#get indexes for the web interface
if ( $function eq 'ifIndex' ) {
    my %items = getIfIndex();
    foreach my $key (sort keys %items){
	print "$key!$items{$key}\n";
    }
}
#calculate the rack based on the assumption: 1st 5 slots are on rack 1, then each rack has maximum 6 slots
if ($function eq 'ifRack'){
    my %items = getRack();
    foreach my $key (sort keys %items){
	print "$key!$items{$key}\n";
    }
}
if ($function eq 'ifShelf'){
    my %items = getShelf();
    foreach my $key (sort keys %items){
	print "$key!$items{$key}\n";
    }
}
if ($function eq 'ifSlot'){
    my %items = getSlot();
    foreach my $key (sort keys %items){
	print "$key!$items{$key}\n";
    }
}
if ($function eq 'ifPort'){
    my %items = getPort();
    foreach my $key (sort keys %items){
	print "$key!$items{$key}\n";
    }
}
if ($function eq 'ifOperStatus'){
    #actually reads the mosIFPrimaryState OID, not mosIFOperStatus
    my %values = (
	'1' => 'inService',
	'2' => 'outOfService',
    );
    
    my %resultList = generateKeys();
    my $operStatus = walkOid("1.3.6.1.4.1.6908.1.6.1.1.5");
    foreach my $oid (keys %{$operStatus}){
	$oid=~/\.([0-9]+)$/;
	my $ifindex = $1;
	foreach my $key (keys %resultList){
	    $key=~/^([0-9]+)\./;
	    my $keyIfIndex = $1;
	    if($keyIfIndex eq $ifindex){
		
		print "$key!".$values{$operStatus->{$oid}}."\n";
	    }
	}
    }
}
if ($function eq 'ifType'){
    my %values = (
    '-1' => 'unknown',
    '33' => 'rs232', 
    '56' => 'fibreChannel', 
    '62' => 'fastEther', 
    '73' => 'escon', 
    '117' => 'gigabitEthernet', 
    '200' => 'oc3', 
    '201' => 'oc12', 
    '202' => 'oc48', 
    '203' => 'dataLambda', 
    '204' => 'oscPhy', 
    '205' => 'osc', 
    '206' => 'fibre', 
    '207' => 'transparent2R', 
    '208' => 'transparent3R25G', 
    '209' => 'fibreConnector',
    '210' => 'sap',
    '211' => 'excp',
    '212' => 'oc3c',
    '213' => 'oc12c',
    '214' => 'oc48c',
    '215' => 'stm1',
    '216' => 'stm1c',
    '217' => 'stm4',
    '218' => 'stm4c',
    '219' => 'stm16',
    '220' => 'stm16c',
    '221' => 'oc192', 
    '222' => 'oc192c', 
    '223' => 'bitsA',
    '224' => 'bitsB',
    '225' => 'oscTiming',
    '226' => 'internalTiming',
    '227' => 'stm64',
    '228' => 'stm64c',
    '229' => 'edfa',
    '230' => 'voa',
    '231' => 'transparent3R10G',
    '232' => 'opm',
    '233' => 'wxcFiber',
    '234' => 'ds0',
    '235' => 'ds1',
    '236' => 'e1',
    '237' => 'ds2',
    '238' => 'e2',
    '239' => 'e3',
    '240' => 'ds3',
    '241' => 'sts1',
    '242' => 'fastEthernet',
    '243' => 'e4',
    '244' => 'tenGigabitEthernetLan',
    '245' => 'oc768',
    '246' => 'stm256',
    '247' => 'tenGigabitEthernetWan',
    '248' => 'opsLine',
    '249' => 'opsLocal',
    '250' => 'raman',
    '251' => 'transparent',
    '252' => 'shelfOsc',
    '253' => 'ficon',
    '254' => 'fibreChannelX2',
    '255' => 'ficonExpress',
    '256' => 'vga',
    '257' => 'otu1',
    '258' => 'otu2',
    '259' => 'xpmLine',
    '260' => 'xpmTrib',
    '261' => 'fibreOA',
    '262' => 'fibrePassThru',
    '263' => 'fibreAdd',
    '264' => 'fibreStandard',
    '265' => 'fibreOffset',  
    );
    
    my %resultList = generateKeys();
    my $type = walkOid("1.3.6.1.4.1.6908.1.6.1.1.4");
    foreach my $oid (keys %{$type}){
	$oid=~/\.([0-9]+)$/;
	my $ifindex = $1;
	foreach my $key (keys %resultList){
	    $key=~/^([0-9]+)\./;
	    my $keyIfIndex = $1;
	    if($keyIfIndex eq $ifindex){
		
		print "$key!".$values{$type->{$oid}}."\n";
	    }
	}
    }
}
if ($function eq 'ifUserLabel'){
    
    my %resultList = generateKeys();
    my $label = walkOid("1.3.6.1.4.1.6908.1.6.1.1.11");
    foreach my $oid (keys %{$label}){
	$oid=~/\.([0-9]+)$/;
	my $ifindex = $1;
	foreach my $key (keys %resultList){
	    $key=~/^([0-9]+)\./;
	    my $keyIfIndex = $1;
	    if($keyIfIndex eq $ifindex){
		
		print "$key!".$label->{$oid}."\n";
	    }
	}
    }
}

sub getIfIndex{
    my %items = ();
    my %resultList = generateKeys();
    foreach my $keys ( keys %resultList ) {
	#keep the ifindex from the list
	$keys=~/^([0-9]+)\./;
	$items{$keys} = $1;
    }
    return %items;
}

sub getRack{
    my %indexes = generateKeys();
    my %items = ();
    foreach my $index ( keys %indexes ) {
	$index=~/^[0-9]+\.([0-9]+)\./;
	$items{$index}=$1;
    }
    return %items;

}

sub getShelf{
    my %indexes = generateKeys();
    my %items = ();
    foreach my $index ( keys %indexes ) {
	$index=~/^[0-9]+\.[0-9]+\.([0-9]+)\./;
	my $shelf = $1;
	#calculate the pretty version of the shelf
	my ($rack, $shelf, $originalShelf) = calculateRackAndShelf($shelf);
	$items{$index}=$shelf;
    }
    return %items;
}

sub getSlot{
    my %indexes = generateKeys();
    my %items = ();
    foreach my $index ( keys %indexes ) {
	$index=~/^[0-9]+\.[0-9]+\.[0-9]+\.([0-9]+)\./;
	$items{$index}=$1;
    }
    return %items;
}

sub getPort{
    my %indexes = generateKeys();
    my %items = ();
    foreach my $index ( keys %indexes ) {
	$index=~/^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+\.([0-9]+)$/;
	$items{$index}=$1;
    }
    return %items;
}

# original method, not correct
#sub calculateRackAndShelf{
#    my $shelf = shift;
#    my $originalShelf = $shelf;
#    my $rack = 1;
#    while($shelf > 6){
#        if($rack == 1){
#    	    $shelf -= 5; #rack 1 has only 5 shelves
#
#	}
#	else{
#	    $shelf -= 6; #other racks have 6 shelves
#	}
#	$rack++;
#    }
#    #in case shelf <=6, check to see the rack (it would skip the while)
#    if($rack == 1 && $shelf == 6){
#        $shelf -= 5;
#        $rack++;
#    }
#    return ($rack, $shelf, $originalShelf);
#}


sub calculateRackAndShelf{
    my $shelf = shift;
    my $originalShelf = $shelf;
    my $rack = 0;
    
    my $rackAndShelf = walkOid('1.3.6.1.4.1.6908.1.4.28.1.4');
    if(defined $rackAndShelf){
	foreach my $oid (keys %{$rackAndShelf}){
	    if($rackAndShelf->{$oid} eq $shelf){
		$oid=~/\.([0-9]+)\.([0-9]+)$/;
		$rack = $1;
		$shelf = $2;
		last;
	    }
	}
    }
    return ($rack, $shelf, $originalShelf);
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
    my ( $session, $error ) = Net::SNMP->session( -hostname => $ip, -version => $snmpversion, -timeout => 3, -community => $community );
    my $result = undef;
    if ( !defined $session ) {
        print STDERR "SNMP error on $ip: $error";
    }
    else {
        $result = $session->get_table( -baseoid => $oids[0] );
    }
    if ( defined $result ) {
        return $result;
    }
    else {
        die "Unable to get a result while walking oid $oids[0]\n";
    }
}

sub generateKeys {
    my %ifIndexList;
    my %resultList;
    
    #get a list of ifindexes
    #for each ifindex, calculate rack and get shelf/slot/port
    my $shelves = walkOid('1.3.6.1.4.1.6908.1.6.1.1.1'); #shelves
    foreach my $oid (keys %{$shelves}){
	$oid=~/\.([0-9]+)$/;
	my $ifindex = $1;
	#calculate rack based on shelf
	my $rack = 1;
	my $shelf = $shelves->{$oid};
	my $originalShelf;
	($rack, $shelf, $originalShelf) = calculateRackAndShelf($shelf);
	
	$ifIndexList{$ifindex}{'shelf'}=$originalShelf;
	$ifIndexList{$ifindex}{'rack'} = $rack;
    }
    
    #get a list of slots
    my $slots = walkOid('1.3.6.1.4.1.6908.1.6.1.1.2');
    foreach my $oid (keys %{$slots}){
	$oid =~/\.([0-9]+)$/;
	$ifIndexList{$1}{'slot'}=$slots->{$oid};
    }
    
    #get a list of ports
    my $ports = walkOid('1.3.6.1.4.1.6908.1.6.1.1.16');
    foreach my $oid (keys %{$ports}){
	$oid =~/\.([0-9]+)$/;
	$ifIndexList{$1}{'port'}=$ports->{$oid};
    }
    
#    print Dumper(\%ifIndexList);
    foreach my $ifindex (sort keys %ifIndexList){
	$resultList{$ifindex.".".$ifIndexList{$ifindex}{'rack'}.".".$ifIndexList{$ifindex}{'shelf'}.".".$ifIndexList{$ifindex}{'slot'}.".".$ifIndexList{$ifindex}{'port'}} = $ifIndexList{$ifindex}{'rack'}.".".$ifIndexList{$ifindex}{'shelf'}.".".$ifIndexList{$ifindex}{'slot'}.".".$ifIndexList{$ifindex}{'port'};
    }

    #return data in the format ifindex.rack.shelf.slot.port as an index
    return %resultList;
}