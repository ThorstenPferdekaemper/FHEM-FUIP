package FUIP::Model;

use strict;
use warnings;

use JSON::Parse 'parse_json';

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


sub _sendRemoteCommand($$) {
	my ($url,$cmd) = @_;
	my $fullurl = $url.'?cmd='.main::urlEncode($cmd).'&XHR=1';
	return main::GetFileFromURL($fullurl);
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
		my $devicesStr = _sendRemoteCommand($url,
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
		my $roomsStr = _sendRemoteCommand($url,
			'{
				my %rooms;;
				foreach my $d (keys %defs ) {
					foreach my $r (split(",", AttrVal($d, "room", "hidden"))) {
						next if $r =~ /^(hidden|CUL_HM|HM485)$/;;
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
				next if $r =~ /^(hidden|CUL_HM|HM485)$/;
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
		my $readingsStr = _sendRemoteCommand($url,
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
			@readings = keys($main::defs{$device}{READINGS});
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
		my $devicesStr = _sendRemoteCommand($url,
			'{  
				my @devices;;
				foreach my $d (keys %attr ) {
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
	delete(@fieldHash{keys $device->{Attributes}});
	delete(@fieldHash{keys $device->{Readings}});
	delete(@fieldHash{keys $device->{Internals}});
	delete(@fieldHash{@{$device->{undefs}}});    # non-existing to avoid asking again
	# anything left?
	if(%fieldHash or not @$fields) {
		my $url = getFhemwebUrl($name);
		my $cmd = 'jsonlist2 '.$devName.' '.join(' ',keys %fieldHash);
		my $jsonResult;
		if($url) {
			$jsonResult = _sendRemoteCommand($url,$cmd);
		}else{
			$jsonResult = main::fhem($cmd);
		};
		my $newDev = parse_json($jsonResult);
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
		delete(@fieldHash{keys $device->{Attributes}});
		delete(@fieldHash{keys $device->{Readings}});
		delete(@fieldHash{keys $device->{Internals}});
		my @missing = keys %fieldHash;
		push @{$device->{undefs}}, @missing;
	};
    # always return the whole thing
	return $device;
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
		my $devicesStr = _sendRemoteCommand($url,
			'{  
				return join(",", grep { defined $defs{$_}{READINGS}{"'.$reading.'"} } keys %defs) 
			}');
		@devices = split(/,/, $devicesStr);
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
	
1;