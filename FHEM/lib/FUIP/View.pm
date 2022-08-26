package FUIP::View;

use strict;
use warnings;
use Scalar::Util qw(blessed weaken);

use lib::FUIP::Exception;
use lib::FUIP::Systems;


my %selectableViews;
	
sub dimensions($;$$){
	my $self = shift;
	if (@_) {
		$self->{width} = shift;
		$self->{height} = shift;
	}	
	return ($self->{width}, $self->{height});
};	


sub isResizable($) {
	my $self = shift;
	return 0 unless defined $self->{sizing};
	return ($self->{sizing} eq "resizable");
};	


sub getDependencies($$) {
	# Parameters: class, fuip object
	# class method to return list of dependencies relative to the FUIP directory
	# currently supported: css and js files
	# css will be "copied" into fhem-tablet-ui-user.css
	# js will be "linked" in header
	return []; # nothing by default
};


# get the HTML for Cell-Like Views, i.e. Cell, ViewTemplate, Dialog
# i.e. wrap it in a popup-widget, if needed
sub getViewHTML($) {
	# $view instead of $self for "historical" reasons
	my ($view) = @_;
	# check whether the view has a popup, i.e. a component of type "dialog"
	# which is actually switched on
	my $viewStruc;
	eval {
		$viewStruc = $view->getStructure(); 
		1;
	} or do {
	    my $ex = $@;
		FUIP::Exception::log($ex);
		return FUIP::Exception::getErrorHtml($ex,"Could not determine structure of ".ref($view));
	};	
	
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
			$dialog = FUIP::Dialog->createDefaultInstance($view->{fuip},$view);
		};
		my ($width,$height) = $dialog->dimensions();
		$dialog->{position} = "screen-center" unless($dialog->{position});
		$result .= '<div data-type="fuip_popup"
						data-mode="fade"
						data-height="'.$height.'px"
						data-width="'.$width.'px"
						data-position="'.$dialog->{position}.'"';
		if($dialog->{autoclose}) {
			$result .= ' data-return-time="'.$dialog->{autoclose}.'"';
		};	
		$result .= '>
					<div>';
	};
	# the normal HTML of the view
	# Do some exception handling stuff around it
	my $singleHtml;
	eval {
		$singleHtml = $view->getHTML();
		1;
	} or do {
	    my $ex = $@;
		FUIP::Exception::log($ex);
		$singleHtml = FUIP::Exception::getErrorHtml($ex,"View rendering error");
	};
	$result .= $singleHtml; 
	
	# and again some popup stuff
	if($popupField) {
		# dialog->getHTML: always locked as we cannot configure the popup directly
		$result .= '</div>
					<div class="'.$dialog->getCssClasses(1).'">
					<header class="fuip-cell-header">'.$dialog->{title}.'</header>	
				'.$dialog->getHTML(1).' 
					</div>
				</div>';
	};			
	return $result;
};	


