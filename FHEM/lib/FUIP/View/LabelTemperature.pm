
# class FUIPViewLabel
package FUIP::View::LabelTemperature;

use strict;
use warnings;

use lib::FUIP::View;
use parent -norequire, 'FUIP::View';
	
	
sub getHTML($){
	my ($self) = @_;
	my $result = "<div data-type=\"label\" 
				 data-device=\"".$self->{temperature}{device}."\" 
				 data-get=\"".$self->{temperature}{reading}."\"
				 data-unit=\" %B0C%0A\"
				 data-fix=\"1\" ";
	if($self->{colors} eq "boiler") {			 
		$result .= "data-limits=\"[-99,25,40,55,70]\"";
	}else{
		$result .= "data-limits=\"[-99,12,19,23,28]\"";
	};
	$result .= " data-colors='[\"#ffffff\",\"#6699ff\",\"#AA6900\",\"#AD3333\",\"#FF0000\"]'
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
		{ id => "title", type => "text", default => { type => "const", value => "Temperature"} },
		{ id => "temperature", type => "device-reading", 
			device => {},
			reading => { default => { type => "const", value => "measured-temp" } } },	
		{ id => "colors", type => "text", 
				default => { type => "const", value => "air" },
				options => ["air","boiler"] }, 	
		{ id => "width", type => "internal", value => 75 },
		{ id => "height", type => "internal", value => 25 }
		];
};
	
1;	