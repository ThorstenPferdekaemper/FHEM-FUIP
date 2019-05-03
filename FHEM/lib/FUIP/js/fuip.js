// everything which should be run after the page has loaded
var fuipGridster;
var fuip = {};

function fuipInit(conf) { //baseWidth, baseHeight, maxCols, gridlines, snapTo
	fuip.baseWidth = conf.baseWidth;
	fuip.baseHeight = conf.baseHeight;
	fuip.cellMargin = conf.cellMargin;
	fuip.snapTo = conf.snapTo;
	$( function() {
		// csrf token
		getLocalCSrf();
		// the settings dialog
		var viewsettings;
		viewsettings = $( "#viewsettings" ).dialog({
			autoOpen: false,
			width: 675,
			modal: true,
		});
		// is this the dialog maintenance page?
		var fieldid = $("html").attr("data-fieldid");
		var templateid = $("html").attr("data-viewtemplate");
		// switch to page settings does not make sense for dialog maintenance
		if(!fieldid && !templateid) {
			$(function() {
				$('.ui-dialog-titlebar').append(
					'<ul id="fuip-menutoggle" data-fuip-state="init"></ul>');
				toggleConfigMenu();
			});
		};	
		// every view is draggable					
		$(".fuip-draggable").each(function() {
			$(this).draggable({
				revert: "invalid",
				stack: ".fuip-draggable",
				start: function(e,ui) {
					fuip.drag_start_left = ui.offset.left - ui.position.left;
					fuip.drag_start_top = ui.offset.top - ui.position.top;
				},	
				drag: function(e,ui) {
					if(fuip.snapTo == "nothing") return;
					if(e.altKey) return;
					var dim = snapDimensions();
					var start = gridStart();
					var n = (ui.position.left + fuip.drag_start_left - start.left) / dim.gridWidth;
					if(n - Math.floor(n) > 0.5) n++;
					var snapped = start.left + Math.floor(n) * dim.gridWidth;  // offset	
					ui.position.left = snapped - fuip.drag_start_left;
					n = (ui.position.top + fuip.drag_start_top - start.top) / dim.gridHeight;
					if(n - Math.floor(n) > 0.5) n++;
					snapped = start.top + Math.floor(n) * dim.gridHeight;  // offset	
					ui.position.top = snapped - fuip.drag_start_top;
				}	
			});
		});
		$(".fuip-resizable").each(function() {
			$(this).resizable({
				stop: onViewResizeStop,
				classes: { "ui-resizable-se" : "ui-resizable-se ui-icon ui-icon-gripsmall-diagonal-se fuip-ui-icon-bright" },
				resize: function(e,ui) {
					if(fuip.snapTo == "nothing") return;
					if(e.altKey) return;
					var dim = snapDimensions();
					var start = gridStart();
					var n = (ui.position.left + ui.size.width) / dim.gridWidth;
					if(n - Math.floor(n) > 0.5) n++;
					var snapped = Math.floor(n) * dim.gridWidth;  // offset	
					ui.size.width = snapped - ui.position.left;
					n = (ui.originalElement.offset().top - start.top + ui.size.height) / dim.gridHeight;
					if(n - Math.floor(n) > 0.5) n++;
					snapped = start.top + Math.floor(n) * dim.gridHeight;  // offset	
					ui.size.height = snapped - ui.originalElement.offset().top;					
				}				
			});
		});		
		
		// every cell is droppable
		$(".fuip-droppable").each(function() {
			$(this).droppable({
				accept: ".fuip-draggable",
				drop: function(event,ui) { onDragStop($(this),ui); }
			});
		});	
	// configure gridster
	if($("html").attr("data-layout") == "gridster") {
		fuipGridster =  $(".gridster ul").gridster({
			widget_base_dimensions: [conf.baseWidth,conf.baseHeight],
			widget_margins: [conf.cellMargin,conf.cellMargin],
			autogrow_cols: true,
			max_cols: conf.maxCols,
			resize: {
				enabled: true,
				stop: onGridsterChangeStop	
			},
			draggable: {
				handle: "header",
				stop: onGridsterChangeStop	
			}	
		}).data('gridster');
	};
	if(conf.gridlines == "show") drawGrid();   
	// render where-used-list(s)
	renderWhereUsedLists();
	});
};
	
	
function pulsateColorStart(key) {
	// reset pulsating stuff
	pulsateColorStop();
	fuip.colorpulse = {};
	// get current color value
	let value = document.documentElement.style.getPropertyValue(key);
	if(!value) value = fuip.colorVariables[key];
	if(!value) return;  // this does not work
	fuip.colorpulse.key = key;
	fuip.colorpulse.resetValue = value;
	// convert to rgba 	
	fuip.colorpulse.rgbaValue = colorToRgbaArray(value);
	fuip.colorpulse.currentOffset = 0;
	fuip.colorpulse.currentDirection = 1;
	fuip.colorpulse.timer = setInterval(pulsateColor,50);
};


function pulsateColorStop() {
	if(!fuip.colorpulse) return;
	clearInterval(fuip.colorpulse.timer);
	document.documentElement.style.setProperty(fuip.colorpulse.key,fuip.colorpulse.resetValue);
	fuip.colorpulse = false;
};	


function pulsateColor() {
	// determine new value
	if(fuip.colorpulse.currentOffset >= 10) {
		fuip.colorpulse.currentDirection = -2;
	}else if(fuip.colorpulse.currentOffset <= -10) {
		fuip.colorpulse.currentDirection = 2;
	};	
	fuip.colorpulse.currentOffset += fuip.colorpulse.currentDirection;
	let value = fuip.colorpulse.rgbaValue;
	for(let i = 0; i < 3; i++){
		value[i] += fuip.colorpulse.currentOffset;
		if(value[i] > 255) value[i] = 255;
		if(value[i] < 0) value[i] = 0;
	};	
	let color = colorToRgbaString(value);
	// set color
	document.documentElement.style.setProperty(fuip.colorpulse.key,color);	
};	


// convert any color to rgba-object
function colorToRgbaArray(color) {
	// return color itself if this is already an array
	if(Array.isArray(color)) return color;
	// remove blanks
	let value = color.replace(/\s/g, "");
	let result = [255,0,0,1];  // R,G,B,A (A = opacity)
	if(value.length == 4) {  // short hex like #ggg
		for(let i = 0; i < 3; i++) {
			result[i] = parseInt(value.charAt(i+1) + value.charAt(i+1),16);
		};
		return result;	
	};	
	if(/^rgba/.test(value)) {  // like rgba(0,80,255,0.2)
		let parts = value.substr(5,value.length - 6).split(",");
		for(let i = 0; i < 3; i++) {
			result[i] = parseInt(parts[i]);
		};	
		result[3] = parseFloat(parts[3]);
		return result;
	};	
	// now it should be #123456
	if(value.length == 7) {
		for(let i = 0; i < 3; i++) {
			result[i] = parseInt(value.charAt(i*2+1) + value.charAt(i*2+2),16);
		};
		return result;	
	};	
	// something is wrong here, just return something "red"
	return result;
};	


function colorToRgbaString(color) {
	let colAsAr = colorToRgbaArray(color);
	let result = 'rgba(';
	for(let i = 0; i < 4; i++) {
		if(i > 0) result += ',';
		result += colAsAr[i].toString();
	};
	result += ')';
	return result;	
};	


function colorToCodeAndOpacity(color) {
	let colAsAr = colorToRgbaArray(color);
	let code = '#';
	for(let i = 0; i < 3; i++) {
		let hexStr = colAsAr[i].toString(16);
		if(hexStr.length < 2) hexStr = '0' + hexStr;
		code += hexStr;
	};		
	return {
		'code': code,
		'opacity': colAsAr[3]
	};	
};	


// change colours 	
function coloursChangeDialog() {
	// close settings dialog
	$("#viewsettings").dialog("close");

	// get variables from style sheets (seems that it does not work easier) 
	fuip.colorVariables = { };
	for(let i = 0; i < document.styleSheets.length; i++){
		let currentSheet = document.styleSheets[i];
		//loop through css Rules
		try {
			for(j = 0; j < currentSheet.cssRules.length; j++){
				let rule = currentSheet.cssRules[j];
				if(rule.selectorText != ":root") continue;
				if(rule.type != CSSRule.STYLE_RULE) continue;
				let style = rule.style;
				for( let k = 0; k < style.length; k++ ) {
					let prop = style.item(k);
					if(! /^--fuip-color-/.test(prop)) continue;		
					fuip.colorVariables[prop] = style.getPropertyValue(prop);
				};	
			};
		}catch(e) {
			// this can happen if a style sheet comes from "elsewhere"
			// however, in this case it probably does not contain any colors
			// which we have to display
		}	
	};
	// now get the current value in case it has already been changed
	for(const prop in fuip.colorVariables) {
		let newVal = document.documentElement.style.getPropertyValue(prop);	
		if(newVal) fuip.colorVariables[prop] = newVal;
	};
	
	// now colorVariables contains all --fuip-color-Variables with their value
	// create message if there are no colors to set (do we really?)
	// create popup with color names and and input type="color"	
	let html = "<form onsubmit='return false'><table>" 
	fuip.oncolorinput = function(id) {
		pulsateColorStop();
		let colArr = colorToRgbaArray($('#'+id).val());
		colArr[3] = parseFloat($('#'+id+'-opacity').val());
		let rgba = colorToRgbaString(colArr);
		document.documentElement.style.setProperty(id,rgba);	
		$('#'+id+'-preview').css('background-color',rgba);
	};	
		
	for(const key in fuip.colorVariables){
		// prepare color value
		let colAsAr = colorToRgbaArray(fuip.colorVariables[key]);
		let color = colorToCodeAndOpacity(colAsAr);
		let rgbaString = colorToRgbaString(colAsAr);
		html += '<tr><td style="text-align:left">' + key.substr(13) + '</td><td>' 
			+ '<input type="color" value="' + color.code + '" id="' + key + '" oninput="fuip.oncolorinput(\''+key+'\')">'
			+ '</td><td> x </td>'
			+ '<td><input type="number" id="'+key+'-opacity" value="'+color.opacity+'" min="0" max="1" step="0.01" style="width:50px;" oninput="fuip.oncolorinput(\''+key+'\')"></td>'
			+ '<td> = </td>'
			+ '<td style="position:relative">transparent<div id="'+key+'-preview" style="position:absolute;top:0;left:0;width:100%;height:100%;background-color:'+rgbaString+';"></div></td>' 
			+ '</tr>';
		$(function(){
			$('#'+key).val(color.code);
			$('#'+key).hover(
				function(){pulsateColorStart(key)},
				function(){pulsateColorStop()});
		});	
	};	
	html += "</table></form>";	
	let buttons = [
		{	text: "Ok", 
			icon: "ui-icon-check",
			click: function() { 
				let cmd = "";
				for(let prop in fuip.colorVariables) {
					let value = document.documentElement.style.getPropertyValue(prop);
					if(value) {
						value = value.replace(/\s/g, "")
						fuip.colorVariables[prop] = value;
						cmd += prop.substr(13) + "=" + value + " ";
					};	
				};	
				fuip.colorchangepopup.dialog("close"); 
				if(cmd.length > 0) {
					cmd = "set " + $("html").attr("data-name") + " colors " + cmd;
					asyncSendFhemCommandLocal(cmd);
				};	
			},
			showLabel: false
		},
		{	text: 'Reset all to style schema',
			icon: 'ui-icon-arrowreturnthick-1-w',
			click: async function() {
				let cmd = "set " + $("html").attr("data-name") + " colors reset"; 
				fuip.colorchangepopup.dialog("close"); 
				await asyncSendFhemCommandLocal(cmd);
				location.reload(true);
			},	
			showLabel: false
		},
		{	text: 'Cancel',
			icon: 'ui-icon-close',
			click: function() {	fuip.colorchangepopup.dialog("close"); }, 
			showLabel: false }
		];
	if(fuip.colorchangepopup) {
		fuip.colorchangepopup.html = html;
	}else{	
		fuip.colorchangepopup = $(html);
	};	
	fuip.colorchangepopup.dialog({
			width: 400,
			title: 'Select colors',
			modal: true,
			buttons: buttons,
			close: function(event,ui) {
				for(let prop in fuip.colorVariables) {
					document.documentElement.style.setProperty(prop,fuip.colorVariables[prop]);
				};	
			}
	});
};	
	
	
function openChangeLog() {
	let name = $("html").attr("data-name").toLowerCase();
	window.open(location.origin + "/fhem/" + name + "/fuip/doc/changes.html","fuipdoc");
};	
	
	
function toggleConfigMenu(){
	// cell menu
	// Goto ->
	//		Page config
	//		View templates
	// Cell ->
	//		Add new
	//		Copy
	//		Export
	//		Import
	//		Delete
	//		Arrange views
	//		Make view templ.
	//
	// page menu
	// Goto ->
	//		Cell config 
	//		View templates
	// Page ->
	//		Copy
	//		Export
	//		Import
	//		Repair
	
	let menu;
	if($('#fuip-menutoggle').attr("data-fuip-state") == "closed"){
		// menu up to "Goto" header
		let html = '<ul id="fuip-menutoggle" data-fuip-state="opened"  style="position:absolute;top:2px;left:2px;z-index:999;width:175px;text-align:left;"><li><div><span class="ui-icon ui-icon-triangle-1-s"></span>Menu</div></li><li class="ui-menu-divider"></li><li class="ui-widget-header"><div>Goto</div></li>';
		let mode = $( "#viewsettings" ).attr("data-mode");
		if(mode != "cell" && mode != "page") 
			return;  
		if(mode == "cell") {
			html += '<li onclick="toggleCellPage()"><div>Page config</div></li>'
				+	'<li onclick="callViewTemplateMaint()"><div>View Templates</div></li>'
				+	'<li class="ui-widget-header"><div>Cell</div></li>'
				+	'<li onclick="acceptSettings(viewAddNew)"><div title="Add a new cell to this page"><span class="ui-icon ui-icon-plus"></span>Add</div></li>'
				+	'<li onclick="acceptSettings(copyCurrentCell)"><div><span class="ui-icon ui-icon-copy"></span>Copy</div></li>'
				+	'<li><div onclick="acceptSettings(exportCellOrDialog)"><span class="ui-icon ui-icon-arrowstop-1-s"></span>Export</div></li>'
				+	'<li><div onclick="importCellOrDialog()"><span class="ui-icon ui-icon-arrowstop-1-n"></span>Import</div></li>'
				+	'<li><div onclick="acceptSettings(autoArrange)"><span class="ui-icon ui-icon-calculator"></span>Arrange views</div></li>'
				+	'<li><div onclick="acceptSettings(dialogConvertToViewtemplate)" title="Create a view template which looks like this cell">Make view template</div></li>'
				+	'<li><div onclick="deleteCell()"><span class="ui-icon ui-icon-trash"></span>Delete</div></li>';
		}else{
			html += '<li onclick="toggleCellPage()"><div>Cell config</div></li>'
				+	'<li onclick="callViewTemplateMaint()"><div>View Templates</div></li>'
				+	'<li class="ui-widget-header"><div>Page</div></li>'
				+	'<li><div onclick="acceptPageSettings(copyCurrentPage)"><span class="ui-icon ui-icon-copy"></span>Copy</div></li>'
				+	'<li><div onclick="acceptPageSettings(exportPage)"><span class="ui-icon ui-icon-arrowstop-1-s"></span>Export</div></li>'
				+	'<li><div onclick="importPage()"><span class="ui-icon ui-icon-arrowstop-1-n"></span>Import</div></li>'
				+	'<li><div onclick="acceptPageSettings(repairPage)"><span class="ui-icon ui-icon-wrench"></span>Repair</div></li>';
		};	
		html +=	'<li class="ui-widget-header"><div>General</div></li>'
			+ '<li onclick="coloursChangeDialog()"><div>Colours</div></li>'
			+ '<li onclick="openChangeLog()"><div>FUIP News</div></li>';
		html += '</ul>';
		menu = $(html);
		menu.hover(() => 0, toggleConfigMenu);
	}else{
		menu = $('<ul id="fuip-menutoggle" data-fuip-state="closed" style="position:absolute;top:2px;left:2px;z-index:999;width:175px;text-align:left;"><li><div><span class="ui-icon ui-icon-triangle-1-e"></span>Menu</div></li></ul>');
		menu.hover(toggleConfigMenu, () => 0);
	};	
	menu.menu({
      items: "> :not(.ui-widget-header)"
    });
	$('#fuip-menutoggle').replaceWith(menu);
};	
	
	
function renderWhereUsedLists() {
	// this only works if we already have determined the local csrf token
	if(!fuip.csrf) {
		window.setTimeout(renderWhereUsedLists,10);
		return;
	};	
	$(".fuip-whereusedlist").each(function(){
		let container = $(this);
		if(container.attr("data-fuip-type") != "viewtemplate") return true;
		let templateid = container.attr("data-fuip-templateid");
		let name = $("html").attr("data-name");
		// call backend to retrieve where used list
		var cmd = "get " + name + " whereusedlist type=viewtemplate recursive=1 templateid=" + templateid;
		sendFhemCommandLocal(cmd).done(function(whereusedlistJson){
			let whereusedlist = json2object(whereusedlistJson);	
			let html = '<h3 style="text-align:left;margin-top:0;margin-bottom:0.3em;color:var(--fuip-color-symbol-active);">Where-used list</h3>';
			if(whereusedlist.length){
				html += '<ul>';	
				// the where-used-list comes back more detailed than we need
				// make sure that each page/viewtemplate is only shown once
				let shown = { pages: {}, viewtemplates: {} };	
				for(let i = 0; i < whereusedlist.length; i++) {
					// already shown?
					if(whereusedlist[i].type == "view" && shown.pages[whereusedlist[i].pageid] ||
						whereusedlist[i].type == "viewtemplate" && shown.viewtemplates[whereusedlist[i].templateid])
							continue;
					html += '<li style="list-style-type:circle;color:var(--fuip-color-symbol-active);">';
					switch(whereusedlist[i].type) {
						case "view":
							shown.pages[whereusedlist[i].pageid] = true;
							html += '<a href="/fhem/' + name.toLowerCase() + '/page/' + whereusedlist[i].pageid + '">Page ' 
									+ whereusedlist[i].pageid + '</a>';
							break;
						case "viewtemplate":
							shown.viewtemplates[whereusedlist[i].templateid] = true;
							html += '<a href="/fhem/' + name.toLowerCase() + '/fuip/viewtemplate?templateid=' 
								+ whereusedlist[i].templateid + '">View template ' + whereusedlist[i].templateid + '</a>';
							break;
						default: 
							html += 'Some object of type "' + whereusedlist[i].type + '"';
					};									
					html += '</li>';
				};	
				html += '</ul>';
			}else{	
				html += '<div>(not used)</div>';
			};	
			container.html(html);
		});	
	});	
};	
	

