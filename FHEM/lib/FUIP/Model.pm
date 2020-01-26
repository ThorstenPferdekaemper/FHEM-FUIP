package FUIP::Model;

use strict;
use warnings;

#use JSON::Parse 'parse_json';
use JSON 'from_json';

my %buffer;
# FUIP-name => {rooms => [<room>],
#				fhemwebUrl => <fhembwebUrl>,
#				devices => {<device-name> => { Attributes => { <attr-name> => <attr-value> },
#											   Readings => { <readings-name> => <readings-value> },
#                                              Internals => { <name> => <value> } } },
#				room-device => {<room> => [<device-name>]} }


sub refresh($) {
	my ($name) = @_;
	delete $buffer{$name};
};


sub getFhemwebUrl($) {
	my ($name) = @_;
	$buffer{$name}{fhemwebUrl} = main::AttrVal($name,"fhemwebUrl",0) 
									unless defined($buffer{$name}{fhemwebUrl});
	return $buffer{$name}{fhemwebUrl};
};


sub _getCsrfToken($)
{
	my ($url) = @_;
	my $hash = { 
			hideurl   => 0,
			url       => $url,
            timeout   => undef,
            data      => undef,
            noshutdown=> undef,
            loglevel  => 4,
        };
	my ($err, $ret) = main::HttpUtils_BlockingGet($hash);
	return "err" if $err;
	return "err" unless defined($hash->{httpheader});
	$hash->{httpheader} =~ /X-FHEM-csrfToken:[\x20 ](\S*)/;
	return "" unless $1;
	return $1;	
}


sub _sendRemoteCommand($$$) {
	my ($name,$url,$cmd) = @_;
	# get csrf token unless buffered
	if(not defined $buffer{$name}{csrfToken}) {
		$buffer{$name}{csrfToken} = _getCsrfToken($url);
		main::Log3('FUIP:'.$name, 3, "Determined new csrfToken: ".$buffer{$name}{csrfToken});
	};	
	my $fullurl = $url.'?cmd='.main::urlEncode($cmd).'&XHR=1&fwcsrf='.$buffer{$name}{csrfToken};
	
	my $hash = { hideurl   => 0,
               url       => $fullurl,
               timeout   => undef,
               data      => undef,
               noshutdown=> undef,
               loglevel  => 4,
             };
	my ($err, $ret) = main::HttpUtils_BlockingGet($hash);
	if($err) {
		main::Log3("FUIP:".$name, 3, "Access remote system: $err");
		return undef;
	}
	# do we have an issue with the csrf token?
	if($hash->{code} == 400) {
		# no header -> sth else
		# TODO: really proper error management
		return undef unless defined($hash->{httpheader});	
		$hash->{httpheader} =~ /X-FHEM-csrfToken:[\x20 ](\S*)/;
		return undef unless $1;
		return undef if($1 eq $buffer{$name}{csrfToken});
		# ok, we have a different token
		$buffer{$name}{csrfToken} = $1;  # set new token
		main::Log3('FUIP:'.$name, 3, "Determined new csrfToken: ".$buffer{$name}{csrfToken});
		# retry, but only once
		$fullurl = $url.'?cmd='.main::urlEncode($cmd).'&XHR=1&fwcsrf='.$buffer{$name}{csrfToken};
		$hash = { hideurl   => 0,
               url       => $url.'?cmd='.main::urlEncode($cmd).'&XHR=1&fwcsrf='.$buffer{$name}{csrfToken},
               timeout   => undef,
               data      => undef,
               noshutdown=> undef,
               loglevel  => 4,
              };
		($err, $ret) = main::HttpUtils_BlockingGet($hash);
		if($err) {
			main::Log3("FUIP:".$name, 3, "Access remote system: $err");
			return undef;
		}
	};  
	return $ret;
};


sub callCoding($$;$) {
	my ($fuipName, $codingLines, $forceLocal) = @_;
	# $fuipName: Name of the FUIP instance, usually something like "ui"
	# $codingLines: Coding as an array of lines without ";" (or ";;")
	# it is expected that the coding returns something which works with Dumper
	my $url = $forceLocal ? undef : getFhemwebUrl($fuipName);
	my $result;
	if($url) {
		# make an anonymous sub, call it and return something eval'uable
		my $coding = '{ my $func = sub { '
					.join(";;",@$codingLines)
					.' };;
					return Dumper(&$func());; }';
		my $resultStr = _sendRemoteCommand($fuipName,$url,$coding);
		# older versions of Dumper start with "$VAR..."
		if($resultStr =~ m/^\$/) {
			$resultStr = substr($resultStr,8);
		};	
		$result = eval($resultStr);
		if($@) {
			main::Log3(undef,1,"FUIP::Model::callCoding: ".$@);
			main::Log3(undef,1,"FUIP::Model::callCoding: ".$resultStr);
		};
	}else{
		my $coding = join(";",@$codingLines);
		$result = eval($coding);
		if($@) {
			main::Log3(undef,1,"FUIP::Model::callCoding: ".$@);
		};
	}
	return $result;
};
	

