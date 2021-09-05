package FUIP::Model;

use strict;
use warnings;

#use JSON::Parse 'parse_json';
use JSON 'from_json';

use lib::FUIP::Exception;
use lib::FUIP::Systems;

my %buffer;
# FUIP-name => url => 
#    {rooms => [<room>],
#	  devices => {<device-name> => { Attributes => { <attr-name> => <attr-value> },
#		  						     Readings => { <readings-name> => <readings-value> },
#                                    Internals => { <name> => <value> } } },
#	  room-device => {<room> => [<device-name>]} }


sub refresh($) {
	my ($name) = @_;
	delete $buffer{$name};
};


sub _getCsrfToken($$)
{
	my ($url,$sysid) = @_;
	my $hash = { 
			hideurl   => 0,
			url       => $url,
            timeout   => undef,
            data      => undef,
            noshutdown=> undef,
            loglevel  => 4,
        };
	my ($err, $ret) = main::HttpUtils_BlockingGet($hash);
	#System reached?
	if($err) {
		#Remove the URL from the error message, as it is usually too long
		$err =~ s{\Q$url\E}{}g;
		#Remove leading ":" and spaces
		$err =~ s{^[\s:]*}{};
		FUIP::Exception::raise(["Failed to determine csrf token for $sysid", $err, "URL: $url"]);
	};
	#Do we have an http header?
	unless(defined($hash->{httpheader})){
		FUIP::Exception::raise(["Failed to determine csrf token for $sysid", "No HTTP header received", "URL: $url"]);	
	};
	if($hash->{httpheader} =~ /X-FHEM-csrfToken:[\x20 ](\S*)/) {
		return "" unless defined $1;
		return $1;
	};	
	#If the csrf token is switched off, then it is ok that we do not have it
	return "";
};


sub _sendRemoteCommand($$$$) {
	my ($name,$sysid,$url,$cmd) = @_;
	
	# do we have a URL?
	FUIP::Exception::raise('Cannot send a remote command without a URL') unless $url;
	
	# get csrf token unless buffered
	if(not defined $buffer{$name}{$sysid}{csrfToken}) {
		$buffer{$name}{$sysid}{csrfToken} = _getCsrfToken($url,$sysid);
		main::Log3('FUIP:'.$name, 3, "Determined csrfToken for $sysid: $buffer{$name}{$sysid}{csrfToken}");
	};	
	my ($hash,$ret) = _doBlockingGet($url,$cmd,$name,$sysid);
	#Do we have an issue with the csrf token?
	#We might be able to fix this automatically
	if($hash->{code} == 400 and defined($hash->{httpheader}) and $hash->{httpheader} =~ /X-FHEM-csrfToken:[\x20 ](\S*)/) {
		my $csrfToken = defined($1) ? $1 : "";
		if($csrfToken ne $buffer{$name}{$sysid}{csrfToken}) {
			# ok, we have a different token
			$buffer{$name}{$sysid}{csrfToken} = $csrfToken;  # set new token
			main::Log3('FUIP:'.$name, 3, "CsrfToken changed for $sysid: $buffer{$name}{$sysid}{csrfToken}");
			# retry, but only once
			($hash,$ret) = _doBlockingGet($url,$cmd,$name,$sysid);
		}
	};
	#Could not fix csrf token or some other issue
	#FHEMWEB should always answer with 200 in case of success
	unless(defined($hash->{code}) and $hash->{code} == 200) {
		my $header; 
		if(defined($hash->{httpheader})) {
		    my @headers = split("\r\n",$hash->{httpheader});
			$header = $headers[0];
		}else{
			$header = "No HTTP header received";
		};
		FUIP::Exception::raise(["Sending command to $sysid failed", $header, "URL: $url", 
		                        "Csrf token: $buffer{$name}{$sysid}{csrfToken}", "Command: $cmd"]);			
	};
		
	return $ret;
};


sub _doBlockingGet($$$) {
	my ($url,$cmd,$name,$sysid) = @_;

	my $fullurl = $url.'?cmd='.main::urlEncode($cmd).'&XHR=1&fwcsrf='.$buffer{$name}{$sysid}{csrfToken};
	my $hash = { hideurl   => 0,
                 url       => $fullurl,
                 timeout   => undef,
                 data      => undef,
                 noshutdown=> undef,
                 loglevel  => 4,
               };
	my ($err, $ret) = main::HttpUtils_BlockingGet($hash);
	if($err) {
		#Remove the URL from the error message, as it is usually too long
		$err =~ s{\Q$fullurl\E}{}g;
		#Remove leading ":" and spaces
		$err =~ s{^[\s:]*}{};
		#Raise exception including URL, csrf token and command in clear text 
	    FUIP::Exception::raise(["Cannot access remote system $sysid", $err, "URL: $url", 
		                        "Csrf token: $buffer{$name}{$sysid}{csrfToken}", "Command: $cmd"]);
	};	
	return ($hash,$ret);
};


