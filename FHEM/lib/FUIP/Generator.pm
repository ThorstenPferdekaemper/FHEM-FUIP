package FUIP::Generator;

use strict;
use warnings;

use lib::FUIP::Systems;
use lib::FUIP::Exception;


sub createPage($$) {
	my ($hash,$pageid) = @_;
	eval {
		$hash->{pages}{$pageid} = _createPage($hash,$pageid);
		1;
	} or do {
		my $ex = $@;
		FUIP::Exception::raise("Failed to generate page \"$pageid\"", $ex);
	};	
};


sub getDeviceView($$$$){
	# the views created here have the fuip instance as their parent. They will be re-ordered later anyway
	my ($hash,$name,$level,$sysid) = @_;
	my $device = FUIP::Model::getDevice($hash->{NAME},$name,["TYPE","subType","state","chanNo","model"],$sysid);
	return undef unless defined $device;
	# don't show FileLogs or FHEMWEBs
	# TODO: rooms and types to ignore could be configurable
	return undef if($device->{Internals}{TYPE} =~ m/^(FileLog|FHEMWEB|at|notify|FUIP|HMUARTLGW|HMinfo|HMtemplate|DWD_OpenData)$/);
	if($level eq "overview") {
		return undef if($device->{Internals}{TYPE} =~ m/^(weblink|SVG|DWD_OpenData_Weblink)$/);
	};
	# we have something special for SYSMON
	if($device->{Internals}{TYPE} eq "SYSMON" and not $level eq "overview") {
		my $view = FUIP::View::Sysmon->createDefaultInstance($hash,$hash);
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
		my $view = FUIP::View::Thermostat->createDefaultInstance($hash,$hash);
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
			my $view = FUIP::View::WeatherOverview->createDefaultInstance($hash,$hash);
			$view->{device} = $name;
			$view->{sizing} = "resizable";
			$view->{defaulted}{sizing} = 0;
			$view->{width} = 80;
			$view->{height} = 70;
			$view->{layout} = "small";
			$view->{defaulted}{layout} = 0;
			return $view;
		}else{
			my $view = FUIP::View::WeatherDetail->createDefaultInstance($hash,$hash);
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
	};
	# DWD_OpenData_Weblink
	if($device->{Internals}{TYPE} eq "DWD_OpenData_Weblink"){
		$view = FUIP::View::DwdWebLink->createDefaultInstance($hash,$hash);
		$view->{device} = $name;
		$view->{sizing} = "resizable";
		$view->{defaulted}{sizing} = 0;
		$view->{width} = 600;
		$view->{height} = 175;
		return $view;
	};
	# Charts
	if($device->{Internals}{TYPE} eq "SVG"){
		$view = FUIP::View::Chart->createDefaultInstance($hash,$hash);
		$view->{device} = $name;
		$view->{sizing} = "resizable";
		$view->{defaulted}{sizing} = 0;
		$view->{width} = 280;
		$view->{height} = 175;
		return $view;
	};
	# TODO: Does subType "shutter" exist at all?
	if($subType =~ /^(shutter|blind)$/){
		if($level eq 'overview') {
			$view = FUIP::View::ShutterOverview->createDefaultInstance($hash,$hash);
		}else{
			$view = FUIP::View::ShutterControl->createDefaultInstance($hash,$hash);
		};	
	}else{
		my $state = (exists($device->{Readings}{state}) ? $device->{Readings}{state} : 0);
		if($state eq "on" or $state eq "off") {
			$view = FUIP::View::SimpleSwitch->createDefaultInstance($hash,$hash);
		}else{
			$view = FUIP::View::STATE->createDefaultInstance($hash,$hash);
		};
	};	
	$view->{device} = $name;
	return $view;
}


