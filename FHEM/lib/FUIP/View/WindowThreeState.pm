package FUIP::View::WindowThreeState;

use strict;
use warnings;

use lib::FUIP::View;
use parent -norequire, 'FUIP::View';

	
sub getHTML($){
	my ($self) = @_;
	my @states = ($self->{openstate},$self->{closedstate},$self->{tiltedstate});
	my @icons = ($self->{openicon},$self->{closedicon},$self->{tiltedicon});
	my @colors = ("red","green","red");
	# at least numerical states need to be sorted
	# suppress "not a number" warnings
	no warnings;
	my $gt = ($states[0] > $states[2]);
	use warnings;
	if($gt) {
		@states = ($states[2],$states[1], $states[0]);
		@icons = ($icons[2],$icons[1], $icons[0]);
		@colors = ($colors[2],$colors[1], $colors[0]);
	};
	return '
		<div data-type="symbol" class="compressed '.$self->{iconsize}.'" 
			style="margin: 5px 5px 5px 5px;"
			data-device="'.$self->{device}.'"'."\n". 
			($self->{reading} and $self->{reading} ne "STATE" ? 'data-get="'.$self->{reading}.'"'."\n" : '')
			.'data-states=\'["'.$states[0].'","'.$states[1].'","'.$states[2].'"]\' 
			data-icons=\'["'.$icons[0].'","'.$icons[1].'","'.$icons[2].'"]\' 
			data-colors=\'["'.$colors[0].'","'.$colors[1].'","'.$colors[2].'"]\' >
		</div>'.
		($self->{label} ? '
			<div class="fuip-color">'.$self->{label}.'</div>' : ''); 
};


my %iconsizes = (
	mini => 13,
	tiny => 16,
	small => 21,
	normal => 26,
	large => 33,
	big => 39,
	bigger => 52,
	tall => 91,
	great => 117,
	grande => 156,
	gigantic => 288
	);

	
sub dimensions($;$$){
	my ($self,$width,$height) = @_;
	if($self->{sizing} eq "resizable") {
		$self->{width} = $width if $width;
		$self->{height} = $height if $height;
	};
	if($self->{sizing} eq "fixed") {
		my $size = $iconsizes{$self->{iconsize}} + 10;
		if($self->{label}) {
			return ($size < 100 ? 100 : $size, $size + 19);
		}else{
			return ($size, $size);
		};	
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
		{ id => "reading", type => "reading", refdevice => "device", default => { type => "const", value => "STATE" } },
		{ id => "title", type => "text", 
			default => { type => "field", value => "device" } },
		{ id => "label", type => "text", 
			default => { type => "field", value => "device" } },	
		{ id => "openstate", type => "text",
			default => { type => "const", value => "open" } },		
		{ id => "openicon", type => "icon",
			default => { type => "const", value => "oa-fts_window_1w_open" } },	
		{ id => "closedstate", type => "text",
			default => { type => "const", value => "closed" } },			
		{ id => "closedicon", type => "icon",
			default => { type => "const", value => "oa-fts_window_1w" } },	
		{ id => "tiltedstate", type => "text",
			default => { type => "const", value => "tilted" } },			
		{ id => "tiltedicon", type => "icon",
			default => { type => "const", value => "oa-fts_window_1w_tilt" } },	
		{ id => "iconsize", type => "text",
			options => ["mini","tiny","small","normal","large","big","bigger","tall","great","grande","gigantic"],
			default => {type => 'const', value => 'large'}
		},	
		{ id => "width", type => "dimension", value => 43},
		{ id => "height", type => "dimension", value => 43},
		{ id => "sizing", type => "sizing", options => [ "fixed", "resizable", "auto" ],
			default => { type => "const", value => "fixed" } },
		{ id => "popup", type => "dialog", default=> { type => "const", value => "inactive"} }			
		];
};


# register me as selectable
$FUIP::View::selectableViews{"FUIP::View::WindowThreeState"}{title} = "Window, Door or similar"; 
	
1;
