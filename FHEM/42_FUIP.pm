#
#
# 42_FUIP.pm
# written by Thorsten Pferdekaemper
#
##############################################
# $Id: 42_FUIP.pm 0099 2019-11-16 15:00:00Z ThorstenPferdekaemper $

package main;

sub
FUIP_Initialize($) {
	# load view modules
	FUIP::loadViews();
    my ($hash) = @_;
    $hash->{DefFn}     = "FUIP::Define";
	$hash->{SetFn}     = "FUIP::Set";
	$hash->{GetFn}     = "FUIP::Get";
    $hash->{UndefFn}   = "FUIP::Undef";
	FUIP::setAttrList($hash);
	$hash->{AttrFn}    = "FUIP::Attr";
	$hash->{NotifyFn}  = "FUIP::Notify";
	$hash->{parseParams} = 1;	
	# For FHEMWEB
	$hash->{'FW_detailFn'}    = 'FUIP::fhemwebShowDetail';
	# The following line means that the overview is shown
	# as header, even though there is a FW_detailFn
	$hash->{'FW_deviceOverview'} = 1;

    return undef;
 }


package FUIP;

use strict;
use warnings;
use POSIX qw(ceil);
use vars qw(%data);
use HttpUtils;
use Scalar::Util qw(blessed);
use File::Basename qw(basename);

use lib::FUIP::Model;
use lib::FUIP::View;
use lib::FUIP::Systems;
use lib::FUIP::Generator;

# selectable views
my $selectableViews = \%FUIP::View::selectableViews;

my $matchlink = "^\/?(([^\/]*(\/[^\/]+)*)\/?)\$";
my $fuipPath = $main::attr{global}{modpath} . "/FHEM/lib/FUIP/";

my $currentPage = "";


# Messages
my %messages;
# Messages have probably been seen by the user
# (Hash by FUIP device name)
my %messagesSeen;

sub setMessage($$$) {
	my ($hash,$id,$message) = @_;
	my $name = $hash->{NAME};
	$messages{$name} = {} unless exists $messages{$name};
	$messages{$name}{$id} = $message;
	$messagesSeen{$name} = 0;
};

sub removeMessage($$) {
	my ($hash,$id) = @_;
	my $name = $hash->{NAME};
	return unless exists $messages{$name};
	delete $messages{$name}{$id};
};

sub getMessages($) {
	my ($hash) = @_;
	my $name = $hash->{NAME};
	my @result;
	return \@result unless exists $messages{$name};
	for my $key (sort keys %{$messages{$name}}) {
		push(@result,$messages{$name}{$key});
	};
	return \@result;
};


# possible values of attributes can change...
sub setAttrList($) {
	my ($hash) = @_;
    $hash->{AttrList}  = "layout:gridster,flex locked:0,1 backend_.* backendNames baseWidth baseHeight cellMargin:0,1,2,3,4,5,6,7,8,9,10 pageWidth styleSchema:default,blue,green,mobil,darkblue,darkgreen,bright-mint styleColor viewportUserScalable:yes,no viewportInitialScale gridlines:show,hide snapTo:gridlines,halfGrid,quarterGrid,nothing toastMessages:all,errors,off styleBackgroundImage:";
	my $imageNames = getImageNames();
	$hash->{AttrList} .= join(",",@$imageNames);
	my $cssNames = getUserCssFileNames();
	if(@$cssNames) {
		$hash->{AttrList} .= " userCss:".join(",",@$cssNames);
	};	
	my $htmlNames = getUserHtmlFileNames();
	if(@$htmlNames) {
		$hash->{AttrList} .= " userHtmlBodyStart:".join(",",@$htmlNames);
	};	

	$hash->{AttrList} .= " loglevel:0,1,2,3,4,5 logtype:console,localstorage logareas";

	# Extra attribute for compatibility
	#fhemwebUrl and longPollType are only there for compatibility with earlier versions.
	if(not $main::init_done) {
		$hash->{AttrList} .= " fhemwebUrl longPollType";	
	};
}


# setAttrListDevice
# Set device specific attribute list
sub setAttrListDevice($) {
	my ($hash) = @_;
	# update module specific attribute list, just in case
	setAttrList($main::modules{FUIP});
	$hash->{'.AttrList'} = $main::modules{FUIP}{AttrList};
	
	my $systems = FUIP::Systems::getExplicitSystems($hash);
    # Add backend-attributes
	for my $system (sort keys %$systems) {
		$hash->{'.AttrList'} .= " backend_".$system;
	};
	# Add the first "free" from backend names
	my @backendNames = split(/,/, main::AttrVal($hash->{NAME},'backendNames','trillian,fenchurch,lintilla,alice,dionah'));	
	for my $system (@backendNames) {
		next if exists $systems->{$system};
		$hash->{'.AttrList'} .= " backend_".$system;
		last;
	};
	
	# Add possible values for defaultBackend
	$hash->{'.AttrList'} .= ' defaultBackend:'.join(",",sort keys %$systems);
};


# load view modules
sub loadViews() {
	my $viewsPath = $fuipPath . "View/";

	if(not opendir(DH, $viewsPath)) {
		main::Log3(undef, 1, "FUIP ERROR: Cannot read view modules");
		return;
	};	
	foreach my $m (sort readdir(DH)) {
		next if($m !~ m/(.*)\.pm$/);
		my $viewFile = $viewsPath . $m;
		if(-r $viewFile) {
			main::Log3(undef, 4, 'FUIP: Loading view: ' .  $viewFile);
			my $includeResult = do $viewFile;
			if(not $includeResult) {
				main::Log3(undef, 1, 'FUIP: Error in view module: ' . $viewFile . ":\n $@");
			}
		} else {
			main::Log3(undef, 1, 'FUIP: Error loading view module file: ' .  $viewFile);
		}
	}
	closedir(DH);
};


# determine possible image names (for background)
sub getImageNames() {
	my $imagesPath = $fuipPath . "images/";
	my @result;
	if(not opendir(DH, $imagesPath)) {
		main::Log3(undef, 1, "FUIP ERROR: Cannot read image directory");
		return \@result;
	};	
	foreach my $m (sort readdir(DH)) {
		next if($m !~ m/(.*)\.(jpg|png)$/);
		push(@result,$m);
	}
	closedir(DH);
	return \@result;
};


sub getUserFileNames($) {
	my ($suffix) = @_;
	my $pattern = '(.*)\.('.$suffix.')$';
	my $rex = qr/$pattern/;
	my @result;
	my $cfgPath = $fuipPath."config";
	# create directory if it does not exist
	if(not(-d $cfgPath)) {
		mkdir($cfgPath);
	};
	if(not opendir(DH, $cfgPath."/")) {
		main::Log3(undef, 1, "FUIP ERROR: Cannot read config directory");
		return \@result;
	};	
	foreach my $m (sort readdir(DH)) {
		next if($m !~ m/$rex/);
		push(@result,$m);
	}
	closedir(DH);
	return \@result;
};


# determine names of user css files
sub getUserCssFileNames() {
	return getUserFileNames("css");
};


# determine names of user html files
sub getUserHtmlFileNames() {
	return getUserFileNames("html");
};


#########################
sub addExtension($$$$) {
    my ($name,$func,$link,$friendlyname)= @_;

    # do some cleanup on link/url
    #   link should really show the link as expected to be called (might include trailing / but no leading /)
    #   url should only contain the directory piece with a leading / but no trailing /
    #   $1 is complete link without potentially leading /
    #   $2 is complete link without potentially leading / and trailing /
    $link =~ /$matchlink/;

    my $url = "/".$2;
    my $modlink = $1;

	if(exists($main::data{FWEXT}{$url})) {
		my $msg = 'Link "'.$url.'" already registered';
		if(defined($main::data{FWEXT}{$url}{deviceName})) {
			$msg .= ' by device '.$main::data{FWEXT}{$url}{deviceName};
		};	
		return $msg;
	};
    main::Log3($name, 3, "FUIP: Registering $name for URL $url");
    $main::data{FWEXT}{$url}{deviceName} = $name;
    $main::data{FWEXT}{$url}{FUNC} = $func;
    $main::data{FWEXT}{$url}{LINK} = $modlink;
    $main::data{FWEXT}{$url}{NAME} = $friendlyname;
	return undef;
}

sub removeExtension($) {
    my ($link)= @_;

    # do some cleanup on link/url
    #   link should really show the link as expected to be called (might include trailing / but no leading /)
    #   url should only contain the directory piece with a leading / but no trailing /
    #   $1 is complete link without potentially leading /
    #   $2 is complete link without potentially leading / and trailing /
    $link =~ /$matchlink/;

    my $url = "/".$2;

    my $name= $main::data{FWEXT}{$url}{deviceName};
    main::Log3 $name, 3, "Unregistering FUIP $name for URL $url...";
    delete $main::data{FWEXT}{$url};
}

##################

##################
sub Define($$$) {

  my ($hash, $a, undef) = @_;
  # return "Usage: define <name> FUIP <infix> <directory> <friendlyname>"  if(int(@a) != 5);
  my $name= $a->[0];
  # TODO: check if name allows to be used in an URL
  my $infix= lc($name)."/";
  my $directory= "./www/tablet";  # TODO: change via attribute?
  my $friendlyname= $name;

  $hash->{fhem}{infix}= $infix;
  $hash->{fhem}{directory}= $directory;
  $hash->{fhem}{friendlyname}= $friendlyname;

  my $msg = addExtension($name, "FUIP::CGI", $infix, $friendlyname);
  return $msg if($msg);
  
  $hash->{STATE} = $name;
  $hash->{pages} = {};
  $hash->{editOnly} = 0;
  # set default base dimensions
  $main::attr{$name}{baseWidth} = 142;
  $main::attr{$name}{baseHeight} = 108;  
  $main::attr{$name}{layout} = "gridster";
  # load old definition, if exists
  load($hash);
  $hash->{autosave} = "none";  # in case config file does not yet exist
  checkForAutosave($hash); 
  # Get device specific attributes
  setAttrListDevice($hash);
	
  # Do some stuff after init is ready	
  $hash->{NOTIFYDEV} = "global";
  
  return undef;
}


# attrLowLevel
# Set/delete attribute for automatic fixes
sub attrLowLevel($$$;$) {
	my ($hash,$cmd,$attr,$value) = @_;
	
	my $oldValue = main::AttrVal($hash->{NAME},$attr,undef);
	
	if($cmd eq 'set') {
		# Anyway like it should be
		return if(defined($oldValue) and $oldValue eq $value); 
		$main::attr{$hash->{NAME}}{$attr} = $value;	
		setMessage($hash,$attr.'Set',"Attribute $attr set to $value");
		$main::defs{global}{init_errors} .= "\nFUIP device ".$hash->{NAME}.": Attribute $attr set to $value";
		main::addStructChange("attr", $hash->{NAME}, "$hash->{NAME} $attr $value");
	}elsif($cmd eq 'del') {
		# Anyway like it should be
		return unless defined($oldValue);
		delete $main::attr{$hash->{NAME}}{$attr};
		setMessage($hash,$attr.'Del',"Attribute $attr deleted");
		$main::defs{global}{init_errors} .= "\nFUIP device ".$hash->{NAME}.": Attribute $attr deleted";
		main::addStructChange("deleteAttr", $hash->{NAME}, $attr);
	};
	
	# Anything about systems changed, refresh model cache
	if($attr =~ m/^backend_.*/ or $attr eq "defaultBackend") {
		FUIP::Model::refresh($hash->{NAME});
		setAttrListDevice($hash);
	};

};


sub Notify($$){
	my ($hash, $evtHash) = @_;
	my $ownName = $hash->{NAME}; # own name / hash
 
	my $devName = $evtHash->{NAME}; # Device that created the events
	my $events = main::deviceEvents($evtHash, 1);
	
	# SAVE? Check whether user might have seen messages and remove them
	if($devName eq "global" && grep(m/^SAVE$/, @{$events})) {
		if($messagesSeen{$ownName}) {
			delete $messages{$ownName};
		};	
	};

	# Only INITIALIZED and REREADCFG from global	
	return undef unless($devName eq "global" && grep(m/^INITIALIZED|REREADCFG$/, @{$events}));
	
	# The following is only for downward compatibility and to fix broken setups
	
	# Like in getSystems, but only backend_*-Attributes
	# TODO: Probably getSystems will later be anyway like that
	my %systems;
	# are there backend_.* attributes?
	for my $attrName (keys %{$main::attr{$hash->{NAME}}}) {
		next unless $attrName =~ m/^backend_(.*)$/;
		$systems{$1} = $main::attr{$hash->{NAME}}{$attrName};
	};
	
	# If fhemwebUrl is defined
	my $fhemweburl = main::AttrVal($hash->{NAME},"fhemwebUrl",undef);
	if($fhemweburl) {
	# 1. If there is already at least one backend_* Attribute
		if(%systems) {
	#    Check if the value of fhemwebUrl is in any of these
			unless(grep {$_ eq $fhemweburl} values %systems) {
	#    If yes, just remove it
	#    If no: 
	#         make sure that defaultBackend is set
				attrLowLevel($hash,'set','defaultBackend',FUIP::Systems::getDefaultSystem($hash));
	#         create a new backend_* Attribute with the value of fhemwebUrl
				my $num = 0;
				my $attrName = 'backend_old';
				while(exists $main::attr{$hash->{NAME}}{$attrName}) {
					$num++;
					$attrName = 'backend_old'.$num;
				};
				attrLowLevel($hash,'set',$attrName,$fhemweburl);
			};		
		}else{
	# 2. If there is no backend_* Attribute, but defaultBackend is set:
	#    create a backend_* Attribute with systemid "home" and value of fhemwebUrl
	#    set defaultBackend to "home"
	#    remove fhemwebUrl
	# 3. If there is no defaultBackend either
	#    same as 2
			attrLowLevel($hash,'set','backend_home',$fhemweburl);
			attrLowLevel($hash,'set','defaultBackend','home');
		};
		attrLowLevel($hash,'del','fhemwebUrl');
	}else{
	# If there is no fhemwebUrl defined
	# 1. If there is already at least one backend_* Attribute
	#    Do nothing
	# 2. If there is no backend_* Attribute, but defaultBackend is set:
	#    create a backend_* Attribute with systemid "home" and value "local"
	#    set defaultBackend to "home"
	# 3. If there is no defaultBackend either
	#    Do nothing
		if(not %systems and exists $main::attr{$hash->{NAME}}{defaultBackend}) {
			attrLowLevel($hash,'set','backend_home','local');
			attrLowLevel($hash,'set','defaultBackend','home');
		};
	};	
	
	# If a backend_* Attribute is there, but defaultBackend is not set or set to a
	# wrong system id
	# Determine defaultBackend and set it explicitly
	if(%systems) {
		attrLowLevel($hash,'set','defaultBackend',FUIP::Systems::getDefaultSystem($hash));
	};
	
	# remove longPollType
	attrLowLevel($hash,'del','longPollType');
	
	# re-determine attribute list to remove longPollType and fhemwebUrl
	setAttrListDevice($hash);
	
	#Avoid funny log entries
	return undef;  
};


##################
sub Undef($$) {

  my ($hash, $name) = @_;

  removeExtension($hash->{fhem}{infix});

  return undef;
}


sub Attr ($$$$) {
	my ( $cmd, $name, $attrName, $attrValue ) = @_;
	if($cmd eq "set" and $attrName eq "pageWidth") {
		if($attrValue < 100 or $attrValue > 2500) {
			return "pageWidth must be a number between 100 and 2500";
		}	
	};
	if($cmd eq "set" and $attrName eq "cellMargin") {
		if($attrValue < 0 or $attrValue > 10) {
			return "cellMargin must be a number between 0 and 10";
		}	
	};
	if($attrName eq "locked") {
		# "locked" changed -> remove "set" locks
		delete $main::defs{$name}->{lockIPs};	
	};
	# defaultBackend set to a non-existing value?
	if($cmd eq "set" and $attrName eq "defaultBackend") {
		my $systems = FUIP::Systems::getSystems($main::defs{$name});
		unless(defined($systems->{$attrValue})) {
			return '"'.$attrValue.'" is not defined as a backend system. Set Attribute backend_'.$attrValue.' first.';
		};
	};
	# Trying to delete the default backend?
	if($cmd eq "del" and $attrName =~ m/^backend_(.*)$/) {
		my $sysid = $1;
		my $defaultSysid = main::AttrVal($name,"defaultBackend",undef);
		if($defaultSysid and $sysid eq $defaultSysid) {
			return 'You cannot delete the default backend "'.$sysid.'". Change or delete the attribute defaultBackend first.';
		};
	};	
	
	# Backends cannot be named "index" or "overview"
	if($cmd eq "set" and $attrName =~ m/^backend_(index|overview)$/) {
		return 'A backend system cannot be named "index" or "overview". Choose a different name.'
	};	
	
	# When the first backend_.* attribute is introduced, we might have to make
	# sure that the "old" stuff still works.
	# I.e. if...
	# - A backend_.* attribute is set and
	# - defaultBackend is not set (yet) and
	# - there are already pages 
	# -> 
	# Make sure that defaultBackend is set 
	# If no backend-Attributes are set so far, make 
	# sure that there is a "local" backend
	if($main::init_done) {
		if($cmd eq "set" and $attrName =~ m/^backend_(.*)$/ 
				and not main::AttrVal($name,"defaultBackend",undef)
				and $main::defs{$name}{pages} ) {
			my $sysid = $1;
			my $found = 0;
			for my $attrName (keys %{$main::attr{$name}}) {
				next unless $attrName =~ m/^backend_(.*)$/;
				$found = 1;
				last;
			};	
			if($found) {
				#Make sure that the defaultBackend is kept
			    attrLowLevel($main::defs{$name},'set','defaultBackend',FUIP::Systems::getDefaultSystem($main::defs{$name}));
			}else{
				#Make sure that we have a system with URL "local"
				if($attrValue ne "local") {
					#We are not creating the "local" system, do it now
					if($attrName eq "backend_home") {
						$sysid = "local";
					}else{
						$sysid = "home";
					};	
					attrLowLevel($main::defs{$name},'set','backend_'.$sysid,"local");
				};		
				attrLowLevel($main::defs{$name},'set','defaultBackend',$sysid);
			};
		};	
	};
	
	# Anything about systems changed, refresh model cache
	if($attrName =~ m/^backend_.*/ or $attrName eq "defaultBackend" or $attrName eq "backendNames") {
		FUIP::Model::refresh($name);
		main::InternalTimer( main::gettimeofday(), 'FUIP::setAttrListDevice', $main::defs{$name}, 0);
	};
	return undef;
}


sub getCellMargin($) {
	my $hash = shift;
	return main::AttrVal($hash->{NAME},"cellMargin",5);	
};


sub determineMaxCols($;$) {
	my ($hash,$default) = @_;
	$default = 7 unless defined $default;
	my $baseWidth = main::AttrVal($hash->{NAME},"baseWidth",142);
	my $pageWidth = main::AttrVal($hash->{NAME},"pageWidth",undef);
	#should be compatible to what we did before
	return $default unless $pageWidth;
	use integer;
	my $maxCols = $pageWidth / ($baseWidth + getCellMargin($hash) * 2);
	no integer;
	return 1 unless $maxCols > 1;  # 0 or negative cols do not make sense
	return $maxCols;
};

sub urlBase($) {
	# return base path for the fuip device, i.e. usually /fhem/<device>
	my ($hash) = @_;
	return "$main::FW_ME/".lc($hash->{NAME});	
};

sub renderFuipInit($;$) {
	# include fuip.js, call fuipInit and include proper JQueryUI style sheet
	my ($hash,$gridlines) = @_;
	my $baseWidth = main::AttrVal($hash->{NAME},"baseWidth",142);
	my $baseHeight = main::AttrVal($hash->{NAME},"baseHeight",108);	
	if(not $gridlines) {
		$gridlines = main::AttrVal($hash->{NAME},"gridlines","hide");
	};	
	my $snapto = main::AttrVal($hash->{NAME},"snapTo","nothing");
	# webname is the contents of attribute webname of the FHEMWEB instance
	#         or /fhem as default
	return '<script src="'.urlBase($hash).'/fuip/js/fuip.js"></script>
  			<script>
				fuipInit({	webname:"'.$main::FW_ME.'", 
							baseWidth:'.$baseWidth.',
							baseHeight:'.$baseHeight.',
							cellMargin:'.getCellMargin($hash).',
							maxCols:'.determineMaxCols($hash,99).',
							gridlines:"'.$gridlines.'",
							snapTo:"'.$snapto.'" })
			</script>
			<link rel="stylesheet" href="'.urlBase($hash).'/fuip/css/theme.blue.css">';
};


sub getViewDependencies($$$) {
	my ($hash,$page,$suffix) = @_;
	
	# pageId might also be a dialog/viewtemplate instance
	
	# if($pageId) {
		# main::Log3(undef,1,"getViewDependencies page: ".$pageId);
	# }else{
		# main::Log3(undef,1,"getViewDependencies without pageId");
	# };
	
	my $pattern = '(.*)\.('.$suffix.')$';
	my $rex = qr/$pattern/;
	
	my %dependencies;

	# callback function to collect dependencies	
	my $cb = sub ($) {
				my ($view) = @_;
				my $deps = $view->getDependencies($hash);
				for my $dep (@$deps) {
					next unless $dep =~ m/$rex/;
					$dependencies{$dep} = 1;
				};
			};	
	
	# do this for all views
	_traverseViewsOfPage($hash,$cb,$page);

	my @result = sort keys %dependencies;
	return \@result;
};


sub renderHeaderHTML($$) {
	my ($hash,$pageId) = @_;
	my $dependencies = getViewDependencies($hash,$pageId,"js");
	# common script parts
	my $result = '<script src="'.urlBase($hash).'/fuip/js/fuip_common.js"></script>'."\n";
	$result .= renderSystemsFunction($hash);					
	for my $dep (@$dependencies) {
		$result .= '<script src="'.urlBase($hash).'/fuip/'.$dep.'"></script>'."\n";
	};
	$result .= 	'<link href="'.urlBase($hash).'/css/fhem-tablet-ui-user.css" rel="stylesheet" type="text/css">'."\n";
	return $result;
};


sub getBackgroundImage($) {
	#Determine background image for page
	my ($page) = @_;
	
	if(exists($page->{backgroundImage}) && $page->{backgroundImage}) {
		return $page->{backgroundImage};
	};		
	return main::AttrVal($page->{fuip}{NAME},"styleBackgroundImage",undef);
};	


