#
#
# 42_FUIP.pm
# written by Thorsten Pferdekaemper
#
##############################################
# $Id: 42_FUIP.pm 00099 2018-09-24 15:00:00Z Thorsten Pferdekaemper $

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
	$hash->{parseParams} = 1;	
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

# selectable views
my $selectableViews = \%FUIP::View::selectableViews;

my $matchlink = "^\/?(([^\/]*(\/[^\/]+)*)\/?)\$";
my $fuipPath = $main::attr{global}{modpath} . "/FHEM/lib/FUIP/";

my $currentPage = "";

# possible values of attributes can change...
sub setAttrList($) {
	my ($hash) = @_;
    $hash->{AttrList}  = "layout:gridster,flex locked:0,1 fhemwebUrl baseWidth baseHeight cellMargin:0,1,2,3,4,5,6,7,8,9,10 pageWidth styleSchema:default,blue,green,mobil,darkblue,darkgreen,bright-mint styleColor viewportUserScalable:yes,no viewportInitialScale gridlines:show,hide snapTo:gridlines,halfGrid,quarterGrid,nothing toastMessages:all,errors,off styleBackgroundImage:";
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
}


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
  return undef;
}

##################
sub Undef($$) {

  my ($hash, $name) = @_;

  removeExtension($hash->{fhem}{infix});

  return undef;
}


sub Attr ($$$$) {
	my ( $cmd, $name, $attrName, $attrValue  ) = @_;
	# if fhemwebUrl is changed, we need to refresh the buffer
	if($attrName eq "fhemwebUrl") {
		FUIP::Model::refresh($name);
	};
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
	return undef;
}


sub getCellMargin($) {
	my $hash = shift;
	return main::AttrVal($hash->{NAME},"cellMargin",5);	
};


sub createRoomsMenu($$) {
	my ($hash,$pageid) = @_;
	my $cell = FUIP::Cell->createDefaultInstance($hash);
	$cell->{title} = "R&auml;ume";	
	$cell->position(0,1);
    # create a MenuItem view for each room
	my @rooms = FUIP::Model::getRooms($hash->{NAME});
	my $posY = 0; 
	for my $room (@rooms) {
		my $menuItem = FUIP::View::MenuItem->createDefaultInstance($hash);
		$menuItem->{text} = $room;
		$menuItem->{link} = "room/".$room;
		$menuItem->{active} = "0";
		my @parts = split('/',$pageid);
		if(@parts > 1) {
			if($parts[0] =~ /room|device/ and main::urlDecode($parts[1]) eq $room) {
				$menuItem->{active} = "1";
			};
		};	
		$menuItem->position(0,$posY);
		my (undef,$h) = $menuItem->dimensions();
		$posY += $h;  
		push(@{$cell->{views}}, $menuItem);												
	};
	$cell->dimensions(1,undef);
    return $cell;
};


