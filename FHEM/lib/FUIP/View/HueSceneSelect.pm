package FUIP::View::HueSceneSelect;

use strict;
use warnings;

use lib::FUIP::View;
use parent -norequire, 'FUIP::View';


sub _getBridge($$$) {
	my ($fuipName,$devName,$sysid) = @_; 
	my $coding = [
		'my $device = $main::defs{"'.$devName.'"}',
		'return undef unless $device',
		'return "'.$devName.'" if($device->{TYPE} eq "HUEBridge")',
		'return undef unless($device->{TYPE} eq "HUEDevice")',
		'return $device->{IODev}{NAME}'
	];
	return FUIP::Model::callCoding($fuipName,$coding,$sysid);
}


sub _getScenes($$$) {
	# get all scenes for a device (group or bridge) 
	my ($fuipName,$devName,$sysid) = @_; 
	# find bridge and group for the device
	# and check whether this is anything "HUE like", which can have scenes,
	# i.e. the bridge or a group (not a device)
	
	my $bridgeName = _getBridge($fuipName,$devName,$sysid);
	return {} unless $bridgeName;
	my $groupNumber = 0;
	if($devName ne $bridgeName) {
		my $coding = [
			'my $device = $main::defs{"'.$devName.'"}',
			'return -1 unless(substr($device->{ID},0,1) eq "G")',
			'my	$group = substr($device->{ID},1)',
			'return $group' 
		];	
		$groupNumber = FUIP::Model::callCoding($fuipName,$coding,$sysid);
		return {} if $groupNumber < 0;
	};
	
	# Filter scenes
	# 1. Device is the bridge => return all scenes
	# 2. Device is a group (ID starts with G)
	#		Group 0 => return all scenes
	#		Otherwise => return scenes where type = GroupScene
	#                                    and group = group number (number after G in ID)
	# 3. Device is sth else => return empty hash (no scenes)

	# get all scenes for bridge (should not be THAT many)
	# there are some issued with the fields locked and recycle, these need to be translated
	my $coding = [
		'my $result = $main::defs{"'.$bridgeName.'"}->{helper}{scenes}',
		'for my $key (keys %$result) {',
	    '    delete $result->{$key}{locked}',
		'    delete $result->{$key}{recycle}',	
		'}',
		'return $result'
	];
	my $scenes = FUIP::Model::callCoding($fuipName,$coding,$sysid);
	return $scenes unless $groupNumber;
	my %result;
	for my $key (keys %$scenes) {
		next unless $scenes->{$key}{type} eq "GroupScene"
				and $scenes->{$key}{group} == $groupNumber;
		$result{$key} = $scenes->{$key};		
	};	
	return \%result;
};


sub _getGroups($$$) {
	my ($fuipName,$bridgeName,$sysid) = @_; 
	# get for each group assigned to the bridge:
	# Name of FHEM device
	# Alias of FHEM device
	# Name on bridge
	
	# get all groups for bridge (should not be THAT many)
	my $coding = [
		'return $main::defs{"'.$bridgeName.'"}->{helper}{groups}'
	];
	my $bridgeGroups = FUIP::Model::callCoding($fuipName,$coding,$sysid);
	# no groups on bridge?
	return {} unless $bridgeGroups and %$bridgeGroups;
	
	$coding = [
		'my $groups = {}',
		'foreach my $dev ( values %{$main::modules{HUEDevice}{defptr}} ) {
			next if( !$dev->{IODev} )',
		'	next if( $dev->{IODev}{NAME} ne "'.$bridgeName.'" )',
		'	next if( $dev->{helper}{devtype} ne "G" )',
		'	my $groupNumber = substr($dev->{ID},1)',
		'	next unless $groupNumber',  # group 0 does not count as group
		'	$groups->{$groupNumber} = {
					fhemName => $dev->{NAME} ,
					fhemAlias => main::AttrVal($dev->{NAME}, "alias", "") }',	
		'}',
		'return $groups'
	];
	my $groups = FUIP::Model::callCoding($fuipName,$coding,$sysid);
	# in principle, the FHEM groups can be deleted...
	for my $key (keys %$bridgeGroups) {
		$groups->{$key} = {} unless $groups->{$key};
		$groups->{$key}{name} = $bridgeGroups->{$key}{name};
	};
	return $groups;
};


