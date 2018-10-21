package FUIP::View::Html;

use strict;
use warnings;

    use lib::FUIP::View;
	use parent -norequire, 'FUIP::View';
	
	
	sub getHTML($){
		my ($self) = @_;
		my $html = $self->{html};
		$html =~ s/\\/\\\\/g;  	# \ -> \\
		$html =~ s/\r//g;		# remove lf
		$html =~ s/\n/\\n/g;	# replace new line by \n
		$html =~ s/\"/\\\"/g;	# " -> \"
		$html =~ s|<\/script>|<\\/script>|g; # </script> => <\/scipt>
		return '<script type="text/javascript">
						var elem = document.createElement("div");
						elem.innerHTML = "'.$html.'";
						document.write(elem.innerHTML);
					</script>';	
	};

	
	sub dimensions($;$$){
		my $self = shift;
		# we ignore any settings
		$self->{width} = 50 unless $self->{width};
		$self->{height} = 25 unless $self->{height};
		return ($self->{width}, $self->{height});
	};	
	
	
	sub getStructure($) {
	# class method
	# returns general structure of the view without instance values
	my ($class) = @_;
	return [
		{ id => "class", type => "class", value => $class },
		{ id => "title", type => "text" },
		{ id => "html", type => "longtext" },
		{ id => "width", type => "number", min => 5, max => 1000, step => 1, value => 50 },
		{ id => "height", type => "number", min => 5, max => 1000, step => 1, value => 25 },
		{ id => "popup", type => "dialog", default=> { type => "const", value => "inactive"} }			
		];
};


# register me as selectable
$FUIP::View::selectableViews{"FUIP::View::Html"}{title} = "Free HTML"; 
	
1;	