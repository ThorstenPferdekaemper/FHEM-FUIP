
# class FUIPViewLabel
package FUIP::View::LabelHumidity;

use strict;
use warnings;

    use lib::FUIP::View;
	use parent -norequire, 'FUIP::View';
	
	
sub getHTML($){
	my ($self) = @_;
	my $result = '';
	if($self->{label}) {
		$result .= '<div class="fuip-color big left">'.$self->{label}.':</div>
					<div style="position:absolute;top:0px;left:120px"';
	}else{
		$result .= '<div';
	};	
	$result .= " data-type=\"label\" 
						 data-device=\"".$self->{humidity}{device}."\" 
						 data-get=\"".$self->{humidity}{reading}."\"
						 data-unit=\" %\"
						 data-limits=\"[-1,20,39,59,65,79]\"
						 data-colors='[\"#ffffff\",\"#6699ff\",\"#AA6900\",\"#AB4E19\",\"#AD3333\",\"#FF0000\"]'
						 class=\"big\">
					</div>";
	return $result;	
};

	
sub dimensions($;$$){
	my $self = shift;
	return (180,25) if($self->{label});
	return (60, 25);	
};	
	
	
	sub getStructure($) {
	# class method
	# returns general structure of the view without instance values
	my ($class) = @_;
	return [
		{ id => "class", type => "class", value => $class },
		{ id => "title", type => "text", default => { type => "const", value => "Humidity"} },
		{ id => "humidity", type => "device-reading",
			device => { },
			reading => { default => { type => "const", value => "humidity"} } },
		{ id => "label", type => "text", default => { type => "field", value => "humidity-reading"} },
		{ id => "popup", type => "dialog", default=> { type => "const", value => "inactive"} }			
		];
};

# register me as selectable
$FUIP::View::selectableViews{"FUIP::View::LabelHumidity"}{title} = "Humidity Label"; 
	
1;	