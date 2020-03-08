package FUIP::View::Push;

use strict;
use warnings;
    use lib::FUIP::View;
	use parent -norequire, 'FUIP::View';
	
	
sub getHTML($){
	my ($self) = @_;
	$self->{border} = 'solid' unless $self->{border};
	my $backgroundIcon = "";
	$backgroundIcon = "fa-square-o" if $self->{border} eq "solid";
	my $left = "";
	my $top = "";
	if($self->{border} eq "none") {
		$top = 'top:6px;';	
		if($self->{label}){
			$left = 'left:28px;';
		}else{
			$left = 'left:5px;';
		}	
	}else{	
		if($self->{label}){
			$left = 'left:24px;';
		};
	};	
	my $position = "";
	$position = "position:absolute;".$left.$top;
	my $result = '<div style="'.$position.'" data-type="push" 
					data-device="'.$self->{device}.'" 
					data-icon="'.$self->{icon}.'" data-background-icon="'.$backgroundIcon.'"';
	# it seems that data-set and data-set-on does not always work
	$result .= ' data-fhem-cmd="set '.$self->{device}.' '.$self->{set}.' '.$self->{option}.'"';
	$result .= ' class="readonly';
	$result .= ' big compressed' if $self->{border} eq "none"; # make it bigger if there is no border
	$result .= '"> </div>';
	if($self->{label}) {
		$result .= '<div style="position:relative;top:52px;" class="fuip-color">'.$self->{label}.'</div>';
	};	
	return $result;	 
};

	
sub dimensions($;$$){
    my $self = shift;
	my $height = 52;
	my $width = 52;
	if($self->{label}) {
		$height += 17 ;
		$width = 100;
	};	
	return ($width, $height);
};	
	
	
sub getStructure($) {
	# class method
	# returns general structure of the view without instance values
	my ($class) = @_;
	return [
		{ id => "class", type => "class", value => $class },
		{ id => "device", type => "device" },
		{ id => "icon", type => "icon" },
		{ id => "set", type => "set", refdevice => "device" },
		{ id => "option", type => "setoption", refset => "set" },
		{ id => "title", type => "text", default => { type => "field", value => "device"} },
		{ id => "label", type => "text" },
		{ id => "border", type => "text", options => [ "solid", "none" ], 
			default => { type => "const", value => "solid" } }
		];
};


our %docu = (
	general => "Diese View ist ein Pushbutton, also eine Art Taster, der einen einzelnen Befehl an FHEM sendet.",
	set => 'Hier wird der Befehl eingetragen, der an das Device gesendet werden soll. Wenn man z.B. ein <i>"set myHeating desired-temperature 27,5"</i> senden will, dann geh&ouml;rt hier das <i>"desired-temp"</i> hinein.', 
	option => 'Falls der Befehl, der an das Device gesendet werden soll, noch weitere Parameter hat, dann wird das hier eingetragen. Wenn man z.B. ein <i>"set myHeating desired-temperature 27,5"</i> senden will, dann geh&ouml;rt hier das <i>"27,5"</i> hinein.', 
	border => "Hier kann man angeben, ob der Button einen Rahmen haben soll. Bei der Option <i>solid</i> wird ein Rahmen gezeichnet, bei der Option <i>none</i> wird kein Rahmen erzeugt. Ein Icon mit Rahmen wird etwas kleiner dargestellt als ein Icon ohne Rahmen. Ansonsten w&uuml;rsen die Gr&ouml;&szlig;enverh&auml;ltnisse nicht mehr passen." 
);


# register me as selectable
$FUIP::View::selectableViews{"FUIP::View::Push"}{title} = "Push button"; 

1;	