function callViewTemplateMaint() {
	let name = $("html").attr("data-name").toLowerCase();
	window.location.href = location.origin + "/fhem/" + name + "/fuip/viewtemplate";
};	


function viewTemplateDelete(name,templateid){
	let cmd = "set " + name + " delete type=viewtemplate templateid=" + templateid;	
	sendFhemCommandLocal(cmd).done(function(message) {
		if(message) {
			popupError("Cannot delete " + templateid,message);
			return;
		};
		window.location.replace(location.origin + "/fhem/" + name + "/fuip/viewtemplate");
	});	
};


async function viewTemplateRename(name,templateid){
	try{
		let targettemplateid = await dialogNewViewTemplateName({
					defaultName: templateid,
					title: "Enter new view template id"
				});
		await asyncSendFhemCommandLocal(
			"set " + name + " rename type=viewtemplate origintemplateid=" + templateid 
					+ " targettemplateid=" + targettemplateid
			);
		window.location.replace("/fhem/" + name.toLowerCase() +"/fuip/viewtemplate?templateid="+targettemplateid);
	}catch(e){}; // we can ignore this, usually only user input error 
};	
	

function gridDimensions() {
	// try to determine "smart" dimensions to have gridlines
	// with about 30 px distance, but have a gridline at the 
	// left border of each cell and at the lower border of the header
	// of each cell
	let cellSpacing = 2 * fuip.cellMargin;
	let nH = Math.round((fuip.baseHeight + cellSpacing) / 30.0);
	let nW = Math.round((fuip.baseWidth + cellSpacing) / 30.0);
	return { 
		gridHeight: (fuip.baseHeight + cellSpacing) / nH,
		gridWidth : (fuip.baseWidth + cellSpacing) / nW };
};	


function gridStart() {
	// determine coordinates of the first grid lines
	// returns { left: ..., top: ... }
	// get offset of maintained area
	let offset;
	if($("html").attr("data-fieldid")) {
		offset = $("#popupcontent").offset();
		offset.top += 16;
	}else if($("html").attr("data-viewtemplate")) {
		offset = $("#templatecontent").offset();
	}else {
		offset = {left: fuip.cellMargin, top: 22 + fuip.cellMargin};
	};	
	// move grid so that it fits offset	
	let dim = gridDimensions();
	return {left: offset.left % dim.gridWidth, top: offset.top % dim.gridHeight };
};	


function snapDimensions() {
	var dim = gridDimensions();
	if(fuip.snapTo == "halfGrid") {
		dim.gridWidth /= 2;
		dim.gridHeight /= 2;
	};	
	if(fuip.snapTo == "quarterGrid") {
		dim.gridWidth /= 4;
		dim.gridHeight /= 4;
	};	
	return dim;
};	
		
		
function drawGrid() {
	// determine grid width
	var dim = gridDimensions();
	var start = gridStart();
	// create canvas to draw on
	$("body").append('<canvas id="gridCanvas" width=' + $(document).width() + ' height=' + $(document).height() + ' style="position:absolute;top:0;left:0;z-index:99;pointer-events:none;"></canvas>');
	var canvas = document.getElementById("gridCanvas");
	var c = canvas.getContext("2d");
	c.setLineDash([1,4]);
	for(var x = start.left; x < $(document).width(); x += dim.gridWidth) {
		c.moveTo(x,0);
		c.lineTo(x,$(document).height() -1);
	};	
	for(var y = start.top; y < $(document).height(); y += dim.gridHeight) {
		c.moveTo(0,y);
		c.lineTo($(document).width() -1,y);
	};	
	c.strokeStyle = "LightGrey";
	c.lineWidth = 1;
	c.stroke();
};	
		

function getLocalCSrf() {
    $.ajax({
        'url': location.origin + '/fhem/',
        'type': 'GET',
        cache: false,
        data: {
            XHR: "1"
        },
        'success': function (data, textStatus, jqXHR) {
            fuip.csrf = jqXHR.getResponseHeader('X-FHEM-csrfToken');
			if(!fuip.csrf) fuip.csrf = "none";
        },
		error: function (jqXHR, textStatus, errorThrown) {
			console.log("FUIP: Failed to get csrfToken: " + textStatus + ": " + errorThrown);
			ftui.toast("FUIP: Failed to get csrfToken: " + textStatus + ": " + errorThrown,"error");
		}
    }); 
};
				

// when cell move/resize stops
function onGridsterChangeStop(e,ui,widget) {
	var s = JSON.stringify(fuipGridster.serialize()).replace(/\:/g, " => ");
	var name = $("html").attr("data-name");
	var pageId = $("html").attr("data-pageid");
	var cmd = '{FUIP::FW_setPositionsAndDimensions("' + name + '","' + pageId + '",' + s + ')}';
	sendFhemCommandLocal(cmd);
	// TODO: The following can be optimized by only calling resize() for the views where 
	// this makes sense. However, this is effort...
	$(window).trigger("resize");	
};	


// "serialize" the position and sizes 
function flexMaintSerialize(id,region,sizes) {
	var grid = $("#"+id);
	grid.children('[id^=fuip-flex-fake-]').each(function() {
		var area = flexMaintGetArea($(this));
		var i = parseInt($(this).children(':first').attr('data-cellid'));
		sizes[i] = {col: area.col_start,
					row: area.row_start,
					size_x: area.col_end - area.col_start,
					size_y: area.row_end - area.row_start,
					region: region};
	});
};
	

// the same for "flex"
function onFlexChangeStop() {
   /*#    'size_y' => 1,
    #    'col' => 1,
    #    'size_x' => 1,
    #    'row' => 1 
	region => menu/main */
	var sizes = [];
	flexMaintSerialize("fuip-flex-menu","menu",sizes);
	flexMaintSerialize("fuip-flex-title","title",sizes);
	flexMaintSerialize("fuip-flex-main","main",sizes);
	var s = JSON.stringify(sizes).replace(/\:/g, " => ");
	var name = $("html").attr("data-name");
	var pageId = $("html").attr("data-pageid");
	var cmd = '{FUIP::FW_setPositionsAndDimensions("' + name + '","' + pageId + '",' + s + ')}';
	sendFhemCommandLocal(cmd);		
};	
			

// when in the dialog (popup) or view template resizing was finished
function onResize(e,ui) { 
	let key = getKeyForCommand();
	if(!key) return;
	var cmd = "set " + $("html").attr("data-name") + " resize " + key + " width=" + ui.size.width + " height=" + ui.size.height; 
	asyncSendFhemCommandLocal(cmd);					
};		


// determine position and dimension of a grid item
function flexMaintGetArea(cell) {
	var area = cell.css(["grid-column-start","grid-column-end","grid-row-start","grid-row-end"]);	
	// convert to proper numbers (and convert to some nicer format
	var result = {col_start:parseInt(area["grid-column-start"]),row_start:parseInt(area["grid-row-start"])};
	// -end may come as "span x"
	var help = area["grid-column-end"].split(" ");
	if(help[0] == "span"){
		result.col_end = result.col_start + parseInt(help[1]);
	}else{
		result.col_end = parseInt(area["grid-column-end"]);
	};	
	help = area["grid-row-end"].split(" ");
	if(help[0] == "span"){
		result.row_end = result.row_start + parseInt(help[1]);
	}else{
		result.row_end = parseInt(area["grid-row-end"]);
	};	
	return result;
};	


// fix overlaps caused by item "cell"
// overlaps are fixed by moving down overlapping items
// so far, this is only for resizing, i.e. overlaps only occur to the right and the bottom
// TODO: make more general...
function flexMaintSolveOverlaps(cell) {
	// get position and size
	var area1 = flexMaintGetArea(cell);
	var id1 = cell.attr('id');
	// for all items in the grid
	cell.parent().children('[id^=fuip-flex-fake-]').each(function() {
		// not for the cell itself
		if($(this).attr('id') == id1) { return };
		var area2 = flexMaintGetArea($(this));
		// when we don't have an overlap...
		if(area1.col_start >= area2.col_end || area1.row_start >= area2.row_end
			|| area2.col_start >= area1.col_end || area2.row_start >= area1.row_end) {
			return;
		};
		// now we know that there is an overlap
		var moveDown = area1.row_end - area2.row_start;
		$(this).css({"grid-row-start":(area2.row_start + moveDown).toString(), "grid-row-end":(area2.row_end+moveDown).toString()});
		// now this might cause another overlap
		flexMaintSolveOverlaps($(this));	
	});	
};


// returns whether cell at (x,y) is free
// TODO: this is probably slow...
function flexMaintIsFree(grid,x,y) {
	return !flexMaintGetCellAt(grid,x,y);
};	


function flexMaintGetCellAt(grid,x,y) {
	var result;
	grid.children('[id^=fuip-flex-fake-]').each(function() {
		var area = flexMaintGetArea($(this));
		if(area.col_start <= x && x < area.col_end && area.row_start <= y && y < area.row_end) {
			result = $(this);
			return false;
		};	
	});	
	return result;
};	


function flexMaintMoveCellsUp(cell,includingMyself) {
	// cell is the cell which became smaller or moved up itself
	// we move all others, but not this one
	var id1 = cell.attr('id');
	var grid = cell.parent();
	// for all items in the grid
	grid.children('[id^=fuip-flex-fake-]').each(function() {
		// not for the cell itself
		if(!includingMyself && $(this).attr('id') == id1) { return };
		var area = flexMaintGetArea($(this));
		// we have a candidate now, but not clear yet whether we should move it up
		var newRowStart;
		for(newRowStart = area.row_start -1;newRowStart >= 1;newRowStart--){
			var x;
			for(x = area.col_start;x < area.col_end;x++) {
				if(!flexMaintIsFree(grid,x,newRowStart)) break;	
			};	
			if(x < area.col_end) break;
		};	
		newRowStart++;
		if(newRowStart == area.row_start) return;
		// ok, need to move to newRowStart
		$(this).css({"grid-row-start":newRowStart.toString(), 
					 "grid-row-end":(area.row_end - area.row_start + newRowStart).toString()});
		// and do the same recursively
		flexMaintMoveCellsUp($(this));	
	});
};	


function onFlexMaintResizeStart(e,ui) {
	// make "fake" element visible
	let fakeElem = ui.element.parent();
	fakeElem.css("background-color","");
	fakeElem.addClass("fuip-flex-fake");
};	


