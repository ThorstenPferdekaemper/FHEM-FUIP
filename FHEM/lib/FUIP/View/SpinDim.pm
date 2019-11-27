package FUIP::View::SpinDim;

use strict;
use warnings;
use lib::FUIP::View;
use parent -norequire, 'FUIP::View';
	
	
sub getHTML($){
	my ($self) = @_;
	my (undef,$height) = $self->dimensions();
	$self->{step} = 1 unless defined $self->{step};
	my $result = '<table style="width:100%;height:'.$height.'px !important;border-collapse: collapse;">
					<tr>
					<td style="padding:0;">
			<div 
				data-type="spinner" 
				data-device="'.$self->{dimmer}{device}.'"
				data-get="'.$self->{dimmer}{reading}.'"
				data-set="'.$self->{dimmer}{reading}.'"
				data-min="'.$self->{min}.'"
				data-max="'.$self->{max}.'"
				data-step="'.$self->{step}.'"
				data-height="34"
				data-width="154" 
				class="value"
				data-icon-left="fa-caret-down"
				data-icon-right="fa-caret-up"
				data-gradient-color=\'["black","white"]\'>
			</div></td></tr>';	
	if($self->{label}) {
		$result .= '<tr><td  style="padding:0;" class="fuip-color">'.$self->{label}.'</td></tr>';
	};	
	$result .= '</table>';	
	return $result;
};


sub dimensions($;$$){
    my $self = shift;
	my $height = 40;
	$height += 17 if($self->{label});
	return (160, $height);
};	
	
	
sub getStructure($) {
	# class method
	# returns general structure of the view without instance values
	my ($class) = @_;
	return [
		{ id => "class", type => "class", value => $class },
		{ id => "dimmer", type => "device-reading", 
			device => {},
			reading => { default => { type => "const", value => "level" } } },	
		{ id => "title", type => "text", default => { type => "field", value => "dimmer-device"} },
		{ id => "label", type => "text" },
		{ id => "min", type => "text", default => { type => "const", value => "0"}},
		{ id => "max", type => "text", default => { type => "const", value => "100"}},
		{ id => "step", type => "text", default => { type => "const", value => "1"}}
		];
};

our %docu = (
	general => "Dimmer als Spinner-Widget<br>
		Diese View eignet sich zum Einstellen von numerischen Werten. Es wurde f&uuml;r Dimmer und &auml;hnliches entwickelt, man kann im Prinzip aber beispielsweise auch Thermostate damit steuern.",
	dimmer => "Device und Reading/Set-Option, welche(s) gesteuert wird<br>
		Dieser Parameter besteht aus dem FHEM-Device, welches gesteuert werden soll, sowie dem Namen eines Readings. Es wird davon ausgegangen, dass das Device auch eine Set-Option mit demselben Namen wie das Reading hat. In der Regel ist das bei Dimmern oder auch Thermostaten der Fall.",
	label => "Dieser Text erscheint unter dem Spinner-Widget. Man kann das Label auch leer lassen.",
	min => "Minimaler einstellbarer/darstellbarer Wert.",
	max => "Maximaler einstellbarer/darstellbarer Wert.",
	step => "Schrittweite<br>
		Jedesmal, wenn man die \"hoch\"- bzw. \"runter\"-Taste dr&uuml;ckt wird der Wert um <i>step</i> erh&ouml;ht bzw. vermindert."	
);


# register me as selectable
$FUIP::View::selectableViews{"FUIP::View::SpinDim"}{title} = "Dimmer (als Spinner-Widget)"; 

1;	