sub getDeviceKeys($) {
# get the names of all devices
	my ($name) = @_;
	# buffered?
	return $buffer{$name}{devicekeys} if(defined($buffer{$name}{devicekeys}));
	# not buffered, determine
	
	my $coding = [
		'my @devices = (keys %main::defs)',
		'return \@devices'
	];
	my $devices = callCoding($name,$coding);	
	$buffer{$name}{devicekeys} = $devices;
	return $devices;
};	


sub getRooms($) {
# get all rooms
	my ($name) = @_;
	# buffered?
	return @{$buffer{$name}{rooms}} if(exists($buffer{$name}{rooms}));
	# not buffered, determine rooms

	# we do not return the room "hidden" or "Unsorted"
	# the following also ignores the "empty string" room
	# TODO: Rooms to be ignored should be configurable	
	my $coding = [
		'my %rooms',
		'foreach my $d (keys %main::defs ) {',
		'	foreach my $r (split(",", main::AttrVal($d, "room", "hidden"))) {',
		'		next if $r =~ /^(hidden|CUL_HM|HM485|)$/',
		'		$rooms{$r} = 1',
		'	}',
		'}',
		'my @rooms = keys(%rooms)',
		'return \@rooms'
	];
	my $unsortedRooms = callCoding($name,$coding);
	my @rooms = sort(@$unsortedRooms);
	$buffer{$name}{rooms} = \@rooms;
	return @rooms;
};
	
	
sub getReadingsOfDevice($$) {
# get all readings of one or multiple device(s) (only the reading names, without values)
	my ($name,$deviceStr) = @_;
	my @devices = split /,/ , $deviceStr;
	my %resultHash;
	for my $device (@devices) {
		my $coding = [
			'return [] unless defined $main::defs{"'.$device.'"}',
			'my @result = (keys(%{$main::defs{"'.$device.'"}{READINGS}}))',
			'return \@result'
		];
		my $readings = callCoding($name,$coding);
		for my $reading (@$readings) {
			$resultHash{$reading} = 1;
		};	
	};
	my @result = sort keys %resultHash;
	return \@result;
};		
	
	
sub getDevicesForRoom($$) {
# get all devices for a room
	my ($name,$room) = @_;
	# buffered?
	return $buffer{$name}{"room-device"}{$room} if(defined($buffer{$name}{"room-device"}{$room}));
	# not buffered, determine
	
	my $coding = [
		'my @devices',
		'foreach my $d (keys %main::attr ) {',
		'	next unless grep {$_ eq "'.$room.'"} split(",", main::AttrVal($d, "room", "Unsorted"))',
		'	push(@devices,$d)',
		'}',
		'return \@devices'	
	];
	my $devices = callCoding($name,$coding);
	@$devices = sort(@$devices);
	$buffer{$name}{"room-device"}{$room} = $devices;
	return $devices;
};	
	
	
sub getDevice($$$) {
# get certain attributes, readings, internals for a device
	my ($name,$devName,$fields) = @_;
	# do we have the device 
	my $device = $buffer{$name}{devices}{$devName};
	if(not defined($device)) {
		$buffer{$name}{devices}{$devName} = {Attributes => {}, Readings => {}, Internals => {}, undefs => []};
		$device = $buffer{$name}{devices}{$devName};
	};
	# which fields are missing?
	my %fieldHash;
	@fieldHash{@$fields} = undef;
	delete(@fieldHash{keys %{$device->{Attributes}}});
	delete(@fieldHash{keys %{$device->{Readings}}});
	delete(@fieldHash{keys %{$device->{Internals}}});
	delete(@fieldHash{@{$device->{undefs}}});    # non-existing to avoid asking again
	# anything left?
	if(%fieldHash or not @$fields) {
		my $url = getFhemwebUrl($name);
		my $cmd = 'jsonlist2 '.$devName.' '.join(' ',keys %fieldHash);
		my $jsonResult;
		if($url) {
			$jsonResult = _sendRemoteCommand($name,$url,$cmd);
		}else{
			$jsonResult = main::fhem($cmd,1);
		};
		# the json "object" is always a proper object, but nevertheless some Perl JSON 
		# implementations throw an error sometimes without allow_nonref
		my $newDev = from_json($jsonResult, {allow_nonref => 1});
		main::Log3('FUIP:'.$name, 3, "getDevice: NULL") unless $newDev;
		for my $entry (@{$newDev->{Results}}) {
			next unless $entry->{Name} eq $devName;
			for my $key (keys %{$entry->{Internals}}) {
				$device->{Internals}{$key} = $entry->{Internals}{$key};
			};
			for my $key (keys %{$entry->{Attributes}}) {
				$device->{Attributes}{$key} = $entry->{Attributes}{$key};
			};
			for my $key (keys %{$entry->{Readings}}) {
				$device->{Readings}{$key} = $entry->{Readings}{$key}{Value};
			};
		};
		# check for missing ones
		@fieldHash{@$fields} = undef;
		delete(@fieldHash{keys %{$device->{Attributes}}});
		delete(@fieldHash{keys %{$device->{Readings}}});
		delete(@fieldHash{keys %{$device->{Internals}}});
		my @missing = keys %fieldHash;
		push @{$device->{undefs}}, @missing;
	};
    # always return the whole thing
	return $device;
};	
	