// flex maint: resize cell
function onFlexMaintResize(e,ui) {
	// do "gridster effect"
	// width = (baseWidth + 10) * sizeX - 10
	// sizeX = (width + 10) / (baseWidth + 10) 
	let cellSpacing = 2 * fuip.cellMargin;
	let width = ui.size.width;
	let height = ui.size.height;
	let sizeX = Math.floor((width + cellSpacing + 0.9 * fuip.baseWidth) / (fuip.baseWidth +cellSpacing));
	let fakeWidth = sizeX * (fuip.baseWidth + cellSpacing) - cellSpacing;
	let sizeY = Math.floor((height + cellSpacing + 0.9 * fuip.baseHeight) / (fuip.baseHeight + cellSpacing));
	let fakeHeight = sizeY * (fuip.baseHeight + cellSpacing) - cellSpacing;
	let fakeElem = ui.element.parent();
	fakeElem.width(fakeWidth).height(fakeHeight);
	// set new grid element size
	// ...but first store old size
	let oldArea = flexMaintGetArea(fakeElem);
	let oldSizeX = oldArea.col_end - oldArea.col_start;
	let oldSizeY = oldArea.row_end - oldArea.row_start;
	if(oldSizeY != sizeY || oldSizeX != sizeX) {	
		fakeElem.css({"grid-column-end":"span "+sizeX, "grid-row-end":"span "+sizeY});
		if(sizeY > oldSizeY  || sizeX > oldSizeX) {
			// now care for overlaps  TODO: later this might happen due to resizing in the menu part as well
			flexMaintSolveOverlaps(fakeElem);
		};
		// if (at least) one dimension became smaller, we might have to move up some cells
		if(sizeY < oldSizeY || sizeX < oldSizeX) {
			flexMaintMoveCellsUp(fakeElem);
		};	
	};
};	
			

function onFlexMaintResizeStop(e,ui) {
	// hide fake element
	let fakeElem = ui.element.parent();
	fakeElem.css("background-color","rgba(0,0,0,0)");
	fakeElem.removeClass("fuip-flex-fake");
	// correct size is the size of the preview
	ui.element.height(fakeElem.height());
	ui.element.width(fakeElem.width());
	// TODO: The following can be optimized by only calling resize() for the views where 
	// this makes sense. However, this is effort...
	$(window).trigger("resize");
	onFlexChangeStop();
};	


function onFlexMaintDragStart(e,ui) {
	if($("#fuip-flex-maint-drag").length) {
		$("#fuip-flex-maint-drag").css({top:ui.offset.top.toString()+'px', left:ui.offset.left.toString()+'px'});
	}else{	
		$("body").prepend('<div id="fuip-flex-maint-drag" style="position:absolute;top:'+ui.offset.top.toString()+'px;left:'+ui.offset.left.toString()+'px;"></div>');
	};
	$("#fuip-flex-maint-drag").prepend(ui.helper);
	var id = ui.helper.attr("id");
	id = id.replace("cell","fake"); 
	var fakeElem = $("#"+id);
	fakeElem.css("background-color","");
	fakeElem.addClass("fuip-flex-fake");
	fuip.drag_start_area = flexMaintGetArea(fakeElem);
	fuip.drag_start_region = fakeElem.parent().attr("id");
	fuip.drag_colzero = 0;
	fuip.drag_rowzero = 0;
};	


function flexMaintGetMaxCol(grid) {
	var result = 0;
	grid.children('[id^=fuip-flex-fake-]').each(function() {
		var area = flexMaintGetArea($(this));
		if(result < area.col_end-1) result = area.col_end-1;
	});
	return result;
};	


function flexMaintGetMaxRow(grid) {
	var result = 0;
	grid.children('[id^=fuip-flex-fake-]').each(function() {
		var area = flexMaintGetArea($(this));
		if(result < area.row_end-1) result = area.row_end-1;
	});
	return result;
};	


function onFlexMaintDrag(e,ui) {
	// ui.position: relative to parent
	// ui.offset: relative to page
	let id = ui.helper.attr("id");
	id = id.replace("cell","fake"); 
	let fakeElem = $("#"+id);
	let area = fuip.drag_start_area;
	let cellSpacing = 2 * fuip.cellMargin;
	// move by 1 cell if moved by 50% of the baseWidth/Height
	let moveX = Math.round(ui.position.left / (fuip.baseWidth + cellSpacing));
	let moveY = Math.round(ui.position.top  / (fuip.baseHeight + cellSpacing));
	let region = fakeElem.parent().attr("id");
	if(region == "fuip-flex-main") {
		if(area.col_start + moveX + fuip.drag_colzero < 1){
			// "main" -> "menu"
			// remember which column we came in
			if(fuip.drag_start_region == "fuip-flex-menu") {
				fuip.drag_colzero = 0;
			}else{	
				fuip.drag_colzero = flexMaintGetMaxCol($("#fuip-flex-menu"));
			};
			$("#fuip-flex-menu").append(fakeElem);
			flexMaintMoveCellsUp($("#fuip-flex-main").children(":first"),true);
		}else if(area.row_start + moveY + fuip.drag_rowzero < 1){
			// "main" -> "title"
			// remember which row we came in
			if(fuip.drag_start_region == "fuip-flex-title") {
				fuip.drag_rowzero = 0;
			}else{
				// +1 at the end to avoid that it immediately swaps places with the first row	
				fuip.drag_rowzero = flexMaintGetMaxRow($("#fuip-flex-title")) +1;
			};
			$("#fuip-flex-title").append(fakeElem);
			flexMaintMoveCellsUp($("#fuip-flex-main").children(":first"),true);
		};	
	};
	if(region == "fuip-flex-menu") {
		// care for "moving out to the right"
		// we move out if otherwise, we'd have a completely free column 
		var moveIt = false;
		if(area.col_end + moveX + fuip.drag_colzero -1 > flexMaintGetMaxCol($("#fuip-flex-menu"))) {
			moveIt = true;
			var maxRow = flexMaintGetMaxRow($("#fuip-flex-menu"));		
			for(var r = 1;r <= maxRow;r++) {
				var cell = flexMaintGetCellAt($("#fuip-flex-menu"),area.col_start + moveX + fuip.drag_colzero -1,r);
				if(!cell) continue;
				if(cell.attr("id") == id) continue;
				moveIt = false;
				break;
			};
		};
		if(moveIt) {
			// if it starts in a "title row", then move to the title region, otherwise main
			var maxTitleRow = flexMaintGetMaxRow($("#fuip-flex-title"));
			if(area.row_start + moveY + fuip.drag_rowzero <= maxTitleRow) {
				// menu -> title
				$("#fuip-flex-title").append(fakeElem);		
				if(fuip.drag_start_region == "fuip-flex-menu") {
					fuip.drag_colzero = -1 - flexMaintGetMaxCol($("#fuip-flex-menu"));
				}else{
					fuip.drag_colzero = 0;
				};
			}else{			
				// menu -> main
				$("#fuip-flex-main").append(fakeElem);
				if(fuip.drag_start_region == "fuip-flex-title") {
					fuip.drag_colzero = 0;	
					fuip.drag_rowzero = -1 - flexMaintGetMaxRow($("#fuip-flex-title"));
				}else if(fuip.drag_start_region == "fuip-flex-main") {
					fuip.drag_colzero = 0;
					fuip.drag_rowzero = 0;	
				}else{  // we came from menu
					fuip.drag_colzero = -1 - flexMaintGetMaxCol($("#fuip-flex-menu"));
					fuip.drag_rowzero = -1 - flexMaintGetMaxRow($("#fuip-flex-title"));
				};
			};	
			flexMaintMoveCellsUp($("#fuip-flex-menu").children(":first"),true);
		};			
	};	
	if(region == "fuip-flex-title") {
		if(area.col_start + moveX + fuip.drag_colzero < 1){
			// "title" -> "menu"
			// remember which column we came in
			if(fuip.drag_start_region == "fuip-flex-menu") {
				fuip.drag_colzero = 0;
			}else{	
				fuip.drag_colzero = flexMaintGetMaxCol($("#fuip-flex-menu"));
			};
			$("#fuip-flex-menu").append(fakeElem);
			flexMaintMoveCellsUp($("#fuip-flex-title").children(":first"),true);
		}else if(area.row_start + moveY + fuip.drag_rowzero > flexMaintGetMaxRow($("#fuip-flex-title")) + 1){
			// "title" -> "main"
			// (we move out if otherwise, we'd have a completely free row) 
			$("#fuip-flex-main").append(fakeElem);		
			if(fuip.drag_start_region == "fuip-flex-main") {
				fuip.drag_rowzero = 0;
			}else{	
				fuip.drag_rowzero = -1 - flexMaintGetMaxRow($("#fuip-flex-title"));
			};	
		};			
	};	
	if(area.col_start + moveX  + fuip.drag_colzero < 1){
		moveX = 1 - area.col_start - fuip.drag_colzero;
	};
	if(area.row_start + moveY + fuip.drag_rowzero < 1){
		moveY = 1 - area.row_start - fuip.drag_rowzero;  
	};	
	// if we started in "main", but current is "menu", fuip.drag_colzero needs to be added 
	fakeElem.css({"grid-column-start":(area.col_start + moveX + fuip.drag_colzero).toString(),
					"grid-column-end":(area.col_end + moveX + fuip.drag_colzero).toString(),
					"grid-row-start":(area.row_start + moveY + fuip.drag_rowzero).toString(),
					"grid-row-end":(area.row_end + moveY + fuip.drag_rowzero).toString()});
	// now move overlapping cells out of the way	
	flexMaintSolveOverlaps(fakeElem);
	// and move others up again
	flexMaintMoveCellsUp(fakeElem,true);
};


function onFlexMaintDragStop(e,ui) {
	var id = ui.helper.attr("id");
	id = id.replace("cell","fake"); 
	var fakeElem = $("#"+id);
	fakeElem.css("background-color","rgba(0,0,0,0)");
	fakeElem.removeClass("fuip-flex-fake");
	fakeElem.prepend(ui.helper);
	ui.helper.css({top:0,left:0});
	fuip.drag_colzero = 0;
	onFlexChangeStop();
};	

			
// when a view is dropped on a cell
async function onDragStop(cell,ui) {
	let type = 'cell';
	let view = ui.draggable;
	let newCellId;
	if($("html").attr("data-fieldid")) {
		type = 'dialog';
	}else if($("html").attr("data-viewtemplate")) {
		type = 'viewtemplate';
	}else{
		newCellId = cell.attr("data-cellid");
		let oldCellId = view.closest("[data-cellid]").attr("data-cellid");
		if(newCellId != oldCellId) 
			type = 'cellmove';
	};
	let cmd = 'set ' + $("html").attr("data-name") + ' position ';
	switch(type) {
		case 'cellmove':
			cmd += 'newcellid="' + newCellId + '" ';
			let oldCellPos = view.closest("[data-cellid]").offset();
			let newCellPos = cell.offset();
			cmd += 'x=' + (ui.position.left + oldCellPos.left - newCellPos.left) 
					+ ' y=' + (ui.position.top + oldCellPos.top - newCellPos.top - 22);
			break;		
		case 'viewtemplate':
			cmd += 'x=' + ui.position.left + ' y=' + ui.position.top;
			break;
		default:
			cmd += 'x=' + ui.position.left + ' y=' + (ui.position.top-22);
	};	
	// attach the key at the end (unusual, but does not matter)
	cmd += ' ' + getViewKeyForCommand(view);
	// TODO: error handling when sending command
	await asyncSendFhemCommandLocal(cmd);
	location.reload(true);
};
							

function getViewKeyForCommand(view) {
	let result = 'type=view ';
	let templateid = $("html").attr("data-viewtemplate");
	if(templateid) {
		// view template
		result += 'templateid="' + templateid + '" ';
	}else{
		// normal cell
		let cell = view.closest("[data-cellid]");
		result += 'pageid="' + $("html").attr("data-pageid") + '" cellid="' + cell.attr("data-cellid") + '" ';
	};		
	let fieldid = $("html").attr("data-fieldid");
	if(fieldid) { 
		// dialog
		result += 'fieldid="' + fieldid + '" ';
	};
	let viewid = view.attr("data-viewid");
	result += 'viewid="' + viewid + '"';
	return result;
};


// when a view resize finished
function onViewResizeStop(event,ui) {
	let view = ui.originalElement;
	let cmd = "set " + $("html").attr("data-name") + " resize " + getViewKeyForCommand(view);
	cmd += ' width=' + ui.size.width + ' height=' + ui.size.height;
	asyncSendFhemCommandLocal(cmd);
};


// show dialog with an error text 
// text can be almost arbitrary html
function popupError(title,text,onClose) {
	var popup = $("<div>"+text+"</div>");
	var buttons = [{
			text: "Ok",
			icon: "ui-icon-check",
			click: function() { popup.dialog("close"); },
			showLabel: false
		}];
	let settings = {
			title: title,
			modal: true,
			buttons: buttons,
			classes: { "ui-dialog-titlebar": "ui-state-error" }
		};
	if(onClose) settings.close = onClose;	
	popup.dialog(settings);
};	


function sendFhemCommandLocal(cmdline) {
	cmdline = cmdline.replace('  ', ' ');
	return $.ajax({
		async: true,
		cache: false,
		method: 'GET',
		dataType: 'text',
		url: location.origin + '/fhem/',
		// username: ftui.config.username,
		// password: ftui.config.password,
		data: {
			cmd: cmdline,
			fwcsrf: fuip.csrf,
			XHR: "1"
		},
		error: function (jqXHR, textStatus, errorThrown) {
				console.log("FUIP command: " + cmdline);
				console.log("FUIP: Local FHEM command failed: " + jqXHR.status + " " + textStatus + " " + errorThrown);
				ftui.toast("FUIP: Local FHEM command failed: " + jqXHR.status + " " + textStatus + " " + errorThrown,"error");
		}
	});
};


async function asyncSendFhemCommandLocal(cmdline) {
	return new Promise(function(resolve,reject) {
		cmdline = cmdline.replace('  ', ' ');
		$.ajax({
			async: true,
			cache: false,
			method: 'GET',
			dataType: 'text',
			url: location.origin + '/fhem/',
			// username: ftui.config.username,
			// password: ftui.config.password,
			data: {
				cmd: cmdline,
				fwcsrf: fuip.csrf,
				XHR: "1"
			},
			error: function (jqXHR, textStatus, errorThrown) {
					console.log("FUIP command: " + cmdline);
					console.log("FUIP: Local FHEM command failed: " + jqXHR.status + " " + textStatus + " " + errorThrown);
					ftui.toast("FUIP: Local FHEM command failed: " + jqXHR.status + " " + textStatus + " " + errorThrown,"error");
					reject(new Error("FUIP: Local FHEM command failed: " + jqXHR.status + " " + textStatus + " " + errorThrown));
			}
		}).done((result) => { 
				// set-commands should not return a result, otherwise we have an error
				if(cmdline.startsWith("set ") && result.length > 0) {
					popupError("FHEM error", result);
					reject(new Error("FHEM says: " + result));
				}else{	
					resolve(result);
				};		
			});
	});
};