sub _getUrl($$) {
	my ($fuipName,$sysid) = @_;
	# Since "multifhem", the system id needs to be given explicitely
	# "local" means to use the FHEM where FUIP is running on
	my $hash = $main::defs{$fuipName};
	my $url = FUIP::Systems::getSystemUrl($hash,$sysid);
	unless($url){
		$sysid = '<undef>' unless defined $sysid;
		FUIP::Exception::raise('Could not determine URL for system id '.$sysid);
	};	
	return $url;
};


sub callCoding($$$) {
	my ($fuipName, $codingLines, $sysid) = @_;
	# $fuipName: Name of the FUIP instance, usually something like "ui"
	# $codingLines: Coding as an array of lines without ";" (or ";;")
	# it is expected that the coding returns something which works with Dumper
	
	my $url = _getUrl($fuipName,$sysid);
	# if there is no URL, we should already have a message in the log
	# i.e. just return
    return undef unless $url;	
	
	my $result;
	if($url eq 'local') {
		# We are using the FHEM instance this FUIP is running on
		my $coding = join(";",@$codingLines);
		$result = eval($coding);
		if($@) {
			main::Log3(undef,1,"FUIP::Model::callCoding: ".$@);
		};
	}else{
		# make an anonymous sub, call it and return something eval'uable
		my $coding = '{ my $func = sub { '
					.join(";;",@$codingLines)
					.' };;
					use Data::Dumper;;
					return Dumper(&$func());; }';
		my $resultStr = _sendRemoteCommand($fuipName,$sysid,$url,$coding);
		# older versions of Dumper start with "$VAR..."
		if($resultStr =~ m/^\$/) {
			$resultStr = substr($resultStr,8);
		};	
		$result = eval($resultStr);
		if($@) {
			main::Log3(undef,1,"FUIP::Model::callCoding: ".$@);
			main::Log3(undef,1,"FUIP::Model::callCoding: ".$resultStr);
		};
	}
	return $result;
};
	

sub getDeviceKeys($$) {
# get the names of all devices
	my ($name,$sysid) = @_;
	# buffered?
	return $buffer{$name}{$sysid}{devicekeys} if(defined($buffer{$name}{$sysid}{devicekeys}));
	# not buffered, determine
	
	my $coding = [
		'my @devices = (keys %main::defs)',
		'return \@devices'
	];
	my $devices = callCoding($name,$coding,$sysid);	
	$buffer{$name}{$sysid}{devicekeys} = $devices;
	return $devices;
};	


