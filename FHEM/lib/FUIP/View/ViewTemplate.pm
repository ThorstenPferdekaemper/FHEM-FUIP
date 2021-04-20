package FUIP::ViewTemplate;

use strict;
use warnings;
use POSIX qw(ceil);
use Scalar::Util qw(blessed weaken);
use Storable qw(dclone);

use lib::FUIP::View;
use parent -norequire, 'FUIP::View';

sub dimensions($;$$){
	my $self = shift;
	if (@_) {
		$self->{width} = shift;
		$self->{height} = shift;
	}	
	return ($self->{width},$self->{height});
};	
	
	
sub getHTML_swiper($$){
	my ($self,$locked) = @_;
	my $views = $self->{views};
	my @classes;
	push(@classes, "navbuttons") if($self->{navbuttons} eq "on");
	push(@classes, "nopagination") if($self->{pagination} eq "off");
	my $result = 
		'<div data-type="swiper" style="position:absolute;top:0px;left:0px;height:100%;" data-height="100%" data-autoplay="'.$self->{autoplay}.'" class="'.join(' ',@classes).'">
			<ul>';
	my $i = 0;
	my (undef, $cellHeight) = $self->dimensions();
	for my $view (@$views) {
		my ($width,$height) = $view->dimensions();
		my $resizable = ($view->isResizable() ? " fuip-resizable" : "");
		$result .= '
		<li>
			<div style="position:absolute;left:'.($self->{navbuttons} eq "on" ? '37' : '0').'px;width:'.($self->{navbuttons} eq "on" ? 'calc(100% - 74px)' : '100%').';">
				<div data-viewid="'.$i.'"'.($locked ? '' : ' class="fuip-draggable'.$resizable.'"').' style="';
		if($width eq "auto") {
			$result .= 'width:100%;';
			# It seems that the swiper widget does some funny computations for the height, so 100% and calculations do not 
			# work directly. I.e. we need to find out the height of the cell and determine from there
			$result .= 'height:'.($cellHeight - ($self->{pagination} eq "on" ? 25 : 0)).'px;'; 
		}else{
			$result .= 'width:'.$width.'px;';
			$result .= 'height:'.$height.'px;';
			$result .= 'margin:auto;';
			$result .= 'top:'.(($cellHeight - ($self->{pagination} eq "on" ? 25 : 0) - $height)/2).'px;';
		};
		$result .= 'z-index:10;position:relative;"><div style="position:absolute;width:100%;height:100%;">'.$view->getViewHTML().'</div>';
		if( not $locked and $self->{fuip}{editOnly}) {
			my $title = ($view->{title} ? $view->{title} : '');
			$title .= ' ('.blessed($view).')';
			$result .= '<div title="'.$title.'" style="position:absolute;left:0;top:0;width:100%;height:100%;z-index:11;background:var(--fuip-color-editonly,rgba(255,255,255,.1));"></div>';
		};
		$result .= '</div></div></li>';
		$i++;
	};
	$result .= '</ul>';
	$result .= '</div>';
	return $result;	
};	
	
	
sub getHTML($$){
	my ($self,$locked) = @_;
	if($self->{layout} and $self->{layout} eq "swiper") {
		return getHTML_swiper($self,$locked);
	};	
	my $views = $self->{views};
	my $result = "";

	my $i = 0;
	for my $view (@$views) {
		my ($left,$top) = $view->position();
		my ($width,$height) = $view->dimensions();
		my $resizable = ($view->isResizable() ? " fuip-resizable" : "");
		$result .= '<div><div data-viewid="'.$i.'"'.($locked ? '' : ' class="fuip-draggable'.$resizable.'"').' style="position:absolute;left:'.$left.'px;top:'.$top.'px;';
		if($width eq "auto") {
			$result .= 'width:calc(100% - '.$left.'px);';
			$result .= 'height:calc(100% - '.$top.'px);'; 
		}else{
			$result .= 'width:'.$width.'px;';
			$result .= 'height:'.$height.'px;';
		};
		$result .= 'z-index:10">'.$view->getViewHTML();
		if( not $locked and $self->{fuip}{editOnly}) {
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
	if(blessed($class)) {
		my $self = $class;
		my $result = [
			{ id => "class", type => "class", value => "FUIP::VTempl::".$self->{id} },
			{ id => "templateid", type => "internal", value => $self->{id} }, 
			{ id => "title", type => "text", 
					default => { type => "const", value => $self->{id} } },
			{ id => "width", type => "dimension", value => $self->{width}},
			{ id => "height", type => "dimension", value => $self->{height}},
			{ id => "sizing", type => "sizing", options => [ "resizable","auto","fixed" ],
				default => { type => "const", value => "resizable" } },
		];
		# now add template variables
		# TODO: This might not have best performance...
		# get instance independent structure... 
		my $conf = "FUIP::ViewTemplate"->getDefaultFields();
		# ...and fill with values
		for my $field (@$conf) {
			$self->_fillField($field);
		};
		# add whatever has a variable as this variable
		for my $variable (@{$self->{variables}}) {
			for my $fieldpath (@{$variable->{fields}}) {
				my $fieldRef = $self->_findField($conf,$fieldpath);
				# It happened that the variable was assigned to a field which does not exist
				# anymore. We need to ignore these, but log a message.
				unless($fieldRef) {
					$fieldpath = "" unless $fieldpath;
					main::Log3(undef, 2, "FUIP: field path not found ".$fieldpath);
					next;
				};	
				my $field = dclone($self->_findField($conf,$fieldpath));
				my ($type,$basePath) = _findFieldBase($conf,$fieldpath);
				$field->{id} = $variable->{name};
				$field->{flexfield} = 0; 
				# for fields with a reference, we can only take this (TODO: for now?), if the reference 
				# field is also assigned to a variable (refdevice, refset, default[type=field]-value, reading of device-reading
				# refdevice
				if(exists($field->{refdevice})) {
					$field->{refdevice} = _findVariableForReffield($self->{variables},$basePath,$field->{refdevice});
					delete $field->{refdevice} unless $field->{refdevice};
				};
				# refset
				if(exists($field->{refset})) {
					$field->{refset} = _findVariableForReffield($self->{variables},$basePath,$field->{refset});
					delete $field->{refset} unless $field->{refset};
				};
				# default[type=field]-value
				if(exists($field->{default}) and $field->{default}{type} eq "field") {
					#main::Log3(undef,1,"Find var for default field ".$field->{default}{value});
					#main::Log3(undef,1,"Find var for base path ".$basePath);
					$field->{default}{value} = _findVariableForReffield($self->{variables},$basePath,$field->{default}{value});
					delete $field->{default} unless $field->{default}{value};
				};
				# default const -> use value from template field
				if(exists($field->{default}) and $field->{default}{type} eq "const") {
					$field->{default}{value} = $field->{value};
				};
				# depends
				if(exists($field->{depends})) {
					# find a variable for the field this one depends on
					my $depVar = _findVariableForReffield($self->{variables},$basePath,$field->{depends}{field});
					# if there is such a variable, use it as depends-field
					if($depVar) {
						$field->{depends}{field} = $depVar;
					}else{
						# otherwise, check the content of the original field and
						# remove the depends-part or the whole field
						my $depField = $self->_findReffield($conf,$basePath,$field->{depends}{field});
						if($depField->{value} eq $field->{depends}{value}) {
							delete $field->{depends};
						}else{
							next;  # do not use this field
						};	
					};
				};
				# reading of device-reading
				# if there is no type, this is probably a part of device-reading
				if($type eq 'device-reading') {
					if($fieldpath =~ m/-device$/) {
						$field->{type} = 'device';
					}elsif($fieldpath =~ m/-reading$/) {
						$field->{type} = 'reading';
						my $refdevice = _findVariableForReffield($self->{variables},$fieldpath,'device');
						$field->{refdevice} = $refdevice if $refdevice;	
					};	
				};
				push @$result, $field;  # TODO: duplicates? (with "standard" names like "title", "width"...
				last;  # only take the first occurrence to determine type etc.
			};
		};
		return $result;
	};
	return [
		{ id => "class", type => "class", value => $class },
		{ id => "id", type => "internal" },
		{ id => "variables", type => "variables", value => [] },
		{ id => "title", type => "text" },
		{ id => "layout", type => "text", options => ["position","swiper"], 
			default => { type => "const", value => "position" } },
		{ id => "autoplay", type => "text", 
			default => { type => "const", value => "0" }, 
			depends => { field => "layout", value => "swiper" } },
		{ id => "navbuttons", type => "text", options => ["on","off"], 
			default => { type => "const", value => "on" }, 
			depends => { field => "layout", value => "swiper" } },
		{ id => "pagination", type => "text", options => ["on","off"], 
			default => { type => "const", value => "on" }, 
			depends => { field => "layout", value => "swiper" } },
		{ id => "width", type => "dimension", value => 300},
		{ id => "height", type => "dimension", value => 200 },
		{ id => "sizing", type => "sizing", options => [ "resizable" ],
			default => { type => "const", value => "resizable" } },
		{ id => "views", type => "viewarray" }
	];
};


sub getDefaultFields($;$) {
	# class method
	# returns view structure with all "const" defaults filled
	# and defaulting set to "true"
	# $includes is a list of field types which are normally not visible
	my ($class,$includesInternals) = @_;
	my $result = $class->getStructure();  # without values
	
	if(not $includesInternals) {
		my @withoutInternals = grep {$_->{type} ne "internal"} @$result;
		$result = \@withoutInternals; 
	};
	for my $field (@$result) {
		next if $field->{id} eq "class";
		$class->_fillFieldDefault($field);
	};
	return $result;
};
	
	
sub createTemplInstance($$) {
	# creates default instance for this template
	# $fuip is the FUIP instance this belongs to
	my ($self,$fuip) = @_;
	my $defaultFields = $self->getDefaultFields(1); #i.e. include internals
	my $result = { fuip => $fuip };
	# Do not create cycles (garbage collection)
	weaken($result->{fuip});
	for my $field (@$defaultFields) {
		if($field->{type} eq 'class') {
			next;
		}elsif($field->{type} eq 'device-reading') {
			$result->{$field->{id}}{device} = $field->{device}{value};
			$result->{$field->{id}}{reading} = $field->{reading}{value};
		}else{
			$result->{$field->{id}} = $field->{value};
		};
	};
	$result->{templateid} = $self->{id};
	$result->{viewtemplate} = $self;
	return bless($result,"FUIP::ViewTemplInstance");
};	


sub setVariableDefSingle($$$$) {
	my ($variables,$h,$oldFieldName,$newFieldName) = @_;
	# this is where the value is set
	return unless defined $h->{$oldFieldName."-varcheck"};
	return unless $h->{$oldFieldName."-varcheck"} eq "1";
	return unless defined $h->{$oldFieldName."-variable"};
	my $varname = $h->{$oldFieldName."-variable"};
	return unless $varname;
	# get entry in variables list
	my $var;
	for my $curr (@$variables) {
		if($curr->{name} eq $varname) {
			$var = $curr;
			last;
		};	
	};
	unless($var) {
		$var = { name => $varname, fields => [] };
		push(@$variables,$var);
	};
	# is this part of a dialog?
	$newFieldName = $h->{fieldid}.'-'.$newFieldName if($h->{type} eq "dialog");
	push(@{$var->{fields}}, $newFieldName);
};


sub removeOldVariables($;$$) {
	my ($self,$fieldid,$view) = @_;
	if($fieldid) {
		$fieldid .= '-';
	}else{
		$fieldid = '';
	};	
	$view = $self unless $view;
	# remove all fields, which are on the same level like fieldid
	for my $variable (@{$self->{variables}}) {
		for my $i (0 .. $#{$variable->{fields}}) {
			my $field = $variable->{fields}[$i];
			if($fieldid) {
				# if field does not start with fieldid, then don't remove
				next if(substr($field,0,length($fieldid)) ne $fieldid);
				# cut off field id
				$field = substr($field,length($fieldid));
			};
			# $view is now either a view template or a dialog
			# and $field should be like views-<i>-<field> or views-<i>-<field>-<device/reading>
			# otherwise we do not delete
			my @parts = split(/-/,$field);
			next unless(scalar(@parts) == 1 or scalar(@parts) == 3 or scalar(@parts) == 4);
			# probably we do not need to check more. If the field belongs to a next level popup,
			# then $field would look like views-<i>-popup-views-<i>-<field>(-...)
			# i.e. we can safely delete the field here
			$variable->{fields}[$i] = undef;
		}
		# now really remove from the fields array
		@{$variable->{fields}} = grep { $_ } @{$variable->{fields}};
	};	
	# remove variables with empty field list
	@{$self->{variables}} = grep { @{$_->{fields}} } @{$self->{variables}};
};


sub setVariableDefs($$;$$$) {
	# store variable definitions according to viewsettings
	my ($self,$h,$view,$oldPrefix,$newPrefix) = @_;
	# "loop" through all config fields
	# 	check whether ...-varcheck is set
	#	store ...-variable as key with list of (full) field names
	$oldPrefix = "" unless $oldPrefix;
	$newPrefix = "" unless $newPrefix;
	
	my $fields;
	if($view) {
		$fields = $view->getStructure();
	}elsif($h->{type} eq "viewtemplate"){	
		$fields = "FUIP::ViewTemplate"->getStructure();
		$view = $self;
		# if this is not called for a view, we need to delete "old" variables/fields
		$self->removeOldVariables();	
	}else{  # should be dialog
		$view = FUIP::findDialogFromFieldId($self->{fuip},$h,$h->{fieldid});
		$fields = $view->getStructure();
		$self->removeOldVariables($h->{fieldid},$view);
	};	
	$view->addFlexFields($fields);
	for my $field (@$fields) {
		if($field->{type} eq "device-reading") {
			setVariableDefSingle($self->{variables},$h,$oldPrefix.$field->{id}.'-device',$newPrefix.$field->{id}.'-device');
			setVariableDefSingle($self->{variables},$h,$oldPrefix.$field->{id}.'-reading',$newPrefix.$field->{id}.'-reading');
		}elsif($field->{type} eq "viewarray"){
			# we must have a "sort order" argument
			my @sortOrder;
			if(defined($h->{$oldPrefix.$field->{id}})){
				@sortOrder = split(',',$h->{$oldPrefix.$field->{id}});
			};
			for my $i (0 .. $#sortOrder) {
				$self->setVariableDefs($h,$view->{$field->{id}}[$i],
						$oldPrefix.$field->{id}.'-'.$sortOrder[$i].'-', $newPrefix.$field->{id}.'-'.$i.'-');
			};
		}else{
			setVariableDefSingle($self->{variables},$h,$oldPrefix.$field->{id},$newPrefix.$field->{id});
		};	
	};
};


sub _findField($$$) {
	my ($self,$conf,$path) = @_;
	my $result = $conf;
	my @parts = split(/-/,$path);
	for my $key (@parts) {
		my $type = (ref($result) eq "HASH" && defined($result->{type})) ? $result->{type} : "";
		if($type eq "viewarray"){
			$result = $result->{value}[$key];
		}elsif($type eq "device-reading"){
			$result = $result->{$key};  # device or reading
		}else{
			if($type eq "dialog") {
				return undef unless defined $result->{value};
				my $dialog = $result->{value};
				return undef unless blessed($dialog);
				$result = $dialog->getConfigFields();
			};	
			# if the field does not exist (or belongs to a "higher" popup,
			# then this is not an array now
			return undef unless ref($result) eq "ARRAY";
			# find the field def with the id 
			for my $field (@$result) {
				next unless $field->{id} eq $key;
				$result = $field;
				last;
			};
		};
	};
	return $result;
};


sub _findFieldBase($$$) {
	# if device-reading, return (device-reading, path without last bit)
	# otherwise, return (type,path)
	my ($conf,$path) = @_;
	my $baseField = $conf;
	my $result = "";
	my @parts = split(/-/,$path);
	for my $key (@parts) {
		my $type = (ref($baseField) eq "HASH" && defined($baseField->{type})) ? $baseField->{type} : "";
		if($type eq "viewarray"){
			$baseField = $baseField->{value}[$key];
		}elsif($type eq "device-reading"){
			return ('device-reading',$result);
		}else{
			if($type eq "dialog") {
				my $dialog = $baseField->{value};
				$baseField = $dialog->getConfigFields();
			};
			# find the field def with the id 
			for my $field (@$baseField) {
				next unless $field->{id} eq $key;
				$baseField = $field;
				last;
			};
		};
		$result .= ($result ? '-' : '').$key;
	};
	return ($baseField->{type} ? $baseField->{type} : "", $path);
};


sub _findVariableForReffield($$$) {
	my ($variables,$fieldpath,$reffield) = @_;
	my @path = split(/-/,$fieldpath);
	pop(@path);
	push(@path,$reffield);
	$fieldpath = join('-',@path);
	for my $variable (@$variables) {
		for my $field (@{$variable->{fields}}) {
			next unless $field eq $fieldpath;
			return $variable->{name};
		};
	};
	return undef;
};	
	
	
sub _findReffield($$$) {
	my ($self,$conf,$fieldpath,$reffield) = @_;
	my @path = split(/-/,$fieldpath);
	pop(@path);
	push(@path,$reffield);
	$self->_findField($conf,join('-',@path));
};	
	

sub getConfigFieldsSetVariables($$;$) {
	my ($self,$conf,$fieldid) = @_;
	$fieldid .= '-' if $fieldid;
	# set variables into field definitions
	for my $variable (@{$self->{variables}}) {
		for my $i (0 .. $#{$variable->{fields}}) {
			my $fieldpath = $variable->{fields}[$i];
			if($fieldid) {
				# if field does not start with fieldid, then don't remove
				next if(substr($fieldpath,0,length($fieldid)) ne $fieldid);
				# cut off field id
				$fieldpath = substr($fieldpath,length($fieldid));			
			};
			# we do not fill fields of popups in popups
			my @parts = split(/-/,$fieldpath);
			next unless(scalar(@parts) == 1 or scalar(@parts) == 3 or scalar(@parts) == 4); 		
			my $field = $self->_findField($conf,$fieldpath);
			next unless $field;
			$field->{variable} = $variable->{name};
		};
	};
};	
	
	
sub getConfigFields($) {
	# returns config fields including value, type and defaulting information
	# array of hash id, type, value
	# thermostat   : device
	# measuredTemp : device-reading
	# humidity     : device-reading
	# valvePos     : device-reading
	my ($self) = @_;
	my $class = blessed($self);
	# get instance independent structure... 
	my $result = $class->getDefaultFields();
	# ...and fill with values
	for my $field (@$result) {
		$self->_fillField($field);
	};
	# set variables into field definitions
	$self->getConfigFieldsSetVariables($result);
	return $result;
}

our %docu = (
	general => "View Templates sind vom FUIP-Anwender selbst erstellte Views, die wiederum aus anderen Views oder auch anderen View Templates bestehen. Im Prinzip werden sie wie Zellen bearbeitet, k&ouml;nnen aber zus&auml;tzlich Variablen haben, die dann bei der Verwendung entsprechend belegt werden k&ouml;nnen.",
	title => "Kurzbeschreibung des View Template.<br>
			Hier sollte ein kurzer beschreibender Text eingetragen werden. Der Text erscheint nicht auf der Oberfl&auml;che, sondern nur in der View Template &Uuml;bersicht und der Werthilfe zur View-Auswahl.",
	sizing => "Gr&ouml;&szlig;e des View Templates<br>
			Ein View Template selbst ist immer \"resizable\". Man kann die Gr&ouml;&szlig;e frei einstellen, entweder &uuml;ber die Felder f&uuml;r Breite und H&ouml;he auf dem Konfigurations-Popup oder durch Ziehen der rechten unteren Ecke mit der Maus.<br>
			Wird ein View Template dann (als View) verwendet, k&ouml;nnen alle drei \"sizing\"-Optionen verwendet werden. (Also <i>fixed</i>, <i>resizable</i> und <i>auto</i>.) Bei <i>fixed</i> nimmt die View Template Instanz dann die hier eingestellte Gr&ouml;&szlig;e an."
);

1;	