async function asyncPostImportCommand(content,type,pageid) {
	return new Promise(function(resolve,reject) {
		let data = encodeURIComponent(content);
		let url = location.origin + '/fhem/' + $("html").attr("data-name").toLowerCase() + '/fuip/import?type='+type;
		if(type != "viewtemplate") {
			url += '&pageid=' + pageid;
		};	
		if(type == "cell" || type == "dialog") { 
			url += '&cellid=' + $("#viewsettings").attr("data-viewid");
		};	
		if(type == "dialog") {
			url += '&fieldid=' + $("#viewsettings").attr("data-fieldid");		
		};	
		$.ajax({
			async: true,
			cache: false,
			method: 'POST',
			dataType: 'text',
			url: url,
			data: 'content=' + data,
			error: function (jqXHR, textStatus, errorThrown) {
				console.log("FUIP: File import failed: " + jqXHR.status + " " + textStatus + ": " + errorThrown);
				ftui.toast("FUIP: File import failed: " + jqXHR.status + " " + textStatus + ": " + errorThrown,"error");
				reject(new Error("FUIP: File import failed: " + jqXHR.status + " " + textStatus + " " + errorThrown));
			}
		}).done(resolve);
	});	
};
					
					
async function autoArrange() {
	let name = $("html").attr("data-name");
	let key = getKeyForCommand();
	if(!key) return;  // error message has already been sent
	let cmd = "set " + name + " autoarrange " + key;  
	await asyncSendFhemCommandLocal(cmd);
	location.reload(true);
};
	

function collectFieldValues(settingsDialog) {
	// collect all field values "in" settingsDialog
	let result = {};
	settingsDialog.find("input, textarea, select.fuip").each(function() {
		// do not process hidden elements
		if($(this).css("visibility") == "hidden") 
			return true;
		var value;
		if($(this).attr("type") == "checkbox") {
			result[$(this).attr("id")] = ($(this).is(":checked") ? "1" : "0");
		}else{	
			result[$(this).attr("id")] = $(this).val();
		};	
	});
	return result;
};


function validateField(id) {
// check whether field "id" has a valid content
// returns true if ok
// otherwise, issues a message to the user and returns false
// currently checks only variables of view templates
	if(!/-variable$/.test(id)) return true;
	let value = $('#'+id).val();
	if(!/^[_a-zA-Z][_a-zA-Z0-9]*$/.test(value)){
		popupError('Variable name invalid', 'The variable name "'+value+'" is invalid. You can only use letters (a..b,A..B), numbers (0..9) and the underscore (_). The first character can only be a letter or the underscore. Whitespace (blanks) cannot be used.<p>You have to change the variable name.'); 
		return false;
	};
	if(/^(class|defaulted|flexfields|height|id|sizing|templateid|title|variable|variables|views|width)$/.test(value)){
		popupError('Variable name is reserved', 'The variable name "'+value+'" is reserved for FUIP itself. Reserved names are "class", "defaulted", "flexfields", "height", "id", "sizing", "templateid", "title", "variable", "variables", "views" and "width".<p>You have to change the variable name.');
		return false;
	};	
	return true;
};	
	
					
async function acceptSettings(doneFunc) {
// accept changes on config popup 
// doneFunc: this is called on (more or less) successful change
//           This way, e.g. the settings can be "saved" before something else is done. 
//           If this is not used, the page is reloaded.
	var cmd = '';
	// collect sort orders of viewarrays
	$('.ui-accordion').each(function() {
		cmd += ' ' + $(this).attr('id').slice(0,-10) + '=';
		var sortstr = 0;
		$(this).children().each(function() {
			if(sortstr) {
				sortstr += ',';
			}else{	
				sortstr = '';
			};
			var parts = $(this).attr('id').split('-');
			sortstr += parts[parts.length -1];	
		});
		if(sortstr) {
			cmd += sortstr;
		};	
	});
	// collect inputs and checkboxes
	let flexfields = {};
	let allFieldsOk = true;
	$("#viewsettings input, #viewsettings textarea, #viewsettings select.fuip").each(function() {
		// do not process hidden elements
		if($(this).css("visibility") == "hidden") 
			return true;
		// field validation
		allFieldsOk = validateField($(this).attr("id"));
		if(!allFieldsOk) return false;  // leave .each
		var value;
		if($(this).attr("type") == "checkbox") {
			value = ($(this).is(":checked") ? 1 : 0);
		}else{	
			value = $(this).val();
			value = encodeURIComponent(value);
		};	
		value = '"' + value + '"'; 
		cmd += " " + $(this).attr("id") + "=" + value;
		// is this a flex field?
		if($(this).attr("data-flexfield") == "1") {
			let id = $(this).attr('id');
			let parts = id.split('-');
			let name = parts.pop();
			let flexfieldsId = parts.join('-') + '-flexfields';
			if(flexfields.hasOwnProperty(flexfieldsId)) {
				flexfields[flexfieldsId] += ',' + name;
			}else{
				flexfields[flexfieldsId] = name;
			};
			// flex field attributes
			for (let attribute of ["type", "default-type", "default-value", "default-suffix"]) {
				let val = $(this).attr("fuip-" + attribute);
				if(typeof val !== "undefined") cmd += ' ' + id + '-' + attribute + '="' + val + '"';	
			};
			for (let attribute of ["refdevice", "refset", "options"]) {
				let val = $(this).attr("data-" + attribute);
				if(typeof val !== "undefined") cmd += ' ' + id + '-' + attribute + '="' + val + '"';	
			};
			let val = $(this).attr("data-options");
			if(typeof val !== "undefined"){
				val = json2object(val);
				cmd += ' ' + id + '-options="' + val.join(',') + '"';	
			};	
		};	
	});
	// return if there is an issue with a field
	// this should also make sure that the config popup stays open
	if(!allFieldsOk) return;
	// add flex field lists
	for (const id of Object.keys(flexfields)) {
		cmd += ' ' + id + '="' + flexfields[id] + '"';
	};

	let key = getKeyForCommand();
	if(!key) return;
	cmd = "set " + $("html").attr("data-name") + " settings " + key + " " + cmd;
	await asyncSendFhemCommandLocal(cmd);
	if(doneFunc) {
		doneFunc();
	}else{	
		location.reload(true);
	};	
};


function getKeyForCommand(prefix) {
	// create key-part of command 
	if(!prefix) {
		prefix = "";
	};	
	let type = $("#viewsettings").attr("data-mode");
	if(!type) {
		if($("html").attr("data-fieldid")) {
			type = "dialog";
		}else if($("html").attr("data-viewtemplate")) {
			type = "viewtemplate";
		};	
	};	
	let obj = {};
	switch(type) {
		case "cell":
			obj.pageid = $("html").attr("data-pageid");
			obj.cellid = $("#viewsettings").attr("data-viewid");
			break;
		case "dialog":
			if($("html").attr("data-pageid")) {
				obj.pageid = $("html").attr("data-pageid");
				obj.cellid = $("html").attr("data-cellid");
			}else{
				obj.templateid = $("html").attr("data-viewtemplate");
			};	
			obj.fieldid = $("html").attr("data-fieldid");
			break;
		case "viewtemplate":
			obj.templateid = $("html").attr("data-viewtemplate");
			break;
		default:
			console.log("FUIP: getKeyForCommand failed: unknown type");
			ftui.toast("FUIP: getKeyForCommand failed: unknown type","error");
			return false;
	};	
	let result = prefix + "type=" + type + " ";
	for(const key of Object.keys(obj)) {
		result += ' ' + prefix + key + '="' + obj[key] + '"';
	};	
	return result;
};	


function acceptPageSettings(doneFunc) {
	var cmd = '';
	// collect inputs and checkboxes
	$("#viewsettings input").each(function() {
		var value;
		if($(this).attr("type") == "checkbox") {
			value = ($(this).is(":checked") ? 1 : 0);
		}else{	
			value = $(this).val();
			value = value.replace(/;/g , ";;");
		};	
		value = '"' + value + '"'; 
		cmd += " " + $(this).attr("id") + "=" + value;
	});
	var name = $("html").attr("data-name");
	var pageId = $("html").attr("data-pageid");
	cmd = "set " + name + " pagesettings " + pageId + cmd; 
	// TODO: error handling when sending command
	sendFhemCommandLocal(cmd).done(function () {
		if(doneFunc) {
			doneFunc();
		}else{	
			location.reload(true);
		};	
	});	
};


function viewAddNew() {
	var name = $("html").attr("data-name");
	var pageId = $("html").attr("data-pageid");
	var viewId = $("#viewsettings").attr("data-viewid");	
	var region = "";
	if($("html").attr("data-layout") == "flex") {
		region = $("#fuip-flex-fake-" + viewId).parent().attr("id");
		region = region.replace("fuip-flex-","");
	};	
	cmd = "set " + name + " viewaddnew " + pageId + " " + region; 
	// TODO: error handling when sending command
	sendFhemCommandLocal(cmd).done(function () {
		$("#viewsettings").dialog( "close" );
		location.reload(true);
	});	
};
					

function viewAddKnownToArray(arrayName,viewSettings,title) {
	// get the accordion element
	var accordion = $('#'+arrayName+'-accordion');
	// get the number of views and the next index
	var length = parseInt(accordion.attr('data-length'));
	var nextindex = parseInt(accordion.attr('data-nextindex'));
	var elemName = arrayName + '-' + nextindex;
	var html = '<div class="group" id="' + elemName + '"><h3>';
	html += 'New ' + title + '</h3><div>' + createSettingsTable(viewSettings, elemName + '-') + '</div>';
	accordion.append(html);
	accordion.attr('data-length',length+1);
	accordion.attr('data-nextindex',nextindex+1);
	accordion.accordion('refresh');
	accordion.accordion('option','active',length);
};	
					
					
function viewAddNewToArray(arrayName) {
	// get default empty view
	var name = $("html").attr("data-name");
	var cmd = "get " + name + " viewdefaults FUIP::View";
	sendFhemCommandLocal(cmd)
	.done(function(settingsJson){
		viewAddKnownToArray(arrayName,json2object(settingsJson), 'empty view');
	});
};


function viewAddNewByDevice(arrayName) {
	// callback for value help 
	var processDevices = function(devices) {
		if(devices.length == 0) { return; };
		var name = $("html").attr("data-name");
		var cmd = "get " + name + " viewsByDevices " + devices.join(' ');
		sendFhemCommandLocal(cmd)
			.done(function(settingsJson){
				var views = json2object(settingsJson);
				for(var i = 0; i < views.length; i++) {
					var title = '';
					for(var j = 0; j < views[i].length; j++) {
						if(views[i][j].id == 'title') {
							title = views[i][j].value;
							break;
						};								
					};
					viewAddKnownToArray(arrayName,views[i],title);
				};
			});
	};	
	// bring up list of devices
	valueHelpForDevice(arrayName, processDevices, true);
};	
					
					
function viewDeleteFromArray(viewName) {
    var toDelete = $('#'+viewName);
	var accordion = toDelete.parent();
	// nextindex stays the same, just subtract length
	var length = parseInt(accordion.attr('data-length'));
	toDelete.remove();
	accordion.attr('data-length',length-1);
	accordion.accordion('refresh');
};

					
function deleteCell() {
	var cmd = "";
	var name = $("html").attr("data-name");
	var pageId = $("html").attr("data-pageid");
	var viewId = $("#viewsettings").attr("data-viewid");	
	cmd = "set " + name + " viewdelete " + pageId + "_" + viewId; 
	// TODO: error handling when sending command
	sendFhemCommandLocal(cmd).done(function () {
		$("#viewsettings").dialog( "close" );
		location.reload(true);
	});	
};
					
					
function inputChanged(inputElem,influencedFields) {
	for(var i = 0; i < influencedFields.length; i++) {
		// default or own value?
		if($('#' + influencedFields[i] + '-check').is(':checked')) { continue; };
		// default, set default value
		$('#' + influencedFields[i] + '-check').trigger("change");
	};
};
					
					
function defaultCheckChanged(id,defaultDef,fieldType) {
	var inputField = $("#" + id);
	if($("#" + id + "-check").is(":checked")) {
		if(fieldType == "dialog") {
			$(function() {
				$('#' + id).button({
					icon: 'ui-icon-pencil',
					showLabel: true
				});		
			});
			inputField.replaceWith("<button id='" + id + "' type='button' " +
				"onclick='acceptSettings(function() { callPopupMaint(\""+id+"\");})'" +
				">Configure popup</button>");
			return;		
		};	
		inputField.attr("style", "visibility: visible;");
		inputField.removeAttr("readonly");
		inputField.removeAttr("disabled");
		// value help visible
		$('#'+id+'-value').css("visibility","visible");
	}else{
		if(fieldType == "dialog") {
			inputField.replaceWith(
				"<input type='text' name='" + id + "' id='" + id + "' " +
				"value='" + defaultDef.value + "' " +
				"style='visibility: visible;background-color:#EBEBE4;' " +
				"readonly=readonly " + 
				">");
			return;	
		};		
		inputField.attr("style", "visibility: visible;background-color:#EBEBE4;");
		inputField.attr("readonly", "readonly");
		if(inputField.is("select")) {
			inputField.attr("disabled","disabled");
		};	
		// value help invisible
		$('#'+id+'-value').css("visibility","hidden");
		switch(defaultDef.type) {
			case 'const':
				inputField.val(defaultDef.value);
				inputField.trigger("input");
				break;
			case 'field':
				var value = $("#" + defaultDef.value).val();
				if(defaultDef.hasOwnProperty("suffix")) {
					value += defaultDef.suffix;
				};	
				inputField.val(value);
				inputField.trigger("input");
				break;
			default:
				break;
		};
	};
}


function varCheckChanged(id) {
	if($("#" + id + "-varcheck").is(":checked")) {
		$("#" + id + "-variable").css("visibility","visible");
	}else{
		$("#" + id + "-variable").css("visibility","hidden");
	};	
}


function sizingChanged(id,widthId,heightId) {
	if($("#" + id).val() == 'resizable') {
		$("#" + widthId).css("visibility","visible");
		$("#" + heightId).css("visibility","visible");
		$("#" + id + "-x").css("visibility","visible");
	}else{
		$("#" + widthId).css("visibility","hidden");
		$("#" + heightId).css("visibility","hidden");
		$("#" + id + "-x").css("visibility","hidden");
	};	
}

					
function getInfluencedParts(field,parentName,myName) {
	// returns the influenced parts of field
	var fType = 'text';
	if(field.hasOwnProperty('type')) { fType = field.type; }; 		
	switch(fType) {
		case 'device-reading':
			return getInfluencedParts(field.device,parentName,myName + '-device').concat(getInfluencedParts(field.reading,parentName,myName + '-reading'));
		default:
			if(!field.hasOwnProperty("default")) { return []; };
			if(field.default.type == "const") { return []; };
			if(field.default.value != parentName) { return []; };
			return [ myName ];
	};
};
		

