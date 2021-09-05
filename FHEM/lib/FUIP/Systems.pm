package FUIP::Systems;

use strict;
use warnings;


# getExplicitSystems
# Returns all connected FHEM systems, which are set
# explicitly in backend_.* attributes
# => result is { <name> => $backend_<name> }
#    with one entry for each backend_.*
# TODO: Performance, i.e. buffer somewhere or so
sub getExplicitSystems($) {
	my $hash = shift;
	
	my %result;
	# backend_.* attributes?
	for my $attrName (keys %{$main::attr{$hash->{NAME}}}) {
		next unless $attrName =~ m/^backend_(.*)$/;
		$result{$1} = $main::attr{$hash->{NAME}}{$attrName};
	};
	return \%result if(%result); 
	return undef;
};


# getSystems
# Returns all connected FHEM systems
# This depends on attributes backend_.* 
# - no backend_.* attributes set 
#     => result is { home => local }
#        i.e. the default system name is "home"
# - backend_.* is/are set
#     => result is { <name> => $backend_<name> }
#        with one entry for each backend_.*
sub getSystems($) {
	my $hash = shift;
	
	my $result = getExplicitSystems($hash);
	# are there backend_.* attributes?
	return $result if($result); 
	
	# return 'local' only
	return { 'home' => 'local' }; 
};


# TODO: buffer?
sub getNumSystems($) {
	my $hash = shift;
	my $systems = getSystems($hash);
	return scalar (keys %$systems);
};


# getSystemUrl
# Get URL for system
# TODO: Performance, i.e. buffer somewhere or so
sub getSystemUrl($$) {
	my ($hash,$sysid) = @_;
	
	# "local" is always "local"
	if($sysid eq 'local') {
	    return 'local';
	};	

	my $systems = getSystems($hash);
	return $systems->{$sysid};
};


# getDefaultSystem
# This is for downward compatibility and if no 
# system id is set for view/cell/page etc.
# depends on attribute defaultBackend
sub getDefaultSystem($) {
	my $hash = shift;
	my $systems = getSystems($hash);
	my $defaultSysid = main::AttrVal($hash->{NAME},"defaultBackend",undef);
	if(defined($defaultSysid) && defined($systems->{$defaultSysid})) {
	    return $defaultSysid;
	};
	# if there is no defaultBackend or it does not exist,
    # return "smallest" system id	
    return (sort keys %$systems)[0];
};


sub getDefaultSystemUrl($) {
	my $hash = shift;
	return getSystemUrl($hash,getDefaultSystem($hash));
};

1;