sub getHTML($$){
	my ($self,$locked) = @_;
	# This is just empty, but can be filled with some text
	return "<div>".$self->{content}."</div>";
};
	
	
	sub position($;$$) {
		my $self = shift;
		if (@_) {
			$self->{posX} = shift;
			$self->{posY} = shift;
		}	
		return ($self->{posX}, $self->{posY});
	}

	# declaration to avoid warnings because of recursion
	sub serializeRef($$);
	
	sub serializeRef($$) {
		my ($ref,$indent) = @_;
		my $blanks = " " x $indent;
		my $class = blessed($ref);
		if(defined($class)) {
			# main::Log3(undef,1,"Serializing $class");
			return $ref->serialize($indent) if($ref->isa("FUIP::View"));
			return "";  #we can only handle views here
		};
		# otherwise, we allow SCALAR, ARRAY, HASH
		my $refType = ref($ref);
		if(not $refType) {   #not a reference, assuming scalar
			# replace backslash with double-backslash
			$ref =~ s/\\/\\\\/g;
			# replace tick with backslash-tick
			$ref =~ s/'/\\'/g;
			return "'".$ref."'";
		}elsif($refType eq "ARRAY") {
			my $result = 0;
			for my $entry (@$ref) {
				if($result) {
					$result .= ",";
				}else{
					$result = "[";
				};
				$result .= "\n".serializeRef($entry, $indent + 4);
			}
			if($result) {
				$result .= "\n".$blanks."   ]";
			}else{
				$result = "[]";
			};	
			return $result;
		}elsif($refType eq "HASH") {
			my $result = 0;
			for my $key (sort keys %$ref) {
				if($result) {
					$result .= ",";
				}else{	
					$result = "{";
				};
			    # main::Log3(undef,1,"Serializing $key");
				$result .= "\n".$blanks."    ".$key." => ".serializeRef($ref->{$key}, $indent + 4); 		
			};	
			if($result) {
				return $result."\n".$blanks."    }";
			}else{	
				return "{}";
			};	
		};
		return "";
	};
	
	
	sub serialize($;$) {
		my ($self, $indent) = @_;
		$indent = 0 unless($indent);
		my $blanks = " " x $indent;
	    my $result = $blanks."{ class => '".blessed($self)."'";
		for my $field (keys %$self) {
			# fuip is the reference to the FUIP object, don't serialize this
			next if $field eq "fuip";
			next if $field eq "class";
			next if $field eq "parent";
			$result .= ",\n".$blanks."   ".$field." => ".serializeRef($self->{$field},$indent);
		};
		$result .= "\n".$blanks."}";
		return $result;
	}

	
	# declaration to avoid warnings because of recursion
	sub reconstructRec($$);
	
	sub reconstructRec($$) {
		my ($ref,$fuip) = @_;
		my $refType = ref($ref);
		if(not $refType) { 
			# i.e. this is a scalar and not really a reference
			return $ref;
		}elsif($refType eq "ARRAY") {
			for(my $i = 0; $i < @$ref; $i++) {
				$ref->[$i] = reconstructRec($ref->[$i],$fuip);
            };
			return $ref;
		}elsif($refType eq "HASH") {
			if(defined($ref->{class})) {
				my $class = $ref->{class};
				delete($ref->{class});
				# in case there is something wrong with the class, try to 
				# create something meaningful
				my $result;
				eval {
					$result = $class->reconstruct($ref,$fuip);
				};
				if($@) {
					$result = "FUIP::View"->reconstruct($ref,$fuip);
					$result->{content} = "Could not create view of type ".$class;
					$result->{title} = "Error" unless $result->{title};
					$result->{defaulted}{title} = '0';
					$result->{defaulted}{content} = '0';
					$result->{width} = 150 unless $result->{width};
					$result->{height} = 50 unless $result->{height};
				};
				return $result;
			};
			# normal hash
			for my $key (keys %$ref) {
				$ref->{$key} = reconstructRec($ref->{$key},$fuip);
			};	
			return $ref;
		};
	};
	
	
sub reconstruct($$$) {
	my ($class,$conf,$fuip) = @_;
	# this expects that $conf is already hash reference
	# and key "class" is already deleted
	my $self = reconstructRec($conf,$fuip);
	$self->{fuip} = $fuip;
	weaken($self->{fuip});
	$self = bless($self,$class);
	$self->setAsParent();
	return $self;
};


sub setAsParent($) {
	my ($self) = @_;
	# main::Log3(undef,1,"setAsParent: ".blessed($self));
	for my $field (keys %$self) {
		# by default, we assume that all arrays
		# contain some subclass of FUIP::View
		next if $field eq 'fuip';
		next if $field eq 'parent';
		if(ref($self->{$field}) eq "ARRAY") {
		    for my $entry (@{$self->{$field}}) {
			    # set me as parent
				if(blessed($entry) and $entry->isa("FUIP::View")) {
				    $entry->setParent($self);
				};	
		    };
		}elsif(blessed($self->{$field}) and $self->{$field}->isa("FUIP::View")) {
			# this is mainly for popups
			$self->{$field}->setParent($self);
		};	
	};		
};


sub setParent($$) {
	my ($self,$parent) = @_;
	FUIP::Exception::log('Trying to set empty parent') unless $parent;
	$self->{parent} = $parent;
	weaken($self->{parent});
};


