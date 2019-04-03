package FUIP::View::STATE;

use strict;
use warnings;

use lib::FUIP::View;
use parent -norequire, 'FUIP::View';

sub getDependencies($$) {
	return ['js/fuip_5_resize.js','js/fuip_state.js'];
};	


sub _getHTML_fixed($){
	#"old" routine in order to keep existing layouts intact
	my ($self) = @_;
	# show STATE
	my $result = "<table width='100%' class=\"fuip-color\" style='border:1px solid; border-radius:8px;'>";
	if($self->{icon}){
		$result .= '<tr><td style="vertical-align:center">
							<i class="fa '.$self->{icon}.' fuip-color" style="font-size:26px"></i>
					</td><td><table>';
	};
	$result .= "<tr><td class=\"fuip-color\">".$self->{label}."</td></tr>
				<tr><td><div data-type=\"label\" 
							 class=\"fuip-color\"
							 data-device=\"".$self->{device}."\">
				</div></td></tr>";
	if($self->{icon}){
		$result .= '</table></td></tr>';
	};
	$result .= "</table>";
	return $result;
};

	
sub _getHTML_flex($){
	#"old" routine in order to keep existing layouts intact
	my ($self) = @_;
	# show STATE
	my $result = "<div data-fuip-type='fuip-state' 
						data-fuip-lines='".$self->{lines}."'
						class=\"fuip-color\" style='display:flex;width:100%;height:100%;border:1px solid; border-radius:8px;'>";
	if($self->{icon}){
		$result .= '<div style="align-self:center;">
						<i class="fa '.$self->{icon}.' fuip-color"></i>
					</div>';
	};
	$result .= "<div style='display:flex;flex-direction:column;margin-left:auto;margin-right:auto;'>
				<div data-fuip-type='fuip-state-label' class=\"fuip-color\">".$self->{label}."</div>
				<div data-type=\"label\" 
					data-fuip-type='fuip-state-field'
							 class=\"fuip-color\"
							 style='margin-top:auto;margin-bottom:auto;'
							 data-device=\"".$self->{device}."\">
				</div>
				</div>";
	$result .= "</div>";
	return $result;
};		

sub getHTML($){
	my ($self) = @_;
	$self->{sizing} = "fixed" unless $self->{sizing};
	$self->{lines} = 3 unless $self->{lines};
	return $self->_getHTML_fixed() if $self->{sizing} eq "fixed" and $self->{lines} == 3;
	return $self->_getHTML_flex();	
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
		$self->{height} = 60;
	};
	if(not $self->{width} or $self->{sizing} eq "fixed") {
		$self->{width} = main::AttrVal($self->{fuip}{NAME},"baseWidth",142);
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
		{ id => "icon", type => "icon" },
		{ id => "width", type => "dimension" },
		{ id => "height", type => "dimension" },
		{ id => "sizing", type => "sizing", options => [ "fixed", "auto", "resizable" ],
			default => { type => "const", value => "fixed" } },
		{ id => "lines", type => "text", 
				default => { type => "const", value => "3" },
				options => ["1","2","3","4","5","6"] },	
		{ id => "popup", type => "dialog", default=> { type => "const", value => "inactive"} }	
		];
};


# register me as selectable
$FUIP::View::selectableViews{"FUIP::View::STATE"}{title} = "Display STATE"; 

1;	