sub renderBackgroundImage($$){
	my ($page,$pageWidth) = @_;
	my $result = '';
	my $backgroundImage = getBackgroundImage($page);
	if($backgroundImage) {
		# load background picture only after (most of?) the rest has loaded
		$result .= 
			'<script type="text/javascript">
				$(() =>
					$(\'body\').css(\'background\',\'#000000 url('.urlBase($page->{fuip}).'/fuip/images/'.$backgroundImage.') 0 0/';
		if($pageWidth) {
			$result .= $pageWidth.'px';
		}else{	
			$result .= 'cover';
		};
		$result .= ' no-repeat\'));
			</script>'."\n";
	};			
	return $result;
};


sub readTextFile($$) {
	my ($hash,$locator) = @_;
	# Filename starts with "<sysid>:" ?
	my ($sysid,$filename) = split(/:/,$locator,2);
	unless($filename) {
		$sysid = 'local';
		$filename = $locator;
	};
	return FUIP::Model::readTextFile($hash->{NAME},$filename,$sysid);
};


sub renderUserHtmlBodyStart($$) {
	my ($hash,$pageId) = @_;
	# get SVG defs
	my $dependencies = getViewDependencies($hash,$pageId,"svg");
	my $result = "";
	if($dependencies) {
		$result .= '<svg id="fuipsvg" class="basicdefs" style="position:absolute;height:0px;">'."\n";
		for my $dep (@$dependencies) {
			my $part = readTextFile($hash,$dep);
			$result .= $part."\n" if $part;
		};
		$result .= '</svg>';
	};
	# user HTML
	my $userHtml = main::AttrVal($hash->{NAME},"userHtmlBodyStart", undef);
	if($userHtml) {
		my $part = readTextFile($hash,"FHEM/lib/FUIP/config/".$userHtml);
		$result .= $part."\n" if $part;	
	};
	
	# hack to fix wrong weather icon sizes
	$result .= "\n"
		.'<style>
		.wi {
			line-height: inherit;
		}
		</style>'."\n";			

	return $result;
};	


# answers "GET fhem-tablet-ui-user.css"
sub getFtuiUserCss($$) {
	my ($hash,$pageId) = @_;
	# get contents of fuipchart.css and other view specific css files
	my $cssList = getViewDependencies($hash,$pageId,"css");
	# get contents of userCss (if Attribute userCss is set)
	my $userCss = main::AttrVal($hash->{NAME},"userCss", undef);
	push(@$cssList, 'FHEM/lib/FUIP/config/'.$userCss) if $userCss;
	# get contents of original fhem-tablet-ui-user.css (if exists)
	push(@$cssList, 'www/tablet/css/fhem-tablet-ui-user.css');
	# concatenate everything and return text...
	my $result = "";
	for my $css (@$cssList) {
		$result .= readTextFile($hash,$css)."\n";
	};
	# FUIP colors
	$result .= "\n/* FUIP colors */\n"
			.":root{\n";
	for my $key (keys %{$hash->{colors}}) {
		$result .= "    --fuip-color-".$key.": ".$hash->{colors}{$key}.";\n";
	};	
	$result .= "}\n";
	return ("text/css; charset=utf-8", $result);
};


sub renderCommonEditStyles($) {
	# returns style (css) definitions for all "edit" pages
	my $hash = shift;
	return 
		'.tablesorter-filter option {
			background-color:#fff;
		}
		select.tablesorter-filter {
			-moz-appearance: auto;
			-webkit-appearance: menulist;
			appearance: auto;
			border-radius: 0;
			padding: 4px !important;
		}
		select.fuip {
			-moz-appearance: auto;
			-webkit-appearance: menulist;
			appearance: auto;
			border-radius: 0;
			padding: 1px 0px !important;	
			border-style: inset;	
			border-width: 2px;
			border-color: initial;
			border-image: initial;
			width: initial;
			color: initial;
			background-color: initial;
		}
		option.fuip {
			background-color: initial;
		}
		.fuip-ui-icon-bright {
			background-image: url('.urlBase($hash).'/fuip/jquery-ui/images/ui-icons_ffffff_256x240.png);
		}'."\n";	
};


sub renderCommonCss($) {
    my $hash = shift;
	my $name = $hash->{NAME};
	my $lcName = lc($name);
	my $styleSchema = main::AttrVal($name,"styleSchema","default");
	my $styleSchemaLine = "";	
	$styleSchemaLine = '<link rel="stylesheet" href="'.urlBase($hash).'/fuip/css/fuip-'.$styleSchema.'-ui.css" type="text/css" />'."\n" unless $styleSchema eq "default"; 
	return '<link rel="shortcut icon" href="'.$main::FW_ME.'/icons/favicon" />
			<link rel="stylesheet" href="'.urlBase($hash).'/css/fhem-tablet-ui.css"  type="text/css" />'."\n"
			.'<link rel="stylesheet" href="'.urlBase($hash).'/fuip/css/fuip-default-ui.css" type="text/css" />'."\n"
			.$styleSchemaLine
			.'<link rel="stylesheet" href="'.urlBase($hash).'/lib/font-awesome.min.css"   type="text/css" />
			<link rel="stylesheet" href="'.urlBase($hash).'/fuip/fonts/nesges.css" type="text/css" />
			<link rel="stylesheet" href="'.urlBase($hash).'/fuip/fonts/icomoon-free.css" type="text/css" />'."\n";
};


sub renderFhemwebUrl($) {
	my $hash = shift;
	my $fhemweburl = FUIP::Systems::getDefaultSystemUrl($hash);
	if($fhemweburl eq 'local') {
		# if we do not have an external fhem, then we might still 
		# have a webname defined for the FHEMWEB device. In this 
		# case, the default /fhem does not work either in FTUI
		$fhemweburl = substr($main::FW_ME,1);
	};
	return '<meta name="fhemweb_url" content="'.$fhemweburl.'" />';
};


sub renderSystemsFunction($) {
	my $hash = shift;
	my $systems = FUIP::Systems::getSystems($hash);
	
	# getSystemUrl
	my $result = '<script type="text/javascript">
		ftui.getSystemUrl = function(sysid) {'."\n";
	foreach my $sysid (sort keys %$systems) {
		$result .= '    if(sysid == "'.$sysid.'"){'."\n";
		if($systems->{$sysid} eq 'local') {
			$result .= '    	return location.origin + "/'.substr($main::FW_ME,1).'";'."\n";
		}else{
			$result .= '        return "'.$systems->{$sysid}.'";'."\n";
		};
		$result .= '    };'."\n";			
	};
	# Always use the "default" connection as fallback
	$result .= '    return ftui.config.fhemDir;'."\n";
	$result .= '};'."\n";
	
	#getSystemIds
	$result .= 'ftui.getSystemIds = function() {'."\n";	
	$result .= '    return ["';
	$result .= join('","',(sort keys %$systems));
	$result .= '"];'."\n";
	$result .= '};'."\n";	
	
	#getDefaultSystemId
	$result .= 'ftui.getDefaultSystemId = function() {'."\n";
	$result .= '    return "'.FUIP::Systems::getDefaultSystem($hash).'"'."\n";
	$result .= '};'."\n";	
	
	$result .= '</script>'."\n";
	return $result;
};


sub renderCommonMetas($) {
	my $hash = shift;
	my $initialScale = main::AttrVal($hash->{NAME},"viewportInitialScale","1.0");
	my $userScalable = main::AttrVal($hash->{NAME},"viewportUserScalable","yes");
	my $loglevel = main::AttrVal($hash->{NAME},"loglevel",undef);
	my $logtype = main::AttrVal($hash->{NAME},"logtype",undef);
	my $logareas = main::AttrVal($hash->{NAME},"logareas",undef);
	return '<meta http-equiv="X-UA-Compatible" content="IE=edge" />
			<meta name="viewport" content="width=device-width, initial-scale='.$initialScale.', user-scalable='.$userScalable.'" />
			<meta name="mobile-web-app-capable" content="yes" />
			<meta name="apple-mobile-web-app-capable" content="yes" />'.
			#The manifest is mainly used to allow "add to home screen" for apple devices as well
			'<link rel="manifest" href="'.urlBase($hash).'/manifest.json" />'.
			renderFhemwebUrl($hash).
			($loglevel ? '<meta name="loglevel" content="'.$loglevel.'" />' : '').
			($logtype ? '<meta name="logtype" content="'.$logtype.'" />' : '').
			($logareas ? '<meta name="logareas" content="'.$logareas.'" />' : '');
};


sub renderToastSetting($) {
	my $hash = shift;
	my $toast = main::AttrVal($hash->{NAME},"toastMessages",0);
	return "" unless $toast;
	return ' data-fuip-toast="'.$toast.'"';
};


# renderPageSysid
# Renders sysid setting for the page-like entity
# i.e. page, popup or viewtemplate
sub renderPageSysid($;$) {
	my ($page,$locked) = shift;
	# only display?
	return "" if $locked;
	# might be called without a real page, e.g. by viewtemplate overview
	return "" unless $page;  
	my $sysid = $page->getSystem();
	return ' data-sysid="'.$sysid.'"';
};


sub renderAutoReturn($$) {
	my ($page,$locked) = @_;
	return "" unless $page->{autoReturn} and $page->{autoReturn} eq "on";
	my $seconds = $page->{returnAfter} + 0;  # make sure it's a number
	# if we are in maint mode, make sure the page stays long enough to do anything
	$seconds = 5 if(not $locked and $seconds < 5);
	$page->{returnTo} = "" unless $page->{returnTo}; # avoid undef
	return ' data-fuip-return-after='.$seconds.' data-fuip-return-to="'.$page->{returnTo}.'"';
};


sub renderTabletUiJs($) {
	my $hash = shift;
	return '<script src="'.urlBase($hash).'/js/fhem-tablet-ui.js"></script>';
	#return '<script src="/fhem/'.lc($hash->{NAME}).'/fuip/js/fuip_tablet_ui.js"></script>';
};


sub renderPage($$$) {
	my ($hash,$currentLocation,$locked) = @_;
	# falls $locked, dann werden die Editierfunktionen nicht mit gerendert
	my $page = $hash->{pages}{$currentLocation};
	my $title = $page->{title};
	$title = main::urlDecode($currentLocation) unless $title;
	$title = "FHEM Tablet UI by FUIP" unless $title;
	my $baseWidth = main::AttrVal($hash->{NAME},"baseWidth",142);
	my $baseHeight = main::AttrVal($hash->{NAME},"baseHeight",108);	
	my $styleColor = main::AttrVal($hash->{NAME},"styleColor","var(--fuip-color-foreground,#808080)");
	my $pageWidth = main::AttrVal($hash->{NAME},"pageWidth",undef);
	my $layout = main::AttrVal($hash->{NAME},"layout","gridster");
  	my $result = 
	   "<!DOCTYPE html>
		<html data-name=\"".$hash->{NAME}."\"".($locked ? "" : " data-pageid=\"".$currentLocation."\" data-editonly=\"".$hash->{editOnly}."\" data-layout=\"".$layout."\"").renderToastSetting($hash).renderAutoReturn($page,$locked).renderPageSysid($page,$locked).">
			<head>
				".renderCommonMetas($hash)."
				<meta name=\"widget_base_width\" content=\"".$baseWidth."\">
				<meta name=\"widget_base_height\" content=\"".$baseHeight."\">
				<meta name=\"widget_margin\" content=\"".getCellMargin($hash)."\">".
				($locked ? '<meta name="gridster_disable" content="1">' : "").
            "
			<script type=\"text/javascript\">
					// when using browser back or so, we should reload
					if(performance.navigation.type == 2){
						location.reload(true);
					};
				</script>
				<title>".$title."</title>"
				.'<link rel="stylesheet" href="'.urlBase($hash).'/lib/jquery.gridster.min.css" type="text/css">'
				.renderCommonCss($hash)
				."<script type=\"text/javascript\" src=\"".urlBase($hash)."/lib/jquery.min.js\"></script>
		        <script type=\"text/javascript\" src=\"".urlBase($hash)."/fuip/jquery-ui/jquery-ui.min.js\"></script>".
				($locked ? "" : "<link rel=\"stylesheet\" href=\"".urlBase($hash)."/fuip/jquery-ui/jquery-ui.css\">
								<!-- tablesorter -->
								 <script type=\"text/javascript\" src=\"".urlBase($hash)."/fuip/js/jquery.tablesorter.js\"></script>
								 <script type=\"text/javascript\" src=\"".urlBase($hash)."/fuip/js/jquery.tablesorter.widgets.js\"></script>").
				"<script type=\"text/javascript\" src=\"".urlBase($hash)."/lib/jquery.gridster.min.js\"></script>  
                ".
				($locked ? "" : renderFuipInit($hash)).
				renderTabletUiJs($hash)."
					<style type=\"text/css\">
	                .fuip-color {
		                color: ".$styleColor.";
                    }
					.swiper-wrapper > .swiper-slide { 
						position: relative;
					} \n";
	$result .= renderCommonEditStyles($hash) unless $locked;				
	$result .= "</style>\n"
				.renderHeaderHTML($hash,$currentLocation)
				.renderBackgroundImage($page,$pageWidth)
				.'</head>
            <body class="'.$page->getUserCssClasses($locked).'">'
				.renderUserHtmlBodyStart($hash,$currentLocation)."\n"
                .'<div class="gridster"';
	if($pageWidth) {
		$result .= ' style="width:'.$pageWidth.'px"';
	};
	$result .= '>
                    <ul>';
	# render Cells	
	$result .= renderCells($hash,$currentLocation,$locked);
	$result.= '</ul>
	           </div>'.
			   ($locked ? "" :
			   '<div id="viewsettings">
			   </div>
			   <div id="valuehelp">
			   </div>
				<div data-type="symbol" data-icon="ftui-door" class="hide"></div>
				<div data-type="symbol" data-icon="fa-volume-up" class="hide"></div>
				<div data-type="symbol" data-icon="mi-local_gas_station" class="hide"></div>
				<div data-type="symbol" data-icon="oa-secur_locked" class="hide"></div>
				<div data-type="symbol" data-icon="wi-day-rain-mix" class="hide"></div>
				<div data-type="symbol" data-icon="fs-ampel_aus" class="hide"></div>').	
			'<div id="inputpopup01">
			</div>
			'.renderCrashedMessage($hash,$locked).'			
       </body>
       </html>';
    return ("text/html; charset=utf-8", $result);
};


sub renderPageFlex($$) {
	my ($hash,$currentLocation) = @_;
	# falls $locked, dann werden die Editierfunktionen nicht mit gerendert
	my $page = $hash->{pages}{$currentLocation};
	my $title = $page->{title};
	$title = main::urlDecode($currentLocation) unless $title;
	$title = "FHEM Tablet UI by FUIP" unless $title;
	my $styleColor = main::AttrVal($hash->{NAME},"styleColor","var(--fuip-color-foreground,#808080)");
	my $pageWidth = main::AttrVal($hash->{NAME},"pageWidth",undef);
  	my $result = 
	   '<!DOCTYPE html>
		<html data-name="'.$hash->{NAME}.'"'.renderToastSetting($hash).renderAutoReturn($page,1).'>
			<head>
				'.renderCommonMetas($hash)."
				<script type=\"text/javascript\">
					// when using browser back or so, we should reload
					if(performance.navigation.type == 2){
						location.reload(true);
					};	
				</script>
				<title>".$title."</title>"
				.renderCommonCss($hash)
				.'<script type="text/javascript" src="'.urlBase($hash).'/lib/jquery.min.js"></script>
		        <script type="text/javascript" src="'.urlBase($hash).'/fuip/jquery-ui/jquery-ui.min.js"></script>
				'.renderTabletUiJs($hash).'
				<style type="text/css">
	                .fuip-color {
		                color: '.$styleColor.';
                    }
					#fuip-flex-menu {
						display:flex;
						flex-direction:column;
					}
					#fuip-flex-menu-toggle {
						display:none;
						z-index:12;
					}
					#fuip-flex-title {
						display:flex;
					}	
					#fuip-flex-main {
						display:flex;
						flex-wrap:wrap;
					}	
					@media only screen and (max-width: 768px) {
						#fuip-flex-menu {
							display:none;
						}
						#fuip-flex-menu.fuip-flex-menu-show {
							display:flex;
						}
						#fuip-flex-menu-toggle {
							display:initial;
						}
					}
                </style>'
				.renderHeaderHTML($hash,$currentLocation)
				.renderBackgroundImage($page,$pageWidth)
				.'</head>
            <body class="'.$page->getUserCssClasses(1).'">'
				.renderUserHtmlBodyStart($hash,$currentLocation)."\n"	
                .'<div style="display:flex;"';
	# TODO: does the following make any sense?
	#if($pageWidth) {
	#	$result .= ' style="width:'.$pageWidth.'px"';
	#};
	$result .= '>';
	# render Cells	
	$result .= renderCellsFlex($hash,$currentLocation);
	$result.= '</div>
			<div id="inputpopup01">
			</div>	
       </body>
       </html>';
    return ("text/html; charset=utf-8", $result);
};


