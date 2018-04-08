package FUIP::View;

use strict;
use warnings;
use Scalar::Util qw(blessed weaken);

my %selectableViews;
	
	sub dimensions($;$$){
		my $self = shift;
		if (@_) {
			$self->{width} = shift;
			$self->{height} = shift;
		}	
		return ($self->{width}, $self->{height});
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
			return $ref->serialize($indent) if($ref->isa("FUIP::View"));
			return "";  #we can only handle views here
		};
		# otherwise, we allow SCALAR, ARRAY, HASH
		my $refType = ref($ref);
		if(not $refType) {   #not a reference, assuming scalar
			return "'".($ref =~ s/'/\\'/rg)."'";
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
				return $class->reconstruct($ref,$fuip);
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
		return bless($self,$class);
	};
	

sub getStructure($) {
	# class method
	# returns general structure of the view without instance values
	my ($class) = @_;
	return [
		{ id => "class", type => "class", value => $class },
		{ id => "title", type => "text", default => { type => "const", value => "Empty"} },
		{ id => "content", type => "text", default => { type => "const", value => "This is just empty"} },
		{ id => "width", type => "internal" },
		{ id => "height", type => "internal" }
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
	if(not $includesInternals) {
		my @withoutInternals = grep {$_->{type} ne "internal"} @$result;
		$result = \@withoutInternals; 
	};
	for my $field (@$result) {
		$class->_fillFieldDefault($field);
	};
	return $result;
};


sub createDefaultInstance($$) {
	# class method
	# creates default instance for class $
	# $fuip is the FUIP instance this belongs to
	my ($class,$fuip) = @_;
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
	return bless($result,$class);
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
		$self->_fillField($field->{device},$valueRef->{device}, $defaultRef->{device});
		$self->_fillField($field->{reading},$valueRef->{reading}, $defaultRef->{reading});
		return;
	};
	
	$field->{value} = $valueRef;
	if(defined($field->{default})) {
		if(defined($defaultRef)) {
			$field->{default}{used} = $defaultRef;
		};	
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
			$defaultValue = $defaultValue->{$field};
		};	
	}else{
		return; #something wrong
	};
	# get field reference to fill
	my $fieldRef = \$self->{$field->{id}};
	for my $part (@$path) {
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
	return $result;
}


# register me as selectable
$FUIP::View::selectableViews{"FUIP::View"}{title} = "The Empty View"; 

	
1;	