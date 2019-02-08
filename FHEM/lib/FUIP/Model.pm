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


sub getDeviceKeys($) {
# get the names of all devices
	my ($name) = @_;
	# buffered?
	return $buffer{$name}{devicekeys} if(defined($buffer{$name}{devicekeys}));
	# not buffered, determine
	
	my @devices;
	my $url = getFhemwebUrl($name);
	if($url) {
		my $devicesStr = _sendRemoteCommand($name,$url,
			'{  
				return join(",",(keys %defs));;
			}');
		@devices = split(/,/, $devicesStr);
		# for some reason, this has trailing whitespaces
		for(my $i = 0; $i < @devices; $i++) {
			$devices[$i] =~ s/\s+$//;
		};	
	}else{
		@devices = (keys %main::defs);
	};
	$buffer{$name}{devicekeys} = \@devices;
	return \@devices;
};	


sub getRooms($) {
# get all rooms
	my ($name) = @_;
	# buffered?
	return @{$buffer{$name}{rooms}} if(exists($buffer{$name}{rooms}));
	# not buffered, determine rooms
	my @rooms;
	my $url = getFhemwebUrl($name);
	if($url) {
		my $roomsStr = _sendRemoteCommand($name,$url,
			'{
				my %rooms;;
				foreach my $d (keys %defs ) {
					foreach my $r (split(",", AttrVal($d, "room", "hidden"))) {
						next if $r =~ /^(hidden|CUL_HM|HM485|)$/;;
						$rooms{$r} = 1;;
					}
				};;
				return join(",",keys(%rooms))
			}');
		@rooms = sort(split(/,/, $roomsStr));
		# for some reason, this has trailing whitespaces
		for(my $i = 0; $i < @rooms; $i++) {
			$rooms[$i] =~ s/\s+$//;
		};	
	}else{
		my %rooms;
		foreach my $d (keys %main::defs ) {
			# we do not return "hidden" or "Unsorted"
			foreach my $r (split(",", main::AttrVal($d, "room", "hidden"))) {
				# TODO: Rooms to be ignored should be configurable
				# the following also ignores the "empty string" room
				next if $r =~ /^(hidden|CUL_HM|HM485|)$/;
				$rooms{$r} = 1;
			}
		};
		@rooms = sort(keys(%rooms));
	};
	$buffer{$name}{rooms} = \@rooms;
	return @rooms;
};
	
	
sub getReadingsOfDevice($$) {
# get all readings of a device (only the reading names, without values)
	my ($name,$device) = @_;
	# TODO: buffering
	my @readings;
	my $url = getFhemwebUrl($name);
	if($url) {
		my $readingsStr = _sendRemoteCommand($name,$url,
			'{  
				return "" unless defined $defs{"'.$device.'"};;
				return join(",",(keys($defs{"'.$device.'"}{READINGS})));;
			}');
		@readings = split(/,/, $readingsStr);
		# for some reason, this has trailing whitespaces
		for(my $i = 0; $i < @readings; $i++) {
			$readings[$i] =~ s/\s+$//;
		};	
	}else{
		if(defined($main::defs{$device})) {
			@readings = keys(%{$main::defs{$device}{READINGS}});
		};
	};
	@readings = sort(@readings);
	return \@readings;
};		
	
	
sub getDevicesForRoom($$) {
# get all devices for a room
	my ($name,$room) = @_;
	# buffered?
	return $buffer{$name}{"room-device"}{$room} if(defined($buffer{$name}{"room-device"}{$room}));
	# not buffered, determine
	
	my @devices;
	my $url = getFhemwebUrl($name);
	if($url) {
		my $devicesStr = _sendRemoteCommand($name,$url,
			'{  
				my @devices;;
				foreach my $d (keys %defs ) {
					next unless grep {$_ eq "'.$room.'";;} split(",", main::AttrVal($d, "room", "Unsorted"));;
					push(@devices,$d);;
				};;		
				return join(",",@devices);;
			}');
		@devices = sort(split(/,/, $devicesStr));
		# for some reason, this has trailing whitespaces
		for(my $i = 0; $i < @devices; $i++) {
			$devices[$i] =~ s/\s+$//;
		};	
	}else{
		foreach my $d (keys %main::attr ) {
			next unless grep {$_ eq $room;} split(",", main::AttrVal($d, "room", "Unsorted"));
					push(@devices,$d);
		};	
		@devices = sort(@devices);
	};
	$buffer{$name}{"room-device"}{$room} = \@devices;
	return \@devices;
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
	my $url = getFhemwebUrl($fuipName);
	my $resultStr;
	$DB::single = 1;
	if($url) {
		$resultStr = _sendRemoteCommand($fuipName,$url,
			'{  
				return getAllSets("'.$devName.'");;
			}');
	}else{
		$resultStr = main::getAllSets($devName);
	};
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
	my @devices;
	my $url = getFhemwebUrl($name);
	if($url) {
		my $devicesStr = _sendRemoteCommand($name,$url,
			'{  
				return join(",", grep { defined $defs{$_}{READINGS}{"'.$reading.'"} } keys %defs) 
			}');
		# avoid stuff like [""]
		$devicesStr =~ s/\s+$//;
		@devices = split(/,/, $devicesStr) if($devicesStr);
		# for some reason, this has trailing whitespaces
		for(my $i = 0; $i < @devices; $i++) {
			$devices[$i] =~ s/\s+$//;
		};	
	}else{
		@devices = grep { defined $main::defs{$_}{READINGS}{$reading} } keys %main::defs;
	};
	@devices = sort(@devices);
	$buffer{$name}{"reading-device"}{$reading} = \@devices;
	return \@devices;
};	
	
	
sub getGplot($$) {
	my ($name,$device) = @_;
	my $url = getFhemwebUrl($name);
	if($url) {
		my $resultStr = _sendRemoteCommand($name,$url,
			'{	my $filename = $main::defs{"'.$device.'"}{GPLOTFILE};; 
				return undef unless $filename;;
				$filename = $main::FW_gplotdir."/".$filename.".gplot";;  
				my ($err, $cfg, $plot, $srcDesc) = main::SVG_readgplotfile("'.$device.'",$filename,"SVG");; 
				my %conf = main::SVG_digestConf($cfg,$plot);;  
				return Dumper({ srcDesc => $srcDesc, conf => \%conf });;
			}');
			# main::Log3(undef,1,"getGplot remote: ".($resultStr ? $resultStr : "error"));
			return eval(substr($resultStr,8));
	}else{
		my $filename = $main::defs{$device}{GPLOTFILE}; 
		return undef unless $filename;
		$filename = $main::FW_gplotdir."/".$filename.".gplot";  
		my ($err, $cfg, $plot, $srcDesc) = main::SVG_readgplotfile($device,$filename,"SVG"); 
		my %conf = main::SVG_digestConf($cfg,$plot);  
		return { srcDesc => $srcDesc, conf => \%conf };
	};

};	
	
	
sub readTextFile($$;$) {
	my ($name,$filename,$forceLocal) = @_;
	my $url = $forceLocal ? undef : getFhemwebUrl($name);
	if($url) {
		return _sendRemoteCommand($name,$url,
			'{  main::Log3(undef,1,$main::attr{global}{modpath}."/'.$filename.'");;
				open(FILE, $main::attr{global}{modpath}."/'.$filename.'") or return "";;
				my @result = <FILE>;;
				close(FILE);;
				return join("",@result);;
			}');
	}else{
		open(FILE, $main::attr{global}{modpath}.'/'.$filename) or return "";
		my @result = <FILE>;
		close(FILE);
		return join("",@result);
	};
};	


sub getStylesheetPrefix($) {
	my ($name) = @_;
	my $url = getFhemwebUrl($name);
	my $stylesheetPrefix;
	if($url) {
		$stylesheetPrefix = _sendRemoteCommand($name,$url,
			'{  return "" unless $main::FW_wname;; 
				return main::AttrVal($main::FW_wname,"stylesheetPrefix", "");;
			}');	
		# for some reason, this has trailing whitespaces
		$stylesheetPrefix =~ s/\s+$//;	
	}else{
		return "" unless $main::FW_wname;  #this should in principle not happen...
		$stylesheetPrefix = main::AttrVal($main::FW_wname,"stylesheetPrefix", "");
	};	
	$stylesheetPrefix = "" if $stylesheetPrefix eq "default";
	return $stylesheetPrefix;
};
	
1;