function classChangedCopyOldValue(field,oldValues,fieldName) {
	// only if the field exists in the old values
	if(! oldValues.hasOwnProperty(fieldName)) return;
	// if the field has a default and this was selected, 
	// we also take the default of the new (if it has a default as well)
	if(oldValues.hasOwnProperty(fieldName + '-check')
		&& field.hasOwnProperty('default')) {
		if(oldValues[fieldName + '-check'] == "0") {
			return;  // i.e. keep default
		};	
	};		
	field.value = oldValues[fieldName];
	if(field.hasOwnProperty('default')) {
		field.default.used = "0";
	};		
};	
		
					
// classField is the field (input) with the new class name
function classChanged(classField) {
	var elemName = classField.id.slice(0,-6);
	var settingsDialog = $( '#' + elemName );
	// get old values
	let oldValues = collectFieldValues(settingsDialog);
	settingsDialog.html('Just a moment...');
	var name = $("html").attr("data-name");
	var cmd = "get " + name + " viewdefaults " + classField.value;
	sendFhemCommandLocal(cmd).done(function(settingsJson){
		// copy old values into new view type, if possible
		let settings = json2object(settingsJson);
		for(let i = 0; i < settings.length; i++) {
			// not for the class name obviously
			if(settings[i].id == 'class') continue;
			let fieldName = elemName + '-' + settings[i].id;
			if(settings[i].type == "device-reading") {
				classChangedCopyOldValue(settings[i].device,oldValues,fieldName + '-device');
				classChangedCopyOldValue(settings[i].reading,oldValues,fieldName + '-reading');
			}else{
				classChangedCopyOldValue(settings[i],oldValues,fieldName);
			};	
		};
		var html = '<h3>';
		var title = 'New ' + classField.value;
		html += title + '</h3><div>' + createSettingsTable(settings, elemName + '-') + '</div>';
		settingsDialog.html(html);
		var accordion = settingsDialog.parent();
		var active = accordion.accordion('option','active');
		accordion.accordion('refresh');
		accordion.accordion('option','active',active);
	});	
};
					
					
function createClassField(selectedClass,prefix) {
	var fieldName = prefix + 'class';
	// make the value help button a JQuery button
	/*$(function() {
		$('#' + fieldName + '-value').button({
			icon: 'ui-icon-triangle-1-s',
			showLabel: false
		});		
	});	*/	
	return "<tr>" +
			"<td style='text-align:left;'><label for='" + fieldName + "'>View type</label></td>" +  
			"<td style='text-align:left;'><input type='checkbox' style='visibility:hidden;'><input type='text'" +
			" name='" + fieldName + "' id='" + fieldName + "' " +
			"style='visibility:visible;background-color:#EBEBE4;' readonly " +
			"value='" + selectedClass + "' " +
			"oninput='classChanged(this)' >" +
			// "<button id='" + fieldName + "-value' onclick='valueHelp(\""+fieldName+"\",\"class\")' type='button' style='padding:5px 0px 0px 0px;'>Possible values</button>" 
			'<span class="ui-icon ui-icon-triangle-1-s" onclick="valueHelp(\''+fieldName+'\',\'class\')" title="Possible values" style="background-color:#F6F6F6;border: 1px solid #c5c5c5;color:#454545"></span>' 
			+ "</td>" +
			"</tr>";		
};
	
	
function getIcons() {
	//if(document.styleSheets.length == 0) {
	//	window.setTimeout(getIcons,1000);
	//	return;
	//};
	var currentSheet = null;
	var i = 0;
	var j = 0;
	var ruleKey = null;
	//loop through styleSheet(s)
	var allIcons = {};
	for(i = 0; i<document.styleSheets.length; i++){
		currentSheet = document.styleSheets[i];
		//loop through css Rules
		try{
			for(j = 0; j< currentSheet.cssRules.length; j++){
				if(!currentSheet.cssRules[j].selectorText) { continue; };
				var selectors = currentSheet.cssRules[j].selectorText.split(",");
				var key = false;
				for(var k = 0; k < selectors.length; k++) {
					var icons = selectors[k].match(/\.(fa|ftui|mi|oa|wi|fs|nesges)-.*(?=::before)/);
					if(!icons){ continue; };
					var icon = icons[0].substring(1);
					// sometimes there is another class...
					icon = icon.split(" ")[0];
					if(!key) {
						key = icon;
						allIcons[key] = {};
					};	
					allIcons[key][icon] = 1;
				}
			}
		}catch(e) {
			// this can happen if a style sheet comes from "elsewhere"
			// however, in this case it probably does not contain any icons
			// which we have to display
		}	
	}
	var result = [];
	Object.keys(allIcons).sort().forEach(function(key) {
		if(allIcons.hasOwnProperty(key)) {
			var names = false;
			Object.keys(allIcons[key]).sort().forEach(function(name) {
				if(allIcons.hasOwnProperty(key)) {
					if(names) {
						names += ", " + name;
					}else{
						names = name;
					};
				};
			});	
			var prefix = key.split("-")[0];
			if(prefix == "wi") {
				key = "wi " + key;
			};	
			result.push({key:key,names:names});
		}
	});
	return result;
};
	
	
function createValueHelpDialog(okFunction) {
	var valuehelp;	
	valuehelp = $( "#valuehelp" ).dialog({
		autoOpen: false,
		width: 420,
		height: 260,
		modal: true,
		buttons: [{
			text: 'Ok',
			icon: 'ui-icon-check',
			click: okFunction,
			showLabel: false },
		  { text: 'Cancel',
			icon: 'ui-icon-close',
			click: function() {	valuehelp.dialog( "close" ); },
			showLabel: false }
		],
	});
};	


// value help: Filter for room
// e: value in row to check
// f: current filter value
function valueHelpFilterRoom(e, n, f, i, $r, c, data) { 
	return (e.split(",").indexOf(f) >= 0);
};
	

// determine full reference field name (e.g. from refdevice for field type set)	
function getFullRefName(fieldname,reftype) {	
	var shortRefName = $('#'+fieldname).attr("data-"+reftype);  // this is the short name
	if(!shortRefName) { return false; };
	var nameArray = fieldname.split("-").slice(0,-1);
	nameArray.push(shortRefName);
	return nameArray.join("-");
};
	
	
async function valueHelp(fieldName,type) {
	// device help has its own function
	if(type == "device" || type == "devices" || type == "device-reading" && fieldName.match(/-device$/) ) {
		valueHelpForDevice(fieldName, 
			function(value) {
				$('#'+fieldName).val(value);
				$('#'+fieldName).trigger("input");
			},(type == "devices"));
		return;
	};	
	// setoptions
	if(type == "setoptions") {
		valueHelpForOptions(fieldName,
			function(selected) {
				$('#'+fieldName).val(selected);
				$('#'+fieldName).trigger("input");
			},true);	
		return;	
	};	
	// setoption (single)
	if(type == "setoption") {
		valueHelpForOptions(fieldName,
			function(selected) {
				$('#'+fieldName).val(selected);
				$('#'+fieldName).trigger("input");
			},false);	
		return;	
	};	
	// all others
	var name = $("html").attr("data-name");
	createValueHelpDialog(function(){
		var selected = $('#valuehelptable').attr('data-selected');
		if(!selected) { return; };
		var value = $('#'+selected).attr('data-key');
		$('#'+fieldName).val(value);
		$('#'+fieldName).trigger("input");
		$( "#valuehelp" ).dialog("close");
	});
	var valueDialog = $( "#valuehelp" );
	valueDialog.dialog("option","title","Possible values for " + fieldName); 
	valueDialog.html("Please wait...");
	valueDialog.dialog("open");

	// put select-only-one mechanism
    var registerClicked = function() {		 
		$( "#valuehelptable tbody tr" ).on( "click", function() {
			var oldSelected = $('#valuehelptable').attr('data-selected');
			if(oldSelected.length) {
				$('#'+oldSelected).children("td").removeAttr("style"); 	
			};	
			$('#valuehelptable').attr('data-selected',$(this).attr('id'));
			$(this).children("td").attr("style", "background:#F39814;color:black;");
		});
	};

	if(type == "device-reading" && fieldName.match(/-reading$/) || type == "reading") {
		var deviceFieldName;
		if(type == "reading") {
			deviceFieldName = getFullRefName(fieldName,"refdevice");
		}else{
			deviceFieldName = fieldName.replace(/-reading$/,"-device");
		};	
		var device = $('#'+deviceFieldName).val();
		var cmd = "get " + name + " readingslist " + device;
		sendFhemCommandLocal(cmd).done(function(readingsListJson){
			var readingsList = json2object(readingsListJson);
			var valueDialog = $( "#valuehelp" );
			var html = "<table id='valuehelptable' data-selected=''><tr><th>Name</th></tr>";
			for(var i = 0; i < readingsList.length; i++){
				html += "<tr id='valuehelp-row-"+i+"' data-key='"+readingsList[i]+"'><td>"+readingsList[i]+"</td></tr>";
			};
			html += "</table>";
			valueDialog.html(html);
			registerClicked();
		});
	}else if(type == "set") {	
	    var refdeviceFullName = getFullRefName(fieldName,"refdevice");
		var device = $('#'+refdeviceFullName).val();
		if(!device) { return };
		var cmd = "get " + name + " sets " + device;
		sendFhemCommandLocal(cmd).done(function(json){
			var sets = Object.keys(json2object(json));
			var valueDialog = $( "#valuehelp" );
			var html = "<table id='valuehelptable' data-selected=''><tr><th>Name</th></tr>";
			for(var i = 0; i < sets.length; i++){
				html += "<tr id='valuehelp-row-"+i+"' data-key='"+sets[i]+"'><td>"+sets[i]+"</td></tr>";
			};
			html += "</table>";
			valueDialog.html(html);
			registerClicked();
		});	
	}else if(type == "icon") {
		var allIcons = getIcons();
		var html = "<table id='valuehelptable' class='tablesorter' data-selected=''><thead><th>Icon</th><th>Name</th></thead><tbody>";
		for (var i = 0; i < allIcons.length; i++) {
			var icon = allIcons[i];
			html += "<tr id='valuehelp-row-"+i+"' data-key='"+icon.key+"'><td style=\"max-width:64px;padding:5px;border-style:solid;border-width:1px;\"><i class=\"fa " +icon.key+ " bigger lightgray bg-gray\"></i></td><td style=\"border-style:solid;border-width:1px;\">"+icon.names+"</td></tr>";
		};
		html += "</tbody></table>";
		valueDialog.dialog("option","width",540);
		valueDialog.dialog("option","height",560);			
		$( "#valuehelp" ).html(html);
		$(function() {
			$(".tablesorter").tablesorter({
				theme: "blue",
				widgets: ["filter"],
			    headers: {
					0: { sorter: false, parser: false }
				}
			});
			registerClicked();
		});	
	}else if(type == "pageid") {
		var cmd = "get " + name + " pagelist";
		sendFhemCommandLocal(cmd).done(function(pageListJson){
			var pageList = json2object(pageListJson);
			var valueDialog = $( "#valuehelp" );
			var html = "<table id='valuehelptable' class='tablesorter' data-selected=''><thead><tr><th>Page Id</th><th>Title</th></tr></thead>";
			html += "<tbody>";
			for(var i = 0; i < pageList.length; i++){
				html += "<tr id='valuehelp-row-"+i+"' data-key='"+pageList[i].id+"'><td>"+pageList[i].id+"</td><td>"+pageList[i].title+"</td></tr>";
			};
			html += "</tbody></table>";
			valueDialog.dialog("option","width",350);
			valueDialog.dialog("option","height",400);			
			valueDialog.html(html);
			$(function() {
				$(".tablesorter").tablesorter({
					theme: "blue",
					widgets: ["filter"],
				});
				registerClicked();
			});	
		});
	}else if(type == "class") {
		let cmd = "get " + name + " viewclasslist";
		let classListJson = await asyncSendFhemCommandLocal(cmd);
		var classList = json2object(classListJson);
		// if this is a view template maintenance, we need to remove
		// view templates which use the one we are maintaining
		if($("html").attr("data-viewtemplate")) {
			let templateid = $("html").attr("data-viewtemplate");
			let cmd = "get " + name + " whereusedlist filter-type=viewtemplate recursive=1 type=viewtemplate templateid=" + templateid;
			let wulJson = await asyncSendFhemCommandLocal(cmd); 
			let wul = json2object(wulJson);	
			wul.push({templateid: templateid});
			for(let i = 0; i < wul.length; i++) {
				let index = classList.findIndex((elem) => elem.id == "FUIP::VTempl::"+wul[i].templateid);
				if(index >= 0) classList.splice(index,1);
			};
		};
		// go on after special viewtemplate handling
		var valueDialog = $( "#valuehelp" );
		var selectedClass = $('#'+fieldName).val();
		var html = "<table id='valuehelptable' class='tablesorter' data-selected='";
		for(var i = 0; i < classList.length; i++){
			if(classList[i].id == selectedClass) {
				html += 'valuehelp-row-'+i;
				break;
			};
		};	
		html += "'><thead><tr><th>Class</th><th>Title</th><th>Img</th></tr></thead>";
		html += "<tbody>";
		for(var i = 0; i < classList.length; i++){
			var style = "";
			if(classList[i].id == selectedClass) {
				style = " style='background:#F39814;color:black;'";
			};	
			html += "<tr id='valuehelp-row-"+i+"' data-key='"+classList[i].id+"'><td"+style+">"+classList[i].id+"</td><td"+style+">"+classList[i].title+"</td><td"+style+">";
			html += "<img height=48 src='/fhem/"+name.toLowerCase()+"/fuip/view-images/" 
						+ classList[i].id.replace(/::/g,"-") + ".png' onerror=\"this.style.display='none'\">";
			html += "</td></tr>";
		};
		html += "</tbody></table>";
		valueDialog.dialog("option","width",500);
		valueDialog.dialog("option","height",400);			
		valueDialog.html(html);
		$(function() {
			$(".tablesorter").tablesorter({
				theme: "blue",
				widgets: ["filter"],
			    headers: {
					2: { sorter: false, parser: false }
				}
			});
			registerClicked();
		});	
	}else{
		valueDialog.html("No value help for this field.");
	};
};	