sub getSystem($) {
	my $self = shift;
	my $sysid = defined($self->{sysid}) ? $self->{sysid} : '<inherit>';
	# sysid set and not set to inherit?
	return $sysid if $sysid and $sysid ne '<inherit>';
	# try parent
	unless(defined($self->{parent})) {
		main::Log3(undef,1,"undefined parent: ".blessed($self));
		main::Log3(undef,1,"undefined parent: ".$self->{title});
		FUIP::Exception::log('undefined parent'); 
	};
	
	if(blessed($self->{parent}) and $self->{parent}->isa("FUIP::View")) {
		return $self->{parent}->getSystem();
	}else{
		return FUIP::Systems::getDefaultSystem($self->{fuip});
	};	
};


sub getHTML_sysid($$) {
	my ($self,$view) = @_;
	my $sysid = $view->getSystem();
	return ' data-sysid="'.$sysid.'"';
};


sub getStructure($) {
	# class method
	# returns general structure of the view without instance values
	my ($class) = @_;
	return [
		{ id => "class", type => "class", value => $class },
		{ id => "title", type => "text", default => { type => "const", value => "Empty"} },
		{ id => "content", type => "text", default => { type => "const", value => "This is just empty"} },
		{ id => "width", type => "dimension" },
		{ id => "height", type => "dimension" }
		];
};


sub _fillFieldDefault($$) {
	my ($class,$field) = @_; 
	
	my $fType = "text";
	$fType = $field->{type} if defined $field->{type};
	#the class field?
	if($fType eq "class") {
		$field->{value} = $class;
		return;
	};
	#System id
	if($fType eq "sysid") {
		$field->{value} = '<inherit>';
		return;
	};
	# structured field?
	if($fType eq "device-reading") {
		$class->_fillFieldDefault($field->{device});
		$class->_fillFieldDefault($field->{reading});
		return;
	};
	# normal field
	if(defined($field->{default})) {
		# if defaulted is not there yet, set it to 1 (at the beginning, we should use the default)
		$field->{default}{used} = 1;
		if($field->{default}{type} eq "const") {
			$field->{value} = $field->{default}{value};
		};
	};
	# avoid "undefined"
	if(not defined $field->{value}) {
		if($fType eq "viewarray") {
			$field->{value} = [];
		}else{
			$field->{value} = "";
		};
	};	
};	


sub getDefaultFields($;$) {
	# class method
	# returns view structure with all "const" defaults filled
	# and defaulting set to "true"
	# $includes is a list of field types which are normally not visible
	my ($class,$includesInternals) = @_;
	my $result = $class->getStructure();  # without values
	# always add sysid
	# TODO: Maybe add on top somewhere
	# TODO: Maybe do the same for the class, if not there anyway
	push(@$result, { id => "sysid", type => "sysid" } );
	push(@$result, { id => "cssClasses", type => "css-class" } );
	
	if(not $includesInternals) {
		my @withoutInternals = grep {$_->{type} ne "internal"} @$result;
		$result = \@withoutInternals; 
	};
	for my $field (@$result) {
		$class->_fillFieldDefault($field);
	};
	return $result;
};


sub getUserCssClasses($) {
  my $self = shift;	
  
  return "" unless $self->{cssClasses};
  my $result = $self->{cssClasses};
  #replace comma with blanks (we allow comma as delimiter)
  $result =~ tr/,/ /;	
  #replace multiple whitespace by one whitespace
  $result =~ s/\s+/ /g;
  return $result;
};	


sub getCssClasses($$) {
    my ($self,$locked) = @_;
	
	my $userCssClasses = $self->getUserCssClasses();
	return $userCssClasses if $locked;
	
	my $result = 'fuip-draggable'.($self->isResizable() ? ' fuip-resizable' : '');
	$result .= ' '.$userCssClasses if $userCssClasses;
	return $result;
};	


sub createDefaultInstance($$$) {
	# class method
	# creates default instance for class $
	# $fuip is the FUIP instance this belongs to
	my ($class,$fuip,$parent) = @_;
	my $defaultFields = $class->getDefaultFields(1); #i.e. include internals
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
	
	bless($result,$class);
	$result->setParent($parent);
	return $result;
};


