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
	

sub _getViewHTML($) {
	my ($view) = @_;
	# check whether the view has a popup, i.e. a component of type "dialog"
	# which is actually switched on
	my $viewStruc = $view->getStructure(); 
	my $popupField;
	for my $field (@$viewStruc) {
		if($field->{type} eq "dialog") {
			$popupField = $field;
			last;
		};	
	};
	# if we have a default as "no popup", then we might not want a popup
	if($popupField and exists($popupField->{default})) {
		unless(exists($view->{defaulted}) and exists($view->{defaulted}{$popupField->{id}})
				and $view->{defaulted}{$popupField->{id}} == 0) {
			$popupField = undef;
		};	
	};
	# do we have a popup?
	my $result = "";
	my $dialog;
	if($popupField) {
		$dialog = $view->{$popupField->{id}};
		if( not blessed($dialog) or not $dialog->isa("FUIP::Dialog")) {
			$dialog = FUIP::Dialog->createDefaultInstance($view->{fuip});
		};
		my ($width,$height) = $dialog->dimensions();
		$result .= '<div data-type="popup"
						data-height="'.$height.'px"
						data-width="'.$width.'px">
					<div>';
	};
	# the normal HTML of the view
	$result .= $view->getHTML(); 
	# and again some popup stuff
	if($popupField) {
		# dialog->getHTML: always locked as we cannot configure the popup directly
		$result .= '</div>
					<div class="dialog">
					<header>'.$dialog->{title}.'</header>	
				'.$dialog->getHTML(1).' 
					</div>
				</div>';
	};			
	return $result;
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
		$result .= '<div><div data-viewid="'.$i.'"'.($locked ? '' : ' class="fuip-draggable"').' style="position:absolute;left:'.$left.'px;top:'.($top+22).'px;width:'.$width.'px;height:'.$height.'px;z-index:10">'._getViewHTML($view);
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