package FUIP::View::Html;

use strict;
use warnings;

use lib::FUIP::View;
use parent -norequire, 'FUIP::View';

	
sub getDependencies($$) {
	return ['js/fuip_htmlview.js'];
};
	
	
sub getHTML($){
	my ($self) = @_;
	my $html = $self->{html};
	$html =~ s/\\/\\\\/g;  	# \ -> \\
	$html =~ s/\r//g;		# remove lf
	$html =~ s/\n/\\n/g;	# replace new line by \n
	$html =~ s/\"/\\\"/g;	# " -> \"
	$html =~ s|<\/script>|<\\/script>|g; # </script> => <\/scipt>
	my @flexfields = split(/,/,$self->{flexfields});
	my $fieldStr;
	for my $flexfield (@flexfields) {
		if($fieldStr) {
			$fieldStr .= ',';
		}else{
			$fieldStr = '{';
		};
		my $value = $self->{$flexfield};
		if($self->{flexstruc}{$flexfield}{type} eq "setoptions") {
			$value = '[\"'.join('\",\"',@$value).'\"]';
		};
		$fieldStr .= '"'.$flexfield.'":"'.$value.'"'; 
	};
	if($fieldStr) {
		$fieldStr .= '}';
	}else{
		$fieldStr = '{}';
	};	
	return '<script type="text/javascript">
				renderHtmlView("'.$html.'",'.$fieldStr.');
			</script>';	
};

	
sub dimensions($;$$){
	my ($self,$width,$height) = @_;
	if($self->{sizing} eq "resizable") {
		$self->{width} = $width if $width;
		$self->{height} = $height if $height;
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
		{ id => "title", type => "text" },
		{ id => "html", type => "longtext" },
		{ id => "flexfields", type => "flexfields" },
		{ id => "width", type => "dimension", value => 50},
		{ id => "height", type => "dimension", value => 25 },
		{ id => "sizing", type => "sizing", options => [ "resizable", "auto" ],
			default => { type => "const", value => "resizable" } },
		{ id => "popup", type => "dialog", default=> { type => "const", value => "inactive"} }			
		];
};


# register me as selectable
$FUIP::View::selectableViews{"FUIP::View::Html"}{title} = "Free HTML"; 
	
1;	