sub _fillField($$;$$) {
	my ($self,$field,$valueRef,$defaultRef) = @_; 
	
	my $fType = "text";
	$fType = $field->{type} if defined $field->{type};
	#the class field should already be filled
	return if($fType eq "class");
	
	$valueRef = $self->{$field->{id}} unless defined($valueRef);
	$defaultRef = $self->{defaulted}{$field->{id}} unless defined($defaultRef);

	# array?
	# TODO: default for arrays?
	if($fType eq "viewarray") {
		# fill value-array with config information of sub-views 
		$field->{value} = [];
		for my $item (@{$valueRef}) {
			push(@{$field->{value}}, $item->getConfigFields());
		};
		return;
	};
	
	# structured field?
	if($fType eq "device-reading") {
		# when changing the field type in the structure definition, it can happen
		# that $valueRef is not a hash. In this case, we just set the default
		# TODO Maybe remove completely
		#if(ref($valueRef) ne 'HASH' || ref($defaultRef) ne 'HASH') {
		#	$self->_fillField($field->{device}, "", $defaultRef);
		#	$self->_fillField($field->{reading}, "", $defaultRef);
		#}else{
			# If valueRef is not a HASH, then we just leave the field(s) empty or try to
			# force the default
			if(ref($valueRef) ne 'HASH') {
				FUIP::Exception::log("ValueRef $valueRef is not a hash.");
				$self->_fillField($field->{device},"", 1);
				$self->_fillField($field->{reading},"", 1);
			}else{;				
				#If the defaultRef is not a hash, then just use "do not default"
				$self->_fillField($field->{device},$valueRef->{device}, ref($defaultRef) eq 'HASH' ? $defaultRef->{device} : 0);
				$self->_fillField($field->{reading},$valueRef->{reading}, ref($defaultRef) eq 'HASH' ? $defaultRef->{reading} :0);
			};
		#};
		return;
	};
	
	# if valueRef (i.e. the value in the view) is not defined (yet), but there is a 
	# value in the field definition, then keep the value from the field definition
	# this e.g. happens if a new variable is created in a view template
	$field->{value} = $valueRef unless defined($field->{value}) and not defined($valueRef);
	if(defined($field->{default})) {
		if(defined($defaultRef)) {
			$field->{default}{used} = $defaultRef;
		};	
	};
	
	# For system ids, empty or blank means <inherit>
	if($fType eq 'sysid' and not $field->{value}) {
		$field->{value} = '<inherit>';
	};
};	
	

sub applyDefaultToField($$$){
	my ($self,$field,$path) = @_;
	# does this have a default setting at all?
	my $defaultDef = $field;
	for my $part (@$path) {
		$defaultDef = $field->{$part};
	};
	return unless defined $defaultDef->{default};
	$defaultDef = $defaultDef->{default};
	# is the default setting switched off?
	my $defaulted = $self->{defaulted};
	if(defined($defaulted->{$field->{id}})) {
		$defaulted = $defaulted->{$field->{id}};
		for my $part (@$path) {
		
			if(ref($defaulted) ne 'HASH') {
				FUIP::Exception::log("$defaulted is not a hash. Path $part");
				#Let's just assume that $defaulted is something sensible now. 
				#Probably the view structure has changed and $defaulted is 
				#anyway only used as a boolean below
				last;
			};
		
			# TODO maybe remove commented coding
			# if(ref($defaulted) eq 'HASH' and defined($defaulted->{$part})) {
			if(defined($defaulted->{$part})) {
				$defaulted = $defaulted->{$part};
			}else{
				$defaulted = 1;
				last;
			};	
		};
	}else{
		$defaulted = 1;
	};
	return unless $defaulted;
	# get default value
	my $defaultValue;
	if($defaultDef->{type} eq "const") {
		$defaultValue = $defaultDef->{value};
	}elsif($defaultDef->{type} eq "field") {
		my @defValPath = split(/-/,$defaultDef->{value});
		$defaultValue = $self;
		for my $field (@defValPath) {
			# TODO maybe remove commented part
			# last unless ref($defaultValue) eq 'HASH';
			$defaultValue = $defaultValue->{$field};
		};	
		$defaultValue = $defaultValue.$defaultDef->{suffix} if(defined($defaultDef->{suffix})); 
	}else{
		return; #something wrong
	};
	# get field reference to fill
	my $fieldRef = \$self->{$field->{id}};
	for my $part (@$path) {
		#Care for structure changes
		if(ref($$fieldRef) ne 'HASH') {
			$$fieldRef = {};
		};
		$$fieldRef->{$part} = "" unless defined($$fieldRef->{$part});
		$fieldRef = \${$fieldRef}->{$part};
	};
	# assign value
	$$fieldRef = $defaultValue;
};	
	
	
sub applyDefaults($) {
	# instance method
	# apply all (active) defaults to the instance
	my ($self) = @_;
	my $structure = $self->getStructure();
	for my $field (@$structure) {
		if($field->{type} eq "viewarray") {
			for my $subview (@{$self->{$field->{id}}}) {
				$subview->applyDefaults();
			};
		}elsif($field->{type} eq "device-reading") {
			$self->applyDefaultToField($field,["device"]);
			$self->applyDefaultToField($field,["reading"]);		
		}else{	
			$self->applyDefaultToField($field,[]);
		};	
	};
};	


