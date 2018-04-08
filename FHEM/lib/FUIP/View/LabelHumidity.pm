
# class FUIPViewLabel
package FUIP::View::LabelHumidity;

use strict;
use warnings;

    use lib::FUIP::View;
	use parent -norequire, 'FUIP::View';
	
	
	sub getHTML($){
		my ($self) = @_;
		my $result = "<div data-type=\"label\" 
						 data-device=\"".$self->{humidity}{device}."\" 
						 data-get=\"".$self->{humidity}{reading}."\"
						 data-unit=\" %\"
						 data-limits=\"[-1,20,39,59,65,79]\"
						 data-colors='[\"#ffffff\",\"#6699ff\",\"#AA6900\",\"FFCC80\",\"#AD3333\",\"#FF0000\"]'
						 class=\"big\">
					</div>";
		return $result;	
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
		{ id => "width", type => "internal", value => 75 },
		{ id => "height", type => "internal", value => 25 }
		];
};

# register me as selectable
$FUIP::View::selectableViews{"FUIP::View::LabelHumidity"}{title} = "Humidity Label"; 
	
1;	