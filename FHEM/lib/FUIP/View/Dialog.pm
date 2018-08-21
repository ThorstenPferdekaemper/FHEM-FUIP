package FUIP::Dialog;
# Popup, like FUIP::Cell

use strict;
use warnings;
use POSIX qw(ceil);
use Scalar::Util qw(blessed);

use lib::FUIP::View;
use parent -norequire, 'FUIP::View';

sub dimensions($;$$){
	my $self = shift;
	if (@_) {
		$self->{width} = shift;
		$self->{height} = shift;
	}	
	return ($self->{width} ? $self->{width} : 400, $self->{height} ? $self->{height} : 300);
};	
	
	
sub getHTML($$){
	my ($self,$locked) = @_;
	my $views = $self->{views};
	my $result = '';

	my $i = 0;
	for my $view (@$views) {
		my ($left,$top) = $view->position();
		my ($width,$height) = $view->dimensions();
		# TODO: hardcode 22px headers?
		$result .= '<div><div data-viewid="'.$i.'"'.($locked ? '' : ' class="fuip-draggable"').' style="position:absolute;left:'.$left.'px;top:'.($top+22).'px;width:'.$width.'px;height:'.$height.'px;z-index:10">'.$view->getHTML();
		if($self->{fuip}{editOnly}) {
			my $title = ($view->{title} ? $view->{title} : '');
			$title .= ' ('.blessed($view).')';
			$result .= '<div title="'.$title.'" style="position:absolute;left:0;top:0;width:100%;height:100%;z-index:11;background:rgba(255,255,255,.1);"></div>';
		};
		$result .= '</div></div>';
		$i++;
	};
	return $result;	
};

	
sub getStructure($) {
	# class method
	# returns general structure of the view without instance values
	my ($class) = @_;
	return [
		{ id => "class", type => "class", value => $class },
		{ id => "title", type => "text" },
		{ id => "views", type => "viewarray" }
		];
};

	
1;	