sub getRooms($$) {
# get all rooms
	my ($name,$sysid) = @_;
	# buffered?
	return @{$buffer{$name}{$sysid}{rooms}} if(exists($buffer{$name}{$sysid}{rooms}));
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
	my $unsortedRooms = callCoding($name,$coding,$sysid);
	# in case of connection issues, this returns as an undefined reference
	$unsortedRooms = [] unless defined $unsortedRooms;
	my @rooms = sort(@$unsortedRooms);
	$buffer{$name}{$sysid}{rooms} = \@rooms;
	return @rooms;
};
	
	
sub getReadingsOfDevice($$$) {
# get all readings of one or multiple device(s) (only the reading names, without values)
	my ($name,$deviceStr,$sysid) = @_;
	my @devices = split /,/ , $deviceStr;
	my %resultHash;
	for my $device (@devices) {
		my $coding = [
			'return [] unless defined $main::defs{"'.$device.'"}',
			'my @result = (keys(%{$main::defs{"'.$device.'"}{READINGS}}))',
			'return \@result'
		];
		my $readings = callCoding($name,$coding,$sysid);
		for my $reading (@$readings) {
			$resultHash{$reading} = 1;
		};	
	};
	my @result = sort keys %resultHash;
	return \@result;
};		
	
	
sub getDevicesForRoom($$$) {
# get all devices for a room
	my ($name,$room,$sysid) = @_;
	# buffered?
	return $buffer{$name}{$sysid}{"room-device"}{$room} if(defined($buffer{$name}{$sysid}{"room-device"}{$room}));
	# not buffered, determine
	
	my $coding = [
		'my @devices',
		'foreach my $d (keys %main::attr ) {',
		'	next unless grep {$_ eq "'.$room.'"} split(",", main::AttrVal($d, "room", "Unsorted"))',
		'	push(@devices,$d)',
		'}',
		'return \@devices'	
	];
	my $devices = callCoding($name,$coding,$sysid);
	@$devices = sort(@$devices);
	$buffer{$name}{$sysid}{"room-device"}{$room} = $devices;
	return $devices;
};	
	
	
sub getDevice($$$$) {
# get certain attributes, readings, internals for a device
	my ($name,$devName,$fields,$sysid) = @_;
	# do we have the device 
	my $device = $buffer{$name}{$sysid}{devices}{$devName};
	if(not defined($device)) {
		$buffer{$name}{$sysid}{devices}{$devName} = {Attributes => {}, Readings => {}, Internals => {}, undefs => []};
		$device = $buffer{$name}{$sysid}{devices}{$devName};
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
		my $cmd = 'jsonlist2 '.$devName.' '.join(' ',keys %fieldHash);
		my $jsonResult;
		my $url = _getUrl($name,$sysid);
		if($url eq 'local') {
			$jsonResult = main::fhem($cmd,1);
		}else{
			$jsonResult = _sendRemoteCommand($name,$sysid,$url,$cmd);
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
sub getSetsOfDevice($$$) {
	my ($fuipName, $devName, $sysid) = @_;
	# buffered?
	return $buffer{$fuipName}{$sysid}{devicesets}{$devName} if(defined($buffer{$fuipName}{$sysid}{devicesets}{$devName}));
	# not buffered, determine
	my $coding = [ 'return main::getAllSets("'.$devName.'")' ];
	my $resultStr = callCoding($fuipName,$coding,$sysid);
	# split into sets
	my %result;
	for my $setStr (split(" ",$resultStr)) {
		my ($set,$optStr) = split(":",$setStr,2);
		my @options = split(",",$optStr);
		$result{$set} = \@options;
	};
	$buffer{$fuipName}{$sysid}{devicesets}{$devName} = \%result;
	return \%result;
};	
	
	
sub getDevicesForReading($$$) {
# get all devices which have a certain reading
	my ($name,$reading,$sysid) = @_;
	# buffered?
	return $buffer{$name}{$sysid}{"reading-device"}{$reading} if(defined($buffer{$name}{$sysid}{"reading-device"}{$reading}));
	# not buffered, determine
	my $coding = [ 
		'my @devices = grep { defined $main::defs{$_}{READINGS}{"'.$reading.'"} } keys %main::defs',
		'return \@devices'
	];
	my $devices = callCoding($name,$coding,$sysid);	
	unless($devices) {
	    main::stacktrace();
		return undef;
	};
	@$devices = sort(@$devices);
	$buffer{$name}{$sysid}{"reading-device"}{$reading} = $devices;
	return $devices;
};	
	

sub getGplot($$$) {
	my ($name,$device,$sysid) = @_;
	my $coding = [	
		'my $filename = $main::defs{"'.$device.'"}{GPLOTFILE}', 
		'return undef unless $filename',
		'$filename = $main::FW_gplotdir."/".$filename.".gplot"',  
		'my ($err, $cfg, $plot, $srcDesc) = main::SVG_readgplotfile("'.$device.'",$filename,"SVG")', 
		'my %conf = main::SVG_digestConf($cfg,$plot)',  
		'return { srcDesc => $srcDesc, conf => \%conf }'
	];
	return callCoding($name,$coding,$sysid);
};	
	
	
sub readTextFile($$$) {
	my ($name,$filename,$sysid) = @_;
	my $coding = [
		'open(FILE, $main::attr{global}{modpath}."/'.$filename.'") or return []',
		'my @result = <FILE>',
		'close(FILE)',
		'return \@result'
	];
	my $result = callCoding($name,$coding,$sysid);
	return join("",@$result);
};	


sub getStylesheetPrefix($$) {
	my ($name,$sysid) = @_;
	my $coding = [
		'return "" unless $main::FW_wname',
		'return main::AttrVal($main::FW_wname,"stylesheetPrefix", "")'
	];
	my $stylesheetPrefix = callCoding($name,$coding,$sysid);
	$stylesheetPrefix = "" if $stylesheetPrefix eq "default";
	return $stylesheetPrefix;
};


sub getDevicesForType($$$) {
	# Return devices with TYPE SVG
	my ($fuipName,$type,$sysid) = @_;
	my $coding = [
		'my @result',
		'for my $dev (keys %main::defs) {',
		'	my $device = $main::defs{$dev}',
		'	push(@result,$dev) if($device->{TYPE} eq "'.$type.'")',
		'}',
		'return \@result'
	];
	return FUIP::Model::callCoding($fuipName,$coding,$sysid);	
};	

1;