function valueHelpForDevice(fieldTitle, callbackFunction, multiSelect) {
	var name = $("html").attr("data-name");
	createValueHelpDialog(function(){
		var resultArray = [];
		$("tr[data-selected='X']").each(function(){
			resultArray.push($(this).attr('data-key'));
		});	
		$( "#valuehelp" ).dialog("close");
		if(multiSelect) {
			callbackFunction(resultArray);
		}else if(resultArray.length) {
			callbackFunction(resultArray[0]);
		};
	});
	var valueDialog = $( "#valuehelp" );
	valueDialog.dialog("option","title","Possible values for " + fieldTitle); 
	valueDialog.html("Please wait...");
	valueDialog.dialog("open");
	var cmd = "get " + name + " devicelist";
	sendFhemCommandLocal(cmd).done(function(deviceListJson){
		var deviceList = json2object(deviceListJson);
		var valueDialog = $( "#valuehelp" );
		// check whether alias is used at all
		var aliasUsed = false;
		for(var i = 0; i < deviceList.length; i++){
			if(deviceList[i].alias) {
				aliasUsed = true;
				break;
			};	
		};
		var html = "<table id='valuehelptable' class='tablesorter'><thead><tr><th>Name</th>";
		if(aliasUsed) {
			html += "<th>Alias</th>";
		};
		html += "<th class=\"filter-select filter-onlyAvail\">Type</th><th>Room(s)</th></tr></thead>";
		html += "<tbody>";
		var roomFilters = {};
 		// (also works for single selection)
		let selected = $("#"+fieldTitle).val();
		if(selected) {
			selected = selected.split(",");
		}else{
			selected = [];
		};	
		for(var i = 0; i < deviceList.length; i++){
			if(deviceList[i].room == "") {
				deviceList[i].room = "unsorted";
			};	
			let isSel = '';
			let style = '';
			if(selected.indexOf(deviceList[i].NAME) > -1) {
				isSel = 'X';
				style = " style='background:#F39814;color:black;'";
			};	
			html += "<tr id='valuehelp-row-"+i+"' data-selected='"+isSel+"' data-key='"+deviceList[i].NAME+"'><td"+style+">"+deviceList[i].NAME+"</td>";
			if(aliasUsed) {
				html += "<td"+style+">"+deviceList[i].alias+"</td>";
			};
			html += "<td"+style+">"+deviceList[i].TYPE+"</td><td"+style+">"+deviceList[i].room+"</td></tr>";
			var rooms = deviceList[i].room.split(",");
			for(var j = 0; j < rooms.length; j++) {
				roomFilters[rooms[j]] = valueHelpFilterRoom;
			};	
		};
		html += "</tbody></table>";
		valueDialog.dialog("option","width",650);
		valueDialog.dialog("option","height",500);			
		valueDialog.html(html);
		var orderedRoomFilters = {};
		Object.keys(roomFilters).sort().forEach(function(key) {
			orderedRoomFilters[key] = roomFilters[key];
		});
		var roomFilterFunctions;
		if(aliasUsed) {
			roomFilterFunctions = { 3 : orderedRoomFilters };
		}else{
			roomFilterFunctions = { 2 : orderedRoomFilters };
		};		
		$(function() {
			$(".tablesorter").tablesorter({
				theme: "blue",
				widgets: ["filter"],
				widgetOptions: {
					filter_functions: roomFilterFunctions
				}	
			});
			$( "#valuehelptable tbody tr" ).on( "click", function() {
				if(multiSelect) {
					if($(this).attr('data-selected') == 'X') {
						$(this).attr('data-selected','');
						$(this).children("td").removeAttr("style"); 	
					}else{
						$(this).attr('data-selected','X');
						$(this).children("td").attr("style", "background:#F39814;color:black;");
					};				
				}else{  // single select
					$("tr[data-selected='X']").each(function(){
						$(this).attr('data-selected','');
						$(this).children("td").removeAttr("style"); 							
					});
					$(this).attr('data-selected','X');					
					$(this).children("td").attr("style", "background: #F39814;color:black;");
				};	
			});
		});	
	});	
};	


function valueHelpForOptions(fieldName, callbackFunction,multiSelect) {
	var name = $("html").attr("data-name");
	createValueHelpDialog(function(){
		var resultArray = [];
		$("tr[data-selected='X']").each(function(){
			resultArray.push($(this).attr('data-key'));
		});	
		$( "#valuehelp" ).dialog("close");
		if(multiSelect) {
			callbackFunction(resultArray);
		}else if(resultArray.length) {
			callbackFunction(resultArray[0]);
		};
	});
	var valueDialog = $( "#valuehelp" );
	valueDialog.dialog("option","title","Possible values for " + fieldName); 
	valueDialog.html("Please wait...");
	valueDialog.dialog("open");
	
	var innerValueHelp = function(fName,options) {
		var valueDialog = $( "#valuehelp" );
		var html = "<table id='valuehelptable'><thead><tr><th>Name</th></tr></thead>";
		html += "<tbody>";
		// which of the options are set?
		// the following is partially for compatibility with earlier versions
		var selected = json2object($("#"+fName).val());
		if(!(selected instanceof Array)) {
			// new coding (also works for single selection)
			selected = $("#"+fName).val().split(",");
		};	
		for(var i = 0; i < options.length; i++){
			var isSel = '';
			var style = '';
			if(selected.length == 0 || selected.indexOf(options[i]) > -1) {
				isSel = 'X';
				style = " style='background:#F39814;color:black;'";
			};	
			html += "<tr id='valuehelp-row-"+i+"' data-selected='"+isSel+"' data-key='"+options[i]+"'><td"+style+">"+options[i]+"</td></tr>";
		};
		html += "</tbody></table>";
		valueDialog.dialog("option","width",120);
		valueDialog.dialog("option","height",300);			
		valueDialog.html(html);
		$( "#valuehelptable tbody tr" ).on( "click", function() {
			if(multiSelect) {
				if($(this).attr('data-selected') == 'X') {
					$(this).attr('data-selected','');
					$(this).children("td").removeAttr("style"); 	
				}else{
					$(this).attr('data-selected','X');
					$(this).children("td").attr("style", "background: #F39814;color:black;");
				};
			}else{  // single select
					$("tr[data-selected='X']").each(function(){
						$(this).attr('data-selected','');
						$(this).children("td").removeAttr("style"); 							
					});
					$(this).attr('data-selected','X');					
					$(this).children("td").attr("style", "background: #F39814;color:black;");					
			};				
		});		
	};	
	
	// get set name and device name
    var refSetFullName = getFullRefName(fieldName,"refset");
	if(refSetFullName) {  // i.e. we have a "refset"
		var refDeviceFullName = getFullRefName(refSetFullName, "refdevice");
		var cmd = "get " + name + " sets " + $("#"+refDeviceFullName).val();
		sendFhemCommandLocal(cmd).done(function(json){
			var sets = json2object(json);
			innerValueHelp(fieldName,sets[$("#"+refSetFullName).val()]);
		});
	}else{
		// fixed list of options?
		var opts = $('#'+fieldName).attr("data-options");
		if(opts) {
			innerValueHelp(fieldName,json2object(opts));
		};		
	};	
};	


function callPopupMaint(fieldName) {
	let name = $("html").attr("data-name").toLowerCase();
	let cellUrlPart;
	let pageId = $("html").attr("data-pageid");
	if(pageId) {
		// normal page/cell
		let viewId = $("#viewsettings").attr("data-viewid");
		cellUrlPart = "pageid=" + pageId + "&cellid=" + viewId;
	}else{
		// view template
		cellUrlPart = "templateid=" + $("html").attr("data-viewtemplate");	
	};	
	// if this is already the popup maintenance (popup in popup), then we need to concat
    // the field names
	var lowerFieldId = $("html").attr("data-fieldid");
	var fullFieldName;
	if(lowerFieldId) {
		fullFieldName = lowerFieldId + "-" + fieldName; 
	}else{
		fullFieldName = fieldName;
	};	
	window.location.href = location.origin + "/fhem/" + name + "/fuip/popup?" + cellUrlPart + "&fieldid=" + fullFieldName;
};	


function hasValueHelp(settings,fieldNum) {
	// TODO: some of the following are actually errors. E.g. a reading should 
	//       always have a refdevice. Maybe issue error message.
	let field = settings[fieldNum];
	// device, device-reading, icon always have a value help
	if(field.type == "device" || field.type == "devices" || field.type == "device-reading" || field.type == "icon" ) {
		return true;
	};	
	// reading and set needs a refdevice
	if(field.type == "reading" || field.type == "set") {
		return field.hasOwnProperty("refdevice");
	};	
	// setoption(s) need options or refset, which in turn has a refdevice 
	if(field.type == "setoption" || field.type == "setoptions") {	
		if(field.hasOwnProperty("options")) return true;
		if(!field.hasOwnProperty("refset")) return false;
		// find refset field
		for(let refsetfield of settings) {
			if(refsetfield.id != field.refset) continue;
			// found
			return refsetfield.hasOwnProperty("refdevice");
		};	
		return false;  // refset not found
	};
	return false;  // all other types
};	


