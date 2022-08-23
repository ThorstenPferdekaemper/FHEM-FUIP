package FUIP::View::SimpleSwitch;

use strict;
use warnings;
    use lib::FUIP::View;
	use parent -norequire, 'FUIP::View';
	
	sub getDependencies($$) {
	    return ['js/fuip_5_resize.js','js/fuip_simpleswitch.js'];
    };
	
	sub getHTML($){
		my ($self) = @_;
		$self->{sizing} = "fixed" unless $self->{sizing};
		my $result = "";
		#Do not touch sizing if it's fixed for compatibility 
		if($self->{sizing} ne "fixed") {
			$result = '<div data-fuip-type="fuip-simpleswitch" data-has-label="'.($self->{label} ? 'yes' : 'no').'" style="width:100%;height:100%;">';
		};	
		$result .= 
			'<table cellpadding="0" width="100%" >
				<tr><td>
					<div data-type="switch"   
						data-device="'.$self->{device}.'" 
						data-icon="'.$self->{icon}.'"' ;
		if($self->{set}) {
			$result .= '
						data-set="'.$self->{set}.'"';
		};
		if($self->{reading}) {
			$result .= '
						data-get="'.$self->{reading}.'"';
		};
		$result .= '
						data-get-on="on.*|ON.*|[1-9][0-9]*"
						data-get-off="off|OFF|0"
						data-set-on="on"
						data-set-off="off">
					</div>
				</td></tr>';
		$result .= '<tr><td class="fuip-color">'.$self->{label}.'</td></tr>' if($self->{label});
		$result .= '</table>';
		if($self->{sizing} ne "fixed") {
			$result .= '</div>';	
		};	
		
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
		$self->{height} = ($self->{label} ? 78 : 56);  
	};
	if(not $self->{width} or $self->{sizing} eq "fixed") {
		$self->{width} = 70;
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
		{ id => "set", type => "set", refdevice => "device", default => { type => "const", value => "" } },
		{ id => "reading", type => "reading", refdevice => "device", default => { type => "field", value => "set"}},
		{ id => "icon", type => "icon", default => { type => "const", value => "fa-lightbulb-o" } },
		{ id => "width", type => "dimension" },
		{ id => "height", type => "dimension" },	
		{ id => "sizing", type => "sizing", options => [ "fixed", "auto", "resizable" ],
			default => { type => "const", value => "fixed" } }
		];
};


# register me as selectable
$FUIP::View::selectableViews{"FUIP::View::SimpleSwitch"}{title} = "Simple Switch"; 

1;	