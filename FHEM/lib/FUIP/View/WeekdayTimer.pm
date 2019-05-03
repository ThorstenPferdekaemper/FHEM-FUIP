package FUIP::View::WeekdayTimer;

use strict;
use warnings;

use lib::FUIP::View;
use parent -norequire, 'FUIP::View';


sub getHTML($){
	my ($self) = @_;
	# determine levels
	my $levelStr;
	if($self->{levelType} eq "heating") {
		if($self->{minLevel} > $self->{maxLevel}) {
			($self->{minLevel}, $self->{maxLevel}) = ($self->{maxLevel}, $self->{minLevel});
		};	
		for(my $level = $self->{minLevel}; $level <= $self->{maxLevel}; $level += 0.5) {
			my $temp = sprintf("%.1f",$level);
			$levelStr .= ',' if($levelStr);
			$levelStr .= '"'.$temp.'&deg;C":"'.$temp.'"';	
		};
	}elsif($self->{levelType} eq "switch") {
		$levelStr = '"'.$self->{minLevel}.'":"'.$self->{minLevel}.'", "'.$self->{maxLevel}.'":"'.$self->{maxLevel}.'"';
	}else{  # shutter/inverted_shutter
		my @levels;
		use integer;
		my $inverted = ($self->{levelType} eq "inverted_shutter");
		for (my $i=0; $i <= 10; $i++) {
			push(@levels,$self->{minLevel} + ($self->{maxLevel} - $self->{minLevel}) * $i / 10);
		};
		$levelStr = '"Auf":"'.$levels[$inverted ? 0 : 10].'"'; 		
		for (my $i=9; $i >= 1; $i--) {
			$levelStr .= ',"'.(($inverted ? (10 - $i) : $i)*10).'%":"'.$levels[$inverted ? (10 - $i) : $i].'"';
		};
		$levelStr .= ',"Zu":"'.$levels[$inverted ? 10 : 0].'"';
	};
	$self->{timeInput} = "dropdownOnly" unless $self->{timeInput};
	my $result = '
				<div data-type="fuip_wdtimer" 
					data-device="'.$self->{device}.'"    
					data-style="round noicons'.($self->{timeInput} eq "dropdownOnly" ? ' nokeyboard':'').'" 
					data-theme="dark" 
					data-title="'.($self->{label} ? $self->{label} : $self->{title}).'"  
					data-sortcmdlist="MANUELL" ';
	if($self->{saveconfig} eq "yes") {
		$result .= 'data-savecfg=true ';
	};
	$result .= 'data-cmdlist=\'{'.$levelStr.'}\'>
				</div>';
	return $result;
};

	
sub dimensions($;$$){
	my ($self,$width,$height) = @_;
	$self->{sizing} = "fixed" unless $self->{sizing};
	if($self->{sizing} eq "resizable") {
		$self->{width} = $width if $width;
		$self->{height} = $height if $height;
	};
	# do we have to determine the size?
	# even if sizing is "auto", we at least determine an initial size
	# either resizable and no size yet
	# or fixed
	if(not $self->{height} or $self->{sizing} eq "fixed") {
		$self->{height} = 300;
	};
	if(not $self->{width} or $self->{sizing} eq "fixed") {
		$self->{width} = 450;
	};	
	return ("auto","auto") if($self->{sizing} eq "auto");
	return ($self->{width},$self->{height});
};	
	
	
sub getStructure($) {
	# class method
	# returns general structure of the view without instance values
	my ($class) = @_;
	return [
		{ id => "class", type => "class", value => $class },
		{ id => "device", type => "device" },
		{ id => "title", type => "text", default => { type => "field", value => "device"} },
		{ id => "label", type => "text", default => { type => "field", value => "title"} },
		{ id => "saveconfig", type => "text", options => [ "yes", "no" ], 
				default => { type => "const", value => "no" }},
		{ id => "levelType", type => "text", options => [ "shutter", "inverted_shutter", "heating", "switch" ], 
				default => { type => "const", value => "shutter" }},
		{ id => "minLevel", type => "text", default => { type => "const", value => "0" } },
		{ id => "maxLevel", type => "text", default => { type => "const", value => "100" } },
		{ id => "timeInput", type => "text", options => [ "keyboardAllowed", "dropdownOnly" ], 				
				default => { type => "const", value => "dropdownOnly" }},
		{ id => "width", type => "dimension" },
		{ id => "height", type => "dimension" },
		{ id => "sizing", type => "sizing", options => [ "fixed", "auto", "resizable" ],
			default => { type => "const", value => "resizable" } }
		];
};

# register me as selectable
$FUIP::View::selectableViews{"FUIP::View::WeekdayTimer"}{title} = "WeekdayTimer (general)"; 
	
1;	