sub addStandardCells($$$) {
	my ($hash,$cells,$pageid) = @_;
	# determine height of title line
	# this gives more flexibility for baseHeight
	# baseWidth is assumed something roughly around 140
	my $baseHeight = main::AttrVal($hash->{NAME},"baseHeight",108);	
	use integer;
	my $titleHeight = 60 / $baseHeight;
	$titleHeight += 1 if 60 % $baseHeight;
	no integer;
	# Home button
	my $view = FUIP::View::HomeButton->createDefaultInstance($hash);
	$view->{active} = ($pageid eq "home" ? 1 : 0);
	$view->position(0,0);
	my $homeCell = FUIP::Cell->createDefaultInstance($hash);
	$homeCell->position(0,0);
	$homeCell->dimensions(1,$titleHeight);
	$homeCell->{views} = [ $view ];
	$homeCell->{title} = "Home";
	push(@$cells,$homeCell);
	# Clock
	my $clockView = FUIP::View::Clock->createDefaultInstance($hash);
	$clockView->position(0,0);
	# switch sizing of the clock to auto, e.g. to center it
	$clockView->{sizing} = "auto";
	$clockView->{defaulted}{sizing} = 0;
	my $clockCell = FUIP::Cell->createDefaultInstance($hash);
	$clockCell->position(6,0);
	$clockCell->dimensions(1,$titleHeight);
	$clockCell->{views} = [ $clockView ];
	$clockCell->{title} = "Uhrzeit";
	push(@$cells,$clockCell);
	# Title cell
	my $title = ($pageid eq "home" ? "Home, sweet home" : main::urlDecode(( split '/', $pageid )[ -1 ]));
	$view = FUIP::View::Title->createDefaultInstance($hash);
	$view->{text} = $title;
	$view->{icon} = "oa-control_building_s_all" if $pageid eq "home";
	$view->position(0,0);
	my $titleCell = FUIP::Cell->createDefaultInstance($hash);
	$titleCell->position(1,0);
	$titleCell->dimensions(5,$titleHeight);
	$titleCell->{views} = [ $view ];
	$titleCell->{title} = $title;
	push(@$cells,$titleCell);
	# rooms menu
	my $roomsMenu = createRoomsMenu($hash,$pageid);
	# make sure rooms menu is under home button
	$roomsMenu->position(0,$titleHeight);
	push(@$cells,$roomsMenu);
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


sub renderFuipInit($;$) {
	# include fuip.js, call fuipInit and include proper JQueryUI style sheet
	my ($hash,$gridlines) = @_;
	my $baseWidth = main::AttrVal($hash->{NAME},"baseWidth",142);
	my $baseHeight = main::AttrVal($hash->{NAME},"baseHeight",108);	
	if(not $gridlines) {
		$gridlines = main::AttrVal($hash->{NAME},"gridlines","hide");
	};	
	my $snapto = main::AttrVal($hash->{NAME},"snapTo","nothing");
	return "<script src=\"/fhem/".lc($hash->{NAME})."/fuip/js/fuip.js\"></script>
  			<script>
				fuipInit({	baseWidth:".$baseWidth.",
							baseHeight:".$baseHeight.",
							cellMargin:".getCellMargin($hash).",
							maxCols:".determineMaxCols($hash,99).",
							gridlines:\"".$gridlines."\",
							snapTo:\"".$snapto."\" })
			</script>
			<link rel=\"stylesheet\" href=\"/fhem/".lc($hash->{NAME})."/fuip/css/theme.blue.css\">";
};


sub getViewClassesSingle($$);  # recursion

sub getViewClassesSingle($$) {
	# get classes of one view. This might be a dialog or view template, so recursive
	my ($view,$viewClasses) = @_;
	# first the view itself
	$viewClasses->{blessed($view)} = 1;
	# is this a view template instance?
	if(blessed($view) eq "FUIP::ViewTemplInstance") {
		for my $subview (@{$view->{viewtemplate}{views}}) {
			getViewClassesSingle($subview,$viewClasses);
		};
	};
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
	return unless $popupField;
	# if we have a default as "no popup", then we might not want a popup
	if($popupField and exists($popupField->{default})) {
		unless(exists($view->{defaulted}) and exists($view->{defaulted}{$popupField->{id}})
				and $view->{defaulted}{$popupField->{id}} == 0) {
			return;
		};	
	};
	# now we know that there is a popup field 
	# do we have a popup?
	my $dialog = $view->{$popupField->{id}};
	return if( not blessed($dialog) or not $dialog->isa("FUIP::Dialog"));
	# ok, we have a dialog, get the classes of the views of the dialog
	for my $subview (@{$dialog->{views}}) {
		getViewClassesSingle($subview,$viewClasses);
	};
};


sub getViewDependencies($$$) {
	my ($hash,$pageId,$suffix) = @_;
	
	# pageId might also be a dialog/viewtemplate instance
	
	# if($pageId) {
		# main::Log3(undef,1,"getViewDependencies page: ".$pageId);
	# }else{
		# main::Log3(undef,1,"getViewDependencies without pageId");
	# };
	
	my $pattern = '(.*)\.('.$suffix.')$';
	my $rex = qr/$pattern/;
	
	my %viewClasses;
	if(blessed($pageId)){ # this should always have views
		return unless exists $pageId->{views};
		for my $view (@{$pageId->{views}}) {
			getViewClassesSingle($view,\%viewClasses);		
		};
	}elsif(ref($pageId) eq "HASH") {
		# in this case, the hash elements should contain something with views
		# e.g. for view template overview
		for my $elem (values %$pageId) {
			next unless exists $elem->{views};
			for my $view (@{$elem->{views}}) {
				getViewClassesSingle($view,\%viewClasses);		
			};			
		};	
	}else{
		return unless exists $hash->{pages}{$pageId};
		my $cells = $hash->{pages}{$pageId}{cells};
		for my $cell (@{$cells}) {
			for my $view (@{$cell->{views}}) {
				getViewClassesSingle($view,\%viewClasses);
			};
		};
	};
	my %dependencies;
	for my $class (keys %viewClasses) {
		my $deps = $class->getDependencies($hash);
		for my $dep (@$deps) {
			next unless $dep =~ m/$rex/;
			$dependencies{$dep} = 1;
		};
	};
	my @result = sort keys %dependencies;
	return \@result;
};


sub renderHeaderHTML($$) {
	my ($hash,$pageId) = @_;
	my $dependencies = getViewDependencies($hash,$pageId,"js");
	# common script parts
	my $result = '<script src="/fhem/'.lc($hash->{NAME}).'/fuip/js/fuip_common.js"></script>'."\n";
	for my $dep (@$dependencies) {
		$result .= '<script src="/fhem/'.lc($hash->{NAME}).'/fuip/'.$dep.'"></script>'."\n";
	};
	$result .= 	'<link href="/fhem/'.lc($hash->{NAME}).'/css/fhem-tablet-ui-user.css" rel="stylesheet" type="text/css">'."\n";
	return $result;
};


sub renderBackgroundImage($$){
	my ($hash,$pageWidth) = @_;
	my $result = '';
	my $backgroundImage = main::AttrVal($hash->{NAME},"styleBackgroundImage",undef);
	if($backgroundImage) {
		# load background picture only after (most of?) the rest has loaded
		$result .= 
			'<script type="text/javascript">
				$(() =>
					$(\'body\').css(\'background\',\'#000000 url(/fhem/'.lc($hash->{NAME}).'/fuip/images/'.$backgroundImage.') 0 0/';
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
	my ($hash,$filename) = @_;
	my $forceLocal = 1;
	if($filename =~ m/^remote:/) {
		$forceLocal = 0;
		$filename = substr($filename,7);
	};
	return FUIP::Model::readTextFile($hash->{NAME},$filename,$forceLocal);
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
			background-image: url(/fhem/'.lc($hash->{NAME}).'/fuip/jquery-ui/images/ui-icons_ffffff_256x240.png);
		}'."\n";	
};


sub renderCommonCss($) {
	my $name = shift;
	my $lcName = lc($name);
	my $styleSchema = main::AttrVal($name,"styleSchema","default");
	my $styleSchemaLine = "";	
	$styleSchemaLine = '<link rel="stylesheet" href="/fhem/'.$lcName.'/fuip/css/fuip-'.$styleSchema.'-ui.css" type="text/css" />'."\n" unless $styleSchema eq "default"; 
	return '<link rel="shortcut icon" href="/fhem/icons/favicon" />
			<link rel="stylesheet" href="/fhem/'.$lcName.'/css/fhem-tablet-ui.css"  type="text/css" />'."\n"
			.'<link rel="stylesheet" href="/fhem/'.$lcName.'/fuip/css/fuip-default-ui.css" type="text/css" />'."\n"
			.$styleSchemaLine
			.'<link rel="stylesheet" href="/fhem/'.$lcName.'/lib/font-awesome.min.css"   type="text/css" />
			<link rel="stylesheet" href="/fhem/'.$lcName.'/fuip/fonts/nesges.css" type="text/css" />'."\n";
};


sub renderToastSetting($) {
	my $hash = shift;
	my $toast = main::AttrVal($hash->{NAME},"toastMessages",0);
	return "" unless $toast;
	return ' data-fuip-toast="'.$toast.'"';
};


sub renderPage($$$) {
	my ($hash,$currentLocation,$locked) = @_;
	# falls $locked, dann werden die Editierfunktionen nicht mit gerendert
	my $title = $hash->{pages}{$currentLocation}{title};
	$title = main::urlDecode($currentLocation) unless $title;
	$title = "FHEM Tablet UI by FUIP" unless $title;
	my $baseWidth = main::AttrVal($hash->{NAME},"baseWidth",142);
	my $baseHeight = main::AttrVal($hash->{NAME},"baseHeight",108);	
	my $styleColor = main::AttrVal($hash->{NAME},"styleColor","var(--fuip-color-foreground,#808080)");
	my $pageWidth = main::AttrVal($hash->{NAME},"pageWidth",undef);
	my $layout = main::AttrVal($hash->{NAME},"layout","gridster");
	my $initialScale = main::AttrVal($hash->{NAME},"viewportInitialScale","1.0");
	my $userScalable = main::AttrVal($hash->{NAME},"viewportUserScalable","yes");
  	my $result = 
	   "<!DOCTYPE html>
		<html".($locked ? "" : " data-name=\"".$hash->{NAME}."\" data-pageid=\"".$currentLocation."\" data-editonly=\"".$hash->{editOnly}."\" data-layout=\"".$layout."\"").renderToastSetting($hash).">
			<head>
				<meta http-equiv=\"X-UA-Compatible\" content=\"IE=edge\">
				<meta name=\"viewport\" content=\"width=device-width, initial-scale=".$initialScale.", user-scalable=".$userScalable."\" />
				<meta name=\"mobile-web-app-capable\" content=\"yes\">
				<meta name=\"apple-mobile-web-app-capable\" content=\"yes\">
				<meta name=\"widget_base_width\" content=\"".$baseWidth."\">
				<meta name=\"widget_base_height\" content=\"".$baseHeight."\">
				<meta name=\"widget_margin\" content=\"".getCellMargin($hash)."\">".
				(main::AttrVal($hash->{NAME},"fhemwebUrl",undef) ? "<meta name=\"fhemweb_url\" content=\"".main::AttrVal($hash->{NAME},"fhemwebUrl",undef)."\">" : "").
				($locked ? '<meta name="gridster_disable" content="1">' : "").
            "
			<script type=\"text/javascript\">
					// when using browser back or so, we should reload
					if(performance.navigation.type == 2){
						location.reload(true);
					};	
				</script>
				<title>".$title."</title>"
				.'<link rel="stylesheet" href="/fhem/'.lc($hash->{NAME}).'/lib/jquery.gridster.min.css" type="text/css">'
				.renderCommonCss($hash->{NAME})
				."<script type=\"text/javascript\" src=\"/fhem/".lc($hash->{NAME})."/lib/jquery.min.js\"></script>
		        <script type=\"text/javascript\" src=\"/fhem/".lc($hash->{NAME})."/fuip/jquery-ui/jquery-ui.min.js\"></script>".
				($locked ? "" : "<link rel=\"stylesheet\" href=\"/fhem/".lc($hash->{NAME})."/fuip/jquery-ui/jquery-ui.css\">
								<!-- tablesorter -->
								 <script type=\"text/javascript\" src=\"/fhem/".lc($hash->{NAME})."/fuip/js/jquery.tablesorter.js\"></script>
								 <script type=\"text/javascript\" src=\"/fhem/".lc($hash->{NAME})."/fuip/js/jquery.tablesorter.widgets.js\"></script>").
				"<script type=\"text/javascript\" src=\"/fhem/".lc($hash->{NAME})."/lib/jquery.gridster.min.js\"></script>  
                ".
				($locked ? "" : renderFuipInit($hash)).
				"<script src=\"/fhem/".lc($hash->{NAME})."/js/fhem-tablet-ui.js\"></script>
					<style type=\"text/css\">
	                .fuip-color {
		                color: ".$styleColor.";
                    }\n";
	$result .= renderCommonEditStyles($hash) unless $locked;				
	$result .= "</style>\n"
				.renderHeaderHTML($hash,$currentLocation)
				.renderBackgroundImage($hash,$pageWidth)
				.'</head>
            <body>'
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
       </body>
       </html>';
    return ("text/html; charset=utf-8", $result);
};


sub renderPageFlex($$) {
	my ($hash,$currentLocation) = @_;
	# falls $locked, dann werden die Editierfunktionen nicht mit gerendert
	my $title = $hash->{pages}{$currentLocation}{title};
	$title = main::urlDecode($currentLocation) unless $title;
	$title = "FHEM Tablet UI by FUIP" unless $title;
	my $styleColor = main::AttrVal($hash->{NAME},"styleColor","var(--fuip-color-foreground,#808080)");
	my $pageWidth = main::AttrVal($hash->{NAME},"pageWidth",undef);
	my $initialScale = main::AttrVal($hash->{NAME},"viewportInitialScale","1.0");
	my $userScalable = main::AttrVal($hash->{NAME},"viewportUserScalable","no");
  	my $result = 
	   '<!DOCTYPE html>
		<html'.renderToastSetting($hash).'>
			<head>
				<meta http-equiv="X-UA-Compatible" content="IE=edge">'.
				'<meta name="viewport" content="width=device-width, initial-scale='.$initialScale.', user-scalable='.$userScalable.'" />'.
				'<meta name="mobile-web-app-capable" content="yes">
				<meta name="apple-mobile-web-app-capable" content="yes">'.
				(main::AttrVal($hash->{NAME},"fhemwebUrl",undef) ? "<meta name=\"fhemweb_url\" content=\"".main::AttrVal($hash->{NAME},"fhemwebUrl",undef)."\">" : "").
            "
				<script type=\"text/javascript\">
					// when using browser back or so, we should reload
					if(performance.navigation.type == 2){
						location.reload(true);
					};	
				</script>
				<title>".$title."</title>"
				.renderCommonCss($hash->{NAME})
				.'<script type="text/javascript" src="/fhem/'.lc($hash->{NAME}).'/lib/jquery.min.js"></script>
		        <script type="text/javascript" src="/fhem/'.lc($hash->{NAME}).'/fuip/jquery-ui/jquery-ui.min.js"></script>
				<script src="/fhem/'.lc($hash->{NAME}).'/js/fhem-tablet-ui.js"></script>
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
				.renderBackgroundImage($hash,$pageWidth)
				.'</head>
            <body>'
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
	my $title = $hash->{pages}{$currentLocation}{title};
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
		<html data-name=\"".$hash->{NAME}."\" data-pageid=\"".$currentLocation."\" data-editonly=\"".$hash->{editOnly}."\" data-layout=\"flex\"".renderToastSetting($hash).">
			<head>
				<meta http-equiv=\"X-UA-Compatible\" content=\"IE=edge\">
				<meta name=\"viewport\" content=\"width=device-width, initial-scale=".$initialScale.", user-scalable=".$userScalable."\" />
				<meta name=\"mobile-web-app-capable\" content=\"yes\">
				<meta name=\"apple-mobile-web-app-capable\" content=\"yes\">".		
				(main::AttrVal($hash->{NAME},"fhemwebUrl",undef) ? "<meta name=\"fhemweb_url\" content=\"".main::AttrVal($hash->{NAME},"fhemwebUrl",undef)."\">" : "").
            "
				<script type=\"text/javascript\">
					// when using browser back or so, we should reload
					if(performance.navigation.type == 2){
						location.reload(true);
					};	
				</script>
				<title>".$title."</title>"
				.renderCommonCss($hash->{NAME})
				."<script type=\"text/javascript\" src=\"/fhem/".lc($hash->{NAME})."/lib/jquery.min.js\"></script>
		        <script type=\"text/javascript\" src=\"/fhem/".lc($hash->{NAME})."/fuip/jquery-ui/jquery-ui.min.js\"></script>
				<link rel=\"stylesheet\" href=\"/fhem/".lc($hash->{NAME})."/fuip/jquery-ui/jquery-ui.css\">
								<!-- tablesorter -->
								 <script type=\"text/javascript\" src=\"/fhem/".lc($hash->{NAME})."/fuip/js/jquery.tablesorter.js\"></script>
								 <script type=\"text/javascript\" src=\"/fhem/".lc($hash->{NAME})."/fuip/js/jquery.tablesorter.widgets.js\"></script>
                <script src=\"/fhem/".lc($hash->{NAME})."/js/fhem-tablet-ui.js\"></script>".
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
				.renderBackgroundImage($hash,$pageWidth)
				."</head>
            <body>"
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
		$dialog = FUIP::Dialog->createDefaultInstance($hash);
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
				data-editonly=\"".$hash->{editOnly}."\"".renderToastSetting($hash).">
			<head>
	            <title>".$title."</title>"
				.renderCommonCss($hash->{NAME})
				."
				<script type=\"text/javascript\" src=\"/fhem/".lc($hash->{NAME})."/lib/jquery.min.js\"></script>
		        <script type=\"text/javascript\" src=\"/fhem/".lc($hash->{NAME})."/fuip/jquery-ui/jquery-ui.min.js\"></script>".
				"<link rel=\"stylesheet\" href=\"/fhem/".lc($hash->{NAME})."/fuip/jquery-ui/jquery-ui.css\">
								<!-- tablesorter -->
								 <script type=\"text/javascript\" src=\"/fhem/".lc($hash->{NAME})."/fuip/js/jquery.tablesorter.js\"></script>
								 <script type=\"text/javascript\" src=\"/fhem/".lc($hash->{NAME})."/fuip/js/jquery.tablesorter.widgets.js\"></script>".
				"<script type=\"text/javascript\" src=\"/fhem/".lc($hash->{NAME})."/lib/jquery.gridster.min.js\"></script>".
                "<script src=\"/fhem/".lc($hash->{NAME})."/js/fhem-tablet-ui.js\"></script>".
				renderFuipInit($hash).
				"<style type=\"text/css\">
	                .fuip-color {
		                color: ".$styleColor.";
                    }
					".renderCommonEditStyles($hash).
                "</style>".
				(main::AttrVal($hash->{NAME},"fhemwebUrl",undef) ? "<meta name=\"fhemweb_url\" content=\"".main::AttrVal($hash->{NAME},"fhemwebUrl",undef)."\">" : "").
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
		<div id="popupcontent" class="fuip-droppable fuip-cell"
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
			$hash->{viewtemplates}{$templateid} = FUIP::ViewTemplate->createDefaultInstance($hash);
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
				data-editonly=\"".$hash->{editOnly}."\"".renderToastSetting($hash).">
			<head>
				<script type=\"text/javascript\">
					// when using browser back or so, we should reload
					if(performance.navigation.type == 2){
						location.reload(true);
					};	
				</script>
	            <title>".$title."</title>"
				.renderCommonCss($hash->{NAME})
				."
				<script type=\"text/javascript\" src=\"/fhem/".lc($hash->{NAME})."/lib/jquery.min.js\"></script>
		        <script type=\"text/javascript\" src=\"/fhem/".lc($hash->{NAME})."/fuip/jquery-ui/jquery-ui.min.js\"></script>".
				"<link rel=\"stylesheet\" href=\"/fhem/".lc($hash->{NAME})."/fuip/jquery-ui/jquery-ui.css\">
								<!-- tablesorter -->
								 <script type=\"text/javascript\" src=\"/fhem/".lc($hash->{NAME})."/fuip/js/jquery.tablesorter.js\"></script>
								 <script type=\"text/javascript\" src=\"/fhem/".lc($hash->{NAME})."/fuip/js/jquery.tablesorter.widgets.js\"></script>".
                "<script src=\"/fhem/".lc($hash->{NAME})."/js/fhem-tablet-ui.js\"></script>".
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
				(main::AttrVal($hash->{NAME},"fhemwebUrl",undef) ? "<meta name=\"fhemweb_url\" content=\"".main::AttrVal($hash->{NAME},"fhemwebUrl",undef)."\">" : "").
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
							onclick="window.location.replace(\'/fhem/'.lc($hash->{NAME}).'/fuip/viewtemplate\')">
					Show all (overview)
					</a></li>
				<li style="text-align:left;list-style-type:circle;color:var(--fuip-color-symbol-active);"><a href="javascript:void(0);" onclick="dialogCreateNewViewTemplate();">Create new</a></li> 
				<li style="text-align:left;list-style-type:circle;color:var(--fuip-color-symbol-active);"><a href="javascript:void(0);" onclick="dialogImportViewTemplate();">Import</a></li> 
				<br>'."\n";
	for my $viewtemplate (sort keys %{$hash->{viewtemplates}}) {
		$result .= '<li	style="text-align:left;list-style-type:circle;color:var(--fuip-color-symbol-active);">
						<a href="javascript:void(0);" 
							onclick="window.location.replace(\'/fhem/'.lc($hash->{NAME}).'/fuip/viewtemplate?templateid='.$viewtemplate.'\')">
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
			$result .= '<div onclick="window.location.replace(\'/fhem/'.lc($hash->{NAME}).'/fuip/viewtemplate?templateid='.$key.'\')" title="click to change" style="position:absolute;left:0;top:0;width:100%;height:100%;z-index:11;background:var(--fuip-color-background,rgba(255,255,255,.1));opacity:0.1;"></div>';
			$result .= '</div>'."\n";
		};
	};
	$result .= '</div>
		<div id="viewsettings">
		</div>
		<div id="valuehelp">
		</div>
		<div id="inputpopup"></div>
       </body>
       </html>';
    return ("text/html; charset=utf-8", $result);
};


sub defaultPageIndex($) {
	my ($hash) = @_;
	my @cells;
	# home button and rooms menu
	addStandardCells($hash, \@cells, "home");
	# get "room views" 
	my @rooms = FUIP::Model::getRooms($hash->{NAME});
	foreach my $room (@rooms) {
		my $views = getDeviceViewsForRoom($hash,$room,"overview");
		# we do not show empty rooms here
		next unless @$views;
		my @switches;
		my @thermostats;
		my @shutters;
		my @others;  
		for my $view (@$views) {
			if($view->isa('FUIP::View::SimpleSwitch')) {
				push(@switches,$view);
			}elsif($view->isa('FUIP::View::Thermostat')) {	
				push(@thermostats,$view);
			}elsif($view->isa('FUIP::View::ShutterOverview')) {	
				push(@shutters,$view);	
			}else{
				push(@others, $view);
			};		
		};
		@$views = (@thermostats,@shutters);
		if(@switches) {
			if(@$views) {
				my $spacer = FUIP::View::Spacer->createDefaultInstance($hash);
				$spacer->dimensions(cellWidthToPixels($hash,2), 5);
				push(@$views,$spacer);
			};
			push(@$views,@switches);
		};
		if(@others) {
			if(@$views) {
				my $spacer = FUIP::View::Spacer->createDefaultInstance($hash);
				$spacer->dimensions(cellWidthToPixels($hash,2), 5);
				push(@$views,$spacer);
			};
			push(@$views,@others);
		};
	    my $cell = FUIP::Cell->createDefaultInstance($hash);
		$cell->{title} = $room;
		$cell->{views} = $views;
		$cell->applyDefaults();
		$cell->dimensions(2,1);  #auto-arranging will fit the height
		autoArrangeNewViews($cell);
		push(@cells, $cell);
	};
	$hash->{pages}{"home"} = FUIP::Page->createDefaultInstance($hash);
	$hash->{pages}{"home"}{cells} = \@cells;
};


sub defaultPageRoom($$){
	my ($hash,$room) = @_;
	my $pageid = "room/".$room;
	$room = main::urlDecode($room);
	my $viewsInRoom = getDeviceViewsForRoom($hash,$room,"room");
	# sort devices by type
	my @switches;
	my @thermostats;
	my @shutters;
	my @states;  # i.e. STATE only
	my @others;  
	for my $view (@$viewsInRoom) {
		if($view->isa('FUIP::View::SimpleSwitch')) {
			push(@switches,$view);
		}elsif($view->isa('FUIP::View::Thermostat')) {	
			push(@thermostats,$view);
		}elsif($view->isa('FUIP::View::ShutterControl')) {	
			push(@shutters,$view);	
		}elsif($view->isa('FUIP::View::STATE')) {	
			push(@states,$view);		
		}else{
			push(@others, $view);
		};		
	};
	# now render thermostats - shutters - switches (one cell only) - others - states (one cell only)
	my @cells;
	my $cell;
	# create cells for thermostats and shutters 
	for my $view (@thermostats) {
		$cell = FUIP::Cell->createDefaultInstance($hash);
		$cell->{views} = [$view];
		$cell->{title} = "Heizung";
		push(@cells,$cell);
	};
	for my $view (@shutters) {
		$cell = FUIP::Cell->createDefaultInstance($hash);
		$cell->{views} = [$view];
		$cell->{title} = "Rollladen";
		push(@cells,$cell);
	};
	# create one cell for all switches
	if(@switches) {
		$cell = FUIP::Cell->createDefaultInstance($hash);
		$cell->{title} = "Lampen";
		$cell->{views} = \@switches;
		push(@cells,$cell);
	};	
	# create cells for "others"
	for my $view (@others) {
		$cell = FUIP::Cell->createDefaultInstance($hash);
		$cell->{views} = [$view];
		push(@cells,$cell);
	};
	# create one cell for all "STATE only"
	if(@states) {
		$cell = FUIP::Cell->createDefaultInstance($hash);
		$cell->{title} = "Sonstige";
		$cell->{views} = \@states;
		push(@cells,$cell);
	};	
	# care for proper size of the cells
	for $cell (@cells) { 
		$cell->applyDefaults();
		if($cell->{views}[0]->isa('FUIP::View::WeatherDetail') ||
				$cell->{views}[0]->isa('FUIP::View::DwdWebLink') ||
				$cell->{views}[0]->isa('FUIP::View::WebLink')){
			$cell->dimensions(4,1);
			autoArrangeNewViews($cell);
			$cell->{views}[0]{sizing} = "auto";
		}else{	
			$cell->dimensions(2,1);
			autoArrangeNewViews($cell);
		};
	};
	# home button and rooms menu
	addStandardCells($hash, \@cells, $pageid);
	# add to pages
	$hash->{pages}{$pageid} = FUIP::Page->createDefaultInstance($hash);
	$hash->{pages}{$pageid}{cells} = \@cells;
};


sub defaultPageDevice($$$){
    my ($hash,$room,$device) = @_;
	my $pageid = "device/".$room."/".$device;
	my @cells;
	addStandardCells($hash, \@cells,$pageid);
	my $deviceView = FUIP::View::ReadingsList->createDefaultInstance($hash);
	$deviceView->{device} = $device;
	my $cell = FUIP::Cell->createDefaultInstance($hash);
	$cell->{views} = [$deviceView];
	push(@cells, $cell);
	$hash->{pages}{$pageid} = FUIP::Page->createDefaultInstance($hash);
	$hash->{pages}{$pageid}{cells} = \@cells;
};


sub defaultPage($$){
	#creates a default (almost empty) page
	my ($hash,$pageId) = @_;
	$hash->{pages}{$pageId} = FUIP::Page->createDefaultInstance($hash);
	$hash->{pages}{$pageId}{cells} = [];
};


sub getDeviceView($$$){
	my ($hash,$name, $level) = @_;
	my $device = FUIP::Model::getDevice($hash->{NAME},$name,["TYPE","subType","state","chanNo","model"]);
	return undef unless defined $device;
	# don't show FileLogs or FHEMWEBs
	# TODO: rooms and types to ignore could be configurable
	return undef if($device->{Internals}{TYPE} =~ m/^(FileLog|FHEMWEB|at|notify|FUIP|HMUARTLGW|HMinfo|HMtemplate|DWD_OpenData)$/);
	if($level eq "overview") {
		return undef if($device->{Internals}{TYPE} =~ m/^(weblink|SVG|DWD_OpenData_Weblink)$/);
	};
	# we have something special for SYSMON
	if($device->{Internals}{TYPE} eq "SYSMON" and not $level eq "overview") {
		my $view = FUIP::View::Sysmon->createDefaultInstance($hash);
		$view->{device} = $name;
		return $view;
	};
	# don't show HM485 devices, only channels
	if($device->{Internals}{TYPE} eq "HM485") {
		return undef unless $device->{Internals}{chanNo};
	};	
	my $subType = (exists($device->{Attributes}{subType}) ? $device->{Attributes}{subType} : "none");
	# subType "key" does not make that much sense 
	return undef if($subType eq "key");
	my $model = (exists($device->{Attributes}{model}) ? $device->{Attributes}{model} : "none");
	# TODO: Does subType "heating" exist at all?
	if($subType eq "heating" or 
		$device->{Internals}{TYPE} eq "CUL_HM" and defined($device->{Internals}{chanNo}) 
			and ( $model eq "HM-CC-RT-DN" and $device->{Internals}{chanNo} eq "04"
			   or $model eq "HM-TC-IT-WM-W-EU" and $device->{Internals}{chanNo} eq "02" )){
		my $view = FUIP::View::Thermostat->createDefaultInstance($hash);
		$view->{device} = $name;
		if($level eq 'overview') {
			$view->{readonly} = "on";
			$view->{defaulted}{readonly} = 0;
			return $view;
		}else{
			$view->{size} = "big";	
			$view->{defaulted}{size} = 0;
			return $view;
		};	
	};
	# weather (PROPLANTA)
	if($device->{Internals}{TYPE} eq "PROPLANTA") {
		if($level eq "overview") {
			my $view = FUIP::View::WeatherOverview->createDefaultInstance($hash);
			$view->{device} = $name;
			$view->{sizing} = "resizable";
			$view->{defaulted}{sizing} = 0;
			$view->{width} = 80;
			$view->{height} = 70;
			$view->{layout} = "small";
			$view->{defaulted}{layout} = 0;
			return $view;
		}else{
			my $view = FUIP::View::WeatherDetail->createDefaultInstance($hash);
			$view->{device} = $name;
			$view->{sizing} = "resizable";
			$view->{defaulted}{sizing} = 0;
			$view->{width} = 560;
			$view->{height} = 335;
			return $view;
		};	
	};
    my $view;
	# weblink -> no...
	# general weblinks seem to be too dangerous. E.g. the usual DWD-weblink destroys the flex layout
	if($device->{Internals}{TYPE} eq "weblink"){
		return undef;
		#$view = FUIP::View::WebLink->createDefaultInstance($hash);
		#$view->{device} = $name;
		#$view->{sizing} = "resizable";
		#$view->{defaulted}{sizing} = 0;
		#$view->{width} = 600;
		#$view->{height} = 300;
		#return $view;
	};
	# DWD_OpenData_Weblink
	if($device->{Internals}{TYPE} eq "DWD_OpenData_Weblink"){
		$view = FUIP::View::DwdWebLink->createDefaultInstance($hash);
		$view->{device} = $name;
		$view->{sizing} = "resizable";
		$view->{defaulted}{sizing} = 0;
		$view->{width} = 600;
		$view->{height} = 175;
		return $view;
	};
	# TODO: Does subType "shutter" exist at all?
	if($subType =~ /^(shutter|blind)$/){
		if($level eq 'overview') {
			$view = FUIP::View::ShutterOverview->createDefaultInstance($hash);
		}else{
			$view = FUIP::View::ShutterControl->createDefaultInstance($hash);
		};	
	}else{
		my $state = (exists($device->{Readings}{state}) ? $device->{Readings}{state} : 0);
		if($state eq "on" or $state eq "off") {
			$view = FUIP::View::SimpleSwitch->createDefaultInstance($hash);
		}else{
			$view = FUIP::View::STATE->createDefaultInstance($hash);
		};
	};	
	$view->{device} = $name;
	return $view;
}


sub getDeviceViewsForRoom($$$) {
	my ($hash,$room,$level) = @_;
	my @views;
	my $devices = FUIP::Model::getDevicesForRoom($hash->{NAME},$room);
	foreach my $d (@$devices) {
		my $deviceView = getDeviceView($hash,$d,$level);
		next unless $deviceView;
		push(@views,$deviceView);
	};
	return \@views;
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
	my $backgroundImage = main::AttrVal($hash->{NAME},"styleBackgroundImage",undef);
	# now try to render this
	my $result;
	my $i = 0;
	my $cells = $hash->{pages}{$pageId}{cells};
	for my $cell (@{$cells}) {
		my ($col,$row) = $cell->position();
		my ($sizeX, $sizeY) = $cell->dimensions();
		$sizeX = ceil($sizeX);
		$sizeY = ceil($sizeY);
		$result .= "<li data-cellid=\"".$i."\" data-row=\"".($row+1)."\" data-col=\"".($col+1)."\" data-sizex=\"".$sizeX."\" data-sizey=\"".$sizeY."\" class=\"fuip-droppable fuip-cell";
		$result .= ' fuip-transparent' if $backgroundImage;
		$result .= "\">";
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
	my $backgroundImage = main::AttrVal($hash->{NAME},"styleBackgroundImage",undef);
	# now try to render this
	my $result;
	my $i = -1;
	my $cells = $hash->{pages}{$pageId}{cells};
	for my $cell (@{$cells}) {
		$i++;
		my ($col,$row) = $cell->position();
		next unless $cell->{region} eq $region;
		my ($width,$height) = cellSizeToPixels($cell);
		my ($sizeX, $sizeY) = $cell->dimensions();
		$sizeX = ceil($sizeX);
		$sizeY = ceil($sizeY);
		$result .= "<div id='fuip-flex-fake-".$i."' style=\"grid-area:".($row+1)." / ".($col+1)." / ".($row+$sizeY+1)." / ".($col+$sizeX+1).";position:relative;width:".$width."px;height:".$height."px;px;background-color:rgba(0,0,0,0);\">
					<div id='fuip-flex-cell-".$i."' data-cellid=\"".$i."\" class=\"fuip-droppable fuip-cell";
		$result .= ' fuip-transparent' if $backgroundImage;
		$result .= "\" style=\"position:absolute;width:".$width."px;height:".$height."px;
									border:0;\">";
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
	my $cells = $hash->{pages}{$pageId}{cells};
	
	# The "title cell" is the first of the title area
	my $lastMenuRow = 0;
	for my $cl (@{$cells}) {
		my ($c,$r) = $cl->position();
		$lastMenuRow = $r if($cl->{region} eq "menu" and $lastMenuRow < $r);
	};
	my $backgroundImage = main::AttrVal($hash->{NAME},"styleBackgroundImage",undef);
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
		my $cellHtml = "<div data-cellid=\"".$i."\" data-row=\"".($row+1)."\" data-col=\"".($col+1)."\" data-sizex=\"".$sizeX."\" data-sizey=\"".$sizeY."\" class=\"fuip-droppable fuip-cell";
		$cellHtml .= ' fuip-transparent' if $backgroundImage;
		$cellHtml .= "\" style=\"width:";
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
};


sub createPage($$) {
	# creates a new page
	# there is no check whether the page exists, i.e. might be overwritten
	my ($hash,$pageid) = @_;
	if($pageid eq "home"){
		defaultPageIndex($hash);
	}else{
		my @path = split(/\//,$pageid);
		if($path[0] eq "room" and defined($path[1])) {
			shift(@path);
			defaultPageRoom($hash,join("/",@path));
		}elsif($path[0] eq "device" and defined($path[1]) and defined($path[2])){
			shift(@path);
			my $room = shift(@path);
			# we need to put the paths together again in case there are further "/"
			# this is in principle rubbish but we need to avoid crashes
			defaultPageDevice($hash,$room,join("/",@path));
		}else{		
			defaultPage($hash,$pageid);
		};
	};		
};


sub getFuipPage($$) {
	my ($hash,$path) = @_;
	
	my $locked = main::AttrVal($hash->{NAME},"locked",0);
	my ($pageid,$preview) = split(/\?/,$path);
	# preview?
	if($preview and $preview eq "preview") {
		$locked = 1;	
	};
	
	# refresh Model buffer if locked
	# if not locked, this would mean very bad performance for e.g. value help for devices
	FUIP::Model::refresh($hash->{NAME}) if($locked);
	
	# "" goes to "home" 
	if(not defined($pageid) or $pageid eq "") {
		$pageid = "home";
	};	

	# for weird characters in page names etc., URLs are encoded
	# and the page keys also need to be stored encoded. However, 
	# at least one version of FUIP stored decoded keys. I.e. if 
	# there is no "encoded" page, but a "decoded" one, we need to 
	# display this page.
	if(not exists($hash->{pages}{$pageid})) {
		my $decodedPageid = main::urlDecode($pageid);
		if(exists($hash->{pages}{$decodedPageid})) {
			$pageid = $decodedPageid;
		};
	};	

	$currentPage = $pageid;  # might be needed for subsequent GET requests
	
	# do we need to create the page?
	if(not defined($hash->{pages}{$pageid})) {
		return("text/plain; charset=utf-8", "FUIP page $pageid does not exist") if($locked);
		createPage($hash,$pageid);
		# add a cell, as otherwise it cannot be maintained
		push(@{$hash->{pages}{$pageid}{cells}},FUIP::Cell->createDefaultInstance($hash)) unless @{$hash->{pages}{$pageid}{cells}};
	};
	# ok, we can render this	
	if(main::AttrVal($hash->{NAME},"layout","gridster") eq "flex") {
		return renderPageFlex($hash, $pageid) if($locked);
		return renderPageFlexMaint($hash,$pageid);
	}else{
		return renderPage($hash, $pageid, $locked);
	};
};


sub showAllIcons() {
  	my $result = 
	   '<!DOCTYPE html>
		<html>
			<head>
				<script type="text/javascript" src="/fhem/ui/lib/jquery.min.js"></script>
				<script src="/fhem/ui/js/fhem-tablet-ui.js"></script>
				<script>
					$(function() {
						$("body").css("background-color", "#E0E0E0");
						$("body").css("color", "#101010");
					});	
				
					function getIcons() {
						if(document.styleSheets.length == 0) {
							window.setTimeout(getIcons,1000);
							return;
						};
						var currentSheet = null;
						var i = 0;
						var j = 0;
						var ruleKey = null;
						//loop through styleSheet(s)
						var allIcons = {};
						for(i = 0; i<document.styleSheets.length; i++){
							currentSheet = document.styleSheets[i];
							///loop through css Rules
							for(j = 0; j< currentSheet.cssRules.length; j++){
								if(!currentSheet.cssRules[j].selectorText) { continue; };
								var selectors = currentSheet.cssRules[j].selectorText.split(",");
								for(var k = 0; k < selectors.length; k++) {
									var icons = selectors[k].match(/\.(fa|ftui|mi|oa|wi|fs)-.*(?=::before)/);
									if(!icons){ continue; };
									var icon = icons[0].substring(1);
									// sometimes there is another class...
									icon = icon.split(" ")[0];
									allIcons[icon] = 1;
									break;  // only one name of the same icon is enough
								}
							}
						}
						allIconsAsArr = Object.keys(allIcons);
						allIconsAsArr.sort();
						var html = "<table>";
						for (var i = 0; i < allIconsAsArr.length; i++) {
							var icon = allIconsAsArr[i];
							if (! allIcons.hasOwnProperty(icon)) { continue };
							var prefix = icon.split("-")[0];
							if(prefix == "wi") {
								icon = "wi " + icon;
							};	
							html += "<tr><td style=\"max-width:64px;padding:5px;border-style:solid;border-width:1px;\"><i class=\"fa " +icon+ " bigger bg-orange\"></i></td><td style=\"border-style:solid;border-width:1px;\">"+icon+"</td></tr>";
						};
						html += "</table>";
						$("#allicons").html(html);
					};
					getIcons();		
				</script>
			</head>
			<body>
				<h1>Available Icons</h1>
				<div id="allicons">
				<p>Just a moment, more to come...</p>
				<div data-type="symbol" data-icon="ftui-door"></div>
				<div data-type="symbol" data-icon="fa-volume-up"></div>
				<div data-type="symbol" data-icon="mi-local_gas_station"></div>
				<div data-type="symbol" data-icon="oa-secur_locked"></div>
				<div data-type="symbol" data-icon="wi-day-rain-mix"></div>	
				<div data-type="symbol" data-icon="fs-ampel_aus"></div>
				</div>
			</body>
		</html>';	
	return ("text/html; charset=utf-8", $result);
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
	}elsif($targettype eq "cell") {
		# importing as a cell
		# This always creates a new cell
		# If we come from a dialog, we need to convert sizes
		if($class eq "FUIP::Dialog") {
			my $dialog = $newObject;
			$newObject = FUIP::Cell->createDefaultInstance($hash);
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
		return ("text/plain; charset=utf-8", "OK".$id);
	};	
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
# here we answer any request to http://host:port/fhem/$infix and below

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
	
	# special logic for weatherdetail and readingsgroup
	# add "fuip" in front of path to make sure to use the FUIP version
	if($path[0] ne "fuip" and ( $path[-1] eq "widget_weatherdetail.js" or 
								$path[-1] eq "widget_dwdweblink.js" or
								$path[-1] eq "widget_dwdweblink.css" or
								$path[-1] eq "widget_readingsgroup.js" or 
								$path[-1] eq "widget_fuip_wdtimer.js" or
								$path[-1] eq "widget_fuip_wdtimer.css" or
								$path[-1] eq "widget_fuip_colorwheel.js" or
								$path[-1] eq "widget_fuip_colorwheel.css" or
								$path[-1] eq "widget_fuip_popup.js"
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
		}
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
	
	# TODO: remove this again...
	if($path[0] eq "icons") {
		return showAllIcons();
	};

	# otherwise, this is some library file or js or...	
	
    $filename =~ s/\?.*//;
	
	# The following is to block any widget to load jquery-ui again. It would break drag/drop of views.
	my $basename = basename($filename);
	if($basename eq "jquery-ui.js" or $basename eq "jquery-ui.min.js") {
		return("text/plain; charset=utf-8", "");	
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
	my ($rettype, $data) = CGI_inner($request); 
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


sub save($) {
	my ($hash) = @_;
	my $config = serialize($hash);   
	my $filename = "FUIP_".$hash->{NAME}.".cfg";
    my @content = split(/\n/,$config);
	# make sure config directory exists
	my $cfgPath = $fuipPath."config";
	if(not(-d $cfgPath)) {
		mkdir($cfgPath);
		# we do not check for errors here as anyway the FileWrite will fail
	};
	return main::FileWrite($cfgPath."/".$filename,@content);		
};


sub load($) {
	# TODO: some form of error management
	my ($hash) = @_;
	# clear pages and viewtemplates
	$hash->{pages} = {};
	$hash->{viewtemplates} = {};
	my $filename = "FUIP_".$hash->{NAME}.".cfg";
	# try to read from FUIP directory
	my ($error, @content) = main::FileRead($fuipPath."config/".$filename);	
	if($error) {
		# not found or other issue => try to read from main fhem directory (old location for this file)
		my $err2;
		($err2, @content) = main::FileRead($filename);
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
	};
	# now the pages
	for my $pageid (keys %$cPages) {
		my $pageConf = $cPages->{$pageid};
		my $class = $pageConf->{class}; # This allows for other page-implementations (???)
		delete($pageConf->{class});
		$hash->{pages}{$pageid} = $class->reconstruct($pageConf,$hash);
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
	return undef;
};


# dclone does not work because of references to the FUIP object
sub cloneView($) {
	my ($view) = @_;
	my $conf = eval($view->serialize());
	my $class = $conf->{class}; 
	delete($conf->{class});
	return $class->reconstruct($conf,$view->{fuip});
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
			$newView = $newclass->createDefaultInstance($hash);
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
	$hash->{viewtemplates}{$templateid} = FUIP::ViewTemplate->createDefaultInstance($hash);
	$hash->{viewtemplates}{$templateid}{id} = $templateid;
	# create a deep copy of the cell
	my $instanceStr = $origin->serialize();
	my $instance = "FUIP::Cell"->reconstruct(eval($instanceStr),$hash);
	$hash->{viewtemplates}{$templateid}{views} = $instance->{views};
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


sub Set($$$)
{
	my ( $hash, $a, $h ) = @_;

	# main::Log3($hash, 3, 'FUIP: Set: ' . main::Dumper($a).'  '.main::Dumper($h));
	
	return "\"set ".$hash->{NAME}."\" needs at least one argument" unless(@$a > 1);
	my $cmd = $a->[1];
	if($cmd eq "save"){
		return save($hash);
	}elsif($cmd eq "load"){
		return load($hash);
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
		my $newCell = FUIP::Cell->createDefaultInstance($hash);
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
		createPage($hash,$newPageId) unless defined $hash->{pages}{$newPageId};
		my $newCell = cloneView($hash->{pages}{$oldPageId}{cells}[$oldCellId]);
		delete $newCell->{posX};
		delete $newCell->{posY};
		push(@{$hash->{pages}{$newPageId}{cells}},$newCell);
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
	}else{
		# redetermine attribute values
		setAttrList($main::modules{FUIP});
		return "Unknown argument $cmd, choose one of save:noArg load:noArg viewsettings viewaddnew viewdelete viewposition autoarrange refreshBuffer pagedelete:".join(',',sort keys %{$hash->{pages}});
	}
	return undef;  # i.e. all good
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


sub _getDeviceList($) {
	my ($name) = @_;
	my $result = [];
	
	my $keys = FUIP::Model::getDeviceKeys($name);
	for my $key (sort { lc($a) cmp lc($b) } @$keys) {
		my $device = FUIP::Model::getDevice($name,$key,["TYPE","room","alias"]);
		push(@$result, {
			NAME => $key,
			TYPE => $device->{Internals}{TYPE},
			room => $device->{Attributes}{room},
			alias => $device->{Attributes}{alias}
			});
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
		foreach my $i (2 .. $#{$a}) {
			my $view = getDeviceView($hash, $a->[$i],"overview");
			if(not defined($view)) {
				$view = FUIP::View::STATE->createDefaultInstance($hash);
				$view->{device} = $a->[$i];
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
		return _toJson(_getDeviceList($hash->{NAME}));
	}elsif($opt eq "readingslist") {
		# TODO: check if $a->[2] exists
		return _toJson(FUIP::Model::getReadingsOfDevice($hash->{NAME},$a->[2]));
	}elsif($opt eq "sets") {
		return _toJson(FUIP::Model::getSetsOfDevice($hash->{NAME},$a->[2]));
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
		return "Unknown argument $opt, choose one of settings viewclasslist:noArg viewdefaults:".join(",",@$viewclasses)." pagelist:noArg pagesettings:".join(",",@pages)." devicelist:noArg readingslist sets";
	}
}
   
1;