sub addFlexFields($$) {
	# do we have flex fields?
	my ($self,$configFields) = @_;
	# the following allows multiple sets of flexfields
	for(my $i = 0; $i <= $#$configFields; $i++){
		next unless $configFields->[$i]{type} eq "flexfields";
		my $flexFieldsStr = $configFields->[$i]{value};
		$flexFieldsStr = $self->{$configFields->[$i]{id}} unless $flexFieldsStr;
		next unless $flexFieldsStr;
		my @flexfields = split(/,/,$flexFieldsStr);
		for my $id (@flexfields) {
			my $flexfield = $self->{flexstruc}{$id};
			$flexfield->{type} = "text" unless $flexfield->{type};
			$flexfield->{id} = $id;
			# do we have a default?
			if($flexfield->{default}) {	
				# if defaulted is not there yet, set it to 1 (at the beginning, we should use the default)
				$flexfield->{default}{used} = (defined $self->{defaulted}{$id} ? $self->{defaulted}{$id} : 1);
				if($flexfield->{default}{type} eq "const") {
					$flexfield->{value} = $flexfield->{default}{value};
				};
			};
			# avoid "undefined"
			$flexfield->{value} = "" unless defined $flexfield->{value};
			$flexfield->{value} = $self->{$id} if(defined $self->{$id});
			$flexfield->{flexfield} = 1;
			$i++;
			splice(@$configFields,$i,0,$flexfield);
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
	# do we have flex fields?
	$self->addFlexFields($result);
	return $result;
};

my %docu = (
	general => "Es wurde keine spezifische Dokumentation gefunden.<br>
				Eine View im Allgemeinen ist in FUIP eine zusammenh&auml;ngende Sicht auf die Daten z.B. eines Devices in FHEM. Man kann eine View normalerweise frei in einer Zelle (oder einem View Template oder auf einem Popup) frei positionieren. Au&szlig;erdem kann eine View mittels vom View-Typ abh&auml;ngiger Parameter konfiguriert werden.",
	class => "Dies ist der Typ (bzw. die \"Klasse\") der View.<br>
			  Der View-Typ bestimmt die Funktionalit&auml;t der View, welche Parameter sie hat und wie sie auf der Oberfl&auml;che aussieht.",
	title => "Dies ist sozusagen die &Uuml;berschrift der View-Instanz.<br>
			  Der Titel wird in der Regel nur auf dem Konfigurations-Popup verwendet. Meistens taucht dieses Feld nirgends auf der Oberfl&auml;che selbst auf.",
	sizing => "Ermittlung der Gr&ouml;&szlig;e der View<br>
			Es gibt prinzipiell drei verschiedene Mechanismen, wie die Gr&ouml;&szlig;e einer View bestimmt wird: <i>fixed</i>, <i>resizable</i> und <i>auto</i>:
			<ul>
				<li><b>fixed</b>: Die View berechnet selbst ihre Breite und H&ouml;he. Oft ist die Gr&ouml;&szlig;e dann tats&auml;chlich \"fix\", sie kann aber auch von der Konfiguration der View abh&auml;ngen.</li>
				<li><b>resizable</b>: Man kann die Gr&ouml;&szlig;e frei einstellen. Es erscheinen dann zwei Felder zum Eingeben von H&ouml;he und Breite auf dem Konfigurations-Popup. Au&szlig;erdem kann die rechte untere Ecke der View mit der Maus \"gezogen\" werden.</li>
				<li><b>auto</b>: Die View nimmt automatisch den kompletten Platz bis zur rechten unteren Ecke der Zelle (oder des Popups oder des View Templates) ein. D.h. die Gr&ouml;&szlig;e wird nur durch die Position der View bestimmt. Im Flex-Layout kann sich die View auch an Zellen flexibler Gr&ouml;&szlig;e anpassen.</li>
			</ul>",
	popup => "Hiermit kann ein Popup angelegt werden, welches durch Klick auf die View
			  ge&ouml;ffnet wird.<br>	
			  Wird die Checkbox (\"Default-Haken\") aktiviert, dann erscheint ein Button, &uuml;ber den das Popup bearbeitet werden kann. Ein Popup (oder auch \"Dialog\" erscheint auf der Bearbeitungsoberfl&auml;che wie eine FUIP-Seite mit einer einzigen Zelle.",
	device => "Hier wird das FHEM-Device angegeben, auf den sich die View bezieht.<br>
			  Es wird eine Werthilfe mit Filter- und Sortierm&ouml;glichkeit angeboten, &uuml;ber die man das Device ausw&auml;hlen kann. Manche Views bieten automatisch nur solche Devices an, die f&uuml;r die View sinnvoll sind.",
	reading => "FHEM-Reading, auf das sich die View bezieht.<br>
				Dieser Parameter bezieht sich immer auf ein Device-Feld (welches nicht unbedingt <i>device</i> hei&szlig;t) oder es besteht sogar aus zwei Teilfeldern, wobei in das erste Feld das FHEM-Device eingegeben werden muss. Beim Reading wird eine Werthilfe angeboten, die die Readings des zugeh&ouml;rigen Device auflistet. (Daher ist es immer sinnvoll, zuerst das Device auszuw&auml;hlen.)",
	label => "Das \"Label\" ist ein kurzer beschreibender Text, der in der View angezeigt
				wird. Das Label wird je nach Art der View z.B. vor einem Reading oder unter einem Symbol angezeigt. Man kann das Label auch weglassen, indem man es einfach leer l&auml;sst. (Dies ist ein allgemeiner Text f&uuml;r alle Views.)", 	
	icon => "Ein Icon...<br>
			Manche Views benutzen ein Icon zur Darstellung. Dieses kann hier ausgew&auml;hlt werden. Dazu wird eine Werthilfe angeboten, die alle m&ouml;glichen Icons auflistet.",
	layout => "Layout ausw&auml;hlen (Swiper aktivieren)<br>
			Normalerweise werden Views in Zellen und View Templates frei positioniert (<i>layout=position</i>). Man kann aber auch einen \"Swiper\" (oder \"Slider\") aktivieren, mit dem man die einzelnen Views sozusagen \"durchbl&auml;ttern\" bzw \"wischen\" kann (<i>layout=swiper</i>). Im Swiper-Layout werden weitere Felder zur Konfiguration aktiviert. Die Reihenfolge der Views wird durch deren Reihenfolge im Konfigurations-Popup festgelegt. Diese kann durch Drag&amp;Drop &uuml;ber die Titelbalken der einzelnen Views ge&auml;ndert werden.<br>
			Auch im Swiper-Layout ist es m&ouml;glich, Views aus einer Zelle heraus- bzw. hineinzuziehen. Beim \"in den Swiper Fallenlassen\" wird die View momentan als letzte in der Reihe angef&uuml;gt. D.h. es sieht im ersten Moment so aus, als ob die View verschwindet, sie ist aber nur ganz hinten.",
	autoplay => "Automatisch weiterschalten (Swiper-Layout)<br>
		Wenn hier ein Wert ungleich 0 eingegeben wird, dann werden die einzelnen Views automatisch weitergeschaltet. Der bei <i>autoplay</i> angegebene Wert ist die Zeit in Millisekunden, nachdem zur n&auml;chsten View weitergschaltet wird.",
	navbuttons => "Navigationspfeile (de-)aktivieren (Swiper-Layout)<br>
		Normalerweise erscheinen rechts und links vom Swiper-Widget Navigationspfeile. Diese k&ouml;nnen hiermit abgeschaltet werden.",
	pagination => "\"Punkte\" (de-)aktivieren (Swiper-Layout)<br>
		Normalerweise erscheinen unter dem Swiper-Widget Punkte, die den momentanen Zustand anzeigen und mit denen auch eine bestimmte View im Swiper angew&auml;hlt werden kann. Diese Punkte k&ouml;nnen hiermit abgeschaltet werden.",
	sysid => "System-Id, also Name des zugeh&ouml;rigen FHEM-Systems<br>
        Dieses Feld erscheint nur, wenn tats&auml;chlich mehrere FHEM-Systeme (\"Backends\") f&uuml;r die FUIP-Instanz definiert wurden. D.h. es wurden mindestens zwei der <i>backend_</i>-Attribute gesetzt. Die dadurch definierten Systeme erscheinen dann in der Auswahl f&uuml;r das Feld <i>sysid</i>. Damit kann man dann das System zur View, zur Zelle zum Dialog (Popup) oder zur Seite ausw&auml;hlen.<br>
		Standardwert ist <i>&lt;inherit&gt;</i>. Das bedeutet, dass das System vom &uuml;bergeordneten Objekt vererbt wird. Dabei wird von der Seite auf alle ihre Zellen und von der Zelle auf alle ihre Views vererbt. Wenn auch in der Seite <i>&lt;inherit&gt;</i> gesetzt ist, dann wird der Wert des Attributs <i>defaultBackend</i> benutzt.",
	cssClasses => "Zus&auml;tzliche CSS-Klassen<br>
Man kann den meisten Entit&auml;ten (Views, Zellen, Seiten, Popups) zus&auml;tzliche CSS-Klassen zuordnen, die man dann z.B. in einem Stylesheet (siehe Attribut <i>userCss</i>) verwendet werden kann. Allerdings sollte diese M&ouml;glichkeit mit Bedacht verwendet werden. Sp&auml;tere Entwicklungen in FUIP k&ouml;nnten dazu f&uuml;hren, dass eigene Definitionen nicht mehr wie gew&uuml;nscht funktionieren. Au&szlig;erdem kann es schwierig sein, die von FUIP (oder den verwendeten Widgets) vorgegebenen Formatangaben zu &uuml;bersteuern. Bei Farben wird z.B. meistens die Angabe \"!important\" gebraucht.<br>
Im Zweifelsfall ist es immer besser, \"eingebaute\" Funktionen zu verwenden, wie z.B. den \"Colours\"-Dialog."  
	);


sub getDocu($$;$) {
	my ($class,$fieldname,$onlySpecific) = @_;
	# do we have a specific doc of the class?
	my $classdocu = eval('\%'.$class.'::docu');
	if($classdocu) {
		if($fieldname) {
			return $classdocu->{$fieldname} if(exists $classdocu->{$fieldname});
		}else{
			return $classdocu->{general} if(exists $classdocu->{general});
		};
	};	
	# no specific docu
	return undef if $onlySpecific;
	if($fieldname) {
		return $docu{$fieldname} if(exists $docu{$fieldname});
		return "Es wurde keine Dokumentation zum Feld <i>".$fieldname."</i> gefunden.";
	};
	return $docu{general};
};	

# register me as selectable
$FUIP::View::selectableViews{"FUIP::View"}{title} = "Die leere View"; 

	
1;	