sub renderPageFlexMaint($$) {
	my ($hash,$currentLocation) = @_;
	my $page = $hash->{pages}{$currentLocation};
	my $title = $page->{title};
	$title = main::urlDecode($currentLocation) unless $title;
	$title = "FHEM Tablet UI by FUIP" unless $title;
	my $baseWidth = main::AttrVal($hash->{NAME},"baseWidth",142);
	my $baseHeight = main::AttrVal($hash->{NAME},"baseHeight",108);	
	my $styleColor = main::AttrVal($hash->{NAME},"styleColor","var(--fuip-color-foreground,#808080)");
	my $pageWidth = main::AttrVal($hash->{NAME},"pageWidth",undef);
	my $initialScale = main::AttrVal($hash->{NAME},"viewportInitialScale","1.0");
	my $userScalable = main::AttrVal($hash->{NAME},"viewportUserScalable","no");
  	my $result = 
	   "<!DOCTYPE html>
		<html data-name=\"".$hash->{NAME}."\" data-pageid=\"".$currentLocation."\" data-editonly=\"".$hash->{editOnly}."\" data-layout=\"flex\"".renderToastSetting($hash).renderAutoReturn($page,0).renderPageSysid($page).">
			<head>
				".renderCommonMetas($hash)."
				<script type=\"text/javascript\">
					// when using browser back or so, we should reload
					if(performance.navigation.type == 2){
						location.reload(true);
					};	
				</script>
				<title>".$title."</title>"
				.renderCommonCss($hash)
				.'<script type="text/javascript" src="'.urlBase($hash).'/lib/jquery.min.js"></script>
		        <script type="text/javascript" src="'.urlBase($hash).'/fuip/jquery-ui/jquery-ui.min.js"></script>
				<link rel="stylesheet" href="'.urlBase($hash).'/fuip/jquery-ui/jquery-ui.css">
								<!-- tablesorter -->
								 <script type="text/javascript" src="'.urlBase($hash).'/fuip/js/jquery.tablesorter.js"></script>
								 <script type="text/javascript" src="'.urlBase($hash).'/fuip/js/jquery.tablesorter.widgets.js"></script>
				'.renderTabletUiJs($hash)."\n".				 
                renderFuipInit($hash).
				"<style type=\"text/css\">
	                .fuip-color {
		                color: ".$styleColor.";
                    }
					.fuip-flex-region {
						margin:".(getCellMargin($hash)-1)."px;
						border:solid;
						border-width:1px;
						border-color:var(--fuip-color-foreground,#808080);
						display:grid;
						grid-auto-columns:".$baseWidth."px;
						grid-auto-rows:".$baseHeight."px;
						grid-gap:".(getCellMargin($hash)*2)."px;
						place-content:start;
					}
					".renderCommonEditStyles($hash).	
                "</style>"
				.renderHeaderHTML($hash,$currentLocation)
				.renderBackgroundImage($page,$pageWidth)
				.'</head>
            <body class="'.$page->getUserCssClasses(0).'">'
				.renderUserHtmlBodyStart($hash,$currentLocation)."\n"	
		.'<div style="display:flex">
			<div id="fuip-flex-menu" class="fuip-flex-region">'.renderCellsFlexMaint($hash,$currentLocation,"menu").'</div>
			<div style="display:flex;flex-direction:column;">
				<div id="fuip-flex-title" class="fuip-flex-region">'.renderCellsFlexMaint($hash,$currentLocation,"title").'</div>
				<div id="fuip-flex-main" class="fuip-flex-region">'.renderCellsFlexMaint($hash,$currentLocation,"main").'</div>
			</div>				
 		</div>
			   <div id="viewsettings">
			   </div>
			   <div id="valuehelp">
			   </div>
				<div data-type="symbol" data-icon="ftui-door" class="hide"></div>
				<div data-type="symbol" data-icon="fa-volume-up" class="hide"></div>
				<div data-type="symbol" data-icon="mi-local_gas_station" class="hide"></div>
				<div data-type="symbol" data-icon="oa-secur_locked" class="hide"></div>
				<div data-type="symbol" data-icon="wi-day-rain-mix" class="hide"></div>
				<div data-type="symbol" data-icon="fs-ampel_aus" class="hide"></div>	
			<div id="inputpopup01">
			</div>
			'.renderCrashedMessage($hash,0).'	
       </body>
       </html>';
    return ("text/html; charset=utf-8", $result);
};


sub findDialogFromFieldId($$$;$) {
	# gets the FUIP::Dialog instance at the "end" of the field id
	# if this is not a dialog, it is created and assigned to the field of 
	# the related view
	# $cKey: container key. Either pageid/cellid or templateid
	my ($hash,$cKey,$fieldid,$prefix) = @_;
	
	$prefix = ($prefix ? $prefix : "");
	# find the dialog (we start with the container, i.e. cell or view template
	my $dialog;
	if(exists($cKey->{$prefix."pageid"})) { 
		#The stored page id might be an "old" one
		decodePageid($hash,$cKey->{$prefix."pageid"});
		$dialog = $hash->{pages}{$cKey->{$prefix."pageid"}}{cells}[$cKey->{$prefix."cellid"}];
	}else{
		$dialog = $hash->{viewtemplates}{$cKey->{$prefix."templateid"}};
	};	
	
	my @fieldIdSplit = split(/-/,$fieldid);
	# $fieldid should have the form like views-1-popup-views-4-popup-views...
	# or in general
	# <name>-<num>-<name>-<name>-<num>-<name>...
	my $view;
	my $popupName;
	while(@fieldIdSplit) {
		$view = $dialog->{shift(@fieldIdSplit)}[shift(@fieldIdSplit)];
		$popupName = shift(@fieldIdSplit);
		$dialog = $view->{$popupName};
	};	
	# if the dialog maintenance is called, we can assume that the "popup"
	# field is not defaulted (i.e. inactive) and that we need a dialog instance
	if( not blessed($dialog) or not $dialog->isa("FUIP::Dialog")) {
		$dialog = FUIP::Dialog->createDefaultInstance($hash,$view);
		$view->{$popupName} = $dialog;
		$view->{defaulted}{$popupName} = 0;
	};	
	return $dialog;
};


sub renderPopupMaint($$) {
	my ($hash,$request) = @_;
	# get pageid, cellid and fieldid
	my $urlParams = urlParamsGet($request);
	# TODO: error management
	return undef unless (exists($urlParams->{pageid}) and exists($urlParams->{cellid})) 
					or exists($urlParams->{templateid});
	return undef unless exists $urlParams->{fieldid};

	# find the dialog and render it	
	my $dialog = findDialogFromFieldId($hash, $urlParams, $urlParams->{fieldid});
	$currentPage = $dialog;
	
	my $title = "Maintain Popup Content";
	my $styleColor = main::AttrVal($hash->{NAME},"styleColor","var(--fuip-color-foreground,#808080)");
  	my $result = 
	   "<!DOCTYPE html>
		<html data-name=\"".$hash->{NAME}."\" ";
	if(exists($urlParams->{pageid})) {	
		$result .= 'data-pageid="'.$urlParams->{pageid}.'" 
					data-cellid="'.$urlParams->{cellid}.'" ';
	}else{
		$result .= 'data-viewtemplate="'.$urlParams->{templateid}.'" ';
	};	
	$result .= "data-fieldid=\"".$urlParams->{fieldid}."\"
				data-editonly=\"".$hash->{editOnly}."\"".renderToastSetting($hash).renderPageSysid($dialog).">
			<head>
	            <title>".$title."</title>
				".renderCommonCss($hash).'
				<script type="text/javascript" src="'.urlBase($hash).'/lib/jquery.min.js"></script>
		        <script type="text/javascript" src="'.urlBase($hash).'/fuip/jquery-ui/jquery-ui.min.js"></script>'.
				'<link rel="stylesheet" href="'.urlBase($hash).'/fuip/jquery-ui/jquery-ui.css">
								<!-- tablesorter -->
								 <script type="text/javascript" src="'.urlBase($hash).'/fuip/js/jquery.tablesorter.js"></script>
								 <script type="text/javascript" src="'.urlBase($hash).'/fuip/js/jquery.tablesorter.widgets.js"></script>'.
				'<script type="text/javascript" src="'.urlBase($hash).'/lib/jquery.gridster.min.js"></script>'.
                renderTabletUiJs($hash).
				renderFuipInit($hash).
				"<style type=\"text/css\">
	                .fuip-color {
		                color: ".$styleColor.";
                    }
					".renderCommonEditStyles($hash).
                "</style>".
				renderFhemwebUrl($hash).
				'<script>
					$( function() {
						$( "#popupcontent" ).resizable({
							stop: onResize
						});
						$("#popupsettingsbutton").button({
							icon: "ui-icon-gear",
							showLabel: false
						});	
						$("#popuparrangebutton").button({
							icon: "ui-icon-calculator",
							showLabel: false
						});	
						$("#popupmenu").controlgroup({
							direction: "vertical"
						});	
					} );
				</script>'."\n"
				.renderHeaderHTML($hash,$dialog)
            ."</head>
            <body";
	my ($width,$height) = $dialog->dimensions();	
	$result .= '>'."\n"
				.renderUserHtmlBodyStart($hash,$dialog);
	$result .= '<div style="display:flex;"><div style="display:inline-flex;margin:20px;">
		<div id="popupcontent" class="'.$dialog->getCssClasses(0).'"
			style="width:'.$width.'px;height:'.$height.'px;border:0;border-bottom:1px solid #aaa;
					box-shadow: 0 3px 9px rgba(0, 0, 0, 0.5);">
				<header class="fuip-cell-header">'.$dialog->{title}.'</header>';
	$result .= $dialog->getHTML(0);  # this is maint, so never locked	
	$result .= '</div>'."\n";
		$result .= '<div id="popupmenu" style="margin-left:5px;">
					<button id="popupsettingsbutton" type="button" 
							onclick="openSettingsDialog(\'dialog\')">Settings</button>
					<button id="popuparrangebutton" type="button" 
							onclick="autoArrange()">Arrange views (auto layout)</button>		
				</div></div></div>'."\n";
	$result .=	'<div id="viewsettings">
		</div>
		<div id="valuehelp">
		</div>
		'.renderCrashedMessage($hash,0).'
       </body>
       </html>';
    return ("text/html; charset=utf-8", $result);
};


sub renderViewTemplateMaint($$) {
	my ($hash,$request) = @_;
	# get template id
	my $urlParams = urlParamsGet($request);
	# TODO: error management
	my $templateid = exists($urlParams->{templateid}) ? $urlParams->{templateid} : "";
	# find the dialog and render it	
	my $viewtemplate;
	$currentPage = undef;
	my $gridlines = undef;
	if($templateid) {
		if(not exists($hash->{viewtemplates}{$templateid})) {   
			$hash->{viewtemplates}{$templateid} = FUIP::ViewTemplate->createDefaultInstance($hash,$hash);
			$hash->{viewtemplates}{$templateid}{id} = $templateid;
		};
		$viewtemplate = $hash->{viewtemplates}{$templateid};
		$currentPage = $viewtemplate;  
	}else{
		$gridlines = "hide";
		$currentPage = $hash->{viewtemplates};
	};	
	my $title = "Maintain View Template".($templateid ? " ".$templateid : "s");
	my $styleColor = main::AttrVal($hash->{NAME},"styleColor","var(--fuip-color-foreground,#808080)");
  	my $result = 
	   "<!DOCTYPE html>
		<html data-name=\"".$hash->{NAME}."\" data-viewtemplate=\"".$templateid."\" 
				data-editonly=\"".$hash->{editOnly}."\"".renderToastSetting($hash).renderPageSysid($viewtemplate).">
			<head>
				<script type=\"text/javascript\">
					// when using browser back or so, we should reload
					if(performance.navigation.type == 2){
						location.reload(true);
					};	
				</script>
	            <title>".$title."</title>"
				.renderCommonCss($hash)
				.'
				<script type="text/javascript" src="'.urlBase($hash).'/lib/jquery.min.js"></script>
		        <script type="text/javascript" src="'.urlBase($hash).'/fuip/jquery-ui/jquery-ui.min.js"></script>'.
				'<link rel="stylesheet" href="'.urlBase($hash).'/fuip/jquery-ui/jquery-ui.css">
								<!-- tablesorter -->
								 <script type="text/javascript" src="'.urlBase($hash).'/fuip/js/jquery.tablesorter.js"></script>
								 <script type="text/javascript" src="'.urlBase($hash).'/fuip/js/jquery.tablesorter.widgets.js"></script>'.
                renderTabletUiJs($hash).
				renderFuipInit($hash,$gridlines).
				"<style type=\"text/css\">
	                .fuip-color {
		                color: ".$styleColor.";
                    }
					a:link, a:visited {
						color: var(--fuip-color-symbol-active);
					}	
					a:hover {
						color: var(--fuip-color-foreground);
					}	
					".renderCommonEditStyles($hash).
                "</style>".
				renderFhemwebUrl($hash).
				'<script>
					$( function() {
						$( "#templatecontent" ).resizable({
							stop: onResize
						});
						$("#viewtemplatesettingsbutton").button({
							icon: "ui-icon-gear",
							showLabel: false
						});	
						$("#viewtemplatearrangebutton").button({
							icon: "ui-icon-calculator",
							showLabel: false
						});	
						$("#viewtemplateexportbutton").button({
							icon: "ui-icon-arrowstop-1-s",
							showLabel: false
						});	
						$("#viewtemplaterenamebutton").button({
							// label: "R"
						});
						$("#viewtemplatedeletebutton").button({
							icon: "ui-icon-trash",
							showLabel: false
						});
						$("#viewtemplatemenu").controlgroup({
							direction: "vertical"
						});	
					});
				</script>'."\n"
				.renderHeaderHTML($hash,$currentPage)
            ."</head>
            <body style='text-align:left;'";
	$result .= '>'."\n"
				.renderUserHtmlBodyStart($hash,$currentPage)."\n"
	.'<h1 style="text-align:left;margin-left:3em;color:var(--fuip-color-symbol-active);">'.($templateid ? 'View Template '.$templateid.($viewtemplate->{title} ? ' ('.$viewtemplate->{title}.')' : "") : 'Maintain View Templates').'</h1>';
	# check view template id
	if($templateid) {
		my $msg = _checkViewTemplateId($templateid);
		if($msg) {
			$result .= '<p style="color:red;margin-left:20px">'.$msg.'</p>
						<p style="color:red;margin-left:20px">This message is only a warning, but you should rename or delete this view template to avoid issues in the future.</p>';
		};
	};
	$result .= '<div style="display:flex;flex-wrap:wrap;">'
	.'<div style="margin:20px">'."\n";
	# list of all view templates
	$hash->{viewtemplates} = {} unless $hash->{viewtemplates};
	$result .= "<ul>\n";
	$result .= '<li	style="text-align:left;list-style-type:circle;color:var(--fuip-color-symbol-active);">
						<a href="javascript:void(0);" 
							onclick="window.location.replace(\''.urlBase($hash).'/fuip/viewtemplate\')">
					Show all (overview)
					</a></li>
				<li style="text-align:left;list-style-type:circle;color:var(--fuip-color-symbol-active);"><a href="javascript:void(0);" onclick="dialogCreateNewViewTemplate();">Create new</a></li> 
				<li style="text-align:left;list-style-type:circle;color:var(--fuip-color-symbol-active);"><a href="javascript:void(0);" onclick="dialogImportViewTemplate();">Import</a></li> 
				<br>'."\n";
	for my $viewtemplate (sort keys %{$hash->{viewtemplates}}) {
		$result .= '<li	style="text-align:left;list-style-type:circle;color:var(--fuip-color-symbol-active);">
						<a href="javascript:void(0);" 
							onclick="window.location.replace(\''.urlBase($hash).'/fuip/viewtemplate?templateid='.$viewtemplate.'\')">
					FUIP::VTempl::'.$viewtemplate.' ('.$hash->{viewtemplates}{$viewtemplate}{title}.')
					</a></li>'."\n";
	};				
	$result .= '</ul></div>'."\n";
	if($templateid) {
		my ($width,$height) = $viewtemplate->dimensions();	
		$result .= '<div style="display:inline-flex;margin:20px;">
		<div id="templatecontent" class="fuip-droppable fuip-cell"
			style="width:'.$width.'px;height:'.$height.'px;border:0;border-bottom:1px solid #aaa;
					text-align:center;
					border-radius:0px;
					box-shadow: 0 3px 9px rgba(0, 0, 0, 0.5);">';
		$result .= $viewtemplate->getHTML(0);  # this is maint, so never locked	
		$result .= '</div>'."\n";
		$result .= '<div id="viewtemplatemenu" style="margin-left:5px;">
					<button id="viewtemplatesettingsbutton" type="button" 
							onclick="openSettingsDialog(\'viewtemplate\')">Settings</button>
					<button id="viewtemplatearrangebutton" type="button" 
							onclick="autoArrange()">Arrange views (auto layout)</button>	
					<button id="viewtemplateexportbutton" type="button" 
							onclick="exportViewTemplate()">Export view template</button>			
					<button id="viewtemplaterenamebutton" type = "button"
							onclick="viewTemplateRename(\''.$hash->{NAME}.'\',\''.$templateid.'\')"
							title="Rename view template"
							style="height:27.38px;"><span style="position:absolute;left:8.3px;top:5.2px;">R</span></button>			
					<button id="viewtemplatedeletebutton" type = "button"
							onclick="viewTemplateDelete(\''.$hash->{NAME}.'\',\''.$templateid.'\')">Delete view template</button>
				</div></div>'."\n";
		# display usage of this template
		$result .= '<div style="margin:20px;" class="fuip-whereusedlist" data-fuip-type="viewtemplate" data-fuip-templateid='.$templateid.'></div>'."\n";		
	}else{	
		for my $key (sort keys %{$hash->{viewtemplates}}) {
			my $viewtemplate = $hash->{viewtemplates}{$key};
			my ($width,$height) = $viewtemplate->dimensions();	
			$result .= '<div class="fuip-cell"
			style="position:relative;width:'.$width.'px;height:'.$height.'px;border:0;border-bottom:1px solid #aaa;
					text-align:center;
					border-radius:0px;
					box-shadow: 0 3px 9px rgba(0, 0, 0, 0.5);
					border: 1px solid rgba(0, 0, 0, 0.1);
					margin:20px;">'."\n";
			$result .= $viewtemplate->getHTML(1);  # always locked	
			$result .= '<div onclick="window.location.replace(\''.urlBase($hash).'/fuip/viewtemplate?templateid='.$key.'\')" title="click to change" style="position:absolute;left:0;top:0;width:100%;height:100%;z-index:11;background:var(--fuip-color-background,rgba(255,255,255,.1));opacity:0.1;"></div>';
			$result .= '</div>'."\n";
		};
	};
	$result .= '</div>
		<div id="viewsettings">
		</div>
		<div id="valuehelp">
		</div>
		<div id="inputpopup"></div>
		'.renderCrashedMessage($hash,0).'
       </body>
       </html>';
    return ("text/html; charset=utf-8", $result);
};


sub findPositions($$;$); # forward declaration as it calls itself

sub findPositions($$;$) {
	my ($hash,$pageId,$region) = @_;
	# if there is no $region, but we are using flex layout,
	# this needs to be called for menu,title and main
	if(not $region) {
		my $layout = main::AttrVal($hash->{NAME},"layout","gridster");
		if($layout eq "flex") {
			findPositions($hash,$pageId,"menu");
			findPositions($hash,$pageId,"title");
			findPositions($hash,$pageId,"main");
			return;
		};	
	};
	my $cells = $hash->{pages}{$pageId}{cells};
	# TODO: max cols might make some sense for flex, but not 100%
	my $maxCols = determineMaxCols($hash);
	if($region and $region eq "menu") {
		$maxCols = 1;
	}elsif($region) {
		$maxCols--;
	};	
	# find positions for all views
	# cells array:
    #   0 or undef means that the cell is free
    #   everything else means that the cell is occupied 	
	#   the left upper entry of an occupied block contains the reference to "its" view
	#   all other entries of an occupied block contain 1                
	my @places; 	
	# occupy places for cells which are already positioned
	for my $cell (@{$cells}) {
		my ($x,$y) = $cell->position();
		next unless(defined($x) and defined($y));
		next if($region and $region ne $cell->{region}); # flex
		# get dimensions
		my @dim = $cell->dimensions();
		for (my $yv = $y; $yv < $y + $dim[1]; $yv++) {
			for (my $xv = $x; $xv < $x + $dim[0]; $xv++) {
				$places[$xv][$yv] = 1;
			}	
		}	
	};
	
	for my $cell (@$cells) {
		my ($x,$y) = $cell->position();
		# ignore if already positioned
		next if(defined($x) and defined($y));
		# flex
		next if($region and $region ne $cell->{region});
		# get dimensions
		my @dim = $cell->dimensions();
		# find a nice free spot
		my $found = 0;
		for ($y = 0; 1; $y++) {
			# for each column in the row
			# we need to check after the loop body to give
			# views a chance which are actually wider than the page
			for ($x=0; 1; $x++) {
				$found = 1;
				# check dimensions of view
				for (my $yv = $y; $yv < $y + $dim[1]; $yv++) {
					for (my $xv = $x; $xv < $x + $dim[0]; $xv++) {
						if($places[$xv][$yv]) {  # occupied
							$found = 0;
							last;
						}	
					}	
					last unless $found;
				}
				last if $found or $x + $dim[0] >= $maxCols;
			}
			last if $found;
	    };
		# "not found" would be very weird here.
		# TODO: What to do?
		main::Log3($hash, 1, "FUIP: No place found for cell") unless $found;
		# now occupy the place
		for (my $yv = $y; $yv < $y + $dim[1]; $yv++) {
			for (my $xv = $x; $xv < $x + $dim[0]; $xv++) {
				$places[$xv][$yv] = 1;
			}	
		}	
		# and remember where this cell goes
		$cell->position($x,$y);
	};
};


sub renderGearsForCell($) {
	# returns the "gears" to open the config popup
	my ($cellid) = @_;
	return '<span style="position:absolute;right:1px;top:0;z-index:12;" class="fa-stack fa-lg"
				onclick="openSettingsDialog(\'cell\',\''.$cellid.'\')">
				<i class="fa fa-square-o fa-stack-2x"></i>
				<i class="fa fa-cog fa-stack-1x"></i>
			</span>'."\n";
};


sub positionsFlexToGridster($$) {
	# correct positions after changing from flex to gridster layout
	my ($hash,$pageId) = @_;
	my $cells = $hash->{pages}{$pageId}{cells};
	my $firstMainCol = 0;  # i.e. right of menu
	my $firstMainRow = 0;  # i.e. under title
	my $regionFound = 0;
	for my $cell (@{$cells}) {
		next unless $cell->{region}; # should be fast if empty
		$regionFound = 1;
		next if $cell->{region} eq "main";	
		my ($col,$row) = $cell->position();
		next unless defined($col) and defined($row);
		my ($sizeX, $sizeY) = $cell->dimensions();
		$sizeX = ceil($sizeX);
		$sizeY = ceil($sizeY);
		if($cell->{region} eq "menu") {
			$firstMainCol = $col + $sizeX if($firstMainCol < $col + $sizeX);
		}else{  # title
			$firstMainRow = $row + $sizeY if($firstMainRow < $row + $sizeY);
		};
	};
	return unless $regionFound;  # everything without region
	for my $cell (@{$cells}) {
		next unless $cell->{region}; # should be fast if empty	
		my ($col,$row) = $cell->position();
		if(defined($col) and defined($row)) {
			if($cell->{region} eq 'title') {
				$cell->position($col + $firstMainCol, $row);
			};
			if($cell->{region} eq 'main') {
				$cell->position($col + $firstMainCol, $row + $firstMainRow);
			};
		};
		delete $cell->{region};	
	};	
};


sub renderCells($$$) {
	my ($hash,$pageId,$locked) = @_;
	positionsFlexToGridster($hash,$pageId);
	findPositions($hash,$pageId);
	my $page = $hash->{pages}{$pageId};
	my $backgroundImage = getBackgroundImage($page);
	# now try to render this
	my $result;
	my $i = 0;
	my $cells = $page->{cells};
	for my $cell (@{$cells}) {
		my ($col,$row) = $cell->position();
		my ($sizeX, $sizeY) = $cell->dimensions();
		$sizeX = ceil($sizeX);
		$sizeY = ceil($sizeY);
		$result .= '<li data-cellid="'.$i.'" data-row="'.($row+1).'" data-col="'.($col+1).'" data-sizex="'.$sizeX.'" data-sizey="'.$sizeY.'" class="'.$cell->getCssClasses($locked).'">';
		$cell->applyDefaults();
		# if there is no title and it is locked, we do not display a header
		# TODO: find better handle for dragging
		if(not $locked or $cell->{title}) {
			$result .= "<header class='fuip-cell-header";
			$result .= ' fuip-transparent' if $backgroundImage;
			$result .= "'>".($cell->{title} ? $cell->{title} : "").($locked ? "" : " ".$i."\n"
							.renderGearsForCell($i)).
						"</header>";
		};				
		$i++;
		$result .= $cell->getHTML($locked);
		$result .= "</li>";
	};
	return $result;
};


sub flexMaintMoveLeftAndUp($$) {
	my ($cells,$region) = @_;
	my $moveLeft = 9999;  #sth big. inf does not seem to be safe
	my $moveUp = 9999;
	for my $cell (@{$cells}) {
		next unless $cell->{region} eq $region;
		my ($col,$row) = $cell->position();
		# not yet positioned cells are not moved
		next unless(defined($col) and defined($row));
		$moveLeft = $col if $col < $moveLeft;
		$moveUp = $row if $row < $moveUp;
	};
	for my $cell (@{$cells}) {
		next unless $cell->{region} eq $region;
		my ($col,$row) = $cell->position();
		next unless(defined($col) and defined($row));
		$cell->position($col-$moveLeft,$row-$moveUp);
	};
}


# determine region in case not determined so far
# this also corrects the column and row if at 
# least one cell without region found
# TODO: can anything here lead to overlaps?
sub flexMaintFindRegion($$) {
	my ($hash,$pageId) = @_;
	my $cells = $hash->{pages}{$pageId}{cells};
	my $cellWithoutRegionFound;
	for my $cell (@{$cells}) {
		next if defined $cell->{region}; # already there
		$cellWithoutRegionFound = 1;
		my ($col,$row) = $cell->position();
		if(defined($col) and defined($row)) {
			$cell->{region} = ($col ? ($row ? "main":"title"):"menu");	
		}else{
			$cell->{region} = "main"; # cells without position are assigned to "main"
		};	
	};
	return unless $cellWithoutRegionFound;
	# move everything to the left and up in all regions 
	flexMaintMoveLeftAndUp($cells,"menu");
	flexMaintMoveLeftAndUp($cells,"main");
	flexMaintMoveLeftAndUp($cells,"title");
};


sub cellWidthToPixels($$) {
	my ($hash,$sizeX) = @_;
	$sizeX = ceil($sizeX);
	my $baseWidth = main::AttrVal($hash->{NAME},"baseWidth",142);
	my $cellSpacing = getCellMargin($hash) * 2;
	return $sizeX * ($baseWidth + $cellSpacing) - $cellSpacing; 
};


sub cellHeightToPixels($$) {
	my ($hash,$sizeY) = @_;
	$sizeY = ceil($sizeY);
	my $baseHeight = main::AttrVal($hash->{NAME},"baseHeight",108);	
	my $cellSpacing = getCellMargin($hash) * 2;
	return $sizeY * ($baseHeight + $cellSpacing) - $cellSpacing; 
};


sub cellSizeToPixels($;$$) {
	my ($hash,$sizeX,$sizeY) = @_;
	unless(defined($sizeX)) {
		my $cell = $hash;
		($sizeX,$sizeY) = $cell->dimensions();
		$hash = $cell->{fuip};
	};
	return (cellWidthToPixels($hash,$sizeX), cellHeightToPixels($hash,$sizeY)); 
};


sub renderCellsFlexMaint($$$) {
	my ($hash,$pageId,$region) = @_;
	# no region set yet? => determine
	flexMaintFindRegion($hash,$pageId);	
	findPositions($hash,$pageId);
	my $page = $hash->{pages}{$pageId};
	my $backgroundImage = getBackgroundImage($page);
	# now try to render this
	my $result;
	my $i = -1;
	my $cells = $page->{cells};
	for my $cell (@{$cells}) {
		$i++;
		my ($col,$row) = $cell->position();
		next unless $cell->{region} eq $region;
		my ($width,$height) = cellSizeToPixels($cell);
		my ($sizeX, $sizeY) = $cell->dimensions();
		$sizeX = ceil($sizeX);
		$sizeY = ceil($sizeY);
		$result .= '<div id="fuip-flex-fake-'.$i.'" style="grid-area:'.($row+1).' / '.($col+1).' / '.($row+$sizeY+1).' / '.($col+$sizeX+1).';position:relative;width:'.$width.'px;height:'.$height.'px;px;background-color:rgba(0,0,0,0);">
					<div id="fuip-flex-cell-'.$i.'" data-cellid="'.$i.'" class="'.$cell->getCssClasses(0).'"';
		$result .= ' style="position:absolute;width:'.$width.'px;height:'.$height.'px;
									border:0;">';
		$cell->applyDefaults();
		# TODO: find better handle for dragging
		$result .= "<header class='fuip-cell-header";
		$result .= ' fuip-transparent' if $backgroundImage;
		$result .= "' style='display: block;
							font-size: 0.85em;font-weight: bold;line-height: 2em;
							text-align: center;width: 100%;'>".($cell->{title} ? $cell->{title} : "").$i."\n"
						.renderGearsForCell($i)				
						."</header>";

		$result .= $cell->getHTML(0);
		$result .= "</div></div>";
		$result .= '<script>
					$( function() {
						$( "#fuip-flex-cell-'.$i.'" ).resizable({
							start: onFlexMaintResizeStart,
							stop: onFlexMaintResizeStop,
							resize: onFlexMaintResize
						});
						$("#fuip-flex-cell-'.$i.'" ).draggable({
							stack: "[id^=fuip-flex-cell-]",
							start: onFlexMaintDragStart,
							drag: onFlexMaintDrag,
							stop: onFlexMaintDragStop
						}); 
					} );
				</script>';	
	};
	return $result;
};


sub cellHasAutoView($) {
	# check whether the cell contains at least one "auto" view
	my ($cell) = @_;
	for my $view (@{$cell->{views}}) {
		next unless exists $view->{sizing};
		return 1 if($view->{sizing} eq "auto");
	};
	return 0;
};


sub renderCellsFlex($$) {
	my ($hash,$pageId) = @_;
	# no region set yet? => determine
	flexMaintFindRegion($hash,$pageId);	
	findPositions($hash,$pageId);
	# now try to render this
	my $menu = '<div id="fuip-flex-menu">';
	my $titlebar = '<div id="fuip-flex-title">';
	my $main = '<div id="fuip-flex-main">';
	my $i = 0;
	my $page = $hash->{pages}{$pageId};
	my $cells = $page->{cells};
	
	# The "title cell" is the first of the title area
	my $lastMenuRow = 0;
	for my $cl (@{$cells}) {
		my ($c,$r) = $cl->position();
		$lastMenuRow = $r if($cl->{region} eq "menu" and $lastMenuRow < $r);
	};
	my $backgroundImage = getBackgroundImage($page);
	for my $cell (@{$cells}) {
		my ($col,$row) = $cell->position();
		my ($sizeX, $sizeY) = $cell->dimensions();
		$sizeX = ceil($sizeX);
		# TODO: determine title sizes properly
		$sizeX = 1 if($cell->{region} eq "title" and $col == 0);
		$sizeY = ceil($sizeY);
		my ($width,$height) = cellSizeToPixels($hash,$sizeX,$sizeY);
		# TODO: col, row, sizex, sizey ?
		# outer DIV: the cell itself
		my $cellHtml = '<div data-cellid="'.$i.'" data-row="'.($row+1).'" data-col="'.($col+1).'" data-sizex="'.$sizeX.'" data-sizey="'.$sizeY.'" class="'.$cell->getCssClasses(1).'" style="width:';
		$cellHtml .= $width.'px';
		$cellHtml .= ";height:".$height."px;position:relative;border:0;
									order:".($row*100+$col).";";
		$cellHtml .= '				flex:auto;' if($cell->{region} eq "menu" and $row == $lastMenuRow or $cell->{region} eq "main" or $cell->{region} eq "title" and $col == 0);
		$cellHtml .= '				margin:'.getCellMargin($hash).'px;">';
		$cell->applyDefaults();
		# if there is no title and it is locked, we do not display a header
		# header, if needed
		if($cell->{title}) {
			$cellHtml .= "<header class='fuip-cell-header";
			$cellHtml .= ' fuip-transparent' if $backgroundImage;
			$cellHtml .= "' style='display: block;
								font-size: 0.85em;font-weight: bold;line-height: 2em;
								text-align: center;width: 100%;'>".$cell->{title}."
						</header>";
		};		
		$i++;
		# inner div, the real content 
		$cellHtml .= '<div style="';
		# the first cell in the title row is supposed to be the title, i.e. left-aligned
		$cellHtml .= 'margin-left:0px;margin-right:auto;' if($col == 0 and $cell->{region} eq "title");
		# in main area, centered stuff should stay centered if the cell grows
		# i.e. distribute extra space due to flex layout
		if($cell->{region} eq "main" and not cellHasAutoView($cell)) {
			$cellHtml .= 'margin-left:auto;margin-right:auto;width:'.$width.'px;'; 
		}else{
		#   otherwise, views should be given the complete area. This especially includes auto sizing views. 
			$cellHtml .= 'width:100%;';
		};	
		$cellHtml .= 'position:relative;';
		# move the content area up by 22px if there is a title
		# this is a bit ugly, but for compatibility with earlier versions 
		$cellHtml .= 'top:-22px;' if($cell->{title});
		$cellHtml .= 'height:'.$height.'px;">';
		if($col == 0 and $cell->{region} eq "title") {
			$cellHtml .= '<div id="fuip-flex-menu-toggle" class="fa-lg"
							style="position:absolute;left:0px;top:0px;"
							onclick="$(\'#fuip-flex-menu\').toggleClass(\'fuip-flex-menu-show\')">
							<i title="Toggle menu" class="fa fa-bars bigger"></i>
						</div>';
		};
		$cellHtml .= $cell->getHTML(1).'</div>';
		$cellHtml .= "</div>";
		if($cell->{region} eq "menu") {  
			$menu .= $cellHtml;
		}elsif($cell->{region} eq "title"){  
			$titlebar .= $cellHtml;
		}else{	           # everything else is "content"
			$main .= $cellHtml;
		};
	};
	$menu .= '</div>';
	$main .= '</div>';	
	$titlebar .= '</div>';	
	return $menu.'<div style="display:flex;flex-direction:column;">'.$titlebar.$main.'</div>';
};


sub FW_setPositionsAndDimensions($$$) {
	my ($name,$pageid,$cells) = @_;
	my $hash = $main::defs{$name};
	return unless $hash;
	return unless defined($hash->{pages}{$pageid});
	my $page = $hash->{pages}{$pageid}{cells};
	#{
    #    'size_y' => 1,
    #    'col' => 1,
    #    'size_x' => 1,
    #    'row' => 1
    #},
	for(my $i = 0; $i < @{$page}; $i++) {
		last unless defined($cells->[$i]);
		$page->[$i]{posX} = $cells->[$i]->{col} -1;
		$page->[$i]{posY} = $cells->[$i]->{row} -1; 
		$page->[$i]{width} = $cells->[$i]->{size_x};
		$page->[$i]{height} = $cells->[$i]->{size_y};
		# flex layout?
		$page->[$i]{region} = $cells->[$i]->{region} if defined $cells->[$i]->{region}; 
	};
	# autosave
	save($hash,1); # TODO: error handling? 
};


sub decodePageid($$) {
	# for weird characters in page names etc., URLs are encoded
	# and the page keys also need to be stored encoded. However, 
	# at least one version of FUIP stored decoded keys. I.e. if 
	# there is no "encoded" page, but a "decoded" one, we need to 
	# display this page.
	# The second parameter (pageid) might be changed.
	my ($hash,$pageid) = @_;
	if(not exists($hash->{pages}{$pageid})) {
		my $decodedPageid = main::urlDecode($pageid);
		if(exists($hash->{pages}{$decodedPageid})) {
			$_[1] = $decodedPageid;
		};
	};	
};	


sub getFuipPage($$) {
	my ($hash,$path) = @_;
	
	my $locked = _getLock($hash);
	my ($pageid,$preview) = split(/\?/,$path);
	# preview?
	if($preview and $preview eq "preview") {
		$locked = 1;	
	};
	
	# refresh Model buffer if locked
	# if not locked, this would mean very bad performance for e.g. value help for devices
	FUIP::Model::refresh($hash->{NAME}) if($locked);
	
	#If no page is explicitly given, determine default page
	# - If there is already a page "home", but no system called "home",
    #   then use "home" as default (this is for the case where the "home"
    #   page already exists and is not directly connected to a system
	# - If there is only one system, use its system id as default page
    # - Multiple systems: default page is "overview"	
	if(not defined($pageid) or $pageid eq "") {
		my $systems = FUIP::Systems::getSystems($hash);
		if(defined($hash->{pages}{home}) and not defined($systems->{home})) {
			$pageid = "home";
		}elsif(scalar(keys %$systems) == 1) {
			$pageid = FUIP::Systems::getDefaultSystem($hash);
		}else{
			$pageid = "overview";
		};
	};	

	# see comment in decodePageid
	decodePageid($hash,$pageid);

	$currentPage = $pageid;  # might be needed for subsequent GET requests
	
	# do we need to create the page?
	if(not defined($hash->{pages}{$pageid})) {
		return("text/plain; charset=utf-8", "FUIP page $pageid does not exist") if($locked);
		FUIP::Generator::createPage($hash,$pageid);
		# add a cell, as otherwise it cannot be maintained
		push(@{$hash->{pages}{$pageid}{cells}},FUIP::Cell->createDefaultInstance($hash,$hash->{pages}{$pageid})) unless @{$hash->{pages}{$pageid}{cells}};
	};
	# ok, we can render this	
	if(main::AttrVal($hash->{NAME},"layout","gridster") eq "flex") {
		return renderPageFlex($hash, $pageid) if($locked);
		return renderPageFlexMaint($hash,$pageid);
	}else{
		return renderPage($hash, $pageid, $locked);
	};
};


sub urlParamsGet($) {
	my ($request) = @_;
	my @splitAtQ = split(/\?/,$request,2);
	return {} unless exists $splitAtQ[1];
	my @splitAtA = split(/&/,$splitAtQ[1]);
	my %result;
	foreach my $entry (@splitAtA) {
		my ($key,$value) = split(/=/,$entry,2);
		$result{$key} = $value;
	};
	return \%result;
};


sub settingsExport($$) {
	my ($hash,$request) = @_;
	# get pageid and cellid
	my $urlParams = urlParamsGet($request);
	# TODO: error management
	return undef unless exists $urlParams->{pageid} or exists $urlParams->{templateid};
	# see comment in decodePageid
	decodePageid($hash,$urlParams->{pageid});
	my $result = "";
	my $filename = "";
	if(exists $urlParams->{fieldid}) {
		my $dialog = findDialogFromFieldId($hash,$urlParams,$urlParams->{fieldid});
		$result = $dialog->serialize();
		$filename = $hash->{NAME}."_".$urlParams->{pageid}."_".$urlParams->{cellid}."_".$urlParams->{fieldid};
	}elsif(exists $urlParams->{cellid}) {
		# export cell
		$result = $hash->{pages}{$urlParams->{pageid}}{cells}[$urlParams->{cellid}]->serialize(); 	
		$filename = $hash->{NAME}."_".$urlParams->{pageid}."_".$urlParams->{cellid};
	}elsif(exists $urlParams->{templateid}) {
		# export view template
		$result = $hash->{viewtemplates}{$urlParams->{templateid}}->serialize(); 	
		$filename = $hash->{NAME}."_".$urlParams->{templateid};
	}else{	
		# export page
		$result = $hash->{pages}{$urlParams->{pageid}}->serialize(); 	
		$filename = $hash->{NAME}."_".$urlParams->{pageid};
	};	
	$filename = main::urlEncode($filename).".fuipexp";
	return("application/octet-stream; charset=utf-8\r\nContent-Disposition: attachment; filename=\"".$filename."\"",
		$result); 
};


sub settingsImport($$) {
	my ($hash,$request) = @_;
	# get pageid and cellid
	my $urlParams = urlParamsGet($request);
	# TODO: error management
	# content is now in $urlParams->{content}, but URI-encoded
	return("text/plain; charset=utf-8", "Content missing (empty file?)") unless $urlParams->{content};
	my $content = $urlParams->{content};
	$content =~ s/\+/%20/g;
	$content = main::urlDecode($content);
	my $confHash = eval($content);
	my $targettype = $urlParams->{type};  # this is what we are trying to import
	$targettype = "" unless $targettype;
	# cell or page?
	# TODO: Also maybe full FUIP instances?
	my $class = $confHash->{class}; # This is what is in the file
	$class = "" unless $class;
	delete($confHash->{class});
	# we only allow FUIP::Cell, FUIP::Dialog, FUIP::Page and FUIP::ViewTemplate so far
	# check whether there is anything sensible in the file and whether the file matches what we are trying to import
	unless($class =~ m/^FUIP::(Cell|Dialog|Page|ViewTemplate)$/) {
		return ("text/plain; charset=utf-8", 
			"<b>Select a FUIP export file</b><p>
			You are probably trying to import a file as a FUIP page, cell, dialog or view template. However, the selected
			file does not seem to be a FUIP export file at all."); 
	};
	if($targettype eq "viewtemplate") {
		return ("text/plain; charset=utf-8", 
			"<b>Select a FUIP view template export file</b><p>
			You are probably trying to import a file as a FUIP <b>view template</b>. However, the selected 
			file looks like an exported <b>cell</b>, <b>dialog</b> or <b>page</b>. Either import the file as a new cell, dialog or page, or select
			a different file.") unless $class eq "FUIP::ViewTemplate"; 	
	}elsif($targettype eq "page") {
		return ("text/plain; charset=utf-8", 
			"<b>Select a FUIP page export file</b><p>
			You are probably trying to import a file as a FUIP <b>page</b>. However, the selected 
			file looks like an exported <b>cell</b>, <b>dialog</b> or <b>view template</b>. Either import the file as a new cell, dialog or view template, or select
			a different file.") unless $class eq "FUIP::Page"; 
	}elsif($targettype =~ m/^(cell|dialog)$/){
		return ("text/plain; charset=utf-8", 			
			"<b>Select a FUIP cell or dialog export file</b><p>
			You are probably trying to import a file as a FUIP <b>cell</b> or <b>dialog</b>. However, the selected 
			file looks like an exported <b>page</b> or <b>view template</b>. Either import the file as a new page or view template, or select
			a different file.") unless $class =~ m/^FUIP::(Cell|Dialog)$/; 	
	}else{
		return ("text/plain; charset=utf-8", 			
			"<b>Unknown type: ".$targettype."</b><p>
			You are probably trying to import a file as a FUIP object. However, the system could not find out the target object type. This is most likely an internal FUIP error, i.e. probably not your fault. Maybe it's time to open a new thread in the FHEM forum."); 	
	};
	my $newObject = $class->reconstruct($confHash,$hash);
	# we might have downloaded something where a view template is missing
	# TODO: real error management/naming concept etc.
	FUIP::ViewTemplInstance::fixInstancesWithoutTemplates();
	my $cellSpacing = 2 * getCellMargin($hash);
	if($targettype eq "dialog") {
		# importing (as) a dialog
		# This means that what we import will replace the current one
		my $dialog = findDialogFromFieldId($hash,$urlParams,$urlParams->{fieldid});
		$dialog->{views} = $newObject->{views};
		$dialog->{title} = $newObject->{title};
		$dialog->{defaulted} = $newObject->{defaulted};
		# If we import from a cell, remove position and convert size
		if($class eq "FUIP::Cell") {
			$newObject->{width} = 1 if $newObject->{width} <= 0;
			$newObject->{height} = 1 if $newObject->{height} <= 0;
			$dialog->{width} = 	cellWidthToPixels($hash,$newObject->{width}) + 2;
			$dialog->{height} = cellHeightToPixels($hash,$newObject->{height}) + 3;	
		}else{
			# must be Dialog now
			$dialog->{width} =  $newObject->{width};
			$dialog->{height} =  $newObject->{height};
		};
		# parent stays like it is
	}elsif($targettype eq "cell") {
		# importing as a cell
		# This always creates a new cell
		# If we come from a dialog, we need to convert sizes
		if($class eq "FUIP::Dialog") {
			my $dialog = $newObject;
			$newObject = FUIP::Cell->createDefaultInstance($hash,$hash->{pages}{$urlParams->{pageid}});
			$newObject->{views} = $dialog->{views};
			$newObject->{title} = $dialog->{title};
			$newObject->{defaulted} = $dialog->{defaulted};
			my $baseWidth = main::AttrVal($hash->{NAME},"baseWidth",142);
			my $baseHeight = main::AttrVal($hash->{NAME},"baseHeight",108);
			my $cellSpacing = getCellMargin($hash)*2;
			$newObject->{width} = ceil(($dialog->{width} + $cellSpacing)/($baseWidth + $cellSpacing));
			$newObject->{height} = ceil(($dialog->{height} + $cellSpacing)/($baseHeight + $cellSpacing));
			$newObject->{width} = 1 unless($newObject->{width} > 0);
			$newObject->{height} = 1 unless($newObject->{height} > 0);
		}else{
			delete $newObject->{posX};
			delete $newObject->{posY};
		};
		push(@{$hash->{pages}{$urlParams->{pageid}}{cells}},$newObject);
	}elsif($targettype eq "page"){
		$hash->{pages}{$urlParams->{pageid}} = $newObject;
		$newObject->setParent($hash);
	}elsif($targettype eq "viewtemplate") {
		# make sure to use a new name
		my $id = $newObject->{id};
		my $cnt = 0;
		while(exists $hash->{viewtemplates}{$id}) {
			$cnt++;
			$id = $newObject->{id}.'_'.$cnt; 
		};
		$newObject->{id} = $id;
		$hash->{viewtemplates}{$id} = $newObject;
		$newObject->setParent($hash);
		return ("text/plain; charset=utf-8", "OK".$id);
	};	
	return("text/plain; charset=utf-8", "OK");
};


sub uploadLog($$) {
	my ($hash,$request) = @_;
	# get pageid and cellid
	my $content;
	my @urlParams = split(/&/,$request);
	if($urlParams[1]) {
		$content = $urlParams[1];
	};	
	# TODO: error management
	# content is now URI-encoded
	# main::Log3($hash,1,"FUIP upload logs: ".$request);
	return("text/plain; charset=utf-8", "Content missing") unless $content;
	$content =~ s/\+/%20/g;
	$content = main::urlDecode($content);
	my @content = split("\n",$content,2);
	my $logid = $content[0];
	$logid =~ s/[-:Z]//g;					#2019-10-21T18:53:39.116Z
	$logid =~ s/T/\./g;
	# now simply save to disk
	my $filename = $hash->{NAME}.'.'.$main::defs{$main::FW_cname }{PEER}.'.'.$logid.'.log';
	# make sure log directory exists
	my $logPath = $fuipPath."log";
	if(not(-d $logPath)) {
		mkdir($logPath);
		# we do not check for errors here as anyway the FileWrite will fail
	};
	# no config DB for logs
	my $param = { FileName => $logPath."/".$filename };
	$param->{ForceType} = "file";
	my $result = main::FileWrite($param,@content);		
	return("text/plain; charset=utf-8", "Error ".$result) if $result;
	# confirmation message
	return("text/plain; charset=utf-8", "OK");
};


sub finishCgiAnswer($$) {
	# this is more or less copied from FW_finishRead of FHEMWEB
	my ($rettype, $data) = @_;	
	my $compressed = "";
	if($rettype =~ m/(text|xml|json|svg|script)/i &&
			$main::FW_httpheader{"Accept-Encoding"} &&
			$main::FW_httpheader{"Accept-Encoding"} =~ m/gzip/ &&
			$main::FW_use{zlib}) {
		utf8::encode($data) if(utf8::is_utf8($data) && $data =~ m/[^\x00-\xFF]/ );
		eval { $data = Compress::Zlib::memGzip($data); };
		if($@) {
			main::Log 1, "memGzip: $@"; 
			$data = ""; 
		}else{
			$compressed = "Content-Encoding: gzip\r\n";
		}
	}
	my $length = length($data);
	# TODO: caching for some static pieces? ...or for everything in "locked" mode?
	#my $expires = ($cacheable ?
    #     "Expires: ".FmtDateTimeRFC1123($main::FW_chash->{LASTACCESS}+900)."\r\n" : 
    #     "Cache-Control: no-cache, no-store, must-revalidate\r\n");
	my $expires = "Cache-Control: no-cache, no-store, must-revalidate\r\n";
	my $client = $main::defs{$main::FW_cname};
	main::FW_addToWritebuffer($client,
           "HTTP/1.1 200 OK\r\n" .
           "Content-Length: $length\r\n" .
           $expires . $compressed . # $main::FW_headerlines .
           "Content-Type: $rettype\r\n\r\n" .
           $data, undef , 1);
}


##################
#
# here we answer any request to http://host:port$FW_ME/$infix and below
# $FW_ME is usually /fhem

sub CGI_inner($) {

  my ($request) = @_;   # /$infix/filename
  
  # main::Log3(undef,1,"FUIP Request: ".$request);
  # Match request first without trailing / in the link part 
  if($request =~ m,^(/[^/]+)(/(.*)?)?$,) {
    my $link = $1;
    my $filename = ($3 ? $3 : "");  # $3 is undef if the "/" at the end is missing
    my $name;
 
    # If FWEXT not found for this make a second try with a trailing slash in the link part
    if(! $main::data{FWEXT}{$link}) {
      $link = $link."/";
      return("text/plain; charset=utf-8", "Illegal request: $request") if(! $main::data{FWEXT}{$link});
    }
    
    # get device name
    $name= $main::data{FWEXT}{$link}{deviceName}; 
	
	my $hash = $main::defs{$name};

    # return error if no such device
    return("text/plain; charset=utf-8", "No FUIP device for $link") unless($hash);
	
	# main::Log3(undef,1,"FUIP Link: ".$link." File: ".$filename);
	my @path = split(/\//, $filename);
	if(@path == 0 or $path[0] eq "page") {
		if(@path > 0){ shift @path };
		return getFuipPage($hash,join('/',@path));
	};
	
	#Minimal manifest file to make sure that the "standalone" (i.e. app-like) display
	#is kept when changing pages (apple)
	if($path[-1] eq "manifest.json") {
		return("text/json; charset=utf-8", '
		  {
			"scope": "'.urlBase($hash).'/",
			"display": "standalone"
	      }
		');  
	};	
	
	# very special logic for tablet-ui kernel
	if($path[0] ne "fuip" and ( $path[-1] eq "fhem-tablet-ui.js")) {
		unshift(@path,"fuip");
		$path[-1] = "fuip_tablet_ui_multifhem.js";  		
	};	
	
	# special logic for weatherdetail and readingsgroup
	# add "fuip" in front of path to make sure to use the FUIP version
	if($path[0] ne "fuip" and ( $path[-1] eq "widget_weatherdetail.js" or 
								$path[-1] eq "widget_dwdweblink.js" or
								$path[-1] eq "widget_dwdweblink.css" or
								$path[-1] eq "widget_readingsgroup.js" or 
								$path[-1] eq "widget_chart.js" or 
								$path[-1] eq "widget_fuip_wdtimer.js" or
								$path[-1] eq "widget_fuip_wdtimer.css" or
								$path[-1] eq "widget_fuip_colorwheel.js" or
								$path[-1] eq "widget_fuip_colorwheel.css" or
								$path[-1] eq "widget_fuip_clock.js" or
								$path[-1] eq "widget_fuip_calendar.js" or
								$path[-1] eq "widget_fuip_readingslist.js" or
								$path[-1] eq "widget_fuip_thermostat.js" or
								$path[-1] eq "widget_fuip_numselect.js" or
								$path[-1] eq "widget_7segment.js" or
								$path[-1] eq "widget_fuip_popup.js" or
								$path[-1] eq "widget_dotmatrix.js" or
								$path[-1] eq "ftui_chart.css"
								)) {
		unshift(@path,"fuip");
	};
	# special logic for css/fhem-tablet-ui-user.css
	if($path[-1] eq "fhem-tablet-ui-user.css" and $path[-2] eq "css" and $path[0] ne "fuip") {
		return getFtuiUserCss($hash,$currentPage); 	
	};	
	# fuip builtin stuff
	if($path[0] eq "fuip") {
		# export/import settings
		if($path[1] =~ m/^export/) {
			return settingsExport($hash,$request);
		}elsif($path[1] =~ m/^import/) {
			return settingsImport($hash,$request);
		# popup maintenance
		}elsif($path[1] =~ m/^popup/) { 
			return renderPopupMaint($hash,$request);
		# view template maintenance
		}elsif($path[1] =~ m/^viewtemplate/) { 
			return renderViewTemplateMaint($hash,$request);		
		# upload logs	
		}elsif($path[1] =~ m/^logupload/) {
			return uploadLog($hash,$request);	
		# documentation
		}elsif($path[1] =~ m/^docu/) {
			return renderDocu($hash);
		};	
		# other built in fuip files
		shift @path;
		$filename = $main::attr{global}{modpath}."/FHEM/lib/FUIP/".join('/',@path);
		my $MIMEtype= main::filename2MIMEType($filename);
		my @contents;
		if(open(INPUTFILE, $filename)) {
			binmode(INPUTFILE);
			@contents= <INPUTFILE>;
			close(INPUTFILE);
			return("$MIMEtype; charset=utf-8", join("", @contents));
		} else {
			return("text/plain; charset=utf-8", "File not found: $filename");
		}
	};
	
	# otherwise, this is some library file or js or...	
	
    $filename =~ s/\?.*//;
	
	# The following is to block any widget to load jquery-ui again. It would break drag/drop of views.
	my $basename = basename($filename);
	if($basename eq "jquery-ui.js" or $basename eq "jquery-ui.min.js") {
		return("text/javascript; charset=utf-8", "");	
	};
		
    my $MIMEtype= main::filename2MIMEType($filename);
    my $directory= $main::defs{$name}{fhem}{directory};
    $filename= "$directory/$filename";
    #Debug "read filename= $filename";
    my @contents;
    if(open(INPUTFILE, $filename)) {
      binmode(INPUTFILE);
      @contents= <INPUTFILE>;
      close(INPUTFILE);
      return("$MIMEtype; charset=utf-8", join("", @contents));
    } else {
      return("text/plain; charset=utf-8", "File not found: $filename");
    }

  } else {
    return("text/plain; charset=utf-8", "Illegal request: $request");
  }
}  


sub CGI($) {
	# the following avoids the FHEMWEB overhead (like f18 style data)
	# and allows for own control over HTTP headers etc.
	my ($request) = @_;   # /$infix/filename
	my ($rettype, $data);

	eval {
		($rettype, $data) = CGI_inner($request); 
		1;
	} or do {
		my $ex = $@;
		FUIP::Exception::log($ex);
		$rettype = "text/html; charset=utf-8";
		$data = FUIP::Exception::getErrorPage($ex);
	};
	finishCgiAnswer($rettype, $data);
	return (undef,undef);
};	


# serializes all pages and views in order to save them
sub serialize($) {
	my ($hash) = @_;
	# pages 
	my $pages = 0;
	for my $pageid (sort keys %{$hash->{pages}}) {
		if($pages) {
			$pages .= ",\n ";
		}else{
			$pages = "{";
		};
		$pages .= " '".$pageid."' => \n".$hash->{pages}{$pageid}->serialize(6);
	};
	if($pages) {
		$pages .= "\n}";
	}else{
		$pages = "{ }\n";
	};	
	# view templates
	my $viewtemplates = 0;
	for my $templateid (sort keys %{$hash->{viewtemplates}}) {
		if($viewtemplates) {
			$viewtemplates .= ",\n ";
		}else{
			$viewtemplates = "{";
		};
		$viewtemplates .= " '".$templateid."' => \n".$hash->{viewtemplates}{$templateid}->serialize(6);
	};
	if($viewtemplates) {
		$viewtemplates .= "\n}";
	}else{
		$viewtemplates = "{ }\n";
	};	
	# colors
	my $colors = 0;
	for my $key (sort keys %{$hash->{colors}}) {
		if($colors) {
			$colors .= ",\n ";
		}else{
			$colors = "{";
		};
		$colors .= " '".$key."' => '".$hash->{colors}{$key}."'";
	};
	if($colors) {
		$colors .= "\n}";
	}else{
		$colors = "{ }\n";
	};	
	# put it together
	my $result = 
	"{\n".
	"  version => 2,\n". 
	"  pages => \n".$pages.",\n".
	"  viewtemplates => ".$viewtemplates.",\n".
	"  colors => ".$colors."\n".
	"}";	
	return $result;
}


sub getAutosaveFiles($) {
	my $hash = shift;
	my $cfgPath = $fuipPath."config/autosave";
	my $pattern = '^FUIP_'.$hash->{NAME}.'_(.*)\.cfg$';
	my @result;
	return \@result unless opendir(DH, $cfgPath);
	foreach my $fName (sort {$b cmp $a} readdir(DH)) {
		next unless $fName =~ m/$pattern/;
		push(@result,"autosave_".$1);
	}
	closedir(DH);
	return \@result;
};


sub getConfigFiles($) {
	my $hash = shift;
	my $result = getAutosaveFiles($hash);
	my $fName = $fuipPath."config/FUIP_".$hash->{NAME}.".cfg";
	# with config DB, always add "latestSave", as it is a bit unclear how to 
	# test file existence (without reading it)
	unshift(@$result,"latestSave") if(-e $fName or main::configDBUsed());
	return $result;
};


sub checkForAutosave($) {
	# Checks whether the autosave is newer than the manually saved
	# config. If yes, returns the "ending" of the newest autosave file.
	# get the newest autosave file
	my $hash = shift;
	my $cfgPath = $fuipPath."config/autosave";
	return unless opendir(DH, $cfgPath);
	my $pattern = '^FUIP_'.$hash->{NAME}.'_(.*)\.cfg$';
	my $autoFileName;
	my $ending;
	foreach my $fName (sort {$b cmp $a} readdir(DH)) {
		next unless $fName =~ m/$pattern/;
		$ending = $1;
		$autoFileName = $fName;
		last;
	}
	closedir(DH);
	# no autosave file -> no issue
	return unless $autoFileName;
	$autoFileName = $fuipPath."config/autosave/".$autoFileName;
	my $confFileName = $fuipPath.'config/FUIP_'.$hash->{NAME}.'.cfg';
	# if (manually) saved file exists and is newer, then no issue
	if(-e $confFileName) {
		return if(-M $autoFileName >= -M $confFileName);
	};
	# now we know that either no manually saved file exists, but an auto file
	# or both exist and the auto file is newer
	$hash->{autosave} = $ending;
	return;
};


sub checkCrashedMessage($) {
	my ($hash) = @_;
	return "" if $hash->{autosave} eq "none";
    return "It looks like you have not saved your work before FHEM was shut down the last time. You can restore the state from before the last shutdown (or crash) using \"set ".$hash->{NAME}." load autosave_".$hash->{autosave}."\" or get rid of this message by \"set ".$hash->{NAME}." save\"";
};


sub fhemwebShowDetail($$$) {
	my ($fwName, $name, $roomName) = @_;
	my $hash = $main::defs{$name};
	my $message = checkCrashedMessage($hash);
	my $messages = getMessages($hash);
	unshift(@$messages,$message) if $message;
	return undef unless @$messages;
	# we assume that the user has seen the messages
	$messagesSeen{$name} = 1;
	my $result = "<table class='block wide'>";
	for $message (@$messages) {
		$result .= "<tr><td style='color:red'>".$message."</td></tr>";
    };	
	$result .= "</table>";
	return $result;
};


sub renderCrashedMessage($$) {
	my ($hash,$locked) = @_;
	return "" if $locked;
	my $message = checkCrashedMessage($hash);
	return "" unless $message;
	return 
		"<fuip-message style='display:none;'>
			<title>Unsaved data</title>
			<text>
				".$message."
			</text>
		</fuip-message>";		
};


sub cleanAutosave($) {
	my $hash = shift;
	my $cfgPath = $fuipPath."config/autosave";
	my $pattern = '^FUIP_'.$hash->{NAME}.'.*\.cfg';
	## get files with their age
	return unless opendir(DH, $cfgPath);
	# my @fNames;
	# just keep 4 "newest" files
	my $num = 0;
	foreach my $fName (sort {$b cmp $a} readdir(DH)) {
		next unless $fName =~ m/$pattern/;
		$num++;
		next unless $num > 4;
		unlink $cfgPath.'/'.$fName;
		#my $t = time() - (stat($cfgPath.'/'.$fName))[9];
		# main::Log3(undef,1,"File ".$fName.' time: '.$t);
		#push(@fNames, { name => $cfgPath.'/'.$fName, age => $t });
	}
	closedir(DH);
};


sub save($;$) {
	my ($hash,$autosave) = @_;
	my $config = serialize($hash);   
	my $filename = "FUIP_".$hash->{NAME};
	if($autosave) {
		my $dateTime = main::TimeNow();
		$dateTime =~ s/ /_/g;
		$dateTime =~ s/(:|-)//g;
		$filename .= '_'.$dateTime;
	};
	$filename .= '.cfg';	
    my @content = split(/\n/,$config);
	# make sure config directory exists
	my $cfgPath = $fuipPath."config";
	if(not(-d $cfgPath)) {
		mkdir($cfgPath);
		# we do not check for errors here as anyway the FileWrite will fail
	};
	if($autosave) {
		$cfgPath .= '/autosave';
		if(not(-d $cfgPath)) {
			mkdir($cfgPath);
		};
	};
	cleanAutosave($hash);
	# no config DB for autosave files
	my $param = { FileName => $cfgPath."/".$filename };
	$param->{ForceType} = "file" if $autosave;
	my $result = main::FileWrite($param,@content);		
	return $result if $result;
	$hash->{autosave} = "none";
	return undef;
};


sub version2filename($$) {
	my ($hash,$version) = @_;
	$version = "latestSave" unless $version;
	return "FUIP_".$hash->{NAME}.".cfg" if $version eq "latestSave";
	if($version =~ m/^autosave_(.*)$/) {
		return "autosave/FUIP_".$hash->{NAME}."_".$1.".cfg";
	};
	return undef;  # something wrong
};


sub load($;$) {
	# TODO: some form of error management
	my ($hash,$fVersion) = @_;
	my $filename = version2filename($hash,$fVersion);
	unless($filename) {
		return "Version ".$fVersion." unknown. You might want to do \"load latestSave\" in order to load the latest (manually) saved version."; 
	};
	# clear pages and viewtemplates
	$hash->{pages} = {};
	$hash->{viewtemplates} = {};
	
	# no config DB for autosave files
	my $param = { FileName => $fuipPath."config/".$filename };
	$param->{ForceType} = "file" if $filename =~ m/^autosave/;
	# try to read from FUIP directory
	my ($error, @content) = main::FileRead($param);	
	if($error) {
		# not found or other issue => try to read from main fhem directory (old location for this file)
		my $err2;
		$param->{FileName} = $filename;
		($err2, @content) = main::FileRead($param);
		return $error if($err2);  # return $error, even though second read failed. This is to avoid confusing error messages.
	};	
	my $config = join("\n",@content);
	# now config is sth we can "eval"
	my $confHash = eval($config);
	if(not $confHash and $@) {
		# i.e. something went wrong
		# write the eval messages into logfile 
		main::Log3($hash,1,"FUIP: Syntax error(s) in config file ".$filename);
		for my $line (split /\R/, $@) {
			main::Log3($hash,1,"FUIP: ".$line);
		};
		return "Syntax errors in config file. Check the FHEM log file for details.";
	};
	# version 1: only pages, directly as a hash
	# version 2: hash with keys version, pages, viewtemplates, maybe colors
	my $version = 1;
	if(exists $confHash->{version} and not ref($confHash->{version})) {
		$version = $confHash->{version};
	};
	my $cPages = {};
	my $cViewtemplates = {};
	if($version == 1) {
		$cPages = $confHash;
	}elsif($version == 2) {
		$cPages = $confHash->{pages};
		$cViewtemplates = $confHash->{viewtemplates};
	}else{
		return "Invalid version in file ".$filename;
	};
	# first do the view templates, as the rest might depend on them
	for my $id (keys %$cViewtemplates) {
		my $conf = $cViewtemplates->{$id};
		my $class = $conf->{class}; # This allows for other page-implementations (???)
		delete($conf->{class});
		$hash->{viewtemplates}{$id} = $class->reconstruct($conf,$hash);
		$hash->{viewtemplates}{$id}{id} = $id;
		$hash->{viewtemplates}{$id}->setParent($hash);
	};
	# now the pages
	for my $pageid (keys %$cPages) {
		my $pageConf = $cPages->{$pageid};
		my $class = $pageConf->{class}; # This allows for other page-implementations (???)
		delete($pageConf->{class});
		$hash->{pages}{$pageid} = $class->reconstruct($pageConf,$hash);
		$hash->{pages}{$pageid}->setParent($hash);
	};
	# there might be view templates, which use other view templates, but "reconstructed"
	# in opposite order...
	# In addition, there might be erroneous (non-existing) view templates.
	FUIP::ViewTemplInstance::fixInstancesWithoutTemplates();
	# colors
	if(defined($confHash->{colors})) {
		$hash->{colors} = $confHash->{colors};
	}else{
		$hash->{colors} = { };
	};	
	$hash->{autosave} = "none";
	return undef;
};


# dclone does not work because of references to the FUIP object
sub cloneView($) {
	my ($view) = @_;
	my $conf = eval($view->serialize());
	my $class = $conf->{class}; 
	delete($conf->{class});
	my $result = $class->reconstruct($conf,$view->{fuip});
	$result->setParent($view->{parent});
	return $result;
};


sub setField($$$$$) {
	my ($view,$field,$component,$values,$prefix) = @_;

	my $refIntoView = $view;
	my $refIntoDefaulted = $view->{defaulted};
	my $refIntoField = $field;
	my $compName = $field->{id};
	my $nameInValues = $prefix.$field->{id};
	for my $comp (@$component) {
		$refIntoView = $refIntoView->{$compName};
		$refIntoDefaulted->{$compName} = {} unless(defined($refIntoDefaulted->{$compName}));
		$refIntoDefaulted = $refIntoDefaulted->{$compName};
		#For structure changes, it can happen that this is not a HASH, so we need to make it a HASH
		$refIntoDefaulted = {} unless ref($refIntoDefaulted) eq 'HASH';
		$refIntoField = $refIntoField->{$comp};
		$compName = $comp;
		$nameInValues .= "-".$comp;
	};
	$refIntoView->{$compName} = main::urlDecode($values->{$nameInValues}) if(defined($values->{$nameInValues}));
	# should this be an array?
	if($field->{type} =~ m/^(setoptions|devices)$/) {
		# this can be an array reference, something that evaluates to an array or a comma separated list
		my $options = $refIntoView->{$compName};
		# not an ARRAY ref, maybe evaluates to an array (-ref)?
		if(ref($options) ne "ARRAY") {
			$options = eval($options);
		};
		# no ARRAY ref, does not evaluate to an array ref, i.e. comma separated list
		if(ref($options) ne "ARRAY") {
			my @options = split(/,/,$refIntoView->{$compName});
			$options = \@options;
		};	
		$refIntoView->{$compName} = $options;	
	};
	# if this has a default setting 
	if(defined($refIntoField->{default}) and defined($values->{$nameInValues."-check"})) {
		$refIntoDefaulted->{$compName} = ($values->{$nameInValues."-check"} eq "1" ? 0 : 1);
	};	
};


# declaration to avoid warnings because of recursion
sub setViewSettings($$$$;$);

sub setViewSettings($$$$;$) {
	my ($hash, $viewlist, $viewindex, $h, $prefix) = @_;
	$prefix = "" unless defined $prefix;
	
	# do we need to (re-)create the view?
	my $newclass = undef;
	$newclass = main::urlDecode($h->{$prefix."class"}) if(defined($h->{$prefix."class"}));
	if(defined($viewlist->[$viewindex])) {
		$newclass = undef if($newclass and $newclass eq blessed($viewlist->[$viewindex]));  # already this class
		# now check for view templates
		if($newclass and $newclass =~ m/^FUIP::VTempl::(.*)/) {
			# Is this the "error class"? If yes, don't do anything
			return if $1 eq "<ERROR>";
			$newclass = undef if(blessed($viewlist->[$viewindex]) eq "FUIP::ViewTemplInstance" 
									and $1 eq $viewlist->[$viewindex]{templateid});
		};
	}else{
		$newclass = "FUIP::View" unless $newclass;  # new view, assign FUIP::View
	};
	# has the class changed?
	if(defined($newclass)) {
		my $newView;
		if($newclass =~ m/^FUIP::VTempl::(.*)$/) {
			$newView = $hash->{viewtemplates}{$1}->createTemplInstance($hash);  # makes a ViewTemplInstance
		}else{
			# Set the fuip instance as parent here. This will be fixed later
			$newView = $newclass->createDefaultInstance($hash,$hash);
		};	
		if(defined($viewlist->[$viewindex])) {
			my $oldView = $viewlist->[$viewindex];
			$newView->{posX} = $oldView->{posX} if defined $oldView->{posX}; 
			$newView->{posY} = $oldView->{posY} if defined $oldView->{posY};
		};	
		$viewlist->[$viewindex] = $newView;
	};
	# now set each field
	# the following automatically ignores fields which cannot be set
	my $view = $viewlist->[$viewindex];
	my $configFields = $view->getConfigFields();
	for my $field (@$configFields) {
		if($field->{type} eq "device-reading") {
			setField($view,$field,["device"],$h,$prefix);
			setField($view,$field,["reading"],$h,$prefix);
		}elsif($field->{type} eq "viewarray"){
			# "sort order" argument
			my @sortOrder;
			if(defined($h->{$prefix.$field->{id}})){
				@sortOrder = split(',',$h->{$prefix.$field->{id}});
			}else{
				@sortOrder = 0 .. $#{$view->{$field->{id}}};
			};	
			my $newviewarray = [];
			for my $i (@sortOrder) {	
				setViewSettings($hash, $view->{$field->{id}},$i,$h,$prefix.$field->{id}.'-'.$i.'-'); 
				push(@$newviewarray,$view->{$field->{id}}[$i]);
			};
			$view->{$field->{id}} = $newviewarray;
		}elsif($field->{type} eq 'dialog') {
			# special case for view template instances
			# when variables are set
			# ...but first update the view according to the new settings
			setField($view,$field,[],$h,$prefix);
			if($view->{$field->{id}} and blessed($view->{$field->{id}})) {   # only if there is already a popup
				setViewSettings($hash, [$view->{$field->{id}}],0,$h,$prefix.$field->{id}.'-');
			};
		}else{
			setField($view,$field,[],$h,$prefix);
		};	
	};
	# flexible fields, e.g. from HTML view?
	if(exists($h->{$prefix.'flexfields'})) {
		my @flexfields = split(/,/,$h->{$prefix.'flexfields'});
		for my $flexname (@flexfields) {
			# put "flex structure" stuff
			delete $view->{flexstruc}{$flexname};
			delete $view->{defaulted}{$flexname};
			for my $attribute ("type", "refdevice", "refset") {
				$view->{flexstruc}{$flexname}{$attribute} = $h->{$prefix.$flexname.'-'.$attribute} if exists $h->{$prefix.$flexname.'-'.$attribute}; 
			};
			if(exists $h->{$prefix.$flexname.'-options'}) {
				my @opts = split(/,/,$h->{$prefix.$flexname.'-options'});
				$view->{flexstruc}{$flexname}{options} = \@opts;
			};
			for my $attribute ("type", "value", "suffix") {
				$view->{flexstruc}{$flexname}{default}{$attribute} = $h->{$prefix.$flexname.'-default-'.$attribute} if exists $h->{$prefix.$flexname.'-default-'.$attribute};	
			};
			# set field value
			setField($view,{id => $flexname, 
							type => $h->{$prefix.$flexname.'-type'},
							default => ($view->{flexstruc}{$flexname}{default} ? $view->{flexstruc}{$flexname}{default} : undef)
							},[],$h,$prefix);
		};
	};
	# parents need to be refreshed
	$view->setAsParent();
};


sub setPageSettings($$) {
	my ($page, $h) = @_;
	# set each field
	# the following automatically ignores fields which cannot be set
	my $configFields = $page->getConfigFields();
	for my $field (@$configFields) {
		setField($page,$field,[],$h,"");
	};	
};


# TODO: This should go to FUIP::Cell, to allow 
# different "layouts" later
sub autoArrange($) {
	my ($cell) = @_;
	# get cell width
	# (This assumes we already have a width.)
	my $width;
	if($cell->isa("FUIP::Cell")) {
		($width,undef) = cellSizeToPixels($cell);
	}else{	
		($width,undef) = $cell->dimensions();
	};	
	my ($posX,$posY) = (0,0);
	my $nextPosY = 0;
	for my $view (@{$cell->{views}}) {
		my ($w,$h) = $view->dimensions();
		if($posX) {
			# i.e. there is already sth in the row, check whether we can fit more
			if($posX + $w > $width) {
				# no, next row
				$posX = 0;
				$posY = $nextPosY;
			};
		};	
		$view->position($posX,$posY);
		$posX += $w;
		$nextPosY = $posY + $h if($nextPosY < $posY + $h);
	};
};


# auto-arrange all views which have not been positioned yet
sub autoArrangeNewViews($) {
	my ($cell) = @_;
	# get cell's dimensions
	my $width;
	my $height;
	my $cellWidth;
	my $cellHeight;
	if($cell->isa("FUIP::Cell")) {
		($cellWidth,$cellHeight) = $cell->dimensions();
		($width,$height) = cellSizeToPixels($cell);
	}else{	
		($width,$height) = $cell->dimensions();
	};	
	# get the lower right corner of what is already occupied
	my ($occUntilX,$occUntilY) = (0,0);
	for my $view (@{$cell->{views}}) {
		my ($x,$y) = $view->position();
		next unless defined($x) or defined($y);
		my ($w,$h) = $view->dimensions();
		$occUntilX = $x + $w if $x + $w > $occUntilX;
		$occUntilY = $y + $h if $y + $h > $occUntilY;
	};
	# start positioning right to the already occupied region
	my ($posX,$posY) = ($occUntilX,0);
	my $nextPosY = 0;
	for my $view (@{$cell->{views}}) {
		# already positioned?
		my ($x,$y) = $view->position();
		next if defined($x) or defined($y);
		my ($w,$h) = $view->dimensions();
		# does this fit into the current row?
		# (unless we are anyway at the beginning of the row
		if($posX > 0 and $posX + $w > $width) {
			# no, next row
			$posY = $nextPosY;
			if($posY < $occUntilY) {
				$posX = $occUntilX;
			}else{
				$posX = 0;
			};	
		};	
		# if we are still "at the right" and it is to tall
		# or it is wider than the complete space to the right,
		# then start below
		if($posY < $occUntilY and ($posY + $h > $occUntilY or $posX + $w > $width)) {
			$posX = 0;
			$posY = $occUntilY;
			$nextPosY = $posY;
		};
		# now posX/posY should be the new position
		$view->position($posX,$posY);
		$posX += $w;
		$nextPosY = $posY + $h if($nextPosY < $posY + $h);
	}		
	# resize the cell itself in case we have added something "below", which does not anyway fit
	if($cell->isa("FUIP::Cell")) {
		my $baseHeight = main::AttrVal($cell->{fuip}{NAME},"baseHeight",108);
		my $cellSpacing = getCellMargin($cell->{fuip})*2;
		if($nextPosY + 22 > $height) {
			$cellHeight = ceil(($nextPosY + $cellSpacing + 22)/($baseHeight+$cellSpacing));
			$cell->dimensions($cellWidth,$cellHeight);
		};
	}else{
		if($nextPosY + 25 > $height) {
			$height = $nextPosY + 25;
			$cell->dimensions($width,$height);
		};
	};
};


sub getPageAndCellId($$) {
# determines page id and cell id from command
# includes error handling
	my ($hash,$a) = @_;
	my $cmd = $a->[1];
	my @pageAndCellId = split(/_/,$a->[2]);
	return (undef, "\"set ".$cmd."\" needs a page id and a view id") unless(@pageAndCellId > 1);
	my $cellId = pop(@pageAndCellId);
	my $pageId = join("_",@pageAndCellId);
	return (undef, "\"set ".$cmd."\": cell ".$pageId." ".$cellId." not found") unless(defined($hash->{pages}{$pageId}) and defined($hash->{pages}{$pageId}{cells}[$cellId]));
	return ($pageId,$cellId);
};


sub _setDelete($$) {
	# e.g. set ui delete type=viewtemplate templateid=test
	my ($hash,$h) = @_;
	return '"set delete": unknown type' unless exists $h->{type} and $h->{type} eq "viewtemplate";
	return '"set delete": template id missing' unless $h->{templateid};
	return 'View template '.$h->{templateid}.' does not exist' unless $hash->{viewtemplates}{$h->{templateid}};
	# check whether view template is used
	my $wul = _getWhereUsedList($hash,$h);
	return 'View template "'.$h->{templateid}.'" is still used. See where-used list for details.' if(@$wul);
	# really delete
	delete $hash->{viewtemplates}{$h->{templateid}};
	return undef;  # clearly return something like false
};	


sub _checkViewTemplateId($) {
#	makes sure that a view template id adheres to the rules for Perl variables
#	returns undef if everything is ok, a message otherwise
	my ($id) = @_;
	return undef if $id =~ m/^[_a-zA-Z][_a-zA-Z0-9]*$/;	
	return 'View template name "'.$id.'" is invalid. You can only use letters (a..b,A..B), numbers (0..9) and the underscore (_). The first character can only be a letter or the underscore. Whitespace (blanks) cannot be used.'; 
};


sub _setRename($$) {
	# e.g. set ui rename type=viewtemplate origintemplateid=test targettemplateid=testnew 
	my ($hash,$h) = @_;
	return '"set rename": unknown type' unless exists $h->{type} and $h->{type} eq "viewtemplate";
	return '"set rename": origin template id missing' unless $h->{origintemplateid};
	return '"set rename": target template id missing' unless $h->{targettemplateid};
	return 'View template '.$h->{origintemplateid}.' does not exist' unless $hash->{viewtemplates}{$h->{origintemplateid}};
	return 'View template '.$h->{targettemplateid}.' already exists' if $hash->{viewtemplates}{$h->{targettemplateid}};
	# now we can start renaming
	my $origin = $h->{origintemplateid};
	my $target = $h->{targettemplateid};
	my $msg = _checkViewTemplateId($target);
	return $msg if $msg;
	# rename usages in all views, which are View Template Instances
	my $cb = sub ($$) {
				my (undef, $view) = @_;
				return unless blessed($view) eq 'FUIP::ViewTemplInstance' and $view->{templateid} eq $origin;
				$view->{templateid} = $target;
		};
	_traverseViews($hash,$cb);
	# rename the view template itself
	$hash->{viewtemplates}{$target} = $hash->{viewtemplates}{$origin};
	delete $hash->{viewtemplates}{$origin};
	$hash->{viewtemplates}{$target}{id} = $target;	
	return undef;  # clearly return "all good"
};	


sub _setConvert($$) {
	# convert one thing into another
	# supported:
	#	cell -> view template
	# set ... convert origintype=... originpageid=... origincellid=... targettype=... targettemplateid=...
	my ($hash,$h) = @_;	
	return '"set convert": origin type '.$h->{origintype}.' not supported' unless $h->{origintype} eq "cell";
	return '"set convert": target type '.$h->{targettype}.' not supported' unless $h->{targettype} eq "viewtemplate";
	my $origin = _getContainerForCommand($hash,$h,"origin");
	return '"set convert": origin does not exist' unless $origin;
	my $templateid = $h->{targettemplateid};
	return '"set convert": target already exists' if(exists($hash->{viewtemplates}{$templateid}));   
	my $msg = _checkViewTemplateId($templateid);
	return $msg if $msg;
	# create new view template
	$hash->{viewtemplates}{$templateid} = FUIP::ViewTemplate->createDefaultInstance($hash,$hash);
	$hash->{viewtemplates}{$templateid}{id} = $templateid;
	$hash->{viewtemplates}{$templateid}->setParent($hash);
	# create a deep copy of the cell
	my $instanceStr = $origin->serialize();
	my $instance = "FUIP::Cell"->reconstruct(eval($instanceStr),$hash);
	for my $comp (qw(layout autoplay navbuttons pagination views)) {
		$hash->{viewtemplates}{$templateid}{$comp} = $instance->{$comp};
	};
	for my $comp (qw(layout autoplay navbuttons pagination)) {
		$hash->{viewtemplates}{$templateid}{defaulted}{$comp} = $instance->{defaulted}{$comp};
	};
	$hash->{viewtemplates}{$templateid}->dimensions(cellSizeToPixels($instance));
	return undef;  # show caller that everything is ok
};


sub _setRepair($$) {
	# currently only for pages
	# simply removes width and height from cells to force them being re-determined
	my ($hash,$h) = @_;
	my $page = _getContainerForCommand($hash,$h);
	for my $cell (@{$page->{cells}}) {
		delete $cell->{width};
		delete $cell->{height};
		delete $cell->{posX};
		delete $cell->{posY};
	};
	return undef;
}


sub _getLock($;$) {
	my ($hash,$ip) = @_;
	if(not $ip) {
		my $client = $main::defs{$main::FW_cname};
		$ip = $client->{PEER};
	};
	if($hash->{lockIPs}) {
		for my $entry (split(/,/,$hash->{lockIPs})) {
			my @entry = split(/:/,$entry);
			return $entry[1] if($entry[0] eq $ip or $entry[0] eq "all");
		};
	};
	return main::AttrVal($hash->{NAME},"locked",0);
};


sub _setLock($$) {
	my ($hash,$a) = @_;
	# Internal lock: List of explicitly (un)locked IP-Addresses or "all"
	#		127.0.0.1:0,192.168.178.45:0 - "home" is unlocked, ...45 is unlocked
	#		all:0 - all unlocked
	#		all:1,127.0.0.1:0 - all locked except home
	# What exactly happens depends on attribute "locked". Entries in internal "lock"
	# are normally the opposite of attribute "locked". Otherwise, they are deleted.
	
	# get attribute "locked"
	my $attrLocked = main::AttrVal($hash->{NAME},"locked",0);
	# get target state
	my $newState = $a->[1] eq "lock" ? 1 : 0;
	# get target IP
	# defaulting: if locked via attribute, then default of unlock is "client", of lock is "all"
	#			  if unlocked via attribute, then vice versa	
	my $ip = $newState == $attrLocked ? "all" : "client";
	if(exists($a->[2])) {
		$ip = $a->[2];
		# The following does not really make sure that the ip 
		# address is valid. However, it makes sure that it is good 
		# enough not to create further issues.
		if ( not $ip =~ m/^all$|^client$|^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$/ ){
			return 'set (un)lock: argument must be a valid ip address or \"all\" or \"client\"';
		};
	};	
	if($ip eq "client") {
		my $client = $main::defs{$main::FW_cname};
		return 'set (un)lock client: no (FHEMWEB) client found' unless $client;
		$ip = $client->{PEER};
	};
	# now $ip should be a proper ip address or "all"
	if($ip eq "all") {
		if($newState == $attrLocked) {
			delete $hash->{lockIPs};
		}else{
			$hash->{lockIPs} = "all:".$newState;
		};
	}else{
		return 'set (un)lock: ignored, won\'t change anything' if _getLock($hash,$ip) == $newState;
		my @ips;
		my $done = 0;
		if($hash->{lockIPs}) {
			for my $entry (split(/,/,$hash->{lockIPs})) {
				my @entry = split(/:/,$entry);
				if($entry[0] eq $ip and $entry[1] != $newState) {
					$done = 1;
				}else{	
					push(@ips,$entry);
				};		
			};
		};
		unshift(@ips,$ip.":".$newState) unless $done; 
		if(@ips) {
			$hash->{lockIPs} = join(",",@ips);
		}else{
			delete $hash->{lockIPs};
		};	
	};
	return undef;
};	


sub _innerSet($$$)
{
	my ( $hash, $a, $h ) = @_;

	# main::Log3($hash, 3, 'FUIP: Set: ' . main::Dumper($a).'  '.main::Dumper($h));
	
	return "\"set ".$hash->{NAME}."\" needs at least one argument" unless(@$a > 1);
	my $cmd = $a->[1];
	if($cmd eq "save"){
		return save($hash);
	}elsif($cmd eq "load"){
		return load($hash,(exists $a->[2] ? $a->[2] : undef));
	}elsif($cmd eq "settings") {
		# type=cell|dialog|viewtemplate
		# cell:
		#	pageid, cellid
		# dialog:
		#	popups in cells: pageid, cellid, fieldid 
		#	popups in viewtemplates: templateid, fieldid
		# viewtemplate
		#	templateid
		return _setSettings($hash,$h);
	}elsif($cmd eq "delete") {
		# e.g. set ui delete type=viewtemplate templateid=test
		return _setDelete($hash,$h);	
	}elsif($cmd eq "rename") {
		# e.g. set ui rename type=viewtemplate origintemplateid=test targettemplateid=testnew 
		return _setRename($hash,$h);
	}elsif($cmd eq "resize") {
		my $container = _getContainerForCommand($hash,$h);
		return "\"set resize\": could not find view/cell/dialog/view template" unless $container;
		$container->dimensions($h->{width},$h->{height});
	}elsif($cmd eq "convert") {
		return _setConvert($hash,$h);
	}elsif($cmd eq "repair") {
		# repair page, i.e. set cell sizes
		return _setRepair($hash,$h);	
	}elsif($cmd eq "viewdelete") {
		# get cell id
		my ($pageId,$cellId) = getPageAndCellId($hash,$a);
		return $cellId unless(defined($pageId));
		# delete cell from array
		splice(@{$hash->{pages}{$pageId}{cells}},$cellId,1);
	}elsif($cmd eq "viewaddnew"){
		#get page id
		my $pageId = (exists($a->[2]) ? $a->[2] : "");
		return "\"set viewaddnew\": page ".$pageId." does not exist" unless defined $hash->{pages}{$pageId};
		my $newCell = FUIP::Cell->createDefaultInstance($hash,$hash->{pages}{$pageId});
		$newCell->{region} = $a->[3] if($a->[3]);	
		push(@{$hash->{pages}{$pageId}{cells}},$newCell);
	}elsif($cmd eq "pagedelete") {
		#get page id
		my $pageId = (exists($a->[2]) ? $a->[2] : "");
		return "\"set pagedelete\": page ".$pageId." does not exist" unless defined $hash->{pages}{$pageId};
		delete($hash->{pages}{$pageId});
	}elsif($cmd eq "pagecopy") {
		#get page ids
		return "\"set pagecopy\" needs two page ids" unless exists($a->[3]);
		my ($oldPageId,$newPageId) = ($a->[2], $a->[3]);
		return "\"set pagecopy\": page ".$oldPageId." does not exist" unless defined $hash->{pages}{$oldPageId};
		$hash->{pages}{$newPageId} = cloneView($hash->{pages}{$oldPageId});
	}elsif($cmd eq "cellcopy") {
		#get page ids etc.
		my ($oldPageId,$oldCellId) = getPageAndCellId($hash,$a);
		return $oldCellId unless(defined($oldPageId));
		return "\"set cellcopy\": needs a target page id" unless exists($a->[3]);
		my $newPageId = $a->[3];
		FUIP::Generator::createPage($hash,$newPageId) unless defined $hash->{pages}{$newPageId};
		my $oldCell = $hash->{pages}{$oldPageId}{cells}[$oldCellId];
		my $newCell = cloneView($oldCell);
		delete $newCell->{posX};
		delete $newCell->{posY};
		push(@{$hash->{pages}{$newPageId}{cells}},$newCell);
		$newCell->setParent($hash->{pages}{$newPageId});
		#Make system id explicit, if it was "inherit" and would change
		if(not defined($oldCell->{sysid}) or $oldCell->{sysid} eq '<inherit>') {
			my $oldSysid = $oldCell->getSystem();
			$newCell->{sysid} = $oldSysid unless $oldSysid eq $newCell->getSystem();
        };
	}elsif($cmd eq "pagesettings") {	
		# get page id
		my $pageId = $a->[2]; 
		return "\"set pagesettings\": page ".$pageId." does not exist" unless defined $hash->{pages}{$pageId};
		setPageSettings($hash->{pages}{$pageId}, $h);
	}elsif($cmd eq "position") {
		my $container = _getContainerForCommand($hash,$h);
		return "\"set position\": could not find view" unless $container;
		$container->position($h->{x},$h->{y});
		# has the view moved into a new cell?
		if(defined($h->{newcellid})) {
			my $oldCell = $hash->{pages}{$h->{pageid}}{cells}[$h->{cellid}];
			my $newCell = $hash->{pages}{$h->{pageid}}{cells}[$h->{newcellid}];
			return '"set position": cell missing when trying to move between cells' unless $oldCell and $newCell;
			# remove view from old cell
			splice(@{$oldCell->{views}},$h->{viewid},1);
			# put view into new cell 
			push(@{$newCell->{views}},$container);
			$container->setParent($newCell);
			#Make system id explicit, if it was "inherit" and would change
			if(not defined($container->{sysid}) or $container->{sysid} eq '<inherit>') {
				my $oldSysid = $oldCell->getSystem();
				$container->{sysid} = $oldSysid unless $oldSysid eq $newCell->getSystem();
            };
		};
	}elsif($cmd eq "autoarrange") {
		my $container = _getContainerForCommand($hash,$h);
		return '"set autoarrange": No container found' unless $container;	
		autoArrange($container);
	}elsif($cmd eq "refreshBuffer") {
		FUIP::Model::refresh($hash->{NAME});
	}elsif($cmd eq "editOnly") {
		$hash->{editOnly} = $a->[2];
	}elsif($cmd eq "colors") {
		if($a->[2] eq "reset") {
			$hash->{colors} = { };
		}else{	
			for my $key (keys %$h) {
				$hash->{colors}{$key} = $h->{$key};
			};
		};	
	}elsif($cmd =~ m/^(lock|unlock)$/) {
		return _setLock($hash,$a);
	}else{
		# redetermine attribute values
		setAttrList($main::modules{FUIP});
		my $files = getConfigFiles($hash);
		return "Unknown argument $cmd, choose one of save:noArg".
				($files ? " load:".join(',',@$files) : "").
				" lock unlock refreshBuffer pagedelete:".join(',',sort keys %{$hash->{pages}});
				# further commands are: viewsettings viewaddnew viewdelete viewposition autoarrange, 
				# but these are only for internal use 
	}
	return undef;  # i.e. all good
}


sub Set($$$) {
	my ( $hash, $a, $h ) = @_;
	my $result = undef;
	eval {	
		$result = _innerSet($hash,$a,$h);
		1;
	} or do {
		my $ex = $@;
		FUIP::Exception::log($ex);
		$result = FUIP::Exception::getShortText($ex);
	};
	return $result if $result;  # error message
	my $cmd = $a->[1]; # this exists, otherwise _innerSet returns error
	return undef if $cmd =~ m/^(save|load|lock|unlock)$/;  # no auto-save for save and load
	save($hash,1); # TODO: error handling? 
	return undef;  # all good
}


sub _getViewClasses() {
	my @result = keys %$selectableViews;
	return \@result;
};


sub _toJson($);  # wegen Rekursion

sub _toJson($){
    my ($var) = @_;
	my $result = "";
	return "\"\"" if(!defined($var)); 
	if(ref($var) eq "HASH") {
		$result = '{';
	    my $afterfirst = 0;
	    foreach my $key (sort keys %{$var}) {
	        if($afterfirst) {
		        $result .= ',';
		    }else{
                $afterfirst = 1;
            };			
	        $result .= "\n";
	        $result .= '"'.$key.'":';
		    $result .= _toJson($var->{$key});
	    };
	    $result .= "\n}";
	}elsif(ref($var) eq "ARRAY") {
		$result .= " [ ";
	    for(my $i = 0; $i < int(@{$var}); $i++) {
		    $result .= "," if($i > 0);
			$result .= _toJson($var->[$i]);	
        };
		$result .= " ] ";
    }else{	
	    $result .= '"'.main::urlEncode($var).'"';
	};	
    return $result;
};


sub _getDeviceList($$) {
	my ($name,$sysid) = @_;
	my $result = [];
	my $keys = FUIP::Model::getDeviceKeys($name,$sysid);
	for my $key (sort { lc($a) cmp lc($b) } @$keys) {
		my $device = FUIP::Model::getDevice($name,$key,["TYPE","room","alias"],$sysid);
		push(@$result, {
			NAME => $key,
			TYPE => $device->{Internals}{TYPE},
			room => $device->{Attributes}{room},
			alias => $device->{Attributes}{alias}
			});
	};
	return $result;
};


sub keyToString($) {
	my $key = shift;
	my $result = $key->{type}.':';
	if($key->{type} eq "page") { 
		$result .= $key->{pageid};
	}elsif($key->{type} eq 'cell') {
		$result .= $key->{cellid};
	}elsif($key->{type} eq 'dialog') {
		$result .= $key->{fieldid};
	}elsif($key->{type} eq 'viewtemplate') {
		$result .= $key->{templateid};
	}elsif($key->{type} eq 'view') {
		$result .= $key->{viewid};
	};	
	return $result;
};


sub _traverseViews($$;$$); # recursion
sub _traverseViews($$;$$) {
	my ($hash,$func,$startkey,$startobj) = @_;
	# traverse all views starting with object $start if given
	# if there is no $start, traverse all views of FUIP device in $hash
	# $func has parameters ($key,$view)
	#	$key: key of view (see sub _getContainerForCommand)
	#	$view: the view currently "traversed"
	# $key 
	#	views in cells: pageid, cellid, viewid
	#	views on popups in cells: pageid, cellid, fieldid, viewid 
	#	views on popups in viewtemplates: templateid, fieldid, viewid
	#	views in viewtemplates:	templateid, viewid
	# types: 
	#	page, cell, dialog, viewtemplate, view
	
	unless($startkey) {  # i.e. when we start from scratch
		# views in cells in pages
		for my $pageid (sort keys %{$hash->{pages}}) { 
			_traverseViews($hash,$func,{type => "page", pageid => $pageid},$hash->{pages}{$pageid});
		};
		# views in view templates
		for my $id (sort keys %{$hash->{viewtemplates}}) {
			_traverseViews($hash,$func,{type => "viewtemplate", templateid => $id},$hash->{viewtemplates}{$id});
		};
		return;
	};	
	
	# main::Log3(undef,1,"Traversing ".keyToString($startkey));
	
	my $key = { %$startkey };
	# traverse single page
	if($startkey->{type} eq "page") { 
		my $cells = $startobj->{cells};
		$key->{type} = "cell";
		for my $cellid (0..$#$cells) {
			$key->{cellid} = $cellid;
			_traverseViews($hash,$func,$key, $cells->[$cellid]);
		};
	# traverse single cell, dialog or viewtemplate
	}elsif($startkey->{type} =~ m/^cell|dialog|viewtemplate/) {
		$key->{type} = "view";
		my $views = $startobj->{views};
		for my $viewid (0..$#$views) {
			my $view = $views->[$viewid];
			$key->{viewid} = $viewid;
			_traverseViews($hash,$func,$key,$view);
		}
	# "traverse" single view
	}elsif($startkey->{type} eq "view") {
		# callback
		&$func($key,$startobj);
		# check for dialogs (popups)
		for my $fieldname (keys %$startobj) { 
			next if $fieldname eq 'parent';
			next unless blessed($startobj->{$fieldname}) and $startobj->{$fieldname}->isa("FUIP::Dialog");
			$key->{type} = "dialog";
			if($key->{fieldid}) {
				$key->{fieldid} .= "-";
			}else{	
				$key->{fieldid} = "";
			};
			$key->{fieldid} .= "views-".$key->{viewid}."-".$fieldname;  # views-1-popup-views-3-popup...	
			_traverseViews($hash,$func,$key,$startobj->{$fieldname});
		};
	};	
};


# simplified form to traverse views of the currently rendered "thing",
# usually called the current page, even if it is a dialog, view template
# or the whole set of view templates
# It does not use the "key" part of the callback, as this is anyway not
# really clean
sub _traverseViewsOfPage($$$) {
	my ($hash,$func,$page) = @_;
	my $key = {};
	
	# define callback for the normal _traverse function
	my $cb; # recursion
	$cb = sub ($$) {
				my ($key, $view) = @_;
				&$func($view);
				# also deep-dive into template instances
				if(blessed($view) eq "FUIP::ViewTemplInstance") {
					my $instance = $view->getInstantiated();
					$key->{type} = "view";
					my $views = $instance->{views};
					for my $viewid (0..$#$views) {
						my $subview = $views->[$viewid];
						$key->{viewid} = $viewid;
						_traverseViews($hash,$cb,$key,$subview);
					};
				};	
			};
	
	if(blessed($page)){ # dialog or view template
		$key->{type} = 'dialog';  # does not really matter here
		_traverseViews($hash,$cb,$key,$page);
	}elsif(ref($page) eq "HASH") { # view template overview
		# in this case, the hash elements should contain something with views
		# e.g. for view template overview
		$key->{type} = 'viewtemplate';
		for my $elem (values %$page) {
			_traverseViews($hash,$cb,$key,$elem);
		};	
	}else{ # should be a page id
		return unless exists $hash->{pages}{$page};
		$key->{type} = 'page';
		_traverseViews($hash,$cb,$key,$hash->{pages}{$page});
	};
};



sub _getWhereUsedList($$;$); # recursion
sub _getWhereUsedList($$;$) {
	# determine where-used-list, currently only for view templates
	# TODO: popups (dialogs)
	my ($hash,$h,$result) = @_;
	# Doc
	# $h: hash with possible keys:
	#	type: 		must be "viewtemplate"
	#	templateid: must be present, contains view template id
	#	filter-type: if set, only return objects of this type
	#	recursive: 1/0 if set and 1, return recursive where used list
	# result
	# 	array reference to array of hashes
	#	each entry can refer to a view or viewtemplate		
	
	return "[]" unless $h->{type} eq "viewtemplate";
	my $templateid = $h->{templateid};
	return "[]" unless $templateid;
	$result = [] unless $result;
	
	unless($h->{"filter-type"} and $h->{"filter-type"} ne "view") {
		# usage in views in cells in pages
		my $cb = sub ($$) {
					my ($key, $view) = @_;
					return unless blessed($view) eq 'FUIP::ViewTemplInstance' and $view->{templateid} eq $templateid;
					push(@$result, {%$key}); 
				};
		for my $pageid (sort keys %{$hash->{pages}}) { 
			_traverseViews($hash,$cb,{type => "page", pageid => $pageid},$hash->{pages}{$pageid});
		};	
	};
	unless($h->{"filter-type"} and $h->{"filter-type"} ne "viewtemplate") {
		# usage in other view templates
		my $cb = sub ($$) {
					my ($key, $view) = @_;
					return unless blessed($view) eq 'FUIP::ViewTemplInstance' and $view->{templateid} eq $templateid;
					push(@$result, {type => "viewtemplate", templateid => $key->{templateid}}); 
					if($h->{recursive}) {
						_getWhereUsedList($hash,{type => "viewtemplate", templateid => $key->{templateid}, 
												"filter-type" => $h->{"filter-type"}, recursive => 1},$result);
					};
				};
		for my $id (sort keys %{$hash->{viewtemplates}}) {
			_traverseViews($hash,$cb,{type => "viewtemplate", templateid => $id},$hash->{viewtemplates}{$id});
		};
	};	
	return $result;
};


sub _getContainerForCommand($$;$) {
	# type=cell|dialog|viewtemplate|view
	# cell:
	#	pageid, cellid
	# dialog:
	#	popups in cells: pageid, cellid, fieldid 
	#	popups in viewtemplates: templateid, fieldid
	# viewtemplate
	#	templateid
	# view
	# 	viewid plus "all of the above"
	my ($hash,$h,$prefix) = @_;
	$prefix = ($prefix ? $prefix : "");
	my $type = $h->{$prefix."type"};
	if($type eq "page") {
		my $pageid = $h->{$prefix."pageid"};
		return $hash->{pages}{$pageid};
	}elsif($type eq "cell") {
		# get cell
		my $cellid = $h->{$prefix."cellid"};
		my $pageid = $h->{$prefix."pageid"};
		# get field list and values from views 
		return undef unless(defined($hash->{pages}{$pageid}) and defined($hash->{pages}{$pageid}{cells}[$cellid]));
		return $hash->{pages}{$pageid}{cells}[$cellid];
	}elsif($type eq "dialog"){  
		# e.g. for popups: Get a component (field) of a view
		# find the dialog
		return findDialogFromFieldId($hash,$h,$h->{$prefix."fieldid"},$prefix);
	}elsif($type eq "viewtemplate"){
		# for view templates
		return $hash->{viewtemplates}{$h->{$prefix."templateid"}};  
	}elsif($type eq "view") {
		my $container;
		if(exists($h->{$prefix."fieldid"})) {
			$container = findDialogFromFieldId($hash,$h,$h->{$prefix."fieldid"},$prefix);
		}elsif(exists($h->{$prefix."templateid"})) {
			$container = $hash->{viewtemplates}{$h->{$prefix."templateid"}};
		}else{
			my $cellid = $h->{$prefix."cellid"};
			my $pageid = $h->{$prefix."pageid"};
			return undef unless(defined($hash->{pages}{$pageid}) and defined($hash->{pages}{$pageid}{cells}[$cellid]));
			$container = $hash->{pages}{$pageid}{cells}[$cellid];
		};
		return undef unless $container;	
		return $container->{views}[$h->{$prefix."viewid"}];
	};
};


sub _getSettings($$) {
	my ($hash,$h) = @_;
	my $container = _getContainerForCommand($hash,$h);
	return "\"get settings\": could not find cell/dialog/view template" unless $container;
	my $result = $container->getConfigFields();
	# some special logic for popups within templates
	if($h->{type} eq 'dialog' and $h->{templateid}) {
		$hash->{viewtemplates}{$h->{templateid}}->getConfigFieldsSetVariables($result,$h->{fieldid});	
	};
	return _toJson($result);
};


sub _setSettings($$) {
	my ($hash,$h) = @_;
	my $container = _getContainerForCommand($hash,$h);
	return "\"set settings\": could not find cell/dialog/view template" unless $container;
	setViewSettings($hash, [$container], 0, $h);
	if($h->{type} eq "viewtemplate" or $h->{type} eq "dialog" and $h->{templateid}) {
		$hash->{viewtemplates}{$h->{templateid}}->setVariableDefs($h);
	};
	autoArrangeNewViews($container);	
	return undef;
};	


my %docuConfPopup = (
	# cell, dialog, viewtemplate, page
	"general" => { 
		"general" => "Auf den Konfigurations-Dialogen legt man haupts&auml;chlich den Inhalt der betreffenden Elemente fest. D.h. man kann hier Views hinzuf&uuml;gen und l&ouml;schen sowie die Views konfigurieren. Die Positionierung der Views erfolgt dann direkt auf der Oberfl&auml;che mittels Drag&amp;Drop.<br><br>
		F&uuml;r die meisten Elemente in den Konfigurationsdialogen erscheinen Hilfetexte. Buttons und manche andere Elemente muss man mittels \"Tab\" in den Fokus holen, um deren Hilfetext zu sehen.",
		"gotovtemplates" => "Ruft die Bearbeitungsoberfl&auml;che f&uuml;r View Templates auf",
		"addview" => "Neuen View einf&uuml;gen.<br>
			Damit wird sozusagen neuer Inhalt zu einer Zelle hinzugef&uuml;gt. Man w&auml;hlt dann aus, welche Art View angelegt werden soll und f&uuml;llt die Details, wie z.B. das zugeh&ouml;rige Device. Der neue View wird an einer freien Stelle (falls m&ouml;glich) in der Zelle positioniert. Nach dem Schlie&szlig;en des Konfigurations-Dialogs kann man den View per Drag&amp;Drop an die gew&uuml;nschte Stelle schieben und ggf. die Gr&ouml;&szlig;e anpassen.",
		"addviewsbydevice" => "Neue Views nach Device ausw&auml;hlen<br>
			Dies dient ebenfalls dazu, neue Views in die Zelle zu packen. Allerdings w&auml;hlt man nicht die Art des Views aus, sondern die FHEM-Devices, die dargestellt werden sollen. Das System sucht dann jeweils einen geeigneten View aus. Bisher funktioniert das nur sehr eingeschr&auml;nkt, hat aber den Vorteil, dass man gleich mehrere Devices ausw&auml;hlen kann.",
		"cancel" => "Damit schlie&szlig;t man den Dialog ohne die &Auml;nderungen zu &uuml;bernehmen.",
		"viewdetails" => "Hier klappt man die Details zum View aus und kann diese &auml;ndern.<br>
			Was man dann genau machen kann kommt auf die Art der View an. Per Drag&amp;Drop kann man auch die Reihenfolge der Views im Konfigurations-Dialog &auml;ndern. Das hat allerdings keinen unmittelbaren Effekt auf die Positonierung bereits existierender Views in der Zelle, au&szlig;er man benutzt die Funktion <i>Arrange views</i>.",
		"deleteview" => "View aus der Zelle bzw. Dialog oder View Template l&ouml;schen.<br>
			Wenn man den View eigentlich nicht l&ouml;schen, sondern in einer anderen Zelle haben will, dann kann man ihn auch per Drag&amp;Drop in die andere Zelle verschieben. L&auml;sst man einen View in einer anderen Zelle \"fallen\", dann wird dieser automatisch der neuen Zelle zugeordnet.",
		"ok" => "Dialog schlie&szlig;en und &Auml;nderungen &uuml;bernehmen.<br>
			Dadurch kann man die Auswirkungen auf der Oberfl&auml;che selbst sehen. Um die &Auml;nderungen allerdings den n&auml;chsten FHEM Neustart &uuml;berleben zu lassen muss man noch ein <i>set...save</i> machen.",
		"autoarrange" => "Views automatisch in der Zelle anordnen (positionieren).<br>
			FUIP ordnet die Views in der Reihenfolge an, in der sie im Konfigurations-Dialog erscheinen. Das zugrunde liegende Layout ist sehr einfach gehalten und kann sich auch noch &auml;ndern. Diese Funktion ist vor Allem brauchbar f&uuml;r mehrere gleichartige Views in derselben Zelle, wie z.B. bei Men&uuml;s.<br>
			Bevor diese Funktion ausgef&uuml;hrt wird, werden alle &Auml;nderungen &uuml;bernommen und der Konfigurations-Dialog wird geschlossen.",
		"export" => "Aktuelle(n) Zelle/Seite/Dialog/ViewTemplate exportieren<br>
			Dies erlaubt die Definition des aktuell bearbeiteten Objekts herunterzuladen und auf dem Client (also dem Rechner, auf dem der Browser l&auml;uft) zu speichern. Exportierte FUIP-Objekte k&ouml;nnen auch in andere FHEM-Installationen hochgeladen werden.",
		"editonly" => "Modus zur einfacheren Bearbeitung aktivieren<br>
			Bei manchen Views ist es schwierig, sie mit der Maus \"anzufassen\", da sie sofort eine Aktion ausl&ouml;sen (z.B. bei Links). Mit \"Toggle editOnly\" wird eine graue \"Schicht\" &uuml;ber die Views gelegt. Dadurch wei&szlig; man besser, wo man den View anfassen kann und Mausklicks haben keine Wirkung mehr, außer f&uuml;r Drag&amp;Drop und &Auml;nderung von H&ouml;he und Breite.",
		"gotocolours" => "Zum \"Farben-Dialog\" springen<br>
			Der \"Farben-Dialog\" erlaubt das &Auml;ndern von bestimmten Farben in der Oberfl&auml;che. Zum Beispiel kann die Hintergrundfarbe, die Vordergrundfarbe und die Farbe der Symbole ge&auml;ndert werden.",
		"opennews" => "FUIP News anzeigen<br>
			Es wird ein neues Browserfenster ge&ouml;ffnet, in dem die \"FUIP News\" angezeigt werden. Dies ist eine Liste von &Auml;nderungen und Neuerungen in FUIP, geordnet nach Datum.",
		"opendocu" => "FUIP Dokumentation anzeigen<br>
			Es wird ein neues Browserfenster ge&ouml;ffnet, in dem eine ausf&uuml;hrliche Dokumentation zu FUIP angezeigt wird.",
		"lock" => "Oberfl&auml;che gegen &Auml;nderungen sperren<br>
			Dies entspricht dem FHEM-Befehl <i>set...lock</i>. Man kann auch w&auml;hlen, ob man nur den aktuellen Client oder alle Clients sperren will." 
	},	
	"Cell" => {
		"general" => "Dies ist der Konfigurations-Dialog f&uuml;r Zellen.",
		"gotopage" => "Wechselt zum Konfigurations-Popup f&uuml;r die aktuelle Seite",
		"addcell" => "Neue Zelle anlegen<br>
			Dadurch wird eine neue (leere) Zelle auf der aktuellen Seite angelegt. Bevor diese Funktion ausgef&uuml;hrt wird, werden alle &Auml;nderungen &uuml;bernommen und der Konfigurations-Dialog wird geschlossen.",
		"copycell" => "Aktuelle Zelle kopieren<br>
			Man muss eine Seite angeben, zu der die kopierte Zelle geh&ouml;ren soll. Das entsprechende Feld ist mit der aktuellen Seite vorbelegt. Falls man dies nicht &auml;ndert, wird einfach eine Kopie der Zelle auf derselben Seite erzeugt. Ansonsten wird die Zelle auf die angegebene Seite kopiert. Bevor diese Funktion ausgef&uuml;hrt wird, werden alle &Auml;nderungen &uuml;bernommen und der Konfigurations-Dialog wird geschlossen. Falls man eine andere Seite angegeben hat, wird zu dieser gewechselt. Wenn man eine Seite angibt, die noch nicht existiert, dann wird diese Seite angelegt mit der kopierten Zelle als einzigen Inhalt.",
		"import" => "Exportierte Zelle von Datei importieren<br>
			FUIP erzeugt uf der aktuellen Seite eine neue Zelle mit dem entsprechenden Inhalt. Das funktioniert auch mit Zellen, die von einer anderen FUIP-Seite, einem anderen FUIP-Device oder von einer anderen FHEM-Installation kommen.",
		"deletecell" => "Aktuelle Zelle l&ouml;schen.<br>
			Die Zelle verschwindet dann von der aktuellen Seite und der Konfigurations-Dialog wird geschlossen.",
		"makevtemplate" => "View Template aus aktueller Zelle generieren<br>
			Die aktuelle Zelle wird als View Template angelegt. Dann wird auf die Bearbeitungsoberfl&auml;che f&uuml;r das neue View Template gesprungen. Die aktuelle Zelle wird dadurch nicht ge&auml;ndert. Insbesondere wird das neue View Template <b>nicht</b> automatisch in der aktuellen Zelle verwendet."
	},	
	"Dialog" => {
		"general" => "Dies ist der Konfigurations-Dialog f&uuml;r Popups (Dialoge)."
	},	
	"ViewTemplate" => {
		"general" => "Dies ist der Konfigurations-Dialog f&uuml;r View Templates."
	},	
	"Page" => { 
		"general" => "Dies ist der Konfigurations-Dialog f&uuml;r Seiten.",
		"gotocell" => "Wechselt zur&uuml;ck zum Konfigurations-Popup f&uuml;r die aktuelle Zelle",
		"copypage" => "Seite kopieren<br>
			Es wird eine neue Seite angelegt, die so aussieht wie die aktuelle. Der Dialog wird dann geschlossen und automatisch zur neuen Seite gesprungen.",
		"import" => "Exportierte Seite von Datei importieren<br>
			Beim Importieren gibt man einen (neuen) Namen f&uuml;r die Seite an. Diese Seite wird dann mit dem Inhalt der Export-Datei angelegt. Der Dialog wird dann geschlossen und automatisch zur neuen Seite gesprungen."
	}	
);

	
sub _getDocu($$) {
	my ($hash,$docid) = @_;
	my ($class,$fieldname) = split(/-/,$docid);
	my (undef,$category,$viewname) = split(/::/,$class);
	my $result = "<b>";
	if($category eq "Cell") {
		$result .= "Zelle";
	}elsif($category eq "View") {
		$result .= $viewname;
	}elsif($category eq "Page") {
		$result .= "Seite";
	}elsif($category eq "Dialog") {
		$result .= "Popup";	
	}elsif($category eq "VTempl") {
		$result .= "View Template \"".$viewname.'"';	
	}elsif($category eq "ViewTemplate") {
		$result .= "View Template";
	}elsif($category eq "ConfPopup") {
		$result .= "Konfiguration ";	
		if($viewname eq "Cell") {
			$result .= "Zelle";
		}elsif($viewname eq "Dialog") {
			$result .= "Popup";
		}elsif($viewname eq "ViewTemplate") {
			$result .= "View Template";
		}elsif($viewname eq "Page") {
			$result .= "Seite";
		};
	};
	if($fieldname) {
		$result .= ": <i>".$fieldname."</i>";
	};
	$result .= "</b><br>";
	if($category =~ /^(View|Page|Cell|Dialog|ViewTemplate)$/) {  
		$result .= $class->getDocu($fieldname);
	}elsif($category eq "VTempl") {
		if($fieldname) {
			$result .= "FUIP::View"->getDocu($fieldname);
		}else{	
			$result .= 	$hash->{viewtemplates}{$viewname}{title}.'<br>';
			$result .= "View Templates sind normalerweise vom FUIP-Anwender selbst erstellte Views, die wiederum aus anderen Views oder auch anderen View Templates bestehen. Sie sind prinzipiell abh&auml;ngig von der FUIP-Instanz, haben also keine spezifische Dokumentation im System.";
		};
	};
	if($category eq "View") {
		$result = '<img src="'.urlBase($hash).'/fuip/view-images/FUIP-View-'.$viewname.'.png" style="border-style:solid;border-width:1px;float:left;margin-right:10px;margin-bottom:10px" />'.$result.'<p style="clear:left;height:0.5em;"></p>';
	};
	if($category eq "ConfPopup") {
		if($fieldname) {
			if($docuConfPopup{$viewname}{$fieldname}) {
				$result .= $docuConfPopup{$viewname}{$fieldname};
			}else{
				$result .= $docuConfPopup{general}{$fieldname};
			}	
		}else{
			$result .= $docuConfPopup{$viewname}{general}."<br>" if($docuConfPopup{$viewname}{general});
			$result .= $docuConfPopup{general}{general} unless $viewname eq "Page";
		};
	};

	return $result;
};	


sub renderDocu($) {
	my $hash = shift;
	# start of help file
	my $result = readTextFile($hash,"FHEM/lib/FUIP/doc/maindoc.html");
	# render docu for all the (selectable) views	
	my $viewclasses = _getViewClasses();	
	for	my $view (sort @$viewclasses) {
		next if $view eq "FUIP::View";
		my (undef,undef,$viewname) = split(/::/,$view);
		$result .= '
			<h3 id="views-'.$viewname.'">'.$viewname.': '.$selectableViews->{$view}{title}.'</h3>
			<img src="'.urlBase($hash).'/fuip/view-images/FUIP-View-'.$viewname.'.png" style="border-style:solid;border-width:1px;float:left;margin-right:10px;margin-bottom:10px" />'.$view->getDocu();
		my $fields = $view->getStructure();	
		my @fieldnames = map { $_->{id} } grep { $_->{id} ne "class" and $_->{type} ne "dimension" and $_->{type} ne "flexfields"} @$fields;
		if(@fieldnames) {
			$result .= '<br>Die View '.$viewname.' l&auml;sst sich &uuml;ber die folgenden Felder konfigurieren: <i>'.join('</i>, <i>',@fieldnames).'</i>.';

		};
		$result .= '<p style="clear:left;height:0em;">
			<ul>';
		for my $field (@$fields) {
			# next if $field->{id} =~ /^(class|title|label|sizing|popup)$/;
			next if $field->{type} =~ /^(dimension|flexfields)$/;
			my $doctext = $view->getDocu($field->{id},1); # 1 => only specific docu 
			next unless $doctext;
			$result .= '<li><b>'.$viewname.' - '.$field->{id}.'</b><br>'.$doctext.'</li>';
		};	
		$result .= '</ul><br>';
	};
	$result .= '
		</body>
		</html>';	
	return ("text/html; charset=utf-8", $result);
};


sub Get($$$)
{
	my ( $hash, $a, $h ) = @_;

	return "\"get ".$hash->{NAME}."\" needs at least one argument" unless(@$a > 1);
    my $opt = $a->[1];
	
	if($opt eq "settings") {
		# type=cell|dialog|viewtemplate
		# cell:
		#	pageid, cellid
		# dialog:
		#	popups in cells: pageid, cellid, fieldid 
		#	popups in viewtemplates: templateid, fieldid
		# viewtemplate
		#	templateid
		return _getSettings($hash,$h);
	}elsif($opt eq "whereusedlist"){
		return _toJson(_getWhereUsedList($hash,$h));
	}elsif($opt eq "viewclasslist") {
		my @result = map { { id => $_, title => $hash->{viewtemplates}{$_}{title} } } sort keys(%{$hash->{viewtemplates}});  
		for my $entry (@result) {
			$entry->{title} = "View template ".$entry->{id} unless($entry->{title});	
			$entry->{id} = "FUIP::VTempl::".$entry->{id};
		};
		push @result, map { { id => $_, title => $selectableViews->{$_}{title} } } sort keys(%$selectableViews);
		return _toJson(\@result);
	}elsif($opt eq "viewdefaults") {
		my $class = $a->[2];
		return "\"get viewdefaults\" needs a view class as an argument" unless $class;
		if($class =~ m/^FUIP::VTempl::(.*)$/) {
			my $templateid = $1;
			return '"get viewdefaults": view template '.$templateid.' does not exist' unless defined $hash->{viewtemplates}{$templateid};
			my $viewtemplate = $hash->{viewtemplates}{$templateid};
			return _toJson($viewtemplate->getDefaultFields());
		}else{	
			my $viewclasses = _getViewClasses();
			return "\"get viewdefaults\": view class ".$class." unknown, use one of ".join(",",@$viewclasses) unless(grep $_ eq $class, @$viewclasses);
			return _toJson($class->getDefaultFields());	
		};	
	}elsif($opt eq "viewsByDevices") {
		my @views;
		# format is "get viewsByDevices <sysid> <device> <device> ..."
		foreach my $i (3 .. $#{$a}) {
			my $view = FUIP::Generator::getDeviceView($hash, $a->[$i],"overview",$a->[2]);
			if(not defined($view)) {
				$view = FUIP::View::STATE->createDefaultInstance($hash,$hash);
				$view->{device} = $a->[$i];
				$view->{sysid} = $a->[2];
			};			
			$view->applyDefaults();
			push(@views,$view->getConfigFields());
		};
		return _toJson(\@views);
	}elsif($opt eq "pagelist"){
		my @pagelist = sort keys %{$hash->{pages}};
		my @result = map { {id => $_, title => ($hash->{pages}{$_}{title} ? $hash->{pages}{$_}{title} : $_) } } @pagelist;
		return _toJson(\@result);		
	}elsif($opt eq "pagesettings"){
		return "\"get pagesettings\" needs a page id" unless(defined($a->[2]));
		my $pageId = $a->[2];
		return "\"get pagesettings\": page ".$pageId." not found" unless(defined($hash->{pages}{$pageId}));
		my $page = $hash->{pages}{$pageId};	
		return _toJson($page->getConfigFields());			
	}elsif($opt eq "devicelist"){
		# TODO: check if $a->[2] exists
		return "\"get devicelist\" needs a system id" unless(defined($a->[2]));
		return _toJson(_getDeviceList($hash->{NAME},$a->[2]));
	}elsif($opt eq "readingslist") {
		# TODO: check if $a->[2] and $a->[3] exists
		return _toJson(FUIP::Model::getReadingsOfDevice($hash->{NAME},$a->[2],$a->[3]));
	}elsif($opt eq "sets") {
		# TODO: check if $a->[2] and $a->[3] exists
		return _toJson(FUIP::Model::getSetsOfDevice($hash->{NAME},$a->[2],$a->[3]));
	}elsif($opt eq "docu") {
		return _getDocu($hash,$a->[2]);
	}else{
		# get all pages
		my @pages = sort keys %{$hash->{pages}};
		# get all possible cells
		my @cells;
		for my $pKey (@pages) {
			# it seems that there is a crash here sometimes as some pages are lacking
			# the cells array
			# TODO: find out why 
			if(not defined $hash->{pages}{$pKey}{cells}) {
				main::Log3($hash,1,"FUIP: Internal error, no cells for page ".$pKey);
				next;
			};
			for(my $cKey = 0; $cKey < @{$hash->{pages}{$pKey}{cells}}; $cKey++) {
				push(@cells,$pKey."_".$cKey);
			};
		};
		my $viewclasses = _getViewClasses();
		return "All get commands are for internal use only.";
		# get commands are:
		# settings viewclasslist:noArg viewdefaults:".join(",",@$viewclasses)." pagelist:noArg 
		# pagesettings:".join(",",@pages)." devicelist:noArg readingslist sets"
		# However, these are only for internal use
	}
};
   
1;

=pod
=item helper
=item summary    FHEM User Interface Painter 
=item summary_DE FHEM User Interface Painter

=begin html_DE

<a id="FUIP"></a>
<h3>FUIP</h3>
<ul>
  Definiert ein "FHEM User Interface Painter Device" (FUIP Device), welches ein "FUIP Frontend" repr&auml;sentiert. D.h. wenn man FUIP nutzen will, muss man mindestens ein FUIP Device anlegen.	
  <br><br>

  <a id="FUIP-define"></a>
  <b>Define</b><br>
  <code>define &lt;name&gt; FUIP</code><br>
	Mehr ist hier nicht notwendig, alles andere wird &uuml;ber Attribute und set-Kommandos bzw. Klickibunti und M&auml;useschubsen gemacht.
  <br><br>
  <a id="FUIP-set"></a>
  <b>Set</b>
  <ul>
  	<li><a id="FUIP-set-save">save</a>: Speichern des aktuellen Zustands der Oberfl&auml;che<br>
	Das Kommando <code>set...save</code> speichert den momentanen Bearbeitungszustand der Oberfl&auml;che. Dies beinhaltet alles, was man per Klickibunti und M&auml;useschubsen macht, aber nicht die Einstellungen in der FHEMWEB-Oberfl&auml;che. Die FUIP-Oberfl&auml;che wird in einer Datei namens "FUIP_&lt;name&gt;.cfg" gespeichert, wobei &lt;name&gt; der Name des FUIP-Device ist. Normalerweise liegt diese Datei im Verzeichnis "/opt/fhem/FHEM/lib/FUIP/config". 	
	<br>Zus&auml;tzlich zum expliziten <code>set...save</code> gibt es noch einen Autosave-Mechanismus. Die entstehenden Dateien k&ouml;nnen einfach per <code>set...load</code> geladen werden.</li>

	<li><a id="FUIP-set-load">load</a>: Laden eines zuvor gespeicherten Zustands der Oberfl&auml;che<br>
	Das Kommando <code>set...load</code> akzeptiert einen Parameter, &uuml;ber den angegeben werden kann, ob man die normal abgespeicherte Konfiguration laden will ("lastSaved" oder einfach leer lassen) oder eine der Autosave-Dateien.
	FUIP speichert jede &Auml;nderung automatisch ab. Dadurch entstehen für jedes FUIP-Device bis zu 5 Autosave-Dateien, die bei <code>set...load</code> ausgew&auml;hlt werden k&ouml;nnen. </li>
	
	<li><a id="FUIP-set-lock">lock</a>: Sperren der Oberfl&auml;che gegen &Auml;nderungen<br>
	Der Befehl <code>set...lock</code> sperrt die Oberfl&auml;che vor&uuml;bergehend gegen &Auml;nderungen, w&auml;hrend das Attribut <code>locked</code> (noch) nicht gesetzt ist (oder explizit auf "0"), bzw. sperrt die Oberfl&auml;che wieder, nachdem sie mit <code>set...unlock</code> vor&uuml;bergehend in den &Auml;nderungsmodus geschaltet wurde.<br>
	Als weiteren Parameter kann man entweder "client", "all" oder eine IP-Adresse angeben: 
	<ul>
	<li>"client" wirkt nur auf den aktuellen Client (also den Rechner, vor dem man sitzt). </li>
		<li>"all" wirkt auf alle Clients.</li>
		<li>Wird eine IP-Adresse angegeben, dann wirkt das Kommando auf den Client mit dieser IP-Adresse. Dadurch kann man z.B. auf dem Tablet/Telefon nachsehen, wie sich eine &Auml;nderung tats&auml;chlich auswirkt. Mehrere <code>set...lock</code> hintereinander wirken additiv. Insbesondere hat nach einem <code>set...lock all</code> ein <code>set...lock 192.168.178.60</code> keine Wirkung mehr.</li>
		<li>Wird <code>set...lock</code> ohne weiteren Parameter aufgerufen, dann h&auml;ngt die Wirkung vom Attribut <code>locked</code> ab. Ist <code>locked=1</code>, dann ist der Default wie "all". Ansonsten ist der Default wie "client".</li> 
	</ul>		
	</li>
	<li><a id="FUIP-set-unlock">unlock</a>: Die Oberfl&auml;che in den &Auml;nderungsmodus schalten<br>
	Der Befehl <code>set...unlock</code> schaltet die Oberfl&auml;che vor&uuml;bergehend in den &Auml;nderungsmodus, w&auml;hrend das Attribut <code>locked</code> (schon) auf "1" gesetzt ist, bzw. entsperrt die Oberfl&auml;che wieder, nachdem sie mit <code>set...lock</code> vor&uuml;bergehend in den Anzeigemodus geschaltet wurde.<br>
	Als weiteren Parameter kann man entweder "client", "all" oder eine IP-Adresse angeben: 
	<ul>
	<li>"client" wirkt nur auf den aktuellen Client (also den Rechner, vor dem man sitzt). Dadurch kann man z.B. &Auml;nderungen an der Oberfl&auml;che machen, ohne dass Familienmitglieder die Zahnr&auml;dchen angezeigt bekommen.</li>
		<li>"all" wirkt auf alle Clients.</li>
		<li>Wird eine IP-Adresse angegeben, dann wirkt das Kommando auf den Client mit dieser IP-Adresse. Mehrere <code>set...unlock</code> hintereinander wirken additiv. Insbesondere hat nach einem <code>set...unlock all</code> ein <code>set...unlock 192.168.178.60</code> keine Wirkung mehr.</li>
		<li>Wird <code>set...unlock</code> ohne weiteren Parameter aufgerufen, dann h&auml;ngt die Wirkung vom Attribut <code>locked</code> ab. Ist <code>locked=1</code>, dann ist der Default wie "client". Ansonsten ist der Default wie "all".</li> 
	</ul>		
	</li>	
	<li><a id="FUIP-set-pagedelete">pagedelete</a>: FUIP-Seiten l&ouml;schen<br>
	FUIP-Seiten k&ouml;nnen nicht &uuml;ber die Frontend-Bearbeitung gel&ouml;scht werden. Au&szlig;erdem kann es schnell passieren, dass man eine FUIP-Seite aus Versehen anlegt. Diese k&ouml;nnen dann per <code>set...pagedelete</code> gel&ouml;scht werden.<br>
	Das L&ouml;schen einer Seite ist eine &Auml;nderung des Frontends und muss mit <code>set...save</code> explizit gespeichert werden.
	</li>	
	<li><a id="FUIP-set-refreshBuffer">refreshBuffer</a>: Device-Puffer l&ouml;schen<br>
	FUIP verwendet Informationen aus dem "eigentlichen" FHEM, wie z.B. die Liste aller Devices sowie bestimmte Readings, Internals und Attribute. Insbesondere bei "entferntem" FUIP, also bei Verwendung der backend_-Attribute, kann die Ermittlung dieser Daten l&auml;nger dauern. Daher wird praktisch alles durch FUIP zwischengespeichert ("gepuffert"). Wenn man nun neue Devices anlegt bzw. bestehende Devices &auml;ndert, dann bekommt das FUIP-Device davon unter Umst&auml;nden nichts mit. In so einem Fall kann man mit <code>set...refreshBuffer</code> den Zwischenspeicher l&ouml;schen, um FUIP dazu zu zwingen, die Informationen erneut zu ermitteln.<br>
	Im Anzeigemodus (also Attribut locked=1 oder <code>set...locked</code> wurde benutzt) treten diese Effekte nicht auf, da der Puffer bei jedem Seitenaufruf automatisch gel&ouml;scht wird.	
	</li>	
  </ul>
  <br>

  <a id="FUIP-attr"></a>
  <b>Attributes</b>
  <ul>
	<li><a id="FUIP-attr-backendNames">backendNames</a>:Liste von Namen f&uuml;r Backend-FHEMs<br>
		Wenn man eine FUIP-Instanz mit einem entfernten FHEM oder mit mehreren FHEM-Systemen verbinden will, wird jedes verbundene FHEM-System einem symbolischen Namen zugeordnet. Dies geschieht im Prinzip dadurch, dass die Adresse des Systems in ein Attribut der Form <i>backend_&lt;name&gt;</i> eingetragen wird. Im Weiteren wird dann &lt;name&gt; als Kennung f&uuml;r das entsprechende System benutzt. Daf&uuml;r schl&auml;gt FUIP f&uuml;r die ersten paar Systeme Namen vor. Es handelt sich dabei um weibliche Namen aus "Per Anhalter durch die Galaxis". Wem das nicht gef&auml;llt, der kann die <i>backend_</i>-Attribute manuell setzen (<code>attr ui backend_zaphod http://eccentrica:8083/gallumbits</code> w&uuml;rde ein FHEM mit den Namen "zaphod" definieren). Alternativ kann man &uuml;ber das Attribut <i>backendNames</i> eigene Namensvorschl&auml;ge machen. Z.B. <code>attr ui backendNames arthur,ford,marvin,zaphod</code> produziert Vorschl&auml;ge mit m&auml;nnliche Namen aus dem Adams'schen Universum.<br>
		Die Liste darf nur Zeichen enthalten, aus denen auch Attribute bestehen k&ouml;nnen. Die System-Namen m&uuml;ssen durch Komma getrennt werden und die Liste darf keine Leerzeichen enthalten. Sicherheitshalber sollte man nur Kleinbuchstaben und Zahlen verwenden. (Ja, auch der Unterstrich und das Minus-Zeichen k&ouml;nnten Probleme machen.)	
	</li>
  	<li><a id="FUIP-attr-backend_" data-pattern="backend_.*">backend_.*</a>: Adresse eines (entfernten) Backend-FHEMs<br>
Mit FUIP kann man sich an ein "entferntes" FHEM oder sogar mehrere FHEM-Instanzen ankoppeln. Die Attribute der Form <code>backend_.*</code> enthalten dann die Adresse(n) der "entfernten" FHEMWEB-Instanz(en), die man verwenden m&ouml;chte. 
Man darf ein backend_-Attribut auf keinen Fall auf eine Adresse oder IP setzen (auch nicht auf 127.0.0.1), wenn man sich auf das lokale FHEM beziehen will. Wenn man festlegen will, dass ein Backend-System die eigene (lokale) FHEM-Instanz ist, dann muss man das backend_-Attribut auf "local" setzen.<br>
Ansonsten muss das backend_-Attribut die ganze Adresse enthalten, inklusive Port und abschlie&szlig;endem "fhem".<br>
Beispiel:<br>
<code>attr ui backend_fenchurch http://fenchurch:8086/fhem</code><br>
<code>attr ui backend_garden http://192.168.178.73:8086/fhem</code><br>
<code>attr ui backend_home local</code><br>
Damit kennt die FUIP-Instanz <i>ui</i> drei Backend-FHEMs (oder auch Backend-Systeme): fenchurch, garden und home. Die ersten beiden beziehen sich auf "entfernte" FHEMs, die dritte Instanz ist dasselbe System, auf dem auch das FUIP-Device definiert ist.<br>
Das Attribut <code>CORS</code> entfernter FHEMWEB-Instanz(en) muss dann auf "1" stehen. Au&szlig;erdem d&uuml;rfen diese FHEMWEB-Instanzen keine Passwort-Pr&uuml;fung haben. Stattdessen kann man mit dem Attribut <code>allowedfrom</code> oder einer allowed-Instanz den Zugriff einschr&auml;nken.<br>
Wenn man ein "entferntes" FHEM benutzt, dann k&ouml;nnen einige Funktionen der Konfigurationsoberfl&auml;che etwas Zeit brauchen. Zum Beispiel m&uuml;ssen für die Eingabehilfe f&uuml;r Devices alle Devices aus dem entfernten FHEM gelesen werden. Das ist so implementiert, dass das entfernte FHEM m&ouml;glichst wenig belastet wird, was aber zu Lasten des FUIP-FHEM geht. Siehe auch das Set-Kommando <code>refreshBuffer</code> zu diesem Thema.	
</li>	
    <li><a id="FUIP-attr-baseHeight">baseHeight</a>: Basish&ouml;he einer Zelle<br>
	Eine 1x1-Zelle ist <code>baseHeight</code> Pixel hoch. Standardwert ist 108.
	</li> 
     <li><a name="baseWidth">baseWidth</a>: Basisbreite einer Zelle<br>
	Eine 1x1-Zelle ist <code>baseWidth</code> Pixel breit. Standardwert ist 142.
	</li>
	<li><a id="FUIP-attr-cellMargin">cellMargin</a>: Zellzwischenraum<br>
	Mit dem Attribut <code>cellMargin</code> kann man jetzt den Platz zwischen den Zellen festlegen. Der Wert muss zwischen 0 und 10 liegen, der Standardwert ist 5. Um jede Zelle herum werden <code>cellMargin</code> Pixel frei gehalten. D.h. zwischen zwei Zellen ist zweimal so viel Platz (in Pixel) wie durch <code>cellMargin</code> festgelegt. Der Rand um den ganzen Anzeigebereich herum ist <code>cellMargin</code> Pixel breit.<br>
	Damit beeinflusst <code>cellMargin</code> auch die Gr&ouml;&szlig;e von mehrspaltigen und mehrzeiligen Zellen. Ansonsten w&uuml;rde das ganze nicht mehr zusammenpassen. Eine dreispaltige Zelle ist beispielsweise standardm&auml;&szlig;ig 446 Pixel breit. Dies ergibt sich aus 3 Spalten zu 142 Pixeln (<code>baseWidth</code>) plus zwei Zwischenr&auml;umen zu je 10 Pixeln (je 2 mal <code>cellMargin</code>).<br>
	Bei Verwendung des "flex" Layouts (siehe Attribut <code>layout</code>) liefert diese Berechnung die Mindestgr&ouml;&szlig;e der Zellen. Je nach Browserfenster k&ouml;nnen die Zellen auch gr&ouml;&szlig;er werden.
	</li>
	<li><a id="FUIP-attr-defaultBackend">defaultBackend</a>: FHEM-System, welches verwendet wird, wenn kein System explizit angegeben ist<br>
	Wenn mehrere Backend-FHEMs verwendet werden, dann sollte immer eines davon als <i>defaultBackend</i> ausgew&auml;hlt werden. Im Prinzip kann man in FUIP auf jeder Ebene (View, Zelle, Seite) das zugeh&ouml;rige Backend-System festlegen. Das muss man aber nicht machen und es w&auml;re bei der Umstellung auf ein Mehrsystem-FUIP auch etwas schwierig. Dar&uuml;ber hinaus gibt es Situationen, in denen ein eindeutiges System festgelegt sein muss. In allen diesen F&auml;llen wird das <i>defaultBackend</i> herangezogen.<br>
	Das <i>defaultBackend</i> wird automatisch gesetzt, wenn es ben&ouml;tigt wird. Man muss sich also nicht unbedingt selbst darum k&uuml;mmern.	
	</li>
	<li><a id="FUIP-attr-gridlines">gridlines</a>: Anzeige eines Gitters aus Hilfslinien<br>
	Das Attribut <code>gridlines</code> kann die Werte "show" und "hide" annehmen. Bei "show" wird im Bearbeitungsmodus ein Gitter aus Hilfslinien angezeigt. Der Defaultwert ist "hide".<br>
	Der Abstand der Linien wird aus <code>baseWidth</code> und <code>baseHeight</code> ermittelt und wird so berechnet, dass sich sowohl der linke Rand jeder Zelle mit einer Linie deckt und der untere Rand des Headers jeder Zelle. Ansonsten ist der Abstand der Linien etwa 30 Pixel. 
</li>
<li><a id="FUIP-attr-layout">layout</a>: Grundlegendes Seitenlayout (Gridster oder Flexbox)<br>
Das Attribut <code>layout</code> kann zwei Werte annehmen: "gridster" oder "flex". Der Defaultwert ist "gridster".<br>
<b>Gridster-Layout</b><br>
<div style="padding-left:2em"> 
Im Gridster-Layout haben die einzelnen Zellen eine fixe Gr&ouml;&szlig;e und Position. D.h. die Oberfl&auml;che sieht auf jedem Ger&auml;t gleich aus und passt sich im Prinzip nicht an das Browserfenster an. (Au&szlig;er ggf. einem Zoomfaktor, der durch die Attribute <code>viewportInitialScale</code> und <code>viewportUserScalable</code> beeinflussbar ist.)
</div>
<b>Flex-Layout</b><br>
<div style="padding-left:2em">
Im Flex-Layout passen sich die Zellen in Position und Breite an den vorhandenen Platz an. D.h. die Oberfl&auml;che sieht auf verschiedenen Ger&auml;ten bzw. je nach Breite des Browserfensters unterschiedlich aus. Dazu hat jede FUIP-Seite drei Bereiche: Ein Men&uuml;bereich links, einen Titelbereich oben und den Hauptbereich rechts unten (der ganze Rest).<br>
Der <b>Men&uuml;bereich</b> selbst bleibt immer gleich und passt sich nicht an die Seitenbreite an. Allerdings verschwindet er, wenn die Seitenbreite 768 Pixel unterschreitet. Stattdessen erscheint dann das &uuml;bliche "Burger-Icon" (die drei Striche).<br>
Im <b>Titelbereich</b> bleiben ebenfalls alle Zellen fix, au&szlig;er der ersten (ganz links). Die erste Zelle im Titelbereich passt ihre Breite so an, dass der Titelbereich immer die Breite des Hauptbereichs hat. Sie kann also auch kleiner werden, als im Bearbeitungsmodus definiert. Die Breite kann allerdings zwei Spalten nicht unterschreiten (Mindestbreite in Pixel ist also 2*<code>baseWidth</code>+2*<code>cellMargin</code>.)<br>
Im <b>Hauptbereich</b> ist die festgelegte Zellenbreite eine Mindestbreite. Die Zellen k&ouml;nnen gr&ouml;&szlig;er werden, wenn mehr Platz zur Verf&uuml;gung steht. Wenn weniger Platz zur Verf&uuml;gung steht, dann werden die Zellen nach und nach untereinander angeordnet. D.h. die Zellen &auml;ndern sowohl ihre Breite als auch ihre Position.<br>
</div>
F&uuml;r "FUIP-Anf&auml;nger" eignet sich das Gridster-Layout besser. Man kann dann sp&auml;ter auf das Flex-Layout umstellen. FUIP versucht dann, die Zellen m&ouml;glichst sinnvoll zuzuordnen, also die erste Spalte in den Men&uuml;bereich, die erste Zeile (ohne die erste Spalte) in den Titelbereich und den Rest in den Hauptbereich.<br>
Im Flex-Layout sollte man das Attribut <code>pageWidth</code> weglassen. Au&szlig;erdem sollte man mit <code>baseHeight</code> und <code>baseWidth</code> etwas herumexperimentieren, bevor man alles genau an die richtige Stelle schiebt. 
</li>
	<li><a id="FUIP-attr-locked">locked</a>: Sperren gegen Frontend-&Auml;nderungen (Anzeigemodus)<br>
Wenn locked auf "1" gesetzt wird, dann sind die FUIP-Seiten gegen Bearbeitung gesperrt. Das Zahnrad-Icon oben rechts in den Zellen erscheint dann nicht mehr. Dadurch kann ein reiner "Frontend Benutzer" die Seiten nicht mehr &auml;ndern. Zus&auml;tzlich verschwinden auch die Zellennummern rechts neben den Zellen&uuml;berschriften und Zellen ohne &Uuml;berschrift haben dann auch keinen "Titelbalken" mehr. Falls das Attribut <code>layout</code> auf "flex" steht passt sich jetzt jede Seite automatisch an die Gr&ouml;&szlig;e des Browserfensters an.<br>
&Uuml;ber <code>set...lock</code> und <code>set...unlock</code> kann die Sperre ebenfalls gesteuert werden.
</li>	
	<li><a id="FUIP-attr-loglevel">loglevel</a>: Detaillierungsgrad Frontend-Log<br>
	Dieses Attribut bezieht sich auf das Frontend-Log, d.h. ein Log, welches vom Browser erzeugt wird. Ein Log f&uuml;r das Backend (also FHEM selbst) kann mit dem Attribut <code>verbose</code> gesteuert werden.<br>
	Normalerweise wird dieses Protokoll nicht ben&ouml;tigt, man l&auml;sst es also am besten aus (<code>loglevel=0</code>), au&szlig;er es ist etwas schief gegangen und man will der Sache nachgehen.<br>
	Das Attribut <code>loglevel</code> kann Werte von 0 bis 5 annehmen. Bei 0 (Default) wird kein Protokoll geschrieben, bei 5 ein sehr detailliertes. Siehe auch die Attribute <code>logareas</code> und <code>logtype</code>. 
	</li>
	<li><a id="FUIP-attr-logareas">logareas</a>: Protokollierte Bereiche (Frontend-Log)<br>
	Da ein Frontend-Log unter Umst&auml;nden sehr lange laufen muss, sollte man es auf die notwendigen Bereiche beschr&auml;nken. Daf&uuml;r akzeptiert <code>logareas</code> eine Komma-separierte Liste mit folgenden Werten als Inhalt:
	<div style="padding-left:2em">
	<b>base.init</b> für die Initialisierungsphase<br>
<b>base.poll</b> für alles rund um den Lebenszyklus der Verbindung zum Backend<br>
<b>base.update</b> für die Aktualisierung der Werte am Frontend<br>
<b>base.widget</b> für die Widget-Basis<br>
<b>unknown</b> für alle Meldungen, die momentan keinen Bereich angeben. Das sind insbesondere alle Log-Einträge, die von den einzelnen Widgets kommen<br>
</div>
Die obige Liste kann mit der Zeit noch wachsen. Am besten, man l&auml;sst das Log eine Weile ohne <code>logareas</code> laufen und schaut in den Logeintr&auml;gen nach, welche Bereiche interessant sein k&ouml;nnten. Siehe auch die Attribute <code>loglevel</code> und <code>logtype</code>.
	</li> 
	<li><a id="FUIP-attr-logtype">logtype</a>: Art des Frontend-Logs<br>
	Normalerweise wird das Protokoll in die "Javascript-Konsole" der Entwicklertools des Browsers geschrieben. Bei Mobilger&auml;ten ist es allerdings etwas schwierig, an diese "Konsole" zu kommen. Daher hat FUIP die M&ouml;glichkeit, das Protokoll zuerst im lokalen Speicher ("localStorage") des Browsers abzulegen und dann sp&auml;ter an das Backend zu schicken. Das Attribut <code>logtype</code> kann dazu zwei Werte annehmen:
		<div style="padding-left:2em">
		<b>console</b>: schreibt das Protokoll in die Javascript-Konsole. Das ist der Defaultwert.<br>
		<b>localstorage</b>: schreibt das Protokoll in den lokalen Speicher des Browsers. Beim Aufruf der n&auml;chsten FUIP-Seite (bzw. Neuladen der Seite) wird das Log dann zu FHEM &uuml;bertragen, welches es dann in eine Datei im Verzeichnis &lt;fhem&gt;/FHEM/lib/FUIP/log schreibt. Der Dateiname enth&auml;lt den Namen des FUIP-Device, die IP-Adresse des Frontends (also z.B. des Mobilger&auml;ts) sowie einen Zeitstempel. So kann leicht zugeordnet werden, woher das Protokoll kommt.<br>
		Die Daten im lokalen Speicher des Browsers werden automatisch wieder gel&ouml;scht, nicht aber die Log-Dateien. Diese m&uuml;ssen manuell aufger&auml;umt werden. 	
	</div>
	Siehe auch die Attribute <code>loglevel</code> und <code>logareas</code>.
	</li>
	<li><a id="FUIP-attr-pageWidth">pageWidth</a>: Seitenbreite in Pixel<br>
	 Wenn <code>pageWidth</code> nicht gesetzt ist (das ist der Default), dann wird die Seitenbreite nicht festgelegt. Bei Attribut <code>layout=gridster</code> ergibt sie sich dann aus <code>baseWidth</code> (d.h. die Breite einer 1er-Zelle) und der Anzahl der verwendeten Spalten plus die Breite der Zwischenr&auml;ume (siehe Attribut <code>cellMargin</code>. Bei <code>layout=flex</code> ist die Seitenbreite durch das Browserfenster festgelegt und beeinflusst ihrerseits die Breite und Anordnung der Zellen. D.h. in der Regel muss man bzw. sollte man <code>pageWidth</code> nicht angeben.<br>
Die Angabe in <code>pageWidth</code> beeinflusst auch die Darstellung des Hintergrundbilds, falls das Attribut <code>styleBackgroundImage</code> gesetzt ist. 
</li>
<li><a id="FUIP-attr-snapTo">snapTo</a>: Automatisches "Einrasten" an den Hilfslinien<br>
Wird dieses Attribut gesetzt, dann werden die Views beim Drag&Drop automatisch am Raster (den Hilfslinien) ausgerichtet. (Die Views "ruckeln" dann also ein bisschen.) Wenn man w&auml;hrend des Ziehens die Alt-Taste dr&uuml;ckt, dann wird das tempor&auml;r deaktiviert, so dass man trotzdem pixelgenau positionieren kann.<br>
Das Attribut kann die Werte "gridlines", "halfGrid", "quarterGrid" und "nothing" annehmen. Bei "gridlines" rasten die Views genau an den Hilfslinien ein, bei "halfGrid" an den Hilfslinien und in der Mitte zweier Linien und bei "quarterGrid" viermal pro Hilfslinie. Bei "nothing" wird das automatische Einrasten deaktiviert. Letzteres ist der Default.<br>
F&uuml;r <code>snapTo</code> ist es egal, ob die Hilfslinien angezeigt werden oder nicht (Attribut <code>gridlines</code>). Die Views rasten dann eben dort ein, wo die Hilfslinien w&auml;ren.
</li>
	<li><a id="FUIP-attr-styleBackgroundImage">styleBackgroundImage</a>: Dateiname des Hintergrundbilds<br>
	 Die Bilddatei muss sich im Verzeichnis &lt;fhem&gt;/FHEM/lib/FUIP/images befinden. (&lt;fhem&gt; steht meistens für /opt/fhem) Unterst&uuml;tzt werden jpg- und png- Dateien. Nachdem eine neue Datei hochgeladen wurde, muss man die FHEMWEB-Seite einmal neu laden, um die neue Datei verwenden zu können.<br>
	Falls das Attribut <code>pageWidth</code> gesetzt ist, dann wird die Breite des Hintergrundbilds auf die angegebene Gr&ouml;&szlig;e gesetzt. Ansonsten (ohne <code>pageWidth</code>) nimmt das Bild die Breite des Browser-Fensters ein. Die H&ouml;he des Bilds wird entsprechend skaliert, man muss sich also selbst darum k&uuml;mmern, dass das Bild ein passendes Seitenverh&auml;ltnis hat.<br>
	Bei Verwendung eines Hintergrundbilds werden die Zellenhintergr&uuml;nde automatisch auf halbtransparent gesetzt, so dass das Bild durchscheint.<br>
	Es ist auch m&ouml;glich, jeder Seite ein eigenes Hintergrundbild zu geben. Daf&uuml;r speichert man alle Hintergrundbilder im Verzeichnis &lt;fhem&gt;/FHEM/lib/FUIP/images und verwendet dann das Feld <i>backgroundImage</i> im Konfigurations-Popup der Seiten (Pages) um die Hintergrundbilder zuzuordnen.
</li>
<li><a id="FUIP-attr-styleColor">styleColor</a>: Vordergrundfarbe (veraltet)<br>
Dieses Attribut kann verwendet werden, um die Standard-Textfarbe (Vordergrundfarbe) f&uuml;r alle Views zu setzen. Allerdings sollten Farben in FUIP inzwischen &uuml;ber das Attribut <code>styleSchema</code> bzw. den Punkt "Colours" im Zellenmenu gesetzt werden. Das Attribut <code>styleColor</code> entspricht dem Eintrag "foreground" (bzw. der CSS-Variable --fuip-color-foreground). Ist <code>styleColor</code> gesetzt, dann &uuml;berschreibt es diesen Eintrag.
</li>
	<li><a id="FUIP-attr-styleSchema">styleSchema</a>: Grundlegendes (Farb-)Schema<br>
	Mittels <code>styleSchema</code> kann man zwischen sieben verschiedenen "Styles" ausw&auml;hlen. Die Styles sind angelehnt an die hier beschriebenen Schema-Dateien: <a href="https://wiki.fhem.de/wiki/FHEM_Tablet_UI#Farben" target="fuipdoc">FHEM_Tablet_UI#Farben</a> D.h. die FUIP-Seiten sehen dann in etwa so aus wie auf den Screenshots dort.<br>
	Weitere Anpassungen kann man &uuml;ber den Punkt "Colours" im Zellenmen&uuml; vornehmen. Au&szlig;erdem kann man eine eigene CSS-Datei &uuml;ber das Attribut <code>userCss</code> einbinden.	
	</li>
	<li><a id="FUIP-attr-toastMessages">toastMessages</a>: Konfiguration der Toast-Nachrichten<br>
	Die Meldungen, die z.B. bei Schaltvorg&auml;ngen normalerweise links unten auftauchen, sind konfigurierbar. Dazu kann das Attribut <code>toastMessages</code> folgende Werte annehmen:
	<div style="padding-left:2em">
<b>all</b>: Alle Meldungen werden angezeigt. Das ist der Defaultwert.<br>
<b>errors</b>: Es werden nur noch Fehlermeldungen (also die roten Popups) angezeigt. Meldungen wie "set xy on" kommen nicht mehr.<br>
<b>off</b>: Es werden keine Meldungen mehr angezeigt, au&szlig;er Fehlermeldungen, die von FUIP im &Auml;nderungsmodus (locked = 0) erzeugt werden. D.h. Lebenspartner oder andere Mitbewohner sehen wahrscheinlich tats&auml;chlich gar keine Meldungen mehr.
</div>
Am Anfang der FUIP-Entwicklung wurden noch relativ viele (Fehler-)Meldungen &uuml;ber den Toast-Mechanismus angezeigt. Seit es das Frontent-Log gibt haben die Toast-Meldungen aber an Bedeutung verloren und st&ouml;ren kaum noch (siehe auch Attribute <code>loglevel</code>, <code>logareas</code> und <code>logtype</code>).
	</li>	
<li><a id="FUIP-attr-userCss">userCss</a>: Eigenes Stylesheet<br>
Mit diesem Attribut kann ein eigenes Stylesheet (CSS-Datei) eingebunden werden. Die zugeh&ouml;rige Datei muss im Verzeichnis &lt;fhem&gt;/FHEM/lib/FUIP/config liegen und die Endung ".css" haben.<br>
Diese M&ouml;glichkeit sollte nicht leichtfertig eingesetzt werden. Zuerst sollte man pr&uuml;fen, ob man etwas passendes mit dem Attribut <code>styleSchema</code> einstellen kann. Die Farben kann man dann mit dem  Punkt "Colours" im Zellenmen&uuml; anpassen. Erst wenn diese M&ouml;glichkeiten ersch&ouml;pft sind, sollte man an das Attribut <code>userCss</code> denken. 
 </li>
<li><a id="FUIP-attr-userHtmlBodyStart">userHtmlBodyStart</a>: Eigenen HTML-Text hinzuf&uuml;gen<br>
Mit diesem Attribut kann der Inhalt einer eigenen HTML-Datei eingebunden werden. Die zugeh&ouml;rige Datei muss im Verzeichnis &lt;fhem&gt;/FHEM/lib/FUIP/config liegen und die Endung ".html" haben. Dies eignet sich z.B. zum Einbinden eigener SVG-Definitionen.<br>
Der HTML-Text wird relativ weit "oben" im generierten HTML-Code eingef&uuml;gt.<br>
Diese M&ouml;glichkeit wird sehr selten ben&ouml;tigt. Meistens ist es besser, eigenen HTML-Code &uuml;ber die HTML-View einzubinden. 
</li>
<li><a id="FUIP-attr-viewportInitialScale">viewportInitialScale</a>: Anf&auml;nglicher Zoomgrad<br>
FUIP generiert ein Meta-Element f&uuml;r den Viewport in jede Seite. Dabei wird der anf&auml;ngliche Zoomgrad auf 1,0 festgelegt. Dies kann mittels <code>viewportInitialScale</code> ge&auml;ndert werden. Der Wert entspricht genau dem "initial-scale"-Parameter des Meta-Elements f&uuml;r den Viewport.<br>
Normalerweise muss man dieses Attribut nicht setzen. Wenn die FUIP-Seiten nicht (genau) in das Browserfenster passen, dann sollte man lieber mit den Attributen <code>baseWidth</code> und <code>cellMargin</code> experimentieren. Au&szlig;erdem kann es helfen, das Flex-Layout zu verwenden. Siehe dazu Attribut <code>layout</code>.
</li>
<li><a id="FUIP-attr-viewportUserScalable">viewportUserScalable</a>: Zoomen erlauben oder nicht<br>
Dieses Attribut entspricht genau dem "user-scalable"-Parameter des Meta-Elements f&uuml;r den Viewport. Man kann damit also festlegen, ob der Benutzer die Seite zoomen darf (Wert "yes") oder nicht ("no"). Defaultwert ist "yes", also ist das Zoomen normalerweise erlaubt.
</li>	
  </ul>
</ul>

=end html_DE
=cut
