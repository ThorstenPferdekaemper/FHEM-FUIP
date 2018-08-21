package FUIP::View::LabelReading;

use strict;
use warnings;

use lib::FUIP::View;
use parent -norequire, 'FUIP::View';


sub getHTML($){
	my ($self) = @_;
	# show reading
	return "<table width='100%' class=\"fuip-color\" style='border:1px solid; border-radius:8px;'>
				<tr><td class=\"fuip-color\">".$self->{label}."</td></tr>
				<tr><td><div data-type=\"label\" 
							 class=\"fuip-color\"
							 data-device=\"".$self->{reading}{device}."\"
							 data-get=\"".$self->{reading}{reading}."\">
				</div></td></tr>
			</table>";
};
	
	
sub dimensions($;$$){
	my $self = shift;
	return (main::AttrVal($self->{fuip}{NAME},"baseWidth",142), 60);
};	
	

sub getStructure($) {
	# class method
	# returns general structure of the view without instance values
	my ($class) = @_;
	return [
		{ id => "class", type => "class", value => $class },
		{ id => "reading", type => "device-reading", 
			device => { },
			reading => { } },	
		{ id => "title", type => "text", default => { type => "field", value => "reading-reading"} },
		{ id => "label", type => "text", default => { type => "field", value => "title"} },
		{ id => "popup", type => "dialog", default=> { type => "const", value => "inactive"} }		
		];
};


# register me as selectable
$FUIP::View::selectableViews{"FUIP::View::LabelReading"}{title} = "Display a reading as text"; 

1;	