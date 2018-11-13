// everything which should be run after the page has loaded
var fuipGridster;
var fuip = {};

function fuipInit(conf) { //baseWidth, baseHeight, maxCols, gridlines, snapTo
	fuip.baseWidth = conf.baseWidth;
	fuip.baseHeight = conf.baseHeight;
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
		// switch to page settings does not make sense for dialog maintenance
		if(!fieldid) {
			$(function() {
				$('.ui-dialog-titlebar').append('<button id="togglecellpage" type="button" style="position:absolute;top:0px;left:0px;" onclick="toggleCellPage()">Cell/Page</button>');
				$('#togglecellpage').button({
					icon: 'ui-icon-transferthick-e-w',
				});		
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
					var dim = gridDimensions();
					var n = (ui.position.left + fuip.drag_start_left - 5) / dim.gridWidth;
					if(n - Math.floor(n) > 0.5) n++;
					var snapped = 5 + Math.floor(n) * dim.gridWidth;  // offset	
					ui.position.left = snapped - fuip.drag_start_left;
					n = (ui.position.top + fuip.drag_start_top - 27) / dim.gridHeight;
					if(n - Math.floor(n) > 0.5) n++;
					snapped = 27 + Math.floor(n) * dim.gridHeight;  // offset	
					ui.position.top = snapped - fuip.drag_start_top;
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
			widget_margins: [5, 5],
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
	});
};
		

function gridDimensions() {
	// try to determine "smart" dimensions to have gridlines
	// with about 30 px distance, but have a gridline at the 
	// left border of each cell and at the lower border of the header
	// of each cell
	var nH = Math.round((fuip.baseHeight + 10) / 30.0);
	var nW = Math.round((fuip.baseWidth + 10) / 30.0);
	return { 
		gridHeight: (fuip.baseHeight + 10) / nH,
		gridWidth : (fuip.baseWidth + 10) / nW };
};	
		
		
function drawGrid() {
	// determine grid width
	var dim = gridDimensions();
	// create canvas to draw on
	$("body").append('<canvas id="gridCanvas" width=' + $(document).width() + ' height=' + $(document).height() + ' style="position:absolute;top:0;left:0;z-index:99;pointer-events:none;"></canvas>');
	var canvas = document.getElementById("gridCanvas");
	var c = canvas.getContext("2d");
	c.setLineDash([1,4]);
	for(var x = 5; x < $(document).width(); x += dim.gridWidth) {
		c.moveTo(x,0);
		c.lineTo(x,$(document).height() -1);
	};	
	for(var y = 27; y < $(document).height(); y += dim.gridHeight) {
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
			

// when in the dialog (popup) maintenance resizing was finished
function onDialogResize(e,ui) { 
	var name = $("html").attr("data-name");
	var pageId = $("html").attr("data-pageid");
	var cellId = $("html").attr("data-cellid");	
	var fieldId = $("html").attr("data-fieldid");
	var cmd = "set " + name + " dialogsize " + pageId + "_" + cellId + " " + fieldId + " " 
				+ ui.size.width + " " + ui.size.height; 
	sendFhemCommandLocal(cmd);					
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


// flex maint: resize cell
function onFlexMaintResize(e,ui) {
	// do "gridster effect"
	// width = (baseWidth + 10) * sizeX - 10
	// sizeX = (width + 10) / (baseWidth + 10) 
	var width = ui.size.width;
	var height = ui.size.height;
	var sizeX = Math.floor((width + 10 + 0.9 * fuip.baseWidth) / (fuip.baseWidth +10));
	var fakeWidth = sizeX * (fuip.baseWidth + 10) - 10;
	var sizeY = Math.floor((height + 10 + 0.9 * fuip.baseHeight) / (fuip.baseHeight + 10));
	var fakeHeight = sizeY * (fuip.baseHeight + 10) - 10;
	var fakeElem = ui.element.parent();
	fakeElem.width(fakeWidth).height(fakeHeight);
	// set new grid element size
	// ...but first store old size
	var oldArea = flexMaintGetArea(fakeElem);
	var oldSizeX = oldArea.col_end - oldArea.col_start;
	var oldSizeY = oldArea.row_end - oldArea.row_start;
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
	// correct size is the size of the preview
	ui.element.height(ui.element.parent().height());
	ui.element.width(ui.element.parent().width());
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
	var id = ui.helper.attr("id");
	id = id.replace("cell","fake"); 
	var fakeElem = $("#"+id);
	var area = fuip.drag_start_area;
	// move by 1 cell if moved by 50% of the baseWidth/Height
	var moveX = Math.round(ui.position.left / (fuip.baseWidth + 10));
	var moveY = Math.round(ui.position.top  / (fuip.baseHeight + 10));
	var region = fakeElem.parent().attr("id");
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
	fakeElem.prepend(ui.helper);
	ui.helper.css({top:0,left:0});
	fuip.drag_colzero = 0;
	onFlexChangeStop();
};	

			
// when a view is dropped on a cell
function onDragStop(cell,ui) {
	// is this on the dialog maint?
	var fieldid = $("html").attr("data-fieldid");
	if(fieldid) {
		onDragStopDialog(fieldid,ui);
		return;
	};	
	var cellId = cell.attr("data-cellid");
	var view = ui.draggable;
	var viewId = view.attr("data-viewid");
	var name = $("html").attr("data-name");
	var pageId = $("html").attr("data-pageid");
	var cmd = "set " + name;
	var oldCellId = view.closest("[data-cellid]").attr("data-cellid");
	if(oldCellId != cellId) {
		var oldCellPos = view.closest("[data-cellid]").offset();
		var newCellPos = cell.offset();
		cmd = cmd + " viewmove " + pageId + "_" + oldCellId + "_" + viewId + " " + cellId + " " + (ui.position.left + oldCellPos.left - newCellPos.left) + " " + (ui.position.top + oldCellPos.top - newCellPos.top - 22); 
		// TODO: error handling when sending command
		sendFhemCommandLocal(cmd).done(function() { 
			location.reload(true);
		});	
		return;
	};	
	cmd = cmd + " viewposition " + pageId + "_" + cellId + "_" + viewId + " " + ui.position.left + " " + (ui.position.top - 22); 
	// TODO: error handling when sending command
	sendFhemCommandLocal(cmd).done(function() {
		location.reload(true);
	});	
};
							

// dialog (popup) maintenance: when a view stops moving
function onDragStopDialog(fieldid,ui) {
	var name = $("html").attr("data-name");
	var pageid = $("html").attr("data-pageid");
	var cellid = $("html").attr("data-cellid");
	// the following is the view which moved
	var view = ui.draggable;
	var viewid = view.attr("data-viewid");
	var cmd = "set " + name +
				" viewposdialog " + pageid + "_" + cellid + " " + fieldid + " " + viewid + " " + ui.position.left + " " + (ui.position.top - 22); 
	// TODO: error handling when sending command
	sendFhemCommandLocal(cmd).done(function() {
		location.reload(true);
	});	
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
	if(onClose) {
		buttons[0].click = function() { popup.dialog("close"); onClose(); };
	};	
	popup.dialog({
			title: title,
			modal: true,
			buttons: buttons,
			classes: { "ui-dialog-titlebar": "ui-state-error" }
		});
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


function postImportCommand(content,isCell,pageid) {
	var data = encodeURIComponent(content);
	var url = location.origin + '/fhem/' + $("html").attr("data-name").toLowerCase() + '/fuip/import?pageid=' + pageid;
	if(isCell) { 
		url += '&cellid=' + $("#viewsettings").attr("data-viewid");
	};	
	var fieldid = $("#viewsettings").attr("data-fieldid");
	if(fieldid) {
		url += '&fieldid=' + fieldid;		
	};	
	return $.ajax({
		async: true,
		cache: false,
		method: 'POST',
		dataType: 'text',
		url: url,
		// username: ftui.config.username,
		// password: ftui.config.password,
		data: 'content=' + data,
		error: function (jqXHR, textStatus, errorThrown) {
			console.log("FUIP: File import failed: " + textStatus + ": " + errorThrown);
			ftui.toast("FUIP: File import failed: " + textStatus + ": " + errorThrown,"error");
		}
	});
};
					
					
function autoArrange() {
	var name = $("html").attr("data-name");
	var pageId = $("html").attr("data-pageid");
	var viewId = $("#viewsettings").attr("data-viewid");
	var fieldid = $("html").attr("data-fieldid");	
	var cmd = "set " + name + " autoarrange " + pageId + "_" + viewId;
	if(fieldid) {
		cmd += " " + fieldid;
	};	
	sendFhemCommandLocal(cmd).done(function() {
		location.reload(true);
	});	
};
					
					
function acceptSettings(doneFunc) {
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
	$("#viewsettings input, #viewsettings textarea, #viewsettings select.fuip").each(function() {
		var value;
		if($(this).attr("type") == "checkbox") {
			value = ($(this).is(":checked") ? 1 : 0);
		}else{	
			value = $(this).val();
			// FHEM needs ;; instead of ;
			// value = value.replace(/;/g , ";;");
			// parseParams does not have any escape mechanism for quotes...
			//value = value.replace(/\\/g,"\\\\");  // backslash doubled
			//value = value.replace(/"/g,"\'");	// double quote becomes escaped single quote
			value = encodeURIComponent(value);
		};	
		value = '"' + value + '"'; 
		cmd += " " + $(this).attr("id") + "=" + value;
	});
	var name = $("html").attr("data-name");
	var pageId = $("html").attr("data-pageid");
	var viewId = $("#viewsettings").attr("data-viewid");	
	var fieldId = $("#viewsettings").attr("data-fieldid");
	if(fieldId) {
		// dialog (popup) settings
		cmd = "set " + name + " viewcomponent " + pageId + "_" + viewId + " " + fieldId + cmd; 
	}else{	
		cmd = "set " + name + " viewsettings " + pageId + "_" + viewId + cmd; 
	};	
	// TODO: error handling when sending command
	sendFhemCommandLocal(cmd).done(function() {
		if(doneFunc) {
			doneFunc();
		}else{	
			location.reload(true);
		};	
	});	
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

					
function deleteView() {
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
		$('#'+id+'-value').attr("style","padding:1px 0px;");
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
		$('#'+id+'-value').attr("style","padding:1px 0px;visibility:hidden;");
		switch(defaultDef.type) {
			case 'const':
				inputField.val(defaultDef.value);
				break;
			case 'field':
				var value = $("#" + defaultDef.value).val();
				if(defaultDef.hasOwnProperty("suffix")) {
					value += defaultDef.suffix;
				};	
				inputField.val(value);
				break;
			default:
				break;
		};
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
					
					
// classField is the field (input) with the new class name
function classChanged(classField) {
	var elemName = classField.id.slice(0,-6);
	var settingsDialog = $( '#' + elemName );
	settingsDialog.html('Just a moment...');
	var name = $("html").attr("data-name");
	var cmd = "get " + name + " viewdefaults " + classField.value;
	sendFhemCommandLocal(cmd).done(function(settingsJson){
		var html = '<h3>';
		var title = 'New ' + classField.value;
		html += title + '</h3><div>' + createSettingsTable(json2object(settingsJson), elemName + '-') + '</div>';
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
	$(function() {
		$('#' + fieldName + '-value').button({
			icon: 'ui-icon-triangle-1-s',
			showLabel: false
		});		
	});		
	return "<table><tr>" +
			"<td><label for='" + fieldName + "'>View type</label></td>" +  
			"<td><input type='text'" +
			" name='" + fieldName + "' id='" + fieldName + "' " +
			"style='width:185px;visibility:visible;background-color:#EBEBE4;' readonly " +
			"value='" + selectedClass + "' " +
			"oninput='classChanged(this)' > " +
			"<button id='" + fieldName + "-value' onclick='valueHelp(\""+fieldName+"\",\"class\")' type='button' style='padding:1px 0px;'>Possible values</button></td>" +
			"</tr></table>";		
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
	
	
function valueHelp(fieldName,type) {
	// device help has its own function
	if(type == "device" || type == "device-reading" && fieldName.match(/-device$/) ) {
		valueHelpForDevice(fieldName, 
			function(value) {
				$('#'+fieldName).val(value);
				$('#'+fieldName).trigger("input");
			},false);
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
		var cmd = "get " + name + " viewclasslist";
		sendFhemCommandLocal(cmd).done(function(classListJson){
			var classList = json2object(classListJson);
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
							+ classList[i].id.replace(/::/g,"-") + ".png'>";
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
		for(var i = 0; i < deviceList.length; i++){
			if(deviceList[i].room == "") {
				deviceList[i].room = "unsorted";
			};	
			html += "<tr id='valuehelp-row-"+i+"' data-selected='' data-key='"+deviceList[i].NAME+"'><td>"+deviceList[i].NAME+"</td>";
			if(aliasUsed) {
				html += "<td>"+deviceList[i].alias+"</td>";
			};
			html += "<td>"+deviceList[i].TYPE+"</td><td>"+deviceList[i].room+"</td></tr>";
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
	var name = $("html").attr("data-name").toLowerCase();
	var pageId = $("html").attr("data-pageid");
	var viewId = $("#viewsettings").attr("data-viewid");
	// if this is already the popup maintenance (popup in popup), then we need to concat
    // the field names
	var lowerFieldId = $("html").attr("data-fieldid");
	var fullFieldName;
	if(lowerFieldId) {
		fullFieldName = lowerFieldId + "-" + fieldName; 
	}else{
		fullFieldName = fieldName;
	};	
	window.location.href = location.origin + "/fhem/" + name + "/fuip/popup?pageid=" + pageId + "&cellid=" + viewId + "&fieldid=" + fullFieldName;
};	


function createField(settings, fieldNum, component,prefix) {
    var field = settings[fieldNum];
	var fieldComp = field;
	var fieldNameWoPrefix = field.id;
	for(var i = 0; i < component.length; i++) {
		fieldComp = fieldComp[component[i]];
		fieldNameWoPrefix += "-" + component[i];
	};
	var fieldName = prefix + fieldNameWoPrefix;
	
	var fieldValue = (fieldComp.value + '').replace(/'/g, "&#39;");
	var checkVisibility = "hidden";
	var checkValue = "";
	var fieldStyle = "style='visibility: visible;'";
	var defaultDef = '{type: "none"}';
	if(fieldComp.hasOwnProperty("default")){
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
	$(function() {
		$('#' + fieldName + '-value').button({
			icon: 'ui-icon-triangle-1-s',
			showLabel: false
		});		
	});		
	var result = "<input type='checkbox' id='" + fieldName + "-check' style='visibility: " + checkVisibility + ";'" 
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
	}else{
		if(fieldComp.hasOwnProperty("options") && field.type != "setoptions"){
			result += "<select class='fuip'";
			if(parseInt(fieldComp.default.used)) {
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
		if(field.type == "setoptions" && fieldComp.hasOwnProperty("options")) {
			result += "data-options='"+JSON.stringify(fieldComp.options)+"' ";
		};	
		result += "value='" + fieldValue + "' " 
				+ fieldStyle + " oninput='inputChanged(this," + JSON.stringify(influencedFields) +")' >";
		// are there options to show? (dropdown)
		if(fieldComp.hasOwnProperty("options") && field.type != "setoptions"){
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
	if(field.type == "device" || field.type == "device-reading" || field.type == "reading" || field.type == "icon" || field.type == "set" || field.type == "setoptions" || field.type == "setoption") {
		result += "<button id='" + fieldName + "-value' onclick='valueHelp(\""+fieldName+"\",\""+field.type+"\")' type='button' style='padding:1px 0px;" 
		// value help invisible?
		if(checkVisibility == "visible" && checkValue != " checked") {
			result += "visibility:hidden;";
		};	
		result += "'>Possible values</button>";
	};	
	return result;
};


function createViewArray(field,prefix) {
    var items = field.value;
	// the current number of items and the (so far) highest item number is stored in the accordion itself
	var result = '<div  class="ui-widget-content" style="border-width: 2px;"><div id="' + prefix + field.id + '-accordion" data-length="' + items.length + '" data-nextindex="' + items.length + '">';
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
	result += '</div></div>';
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
	});
	return result;
};
					

function createSettingsTable(settings,prefix) {
	// this is for one single settings-Array
	// prefix is put in front of all field names (ids)
	var html = "";
	for(var i = 0; i < settings.length; i++){
		if(settings[i].type != 'class') { continue; }; 
		if(settings[i].value == 'FUIP::Cell' || settings[i].value == 'FUIP::Page' 
			|| settings[i].value == 'FUIP::Dialog') { break; };
		html += createClassField(settings[i].value,prefix);
		break;
	};
	html += '<table style="border-style: solid;">';
	for(var i = 0; i < settings.length; i++){
		if(settings[i].type == 'class') { continue; };
		var fieldName = prefix + settings[i].id;		
		switch(settings[i].type) {
			case 'device-reading':
				html += "<tr><td style='text-align:right'><label for='" + fieldName + "'>" + settings[i].id + "</label></td><td style='text-align:left;white-space:nowrap;'>";
				html += createField(settings, i, ["device"],prefix) + createField(settings, i, ["reading"],prefix);
				break;
			case 'viewarray':
				var fieldNameInTicks = '"' + fieldName + '"'; 
				html += "<tr><td style='text-align:left'><label for='" + fieldName + "'>" + settings[i].id + "</label></td><td><button id='" + fieldName + "-add' onclick='viewAddNewToArray("+fieldNameInTicks+")' type='button'>Add new view to " + settings[i].id + "</button></td>" + 
				"<td><button id='" + fieldName + "-addByDevice' onclick='viewAddNewByDevice("+fieldNameInTicks+")' type='button'>Add views by device to " + settings[i].id + "</button></td></tr>"
					+ "<tr><td colspan='3' style='text-align:left'>";
				html += createViewArray(settings[i],prefix) + '</label>';
				// make the button a jquery ui button
				$(function() {
					$('#' + fieldName + '-add').button({
						icon: 'ui-icon-plus',
						showLabel: false
					});		
					$('#' + fieldName + '-addByDevice').button({
						icon: 'ui-icon-plus',
						label: 'by device',
						showLabel: true
					});			
				});
				break;
			default:
				html += "<tr><td style='text-align:right'><label for='" + fieldName + "'>" + settings[i].id + "</label></td><td style='text-align:left'>";
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

								
function changeSettingsDialog(settingsJson,viewId,fieldId) {
	// fieldId is set in the "popup maintenance mode"
	var settingsDialog = $( "#viewsettings" );
	var title = "Settings cell " + viewId;
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
			showLabel: false },
		{   text: 'Arrange views (auto-layout)',
			icon: 'ui-icon-calculator',
			click: function() { acceptSettings(autoArrange); } ,
			showLabel: false }];
	if(!fieldId) {
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
	buttons.push(
			{	text: 'Export ' + (fieldId ? 'dialog' : 'cell'),
				icon: ' ui-icon-arrowstop-1-s',
				click: function() { acceptSettings( function() { 
							var downloadUrl = location.origin + '/fhem/' 
									+ $("html").attr("data-name").toLowerCase() 
									+ '/fuip/export?pageid=' + $("html").attr("data-pageid") 
									+ '&cellid=' + $("#viewsettings").attr("data-viewid");
							if(fieldId) {
								downloadUrl += '&fieldid='+fieldId;
							};	
							location.href = downloadUrl;
						});},
				showLabel: false },
			{	text: 'Import ' + (fieldId ? 'dialog' : 'cell'),
				icon: ' ui-icon-arrowstop-1-n',
			// the following attaches the input field for the file dialog to this function itself
			// it seems that otherwise, it happens that the garbage collector deletes variable "input"
				click: function() { fuip.fileInput = $('<input type="file">');
									fuip.fileInput.on("change",function(evt){
										fuip.fileInput = undefined;  // not needed anymore
										var reader = new FileReader();
										reader.onload = function(e) {
											// TODO: error handling when sending command
											postImportCommand(e.target.result,true,$("html").attr("data-pageid"))
												.done(function(msg) {
													if(msg == "OK") {
														location.reload(true);
													}else{	
														popupError("Import " + (fieldId ? 'dialog' : 'cell') + ": Error",msg);
													};
												});		
										};	
										reader.readAsText(evt.target.files[0]);
									});
									fuip.fileInput.click();
									// for some (unknown to me) reason, this does not work with the usual construct
									// however, the import of a cell does not change the cell or the content of the
									// config popup anyway, so we can just do it "afterwards"
									if(!fieldId){ // for dialog, we anyway overwrite the current state
										acceptSettings( function() {} );  // avoid immediate reload
									};	
								},	
				showLabel: false });
	if(!fieldId) {
		buttons.push(	
			{   text: 'Delete cell',
				icon: 'ui-icon-trash',
				click: deleteView,
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
					
				
function openSettingsDialog(name, pageId, viewId, fieldId) {
	// fieldId is "optional". If set, we are maintaining a popup.
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
	// XMLHTTP request to get config options with current values
	var cmd = "get " + name + " ";
	if(fieldId) {
		// popup or so
		cmd += "viewcomponent " + pageId + "_" + viewId + " " + fieldId;
	}else{
		cmd += "cellsettings " + pageId + "_" + viewId;
	};	
	sendFhemCommandLocal(cmd).done(function(settingsJson){
		changeSettingsDialog(settingsJson,viewId,fieldId);
		settingsDialog.attr("data-mode","cell");
		settingsDialog.attr("data-viewid",viewId);
		// popup maint?
		if(fieldId) {
			settingsDialog.attr("data-fieldid",fieldId);
		};	
		settingsDialog.dialog("open");
	});	
};
			
			
function copyCurrentPage() {
	// get current name and page id
	var name = $("html").attr("data-name");
	var pageid = $("html").attr("data-pageid");
	// create popup to input new page id
	var popup;	
	popup = $( "#inputpopup01" ).dialog({
		autoOpen: false,
		width: 400,
		height: 250,
		modal: true,
		title: "Enter name of new page",
		buttons: [{
			text: 'Ok',
			icon: 'ui-icon-check',
			click: function() {
				var newname = $("#newpagename").val();			
				if(!newname.length) { return; }; // page needs a name
				// TODO: This allows overwriting page "home". Is this good?
				sendFhemCommandLocal("set " + name + " pagecopy " + pageid + " " + newname)
					.done(function() {
						window.location = "/fhem/" + name.toLowerCase() +"/page/"+newname;
					});	
			},
			showLabel: false },
		  { text: 'Cancel',
			icon: 'ui-icon-close',
			click: function() {	popup.dialog( "close" ); },
			showLabel: false }
		],
	});
	popup.html('<form onsubmit="return false;">'+
					'<label for="newpagename">New page name</label>'+
					'<input type="text" id="newpagename" style="visibility:visible;" value="'+pageid+'_copy"/>'+
				'</form>');
	popup.dialog("open");
};	
			

function importAsNewPage(content) {
	// get current name and page id
	var name = $("html").attr("data-name");
	// create popup to input new page id
	var popup;	
	popup = $( "#inputpopup01" ).dialog({
		autoOpen: false,
		width: 400,
		height: 250,
		modal: true,
		title: "Import page: enter name of new page",
		buttons: [{
			text: 'Ok',
			icon: 'ui-icon-check',
			click: function() {
				var newname = $("#newpagename").val();			
				if(!newname.length) { return; }; // page needs a name
				// TODO: This allows overwriting any page. Is this good?
				postImportCommand(content,false,newname)
					.done(function(msg) {
						if(msg == "OK") {
							window.location = "/fhem/" + name.toLowerCase() + "/page/"+newname;
						}else{	
							popupError("Import page: Error",msg, function() { popup.dialog("close"); } );
						};
					});	
			},
			showLabel: false },
		  { text: 'Cancel',
			icon: 'ui-icon-close',
			click: function() {	popup.dialog( "close" ); },
			showLabel: false }
		],
	});
	popup.html('<form onsubmit="return false;">'+
					'<label for="newpagename">New page name</label>'+
					'<input type="text" id="newpagename" style="visibility:visible;" value=""/>'+
				'</form>');
	popup.dialog("open");
};	

			
function toggleCellPage() {
	var settingsDialog = $( "#viewsettings" );
	settingsDialog.html("Just a moment...");
	var mode = settingsDialog.attr("data-mode");
	if(mode == "page") {
		// switch to "cell"
		openSettingsDialog($("html").attr("data-name"),$("html").attr("data-pageid"),settingsDialog.attr("data-viewid"));
	}else{
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
			{	text: 'Export page',
				icon: ' ui-icon-arrowstop-1-s',
				click: function() { acceptPageSettings( function() { location.href = location.origin + '/fhem/' + $("html").attr("data-name").toLowerCase() + '/fuip/export?pageid=' + $("html").attr("data-pageid"); })},
				showLabel: false },	
			{	text: 'Import page',
				icon: ' ui-icon-arrowstop-1-n',
				// the following attaches the input field for the file dialog to this function itself
				// it seems that otherwise, it happens that the garbage collector deletes variable "input"
				click: function() { toggleCellPage.input = $('<input type="file">');
									toggleCellPage.input.on("change",function(evt){
										toggleCellPage.input = undefined;  // not needed anymore
										var reader = new FileReader();
										reader.onload = function(e) {
										//var	cmd = "set uilocal import bla_001 " + e.target.result; 
										// TODO: error handling when sending command
											importAsNewPage(e.target.result);
									};	
									reader.readAsText(evt.target.files[0]);
								});
								toggleCellPage.input.click();
								acceptPageSettings(function(){});  // avoid page reload
				},
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
			click: function() {
				var newname = $("#newpagename").val();			
				sendFhemCommandLocal("set " + name + " cellcopy " + pageid + "_" + viewid + " " + newname)
					.done(function() {
						window.location = "/fhem/"+name+"/page/"+newname;
					});	
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
			
			