# get all sets incl. options for device	
# (same as in FHEMWEB)
sub getSetsOfDevice($$) {
	my ($fuipName, $devName) = @_;
	# buffered?
	return $buffer{$fuipName}{devicesets}{$devName} if(defined($buffer{$fuipName}{devicesets}{$devName}));
	# not buffered, determine
	my $coding = [ 'return main::getAllSets("'.$devName.'")' ];
	my $resultStr = callCoding($fuipName,$coding);
	# split into sets
	my %result;
	for my $setStr (split(" ",$resultStr)) {
		my ($set,$optStr) = split(":",$setStr,2);
		my @options = split(",",$optStr);
		$result{$set} = \@options;
	};
	$buffer{$fuipName}{devicesets}{$devName} = \%result;
	return \%result;
};	
	
	
sub getDevicesForReading($$) {
# get all devices which have a certain reading
	my ($name,$reading) = @_;
	# buffered?
	return $buffer{$name}{"reading-device"}{$reading} if(defined($buffer{$name}{"reading-device"}{$reading}));
	# not buffered, determine
	my $coding = [ 
		'my @devices = grep { defined $main::defs{$_}{READINGS}{"'.$reading.'"} } keys %main::defs',
		'return \@devices'
	];
	my $devices = callCoding($name,$coding);	
	@$devices = sort(@$devices);
	$buffer{$name}{"reading-device"}{$reading} = $devices;
	return $devices;
};	
	

sub getGplot($$) {
	my ($name,$device) = @_;
	my $coding = [	
		'my $filename = $main::defs{"'.$device.'"}{GPLOTFILE}', 
		'return undef unless $filename',
		'$filename = $main::FW_gplotdir."/".$filename.".gplot"',  
		'my ($err, $cfg, $plot, $srcDesc) = main::SVG_readgplotfile("'.$device.'",$filename,"SVG")', 
		'my %conf = main::SVG_digestConf($cfg,$plot)',  
		'return { srcDesc => $srcDesc, conf => \%conf }'
	];
	return callCoding($name,$coding);
};	
	
	
sub readTextFile($$;$) {
	my ($name,$filename,$forceLocal) = @_;
	my $coding = [
		'open(FILE, $main::attr{global}{modpath}."/'.$filename.'") or return []',
		'my @result = <FILE>',
		'close(FILE)',
		'return \@result'
	];
	my $result = callCoding($name,$coding,$forceLocal);
	return join("",@$result);
};	


sub getStylesheetPrefix($) {
	my ($name) = @_;
	my $coding = [
		'return "" unless $main::FW_wname',
		'return main::AttrVal($main::FW_wname,"stylesheetPrefix", "")'
	];
	my $stylesheetPrefix = callCoding($name,$coding);
	$stylesheetPrefix = "" if $stylesheetPrefix eq "default";
	return $stylesheetPrefix;
};


sub getDevicesForType($$) {
	# Return devices with TYPE SVG
	my ($fuipName,$type) = @_;
	my $coding = [
		'my @result',
		'for my $dev (keys %main::defs) {',
		'	my $device = $main::defs{$dev}',
		'	push(@result,$dev) if($device->{TYPE} eq "'.$type.'")',
		'}',
		'return \@result'
	];
	return FUIP::Model::callCoding($fuipName,$coding);	
}	
	
1;