function createField(settings, fieldNum, component,prefix) {
    var field = settings[fieldNum];
	var fieldComp = field;
	var fieldNameWoPrefix = field.id;
	for(var i = 0; i < component.length; i++) {
		fieldComp = fieldComp[component[i]];
		fieldNameWoPrefix += "-" + component[i];
	};
	let fieldName = prefix + fieldNameWoPrefix;
	
	var fieldValue = (fieldComp.value + '').replace(/'/g, "&#39;");
	var checkVisibility = "hidden";
	var checkValue = "";
	var fieldStyle = "style='visibility: visible;'";
	var defaultDef = '{type: "none"}';
	if(fieldComp.hasOwnProperty("default") && !(field.type == "sizing" && fieldComp.hasOwnProperty("options") && fieldComp.options.length == 1)){
		checkVisibility = "visible";
		if(parseInt(fieldComp.default.used)) {
			fieldStyle = "style='visibility: visible;background-color:#EBEBE4;' readonly";
		}else{
			checkValue = " checked";
		};	
		var defaultVal = fieldComp.default.value;
		if(fieldComp.default.type != 'const') {
			defaultVal = prefix + defaultVal;
		};	
		defaultDef = '{type: "' + fieldComp.default.type + '", value: "' + defaultVal + '"';
		if(fieldComp.default.hasOwnProperty("suffix")) {
			defaultDef += ', suffix: "' + fieldComp.default.suffix + '"';
		};	
		defaultDef += ' }';
	};		
	// find the fields which might be influenced by this field (non-recursive)
	var influencedFields = [];
	for(var i = 0; i < settings.length; i++) {
		influencedFields = influencedFields.concat(getInfluencedParts(settings[i],fieldNameWoPrefix,settings[i].id));
	};
	for(var i = 0; i < influencedFields.length; i++) {
		influencedFields[i] = prefix + influencedFields[i];
	};
	var fieldNameInBrackets = '"' + fieldName + '"';
	var result = "<input type='checkbox' id='" + fieldName + "-check' style='visibility: " + checkVisibility + ";'" 
			+ ' title="change (don\'t use default)"'
			+ checkValue + " onchange='defaultCheckChanged(" + fieldNameInBrackets + "," + defaultDef + ",\"" + field.type + "\")'>";
	// popups are a bit special
	if(field.type == "dialog" && (checkValue || !fieldComp.hasOwnProperty("default"))) {
		$(function() {
			$('#' + fieldName).button({
				icon: 'ui-icon-pencil',
				showLabel: true
			});		
		});		
		result += "<button id='" + fieldName + "' type='button' " +
				"onclick='acceptSettings(function() { callPopupMaint(\""+fieldName+"\");})'" +
				">Configure popup</button>";
		return result;		
	};

	if(field.type == "longtext") {
		result += "<textarea rows='5' cols='50' name='" + fieldName + "' id='" + fieldName + "' " 
			+ fieldStyle + " oninput='inputChanged(this," + JSON.stringify(influencedFields) +")' >"
			+ fieldValue + "</textarea>";
	// special case of sizing fixed to "resizable" (or any other single value)		
	}else if(field.type == "sizing" && fieldComp.hasOwnProperty("options") && fieldComp.options.length == 1){		
		result += "<input type='text'";
		result += " name='" + fieldName + "' id='" + fieldName + "' ";
		result += "value='" + fieldComp.options[0] + "' style='visibility: visible;background-color:#EBEBE4;width:79px' readonly >";
	}else{
		if(fieldComp.hasOwnProperty("options") && field.type != "setoptions" && field.type != "setoption"){
			result += "<select class='fuip'";
			if(fieldComp.hasOwnProperty("default") && parseInt(fieldComp.default.used)) {
				result += " disabled";
			};	
		}else{
			result += "<input type='text'";
		};		
		result += " name='" + fieldName + "' id='" + fieldName + "' ";
		if(fieldComp.hasOwnProperty("refdevice")){
			result += "data-refdevice='" + fieldComp.refdevice + "' ";
		};	
		if(fieldComp.hasOwnProperty("refset")){
			result += "data-refset='" + fieldComp.refset + "' ";
		};	
		if(fieldComp.hasOwnProperty("options")) {
			result += "data-options='"+JSON.stringify(fieldComp.options)+"' ";
		};	
		if(fieldComp.hasOwnProperty("flexfield")) {
			result += "data-flexfield='" + fieldComp.flexfield + "' "
					+ "fuip-type='" + field.type + "' ";
			if(fieldComp.hasOwnProperty("default")) {
				for (let attribute of ["type", "value", "suffix"]) {
					if(fieldComp.default.hasOwnProperty(attribute)) {
						result += "fuip-default-" + attribute + "='" + fieldComp.default[attribute] + "' ";
					};	
				};	
			};	
		};	
		result += "value='" + fieldValue + "' " 
				+ fieldStyle + " oninput='inputChanged(this," + JSON.stringify(influencedFields) +")' >";
		// are there options to show? (dropdown)
		if(fieldComp.hasOwnProperty("options") && field.type != "setoptions" && field.type != "setoption"){
			for(var i = 0; i < fieldComp.options.length; i++) {
				result += "<option ";
				if(fieldComp.options[i] == fieldValue) {
					result += "selected ";
				};	
				result += "class='fuip' value='" + fieldComp.options[i] + "'>" + fieldComp.options[i] + "</option>";
			};	
			result += "</select>";
		};	
	};	
	// do we have a value help?
	if(hasValueHelp(settings,fieldNum)) {
		result += '<span id="' + fieldName + '-value" class="ui-icon ui-icon-triangle-1-s" onclick="valueHelp(\''+fieldName+'\',\''+field.type+'\')" title="Possible values" style="background-color:#F6F6F6;border: 1px solid #c5c5c5;color:#454545;'; 
		// value help invisible?
		if(checkVisibility == "visible" && checkValue != " checked") {
			result += "visibility:hidden;";
		};	
		result += '"></span>';
	};	
	// for sizing fields, add width and height (if resizable)
	// TODO: do we need proper default values?
	if(field.type == "sizing") {
		var width = 0;
		var height = 0;
		for(var i = 0; i < settings.length; i++) {
			if(settings[i].id == "width" && settings[i].type == "dimension") {
				width = settings[i].value;
			};
			if(settings[i].id == "height" && settings[i].type == "dimension") {
				height = settings[i].value;
			};	
		};
		result += "<input type='text' style='margin-left:5px;width:35px;' name='" + prefix + "width' id='" + prefix + "width' ";
		result += "value='" + width + "'>";
		result += "<span id='"+fieldName+"-x'>x</span>";
		result += "<input type='text' style='width:35px;' name='" + prefix + "height' id='" + prefix + "height' ";
		result += "value='" + height + "'>";
		$(function() {
			$("#"+fieldName).on("input",function() {
				sizingChanged(fieldName,prefix+"width",prefix+"height");
			});
			sizingChanged(fieldName,prefix+"width",prefix+"height");
		});	
	};	
	// if this is a view template, add variable definition
	if($("html").attr("data-viewtemplate") && field.type != "sizing" && field.type != "dialog" && fieldName != "title" && field.type != "longtext") {
		let checkValue = "";
		let value;
		if(fieldComp.hasOwnProperty("variable")) {
			checkValue = " checked";
			value = fieldComp.variable;
		}else{
			 value = fieldNameWoPrefix.replace(/-/g, "_");
		};	 
		result += "\n</td><td style='text-align:left;white-space:nowrap;'>" +
					"\n<input type='checkbox' id='" + fieldName + "-varcheck' title='make this a variable'" 
					+ checkValue 
					+ " onchange='varCheckChanged(\"" + fieldName + "\")'>" +
					"\n<input type='text' id='" + fieldName + "-variable' value='" + value + "'>";	
		$(function(){varCheckChanged(fieldName)});				
	};
	return result;
};


function createViewArray(field,prefix) {
    var items = field.value;
	// the current number of items and the (so far) highest item number is stored in the accordion itself
	var result = '<table><tr><td class="ui-widget-content" style="border-width: 1px;"><div id="' + prefix + field.id + '-accordion" data-length="' + items.length + '" data-nextindex="' + items.length + '">';
	for(var i = 0; i < items.length; i++) {
		result += '<div class="group" id="' + prefix + field.id + '-' + i + '"><h3>';
		var title = '' + i + ' ';
		for(var j = 0; j < items[i].length; j++) {
			if(items[i][j].id == 'title') {
				title = items[i][j].value;
				break;
			};								
		};
		var fieldNameWithTicks = "'" + prefix + field.id + '-' + i + "'";
		result += title + '<button id="' + prefix + field.id + '-' + i + '-delete" onclick="viewDeleteFromArray('+fieldNameWithTicks+')" type="button" style="position:absolute;right:0;">Delete view from ' + field.id + '</button></h3><div>' + createSettingsTable(items[i], prefix + field.id + '-' + i + '-') + '</div></div>';
		$(function() {
			for(var j = 0; j < items.length; j++) {
				$('#' + prefix + field.id + '-' + j + '-delete').button({
					icon: 'ui-icon-trash',
					showLabel: false
				});		
			};
		});
	};
	result += '</div></td></tr></table>';
	// make this a JQuery Accordion
	$( function() {
		$( "#" + prefix + field.id + "-accordion" )
			.accordion({
				header: "> div > h3",
				collapsible: true,
				active: false,
				heightStyle: "content" 
			})
			.sortable({
				axis: "y",
				handle: "h3",
				stop: function( event, ui ) {
						// IE doesn't register the blur when sorting
						// so trigger focusout handlers to remove .ui-state-focus
						ui.item.children( "h3" ).triggerHandler( "focusout" );
						// Refresh accordion to handle new order
						$( this ).accordion( "refresh" ); 
					  } 
			});
		$(".ui-accordion-content").css("padding-left","10px").css("padding-right","10px");
		$(".ui-accordion").css("min-width","350px");	
	});
	return result;
};
					

function setDefaultsGetMapEntry(field) {   // returns map entry
	let result = { value: field.value, ready: true};
	if(field.hasOwnProperty('default')) {
		if(field.default.used == '1') {
			if(field.default.type == 'field') {
				result.ready = false;
				result.reffield = field.default.value;
				result.suffix = (field.default.hasOwnProperty('suffix') ? field.default.suffix : "");
			}else{
				result.value = field.default.value;
			};	
		};
	};	
	return result;	
};	


function setDefaultsGetDefaults(map,fieldName) {
	if(map[fieldName].ready) return;
	// now we can be sure that there is a reference field 
	// and we need to make sure that this is "ready"
	setDefaultsGetDefaults(map,map[fieldName].reffield);
	map[fieldName].value = map[map[fieldName].reffield].value + map[fieldName].suffix;
};	

	
function setDefaults(settings) {
	let map = {};
	// prepare map field id => value
	for(let i = 0; i < settings.length; i++) {
		if(settings[i].type == 'viewarray') continue;
		if(settings[i].type == 'device-reading') {
			map[settings[i].id + '-device'] = setDefaultsGetMapEntry(settings[i].device);
			map[settings[i].id + '-reading'] = setDefaultsGetMapEntry(settings[i].reading);
		}else{
			map[settings[i].id] = setDefaultsGetMapEntry(settings[i]);
		};	
	};	
	// do the real defaulting
	for(let i = 0; i < settings.length; i++) {
		if(settings[i].type == 'viewarray') continue;
		if(settings[i].type == 'device-reading') {
			setDefaultsGetDefaults(map,settings[i].id + '-device');
			settings[i].device.value = map[settings[i].id + '-device'].value;
			setDefaultsGetDefaults(map,settings[i].id + '-reading');
			settings[i].reading.value = map[settings[i].id + '-reading'].value;
		}else{
			setDefaultsGetDefaults(map,settings[i].id);
			settings[i].value = map[settings[i].id].value;
		};	
	};	
};	


function flexFieldError(message,fieldString) {
// create an error message about a flexible field definition	
	if(!fuip.hasOwnProperty("messages")) {
		fuip.messages = [];
	};	
	let errStr = fieldString.replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;');
	fuip.messages.push({
		title: 'Invalid Flex Field Definition',
		description: 'The code below looks like a definition of a flexible field in an HTML view, but cannot be used by FUIP. This definition will be ignored. <p>'+message+'<p><code>'+errStr+'</code>'
	});
};


function addFieldsFromHtmlView(settings){
	// find whether this is an HTML view
	for(let i = 0; i < settings.length; i++){
		if(settings[i].type != 'class') { continue; };
		if(	settings[i].value != 'FUIP::View::Html' ) { return; };
		break;
	};
	// remove all existing flexfields from settings (we might delete some,
	// change types, change sequence etc.)	
	let oldFlexfields = {};
	for(let i = 0; i < settings.length; i++){
		if(!settings[i].hasOwnProperty("flexfield") || settings[i].flexfield != "1")
			continue;
		oldFlexfields[settings[i].id] = settings[i];	
		settings.splice(i,1);
		i--;
	};
	// find html field and its index
	let index;
	let html = false;
	for(let i = 0; i < settings.length; i++){
		if(settings[i].id != 'html') { continue; };
		index = i;
		html = settings[i].value;
		break;
	};
	// is there anything?
	if(!html) return;
	// find matches for <fuip-field>...</fuip-field>
	let fieldStrings = html.match(/<fuip-field(.|\s)*?<\/fuip-field>/g);
	// something wrong?
	// TODO: error message or so
	if(!fieldStrings) return;  // null if no match
	for(let fieldString of fieldStrings){
		// TODO: The following checks partially mean that a field def was found,
		//		but something is wrong. Maybe proper error message and do not 
		//		change anything
		let fieldDef = $(fieldString);
		if(!fieldDef){
			// It looks like this here is very unlikely. At least, I have not found a way to produce this problem.
			// However, the check does not harm either.	
			flexFieldError("",fieldString);
			continue;
		};
		let id = fieldDef.attr("fuip-name");
		if(!id){
			flexFieldError('It is missing a name (attribute "fuip-name").',fieldString);
			continue;
		};
		// check field name format
		if(!/^[_a-zA-Z][_a-zA-Z0-9]*$/.test(id)){
			flexFieldError('The field name "'+id+'" is invalid. You can only use letters (a..b,A..B), numbers (0..9) and the underscore (_). The first character can only be a letter or the underscore. Whitespace (blanks) cannot be used.', fieldString);
			continue;
		};
		// check for reserved field names
		if(/^(class|defaulted|flexfields|height|html|popup|sizing|title|variable|variables|views|width)$/.test(id)){
			flexFieldError('The field name "'+id+'" is reserved for FUIP itself. Reserved names are "class", "defaulted", "flexfields", "height", "html", "popup", "sizing", "title", "variable", "variables", "views" and "width".',fieldString);
			continue;
		};	
		// check if this is already there 
		// This is ok in principle, but we should not display it twice
		if(settings.find((element) => element.id == id)){
			continue;
		};	
		// not there, add it
		let flexfield = {"id":id, "flexfield":1};
		if(oldFlexfields.hasOwnProperty(id)) {
			flexfield.value = oldFlexfields[id].value;
			if(oldFlexfields[id].hasOwnProperty("variable")) 
				flexfield.variable = oldFlexfields[id].variable;
		}else{
			flexfield.value = fieldDef.text();
		};	
		// flex field attributes
		for (let attribute of ["type", "refdevice", "refset"]) {
			let val = fieldDef.attr("fuip-" + attribute);
			if(typeof val !== "undefined") flexfield[attribute] = val;	
		};
		let val = fieldDef.attr("fuip-options");
		if(typeof val !== "undefined"){
			flexfield.options = val.split(',');	
		};	
		for (let attribute of ["type", "value", "suffix"]) {
			let val = fieldDef.attr("fuip-default-" + attribute);
			if(typeof val !== "undefined"){
				if(!flexfield.hasOwnProperty("default")) 		
					flexfield.default = {};		
				flexfield.default[attribute] = val;	
			};	
		};
		// default used?
		if(flexfield.hasOwnProperty("default")) {
			if(oldFlexfields.hasOwnProperty[id] 
			   && oldFlexfields[id].hasOwnProperty("default")
			   && oldFlexfields[id].default.hasOwnProperty("used")) {
				flexfield.default.used = oldFlexfields[id].default.used;
			}else{
				flexfield.default.used = 1;
			};			
		};		
		if(!flexfield.type) flexfield.type = "text";
		index++;
		settings.splice(index,0,flexfield);
	}; 
};	
					

function createSettingsTable(settings,prefix) {
	// this is for one single settings-Array
	// prefix is put in front of all field names (ids)
	// html special
	addFieldsFromHtmlView(settings);
	// do the defaulting
	setDefaults(settings);
	var html = "<table>";
	for(var i = 0; i < settings.length; i++){
		if(settings[i].type != 'class') { continue; }; 
		if(	settings[i].value == 'FUIP::Cell' || 
			settings[i].value == 'FUIP::Page' || 
			settings[i].value == 'FUIP::Dialog' ||
			settings[i].value == 'FUIP::ViewTemplate') { break; };
		html += createClassField(settings[i].value,prefix);
		break;
	};
	for(var i = 0; i < settings.length; i++){
		if(settings[i].type == 'class') { continue; };
		if(settings[i].type == 'dimension') { continue; };
		if(settings[i].type == 'variables') { continue; };
		if(settings[i].type == 'flexfields') { continue; };
		let fieldName = prefix + settings[i].id;		
		switch(settings[i].type) {
			case 'device-reading':
				html += "<tr><td";
				if($("html").attr("data-viewtemplate")) html += ' rowspan="2"'; 
				html += " style='text-align:left'><label for='" + fieldName + "'>" + settings[i].id + "</label></td><td style='text-align:left;white-space:nowrap;'>";
				html += createField(settings, i, ["device"],prefix) + '</td>';
				if($("html").attr("data-viewtemplate")) {
					html += '</tr><tr>';
				};
				html += '<td style="text-align:left;white-space:nowrap;">' + createField(settings, i, ["reading"],prefix);
				break;
			case 'viewarray':
				html += '</table>';
				html += '<div style="text-align:left;">';
				var fieldNameInTicks = '"' + fieldName + '"'; 
				html += '<div id="fuip-viewarraybuttons" style="margin-top:10px;margin-left:20px;">' + 
					"<button id='" + fieldName + "-add' onclick='viewAddNewToArray("+fieldNameInTicks+")' type='button' title='Add view'>Add view</button>" + 
					"<button id='" + fieldName + "-addByDevice' onclick='viewAddNewByDevice("+fieldNameInTicks+")' type='button' title='Add views by device'>Add views by device</button>" 
					+ '</div>';
				html += createViewArray(settings[i],prefix) 
						+ '</div><table>';
				// make the button a jquery ui button
				$(function() {
					$('#' + fieldName + '-add').button({
						icon: 'ui-icon-plus',
						label: 'view',
						showLabel: true
					});		
					$('#' + fieldName + '-addByDevice').button({
						icon: 'ui-icon-plus',
						label: 'by device',
						showLabel: true
					});
					$('#fuip-viewarraybuttons').controlgroup();
				});
				break;
			default:
				html += "<tr><td style='text-align:left'><label for='" + fieldName + "'>" + settings[i].id + "</label></td><td style='text-align:left'";
				if(settings[i].type == "longtext") html += ' colspan="4"';
				html += ">";
				html += createField(settings, i,[],prefix);
		};
		html += "</td></tr>";
	};
	html += "</table>";
	return html;
};


function decodeObject(o) {
    var type = typeof o 
    if (type != "object") {
		return;
	};
	for (var key in o) {
		if(typeof(o[key]) == "object") {
			decodeObject(o[key]);
		}else{
			o[key] = decodeURIComponent(o[key]);
		};	
    }
}


function json2object(json) {
	try {
		var o = JSON.parse(json);
	} catch(e) {
		return null;
	};	
	decodeObject(o);
	return o;
};	



function exportCellOrDialog() { 
	var downloadUrl = location.origin + '/fhem/' + $("html").attr("data-name").toLowerCase() 
					+ '/fuip/export?pageid=' + $("html").attr("data-pageid") 
					+ '&cellid=' + $("#viewsettings").attr("data-viewid");
	if($("html").attr("data-fieldid")) {
		downloadUrl += '&fieldid='+$("html").attr("data-fieldid");
	};	
	location.href = downloadUrl;
};	


// the following attaches the input field for the file dialog to this function itself
// it seems that otherwise, it happens that the garbage collector deletes variable "input"
async function importCellOrDialog() { 
	let targettype = $("html").attr("data-fieldid") ? "dialog" : "cell";
	// for some (unknown to me) reason, acceptSettings does not work with the usual construct
	// however, the import of a cell does not change the cell or the content of the
	// config popup anyway, so we can just do it "afterwards"
	if(targettype == "cell"){ // for dialog, we anyway overwrite the current state
		acceptSettings( function() {} );  // avoid immediate reload
	};	
	try {
		let content = await dialogFileUpload();
		let msg = await asyncPostImportCommand(content,targettype,$("html").attr("data-pageid"));
		if(msg == "OK") {
			location.reload(true);
		}else{	
			popupError("Import " + targettype + ": Error",msg);
		};
	}catch(e){};  // ignore as messages have already been sent to the user		
};	


async function dialogFileUpload() {
	return new Promise(function(resolve,reject) {
		fuip.fileInput = $('<input type="file">');
		fuip.fileInput.on("change",function(evt){
			fuip.fileInput = undefined;
			let reader = new FileReader();
			reader.onload = function(e) {
				resolve(e.target.result);
			};	
			reader.readAsText(evt.target.files[0]);
		});
		fuip.fileInput.click();
	});	
};


async function dialogImportViewTemplate() { 
	try {
		let content = await dialogFileUpload();
		let msg = await asyncPostImportCommand(content,"viewtemplate","");
		if(msg.slice(0,2) == "OK") {  // OK<templateid>
			window.location.replace("/fhem/" + $("html").attr("data-name").toLowerCase() +"/fuip/viewtemplate?templateid="+msg.slice(2));
		}else{	
			popupError("Import View Template: Error",msg);
		};
	}catch(e){};  // ignore errors, as popups have already been sent	
};	

								
function changeSettingsDialog(settingsJson,type,cellid,fieldid) {
	// type: cell,dialog or viewtemplate
	// fieldId is set in the "popup maintenance mode" (type = dialog)
	var settingsDialog = $( "#viewsettings" );
	var title = "Settings ";
	switch(type) {
		case "cell": 
			title += "cell " + cellid; break;
		case "dialog":
			title += "popup ";
			if($("html").attr("data-pageid")) {
				title += cellid + " ";
			};
			title += fieldid; 
			break;
		case "viewtemplate":
			title += "view template " + $("html").attr("data-viewtemplate"); break;
		default:
			title += type + " ???";
	};		
	var settings = json2object(settingsJson);
	var html = "<form onsubmit='return false'>" + createSettingsTable(settings,"") + "</form>";
	for(var i = 0; i < settings.length; i++){
		if(settings[i].id == "title") {
			title += " (" + settings[i].value + ")"; 
			break;
		};			
	};
	settingsDialog.dialog("option","title",title); 
	settingsDialog.html(html);
	var buttons = 
		[{
			text: 'Ok',
			icon: 'ui-icon-check',
			click: function() { acceptSettings(); },
			showLabel: false }];
	if(type == "cell") {
		buttons.push(	
			{   text: 'Add new cell',
				icon: 'ui-icon-plus',
				click: function() { acceptSettings(viewAddNew);},
				showLabel: false },
			{	text: 'Copy cell',
				icon: 'ui-icon-copy',
				click: function() { acceptSettings(copyCurrentCell);},
				showLabel: false });
	};
	if(type == "dialog") {
		buttons.push(
			{	text: 'Export ' + type,
				icon: ' ui-icon-arrowstop-1-s',
				click: function() { acceptSettings(exportCellOrDialog) },
				showLabel: false },
			{	text: 'Import ' + type,
				icon: ' ui-icon-arrowstop-1-n',
				click: importCellOrDialog,  // does the acceptSettings internally	
				showLabel: false });
	};			
	if(type == "cell") {
		buttons.push(	
			{   text: 'Delete cell',
				icon: 'ui-icon-trash',
				click: deleteCell,
				showLabel: false });
	};
	buttons.push(
		{   text: 'Cancel',
			icon: 'ui-icon-close',
			click: function() {	settingsDialog.dialog( "close" ); 
								// even here, we do a reload as other functions (like export) 
								// could already have "saved" the changes
								location.reload(true);
							},
			showLabel: false },
		{	text: 'Toggle editOnly',
			click: function() { acceptSettings( function() {
				var easyDrag = $('html').attr('data-editonly');
				if(easyDrag == "0") {
					easyDrag = "1";
				}else{
					easyDrag = "0";
				};
				sendFhemCommandLocal("set " + $("html").attr("data-name") + " editOnly " + easyDrag).
					done(function(){ location.reload(true) });
			});} 
		}
		);
	settingsDialog.dialog("option","buttons",buttons);
};
					
				
async function openSettingsDialog(type, cellid) {
	// Parameters depend on type:
	// cell:	Maintain a normal cell 		
	//         	page id is taken from HTML, cellid given in parameters
	// dialog: 	Maintain a dialog (popup)
	//			everything is taken from the HTML
	// viewtemplate: Maintain a view template
	//			everything is taken from the HTML
	
	// FTUI switches off text selection (which only seems to work in IE)
	// The following switches it back on, so select,copy,cut,paste etc. can be used
    $("body").each(function () {
        this.onselectstart = function () {
            return true;
        };
        this.unselectable = "off";
        $(this).css('-moz-user-select', 'text');
        $(this).css('-webkit-user-select', 'text');
    });	
	var settingsDialog = $( "#viewsettings" );
	let name = $("html").attr("data-name");
	// XMLHTTP request to get config options with current values
	var cmd = "get " + name + " settings type=" + type + " ";
	let fieldid;
	switch(type) {
		case "cell": 
			cmd += 'pageid="' + $("html").attr("data-pageid") + '" cellid="' + cellid + '"';
			break;
		case "dialog":
			fieldid = $("html").attr("data-fieldid");
			if($("html").attr("data-pageid")) {
				cellid = $("html").attr("data-cellid");
				cmd += 'pageid="' + $("html").attr("data-pageid") + '" cellid="' + cellid + '"';
			}else{
				cmd += 'templateid="' + $("html").attr("data-viewtemplate") + '"';
			};	
			cmd += ' fieldid="' + fieldid + '"';
			break;
		case "viewtemplate":
			cmd += 'templateid="' + $("html").attr("data-viewtemplate") + '"';
			break;
		default:
			console.log("FUIP: openSettingsDialog failed: unknown type");
			ftui.toast("FUIP: openSettingsDialog failed: unknown type","error");
			fuip.messages = [];
			return;
	};	
	let settingsJson = await asyncSendFhemCommandLocal(cmd);
	changeSettingsDialog(settingsJson,type,cellid,fieldid);
	settingsDialog.attr("data-mode",type);
	settingsDialog.attr("data-viewid",cellid);
	// popup maint?
	if(fieldid) {
		settingsDialog.attr("data-fieldid",fieldid);
	};	
	// have we collected any messages?
	if(fuip.hasOwnProperty("messages")) {
		for(let msg of fuip.messages) {
			await new Promise(function(resolve,reject){
				popupError(msg.title,msg.description,resolve)
			});
		};
		fuip.messages = [];	
	};
	settingsDialog.dialog("open");
};
			
			
async function copyCurrentPage() {
	// get current name and page id
	var name = $("html").attr("data-name");
	var pageid = $("html").attr("data-pageid");
	// get new page id
	try{
		let newname = await dialogNewName({
				title: "Enter name of new page",
				label: "New page name",
				defaultName: pageid+"_copy",
				checkFunc: function(name) { return name.length; }
			});
		// TODO: This allows overwriting page "home". Is this good?
		sendFhemCommandLocal("set " + name + " pagecopy " + pageid + " " + newname)
			.done(function() {
				window.location = "/fhem/" + name.toLowerCase() +"/page/"+newname;
			});	
	}catch(e){
		return; // we ignore this in principle. A message should have been sent already.
	};  		
};	
			

function exportPage() { 
	location.href = location.origin + '/fhem/' + $("html").attr("data-name").toLowerCase() 
			+ '/fuip/export?pageid=' + $("html").attr("data-pageid"); 
};


function exportViewTemplate() { 
	location.href = location.origin + '/fhem/' + $("html").attr("data-name").toLowerCase() 
			+ '/fuip/export?templateid=' + $("html").attr("data-viewtemplate"); 
};


async function repairPage() {
	let cmd = 'set ' + $("html").attr("data-name") + ' repair type=page pageid=' + $("html").attr("data-pageid");
	await asyncSendFhemCommandLocal(cmd);
	location.reload(true);
};	
			
	
async function importPage() {
	acceptPageSettings(function(){});  // avoid page reload
	try {
		let content = await dialogFileUpload();
		let newname = await dialogNewName({
				title: "Import page: enter name of new page",
				label: "New page name",
				checkFunc: function(name) { return name.length; }
			});
		let msg = await asyncPostImportCommand(content,"page",newname);
		if(msg == "OK") {
			window.location = "/fhem/" + $("html").attr("data-name").toLowerCase() + "/page/"+newname;
		}else{	
			popupError("Import page: Error",msg);
		};
	}catch(e){};  // ignore errors, as popups have already been sent	
};

			
function toggleCellPage() {
	var settingsDialog = $( "#viewsettings" );
	var mode = settingsDialog.attr("data-mode");
	if(mode != "cell" && mode != "page") return;
	settingsDialog.html("Just a moment...");
	if(mode == "page") {
		// switch to "cell"
		openSettingsDialog($("html").attr("data-name"),"cell",settingsDialog.attr("data-viewid"));
	}else if(mode == "cell") {
		settingsDialog.dialog("option","title", "Settings page " + $("html").attr("data-pageid"));
		settingsDialog.attr("data-mode","page");
		settingsDialog.dialog("option","buttons",
			[{	text: 'Ok',
				icon: 'ui-icon-check',
				click: function() { acceptPageSettings();},
				showLabel: false },
			{	text: 'Copy page',
				icon: 'ui-icon-copy',
				click: function() { acceptPageSettings(copyCurrentPage); },
				showLabel: false },
			{   text: 'Cancel',
				icon: 'ui-icon-close',
				click: function() {	settingsDialog.dialog( "close" ); 
									location.reload(true);
								},
				showLabel: false }
			]);
		var cmd = "get " + $("html").attr("data-name") + " pagesettings " + $("html").attr("data-pageid");
		sendFhemCommandLocal(cmd).done(function(settingsJson){
			var settings = json2object(settingsJson);
			var html = "<form onsubmit='return false'>" + createSettingsTable(settings,"") + "</form>";
			settingsDialog.html(html);
		});	
	};
};	


function copyCurrentCell() {
	// get current name, page id and view id
	var name = $("html").attr("data-name");
	var pageid = $("html").attr("data-pageid");
	var viewid = $("#viewsettings").attr("data-viewid");	
	// create popup to input new page id
	var popup;	
	popup = $( "#inputpopup01" ).dialog({
		autoOpen: false,
		width: 400,
		height: 250,
		modal: true,
		title: "Enter id of target page",
		buttons: [{
			text: 'Ok',
			icon: 'ui-icon-check',
			click: async function() {
				var newname = $("#newpagename").val();			
				await asyncSendFhemCommandLocal("set " + name + " cellcopy " + pageid + "_" + viewid + " " + newname);
				window.location = "/fhem/"+name+"/page/"+newname;
			},
			showLabel: false },
		  { text: 'Cancel',
			icon: 'ui-icon-close',
			click: function() {	popup.dialog( "close" ); },
			showLabel: false }
		],
	});
	$(function() {
		$('#newpagename-value').button({
			icon: 'ui-icon-triangle-1-s',
			showLabel: false
		});		
	});		
	popup.html('<form onsubmit="return false;">'+
					'<label for="newpagename">Target page id</label>'+
					'<input type="text" id="newpagename" style="visibility:visible;" value="'+pageid+'"/>' +
					"<button id='newpagename-value' onclick='valueHelp(\"newpagename\",\"pageid\")' type='button' style='padding:1px 0px;'>" + 
					"Possible values</button>" +
				'</form>');
	popup.dialog("open");
};	


async function dialogNewViewTemplateName(config) {
	let conf = {			
			title: "Enter name of new view template",
			label: "New template id",
			checkFunc: function(templateid) {
				//	makes sure that a view template id adheres to the rules for Perl variables
				//	returns true if everything is ok, false otherwise
				if(/^[_a-zA-Z][_a-zA-Z0-9]*$/.test(templateid)) 
					return true; // all good	
				popupError('View template name invalid', 'The view template name "'+templateid+'" is invalid. You can only use letters (a..b,A..B), numbers (0..9) and the underscore (_). The first character can only be a letter or the underscore. Whitespace (blanks) cannot be used.'); 
				return false;
			}
	}; 
	if(config)
		$.extend(conf,config);
	return dialogNewName(conf);
};


async function dialogNewName(config) {
	// config object with (all optional) fields:
	//		title: defaults to "Enter new name"
	//		label: defaults to "New name"
	//		defaultName: defaults to ""
	//		checkFunc: defaults to "always return true"
	let conf = { 
			title: "Enter new name",
			label: "New name",
			defaultName: "",
			checkFunc: function(name) { return true; }
		};
	if(config) 
		$.extend(conf,config);	
	return new Promise(function(resolve,reject) {
		// create popup to input new view template name
		let popup = $("#inputpopup");
		if(!popup.length) {
			popup = $('<div id="inputpopup"></div>');
			$("body").append(popup);
		};	
		popup.dialog({
			autoOpen: false,
			width: 350,
			height: 150,
			modal: true,
			title: conf.title,
			buttons: [{
				text: 'Ok',
				icon: 'ui-icon-check',
				click: function() {
					let newname = $("#newname").val();	
					if(conf.checkFunc(newname)) {
						popup.dialog( "close" );
						resolve(newname);
					};		
				},
				showLabel: false },
			{ text: 'Cancel',
				icon: 'ui-icon-close',
				click: function() {	
						popup.dialog( "close" ); 
						reject(new Error('No name given'));
					},
				showLabel: false }
			],
		});
		popup.html('<form onsubmit="return false;">'+
					'<label style="margin-right:1em;" for="newname">'+conf.label+'</label>'+
					'<input type="text" id="newname" style="visibility:visible;" value="'+conf.defaultName+'"/>'+
				'</form>');
		popup.dialog("open");
	});
};


async function dialogCreateNewViewTemplate() {
	try{
		let newname = await dialogNewViewTemplateName();
		window.location.replace("/fhem/" + $("html").attr("data-name").toLowerCase() +"/fuip/viewtemplate?templateid="+newname);
	}catch(e){}; // we can ignore this, usually only user input error 
};


async function dialogConvertToViewtemplate() {
	// convert current cell/dialog to view template
	let newname;
	try{
		newname = await dialogNewViewTemplateName();
	}catch(e){
		return;
	};  
	let cmd = 'set ' + $("html").attr("data-name") + ' convert ' + getKeyForCommand("origin")
				+ ' targettype=viewtemplate targettemplateid="' + newname + '"';
	await asyncSendFhemCommandLocal(cmd);
	window.location.href = location.origin + "/fhem/" + $("html").attr("data-name").toLowerCase() +"/fuip/viewtemplate?templateid="+newname;	
};	