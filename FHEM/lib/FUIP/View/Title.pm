# class FUIP::View
package FUIP::View::Title;

use strict;
use warnings;

    use lib::FUIP::View;
	use parent -norequire, 'FUIP::View';


	sub getHTML($){
		my ($self) = @_;
		return '<table><tr>
				  <td>
				    <div data-type="button" data-icon="'.$self->{icon}.'" 
			             data-on-color="#2A2A2A" data-on-background-color="#aa6900" data-off-color="#2A2A2A" data-off-background-color="#505050" 
			             class="cell small readonly"></div>
		          </td>
			      <td>
			        <div style="color: #808080;" class="bigger">'.uc($self->{text}).'</div>
			      </td>
				</tr></table>';
	};

	
	sub getStructure($) {
	# class method
	# returns general structure of the view without instance values
	# thermostat   : device
	# measuredTemp : device-reading
	# humidity     : device-reading
	# valvePos     : device-reading
	my ($class) = @_;
	return [
		{ id => "class", type => "class", value => $class },
		{ id => "text", type => "text" },
		{ id => "icon", type => "icon" },
		{ id => "title", type => "text", default => { type => "field", value => "text"} },
		{ id => "width", type => "internal", value => 500 },
		{ id => "height", type => "internal", value => 86 },
		{ id => "popup", type => "dialog", default=> { type => "const", value => "inactive"} }	
		];
};


# register me as selectable
$FUIP::View::selectableViews{"FUIP::View::Title"}{title} = "Title"; 
	
1;	