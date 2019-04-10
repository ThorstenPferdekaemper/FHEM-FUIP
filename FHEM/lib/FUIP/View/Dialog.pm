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
	$self->applyDefaults();
	my $views = $self->{views};
	my $result = '';
	my $i = 0;
	for my $view (@$views) {
		my ($left,$top) = $view->position();
		my ($width,$height) = $view->dimensions();
		my $resizable = ($view->isResizable() ? " fuip-resizable" : "");
		# TODO: hardcode 22px headers?
		$result .= '<div><div data-viewid="'.$i.'"'.($locked ? '' : ' class="fuip-draggable'.$resizable.'"').' style="position:absolute;left:'.$left.'px;top:'.($top+22).'px;';
		if($width eq "auto") {
			$result .= 'width:calc(100% - '.$left.'px);';
			$result .= 'height:calc(100% - '.($top+22).'px);'; 
		}else{
			$result .= 'width:'.$width.'px;';
			$result .= 'height:'.$height.'px;';
		};
		$result .= 'z-index:10">'.$view->getViewHTML();
		if(not $locked and $self->{fuip}{editOnly}) {
			my $title = ($view->{title} ? $view->{title} : '');
			$title .= ' ('.blessed($view).')';
			$result .= '<div title="'.$title.'" style="position:absolute;left:0;top:0;width:100%;height:100%;z-index:11;background:var(--fuip-color-editonly,rgba(255,255,255,.1));"></div>';
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
		{ id => "position", type => "text", options => [ "screen-center", "starter-area" ],
			default => { type => "const", value => "screen-center" } },		
		{ id => "views", type => "viewarray" }
		];
};

	
1;	