sub _createPage($$) {
	# creates a new page
	# there is no check whether the page exists, i.e. might be overwritten
	my ($hash,$pageid) = @_;
	
	main::Log3(undef, 3, "FUIP: Creating page ".$pageid);
	
	#System overview?
	if($pageid eq "overview"){
		return _defaultPageIndex($hash);
	};

	my @path = split(/\//,$pageid);
	# To be able to generate a page, we need the system id
	my $sysid = shift(@path);
	if(not FUIP::Systems::getSystemUrl($hash,$sysid)) {
		# Not a proper system id, just create the empty page
		return _defaultPage($hash,$pageid);
	};	
	
	# System page, i.e. nothing after sysid in the path
	if($pageid eq $sysid) {
		return _defaultPageSystem($hash,$sysid);
	};	
	
	if($path[0] eq "room" and defined($path[1])) {
		shift(@path);
		return _defaultPageRoom($hash,join("/",@path),$sysid);
	}elsif($path[0] eq "device" and defined($path[1]) and defined($path[2])){
		shift(@path);
		my $room = shift(@path);
		# we need to put the paths together again in case there are further "/"
		# this is in principle rubbish but we need to avoid crashes
		return _defaultPageDevice($hash,$room,join("/",@path),$sysid);
	}else{	
		# TODO: it might make sense to generate a bit more than an empty page 
		#       if we know the sysid
		return _defaultPage($hash,$pageid);
	};
};


sub _createRoomsMenu($$$) {
	my ($hash,$pageid,$page) = @_;
	
	my $sysid = ( split '/', $pageid )[ 0 ];	
	my $cell = FUIP::Cell->createDefaultInstance($hash,$page);
	$cell->{title} = "R&auml;ume";	
	$cell->position(0,1);
    # create a MenuItem view for each room
	my @rooms = FUIP::Model::getRooms($hash->{NAME},$sysid);
	my $posY = 0; 
	for my $room (@rooms) {
		my $menuItem = FUIP::View::MenuItem->createDefaultInstance($hash,$cell);
		$menuItem->{text} = $room;
		$menuItem->{pageid} = $sysid."/room/".$room;
		$menuItem->{active} = "0";
		my @parts = split('/',$pageid);
		if(@parts > 2) {
			if($parts[0] eq $sysid and $parts[1] =~ /room|device/ and main::urlDecode($parts[2]) eq $room) {
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


sub _generateGetTitleHeight($) {
	my $hash = shift;
	my $baseHeight = main::AttrVal($hash->{NAME},"baseHeight",108);	
	use integer;
	my $titleHeight = 60 / $baseHeight;
	$titleHeight += 1 if 60 % $baseHeight;
	no integer;
	return $titleHeight;
};


sub _addStandardCells($$$$) {
	my ($hash,$cells,$pageid,$page) = @_;
	# determine height of title line
	# this gives more flexibility for baseHeight
	# baseWidth is assumed something roughly around 140
	my $titleHeight = _generateGetTitleHeight($hash);
	# Home button
	my $homeCell = FUIP::Cell->createDefaultInstance($hash,$page);
	my $view = FUIP::View::HomeButton->createDefaultInstance($hash,$homeCell);
	if(FUIP::Systems::getNumSystems($hash) > 1) {
		$view->{active} = ($pageid eq "home" ? 1 : 0);
	}else{
		$view->{active} = ($pageid eq FUIP::Systems::getDefaultSystem($hash) ? 1 : 0);
	};	
	$view->position(0,0);
	$homeCell->position(0,0);
	$homeCell->dimensions(1,$titleHeight);
	$homeCell->{views} = [ $view ];
	$homeCell->{title} = "Home";
	push(@$cells,$homeCell);
	# Clock
	my $clockCell = FUIP::Cell->createDefaultInstance($hash,$page);
	my $clockView = FUIP::View::Clock->createDefaultInstance($hash,$clockCell);
	$clockView->position(0,0);
	# switch sizing of the clock to auto, e.g. to center it
	$clockView->{sizing} = "auto";
	$clockView->{defaulted}{sizing} = 0;
	$clockCell->position(6,0);
	$clockCell->dimensions(1,$titleHeight);
	$clockCell->{views} = [ $clockView ];
	$clockCell->{title} = "Uhrzeit";
	push(@$cells,$clockCell);
	# Title cell
	my $titleCell = FUIP::Cell->createDefaultInstance($hash,$page);
	my $title = ($pageid eq "home" ? "Home, sweet home" : main::urlDecode(( split '/', $pageid )[ -1 ]));
	$view = FUIP::View::Title->createDefaultInstance($hash,$titleCell);
	$view->{text} = $title;
	$view->{icon} = "oa-control_building_s_all" if $pageid eq "home";
	$view->position(0,0);
	$titleCell->position(1,0);
	$titleCell->dimensions(5,$titleHeight);
	$titleCell->{views} = [ $view ];
	$titleCell->{title} = $title;
	push(@$cells,$titleCell);
	# rooms menu unless index page and multifhem...
	return if($pageid eq "overview");
	
	my $roomsMenu = _createRoomsMenu($hash,$pageid,$page);
	# make sure rooms menu is under home button
	$roomsMenu->position(0,$titleHeight);
	push(@$cells,$roomsMenu);
};


# defaultPageIndex
# Creates default index page
# In case there are multiple systems
sub _defaultPageIndex($) {
	my ($hash) = @_;
	
	# Now we can be sure that we are in multifhem mode
	# Create home page with links to each system
	
	my $page = FUIP::Page->createDefaultInstance($hash,$hash);	
	my @cells;
	# home button and rooms menu
	_addStandardCells($hash, \@cells, 'overview', $page);
	# TODO: get "system views", not only system menu 

	my $systemsMenu = FUIP::Cell->createDefaultInstance($hash,$page);
	$systemsMenu->{title} = "Systeme";	
	$systemsMenu->position(0,1);
    # create a MenuItem view for each system
	my $systems = FUIP::Systems::getSystems($hash);
	my $posY = 0; 
	foreach my $sysid (sort keys %$systems) {
		my $menuItem = FUIP::View::MenuItem->createDefaultInstance($hash,$systemsMenu);
		$menuItem->{text} = $sysid;
		$menuItem->{pageid} = $sysid;
		$menuItem->{active} = "0";
		$menuItem->position(0,$posY);
		my (undef,$h) = $menuItem->dimensions();
		$posY += $h;  
		push(@{$systemsMenu->{views}}, $menuItem);												
	};
	$systemsMenu->dimensions(1,undef);
	# make sure systems menu is under home button
	my $titleHeight = _generateGetTitleHeight($hash);
	$systemsMenu->position(0,$titleHeight);
	push(@cells,$systemsMenu);	
	
	$page->{cells} = \@cells;
	return $page;
};


# defaultPageSystem
# Create (generate) default page for one FHEM system.
# sysid should be "home" unless multifhem
sub _defaultPageSystem($$) {
	my ($hash,$sysid) = @_;
	my @cells;
	my $page = FUIP::Page->createDefaultInstance($hash,$hash);
	# TODO: If we do not really have multifhem, but multifhem is introduced
	#       later, the following leads to a page with sysid "home", but there 
	#       might not be a sysid "home". This happens if the first system created
	#       explicitly has the "url" "local".
	$page->{sysid} = $sysid;
	# home button and rooms menu
	_addStandardCells($hash, \@cells, $sysid, $page); 
	# get "room views" 
	my @rooms = FUIP::Model::getRooms($hash->{NAME},$sysid);
	foreach my $room (@rooms) {
		my $cell = FUIP::Cell->createDefaultInstance($hash,$page);
		my $views = _getDeviceViewsForRoom($hash,$room,"overview",$sysid);
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
				my $spacer = FUIP::View::Spacer->createDefaultInstance($hash,$cell);
				$spacer->dimensions(FUIP::cellWidthToPixels($hash,2), 5);
				push(@$views,$spacer);
			};
			push(@$views,@switches);
		};
		if(@others) {
			if(@$views) {
				my $spacer = FUIP::View::Spacer->createDefaultInstance($hash,$cell);
				$spacer->dimensions(FUIP::cellWidthToPixels($hash,2), 5);
				push(@$views,$spacer);
			};
			push(@$views,@others);
		};

		$cell->{title} = $room;
		$cell->{views} = $views;
		$cell->setAsParent();
		$cell->applyDefaults();
		$cell->dimensions(2,1);  #auto-arranging will fit the height
		FUIP::autoArrangeNewViews($cell);
		push(@cells, $cell);
	};

	$page->{cells} = \@cells;
	return $page;
};


sub _defaultPageRoom($$$){
	my ($hash,$room,$sysid) = @_;
	my $pageid = $sysid."/room/".$room;
	$room = main::urlDecode($room);
	my $page = FUIP::Page->createDefaultInstance($hash,$hash);
	# TODO: If we do not really have multifhem, but multifhem is introduced
	#       later, the following leads to a page with sysid "home", but there 
	#       might not be a sysid "home". This happens if the first system created
	#       explicitly has the "url" "local".
	$page->{sysid} = $sysid;
	my $viewsInRoom = _getDeviceViewsForRoom($hash,$room,"room",$sysid);
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
		$cell = FUIP::Cell->createDefaultInstance($hash,$page);
		$cell->{views} = [$view];
		$cell->{title} = "Heizung";
		push(@cells,$cell);
	};
	for my $view (@shutters) {
		$cell = FUIP::Cell->createDefaultInstance($hash,$page);
		$cell->{views} = [$view];
		$cell->{title} = "Rollladen";
		push(@cells,$cell);
	};
	# create one cell for all switches
	if(@switches) {
		$cell = FUIP::Cell->createDefaultInstance($hash,$page);
		$cell->{title} = "Lampen";
		$cell->{views} = \@switches;
		push(@cells,$cell);
	};	
	# create cells for "others"
	for my $view (@others) {
		$cell = FUIP::Cell->createDefaultInstance($hash,$page);
		$cell->{views} = [$view];
		push(@cells,$cell);
	};
	# create one cell for all "STATE only"
	if(@states) {
		$cell = FUIP::Cell->createDefaultInstance($hash,$page);
		$cell->{title} = "Sonstige";
		$cell->{views} = \@states;
		push(@cells,$cell);
	};	
	# care for proper size of the cells
	for $cell (@cells) { 
		$cell->applyDefaults();
		$cell->setAsParent();
		if($cell->{views}[0]->isa('FUIP::View::WeatherDetail') ||
				$cell->{views}[0]->isa('FUIP::View::DwdWebLink') ||
				$cell->{views}[0]->isa('FUIP::View::WebLink')){
			$cell->dimensions(4,1);
			FUIP::autoArrangeNewViews($cell);
			$cell->{views}[0]{sizing} = "auto";
		}else{	
			$cell->dimensions(2,1);
			FUIP::autoArrangeNewViews($cell);
		};
	};
	# home button and rooms menu
	_addStandardCells($hash, \@cells, $pageid, $page);
	# add to pages

	$page->{cells} = \@cells;
	return $page;
};


sub _defaultPageDevice($$$$){
    my ($hash,$room,$device,$sysid) = @_;
	my $pageid = $sysid."/device/".$room."/".$device;
	my @cells;
	my $page = FUIP::Page->createDefaultInstance($hash,$hash);
		# TODO: If we do not really have multifhem, but multifhem is introduced
	#       later, the following leads to a page with sysid "home", but there 
	#       might not be a sysid "home". This happens if the first system created
	#       explicitly has the "url" "local".
	$page->{sysid} = $sysid;
	
	_addStandardCells($hash, \@cells,$pageid, $page);
	my $cell = FUIP::Cell->createDefaultInstance($hash,$page);
	my $deviceView = FUIP::View::ReadingsList->createDefaultInstance($hash,$cell);
	$deviceView->{device} = $device;
	$cell->{views} = [$deviceView];
	push(@cells, $cell);
	$page->{cells} = \@cells;
	return $page;
};


sub _defaultPage($$){
	#creates a default (almost empty) page
	my ($hash,$pageId) = @_;
	my $page = FUIP::Page->createDefaultInstance($hash,$hash);
	$page->{cells} = [];
	return $page;
};




sub _getDeviceViewsForRoom($$$$) {
	my ($hash,$room,$level,$sysid) = @_;
	my @views;
	my $devices = FUIP::Model::getDevicesForRoom($hash->{NAME},$room,$sysid);
	foreach my $d (@$devices) {
		my $deviceView = getDeviceView($hash,$d,$level,$sysid);
		next unless $deviceView;
		push(@views,$deviceView);
	};
	return \@views;
};

1;