sub getHTML($){
	my ($self) = @_;
	my (undef,$height) = $self->dimensions();
	# data-list needs to be set "" explicitly as the default is setList, which would then fetch it
	# again from the device, overriding our settings
	$self->{scenes} = [] unless $self->{scenes};
	my $options = '[]';
	my $alias = '[]';
	my $scenes = _getScenes($self->{fuip}{NAME}, $self->{device},$self->getSystem());
	if(@{$self->{scenes}}) {
		$options = '["'.join('","',@{$self->{scenes}}).'"]';
		$alias = '["'.join('","',map { $scenes->{$_}{name} } @{$self->{scenes}}).'"]';
	};
	my $result = '<table style="width:100%;height:'.($self->{label} ? 49 : 32).'px !important;border-collapse: collapse;">
					<tr>
					<td style="padding:0;">
					<div data-type="select"
					data-device="'.$self->{device}.'"
					data-list=""
					data-items=\''.$options.'\' 
					data-alias=\''.$alias.'\' 
					data-set="scene"
					data-get="scene"
					style="width:100%"></div>
					</td></tr>';
	if($self->{label}) {
		$result .= '<tr><td  style="padding:0;" class="fuip-color">'.$self->{label}.'</td></tr>';
	};
	$result .= '</table>';	
	return $result;
};				

	
sub dimensions($;$$){
	my ($self,$width,$height) = @_;
	if($self->{sizing} eq "resizable") {
		$self->{width} = $width if $width;
		$self->{height} = $height if $height;
	};
	# do we have to determine the size?
	# even if sizing is "auto", we at least determine an initial size
	# either resizable and no size yet
	# or fixed
	if(not $self->{height} or $self->{sizing} eq "fixed") {
		$self->{height} = ($self->{label} ? 49 : 32);
	};
	if(not $self->{width} or $self->{sizing} eq "fixed") {
		$self->{width} = 110;  # this is "double" from the select widget
	};	
	return ("auto","auto") if($self->{sizing} eq "auto");
	return ($self->{width},$self->{height});
};	


sub getScenesForValueHelp($$$) {
	# get all scenes for a device (group or bridge) as json
	# for FUIP's value help
	my ($fuipName,$devName,$sysid) = @_; 
	my $scenes = _getScenes($fuipName,$devName,$sysid); 
	return undef unless $scenes;
	my $bridgeName = _getBridge($fuipName,$devName,$sysid);
	my $tabDef;
	if($devName eq $bridgeName) {
		my $groups = _getGroups($fuipName,$bridgeName,$sysid);
		$groups = {} unless $groups;
		$tabDef = {
				colDef => [ { display => "none" },
							{ title => "Name" },
							{ title => "Group (Alias)" },
							{ title => "Group (FHEM)" },
							{ title => "Group (Bridge)" }
							],
				rowData => [] };		
		for my $key (keys %$scenes) {
			my $group = $scenes->{$key}{group} ? $groups->{$scenes->{$key}{group}} : 0;
			if($group) {
				push(@{$tabDef->{rowData}}, [ $key, $scenes->{$key}{name}, $group->{fhemAlias}, $group->{fhemName}, $group->{name}]);  
			}else{
				push(@{$tabDef->{rowData}}, [ $key, $scenes->{$key}{name}, "", "", ""]);  
			};	
		};
	}else{
		$tabDef = {
				colDef => [ { display => "none" },
							{ title => "Name" }
							],
				rowData => [] };		
		for my $key (keys %$scenes) {
			push(@{$tabDef->{rowData}}, [ $key, $scenes->{$key}{name}]);  
		};
	};
	return FUIP::_toJson($tabDef);
}


sub getDevicesForValueHelp($$) {
	# Return...
	#	all HUEBridge
	#	all HUEDevice, where ID[0] = "G"
	my ($fuipName,$sysid) = @_;
	my $coding = [
		'my @result',
		'for my $dev (keys %main::defs) {',
		'	my $device = $main::defs{$dev}',
		'	if($device->{TYPE} eq "HUEBridge") {',
		'		push(@result,$dev)',
		'	}elsif($device->{TYPE} eq "HUEDevice"){',
		'		next unless substr($device->{ID},0,1) eq "G"',
		'		next unless substr($device->{ID},1,1)',  # i.e. not zero 
		'		push(@result,$dev)',
		'	}',	
		'}',
		'return \@result'
	];
	my $result = FUIP::Model::callCoding($fuipName,$coding,$sysid);	
	return FUIP::_toJson($result);
}	
	
	
sub getStructure($) {
	# class method
	# returns general structure of the view without instance values
	my ($class) = @_;
	return [
		{ id => "class", type => "class", value => $class },
		{ id => "device", type => "device", filterfunc => "FUIP::View::HueSceneSelect::getDevicesForValueHelp" },
		{ id => "scenes", type => "setoptions", reffunc => "FUIP::View::HueSceneSelect::getScenesForValueHelp", refparms => ["device"] }, 	
		{ id => "width", type => "dimension"},
		{ id => "height", type => "dimension"},
		{ id => "sizing", type => "sizing", options => [ "fixed", "resizable", "auto" ],
			default => { type => "const", value => "resizable" } },
		{ id => "title", type => "text", default => { type => "field", value => "device"} },
		{ id => "label", type => "text" }
		];
};

# register me as selectable
$FUIP::View::selectableViews{"FUIP::View::HueSceneSelect"}{title} = "Select from Hue Scenes"; 
	
1;	