// everything which should be run after the page has loaded
var fuipGridster;

function fuipInit(baseWidth,baseHeight) {
	$( function() {
		// the settings dialog
		var viewsettings;
		viewsettings = $( "#viewsettings" ).dialog({
			autoOpen: false,
			width: 675,
			modal: true,
		});
		$(function() {
			$('.ui-dialog-titlebar').append('<button id="togglecellpage" type="button" style="position:absolute;top:0px;left:0px;" onclick="toggleCellPage()">Cell/Page</button>');
			$('#togglecellpage').button({
				icon: 'ui-icon-transferthick-e-w',
			});		
		});
		
		// every view is draggable					
		$(".fuip-draggable").each(function() {
			$(this).draggable({
				revert: "invalid",
				stack: ".fuip-draggable"
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
		fuipGridster =  $(".gridster ul").gridster({
			widget_base_dimensions: [baseWidth,baseHeight],
			widget_margins: [5, 5],
			resize: {
				enabled: true,
				stop: onGridsterChangeStop	
			},
			draggable: {
				handle: "header",
				stop: onGridsterChangeStop	
			}	
		}).data('gridster');
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
				
				
							
// when a view is dropped on a cell
function onDragStop(cell,ui) {
	var cellId = cell.attr("data-cellid");
	var view = ui.draggable;
	var viewId = view.attr("data-viewid");
	var name = $("html").attr("data-name");
	var pageId = $("html").attr("data-pageid");
	var cmd = "set " + name;
	var oldCellId = view.closest("li").attr("data-cellid");
	if(oldCellId != cellId) {
		var oldCellPos = view.closest("li").position();
		var newCellPos = cell.position();
		cmd = cmd + " viewmove " + pageId + "_" + oldCellId + "_" + viewId + " " + cellId + " " + (ui.position.left + oldCellPos.left - newCellPos.left) + " " + (ui.position.top + oldCellPos.top - newCellPos.top - 22); 
		// TODO: error handling when sending command
		sendFhemCommandLocal(cmd);
		location.reload(true);
		return;
	};	
	cmd = cmd + " viewposition " + pageId + "_" + cellId + "_" + viewId + " " + ui.position.left + " " + (ui.position.top - 22); 
	// TODO: error handling when sending command
	sendFhemCommandLocal(cmd);
	location.reload(true);
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
			// fwcsrf: ftui.config.csrf,
			XHR: "1"
		}
	});
};
					
					
function autoArrange() {
	var name = $("html").attr("data-name");
	var pageId = $("html").attr("data-pageid");
	var viewId = $("#viewsettings").attr("data-viewid");	
	var cmd = "set " + name + " autoarrange " + pageId + "_" + viewId; 
	// TODO: error handling when sending command
	sendFhemCommandLocal(cmd);
	location.reload(true);
};
					
					
function acceptSettings() {
	var cmd = '';
	// collect classes
	$("#viewsettings .class-select").each(function() {
		var value;
		value = '"' + $(this).val() + '"';
		cmd += " " + $(this).attr("id") + "=" + value;
	});
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
	$("#viewsettings input, #viewsettings textarea").each(function() {
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
	cmd = "set " + name + " viewsettings " + pageId + "_" + viewId + cmd; 
	// TODO: error handling when sending command
	sendFhemCommandLocal(cmd);
	$("#viewsettings").dialog( "close" );
	location.reload(true);
};


function acceptPageSettings() {
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
	sendFhemCommandLocal(cmd);
	$("#viewsettings").dialog( "close" );
	location.reload(true);
};


function viewAddNew() {
	var name = $("html").attr("data-name");
	var pageId = $("html").attr("data-pageid");
	cmd = "set " + name + " viewaddnew " + pageId; 
	// TODO: error handling when sending command
	sendFhemCommandLocal(cmd);
	$("#viewsettings").dialog( "close" );
	location.reload(true);
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
	sendFhemCommandLocal(cmd);
	$("#viewsettings").dialog( "close" );
	location.reload(true);
};
					
					
function inputChanged(inputElem,influencedFields) {
	for(var i = 0; i < influencedFields.length; i++) {
		// default or own value?
		if($('#' + influencedFields[i] + '-check').is(':checked')) { continue; };
		// default, set parent value
		$('#' + influencedFields[i]).val($(inputElem).val());
	};
};
					
					
function defaultCheckChanged(id,defaultDef) {
	var inputField = $("#" + id);
	if($("#" + id + "-check").is(":checked")) {
		inputField.attr("style", "visibility: visible;");
		inputField.removeAttr("readonly");
		// value help visible
		$('#'+id+'-value').attr("style","padding:1px 0px;");
	}else{
		inputField.attr("style", "visibility: visible;background-color:#EBEBE4;");
		inputField.attr("readonly", "readonly");
		// value help invisible
		$('#'+id+'-value').attr("style","padding:1px 0px;visibility:hidden;");
		switch(defaultDef.type) {
			case 'const':
				inputField.val(defaultDef.value);
				break;
			case 'field':
				inputField.val($("#" + defaultDef.value).val());
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
					
					
function classChanged(event, data) {
	var elemName = 'viewsettings';
	if(event.target.id != 'class') {
		elemName = event.target.id.slice(0,-6);
	};
	var settingsDialog = $( '#' + elemName );
	settingsDialog.html('Just a moment...');
	var name = $("html").attr("data-name");
	var cmd = "get " + name + " viewdefaults " + data.item.value;
	sendFhemCommandLocal(cmd).done(function(settingsJson){
		if(event.target.id == 'class') {
			changeSettingsDialog(settingsJson, settingsDialog.attr("data-viewid"));
			return;
		};	
		// sub-view e.g. in viewarray
		var html = '<h3>';
		var title = 'New ' + data.item.value;
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
	$(function() {
		$("#" + fieldName).selectmenu({
			change: classChanged 
		});
		var name = $("html").attr("data-name");
		var cmd = "get " + name + " viewclasslist";
		sendFhemCommandLocal(cmd).done(function(classListJson){
			var classList = json2object(classListJson);
			var html = "<select id='" + fieldName + "' name='" + fieldName + "' class='class-select'>";
			for(var i = 0; i < classList.length; i++) {
				html +=  "<option" + (classList[i].id == selectedClass ? " selected" : "") + ">" + classList[i].id + "</option>";
			};
			html += "</select>";
			$("#" + fieldName).html(html);
		});
	});
	return "<label>View type " +  
				"<select id='" + fieldName + "' name='" + fieldName + "' class='class-select'>" +
						"<option selected>" + selectedClass + "</option>" +
				"</select>" +
			"</label>";		
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
	

function valueHelp(fieldName,type) {
	// device help has its own function
	if(type == "device" || type == "device-reading" && fieldName.match(/-device$/) ) {
		valueHelpForDevice(fieldName, 
			function(value) {
				$('#'+fieldName).val(value);
				$('#'+fieldName).trigger("input");
			});
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
	if(type == "device-reading" && fieldName.match(/-reading$/) ) {
		var deviceFieldName = fieldName.replace(/-reading$/,"-device");
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
			$(function() {
				$( "#valuehelptable tbody tr" ).on( "click", function() {
					// alert( $( this ).text() );
					var oldSelected = $('#valuehelptable').attr('data-selected');
					if(oldSelected.length) {
						$('#'+oldSelected).removeAttr("style"); 	
					};	
					$('#valuehelptable').attr('data-selected',$(this).attr('id'));
					$(this).attr("style", "background: #F39814;");
				});
			});	
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
			$( "#valuehelptable tbody tr" ).on( "click", function() {
				// alert( $( this ).text() );
				var oldSelected = $('#valuehelptable').attr('data-selected');
				if(oldSelected.length) {
					$('#'+oldSelected).children("td").removeAttr("style"); 	
				};	
				$('#valuehelptable').attr('data-selected',$(this).attr('id'));
				$(this).attr("style", "background: #F39814;");
				$(this).children("td").attr("style", "background: #F39814;");
			});
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
				$( "#valuehelptable tbody tr" ).on( "click", function() {
					// alert( $( this ).text() );
					var oldSelected = $('#valuehelptable').attr('data-selected');
					if(oldSelected.length) {
						$('#'+oldSelected).children("td").removeAttr("style"); 	
					};	
					$('#valuehelptable').attr('data-selected',$(this).attr('id'));
					$(this).children("td").attr("style", "background: #F39814;");
				});
			});	
		});	
	}else{
		valueDialog.html("No value help for this field.");
	};
};	


function valueHelpForDevice(fieldTitle, callbackFunction, multiSelect = false) {
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
		var html = "<table id='valuehelptable' class='tablesorter'><thead><tr><th>Name</th><th class=\"filter-select filter-onlyAvail\">Type</th><th>Room(s)</th></tr></thead>";
		html += "<tbody>";
		var roomFilters = {};
		for(var i = 0; i < deviceList.length; i++){
			if(deviceList[i].room == "") {
				deviceList[i].room = "unsorted";
			};	
			html += "<tr id='valuehelp-row-"+i+"' data-selected='' data-key='"+deviceList[i].NAME+"'><td>"+deviceList[i].NAME+"</td><td>"+deviceList[i].TYPE+"</td><td>"+deviceList[i].room+"</td></tr>";
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
		$(function() {
			$(".tablesorter").tablesorter({
				theme: "blue",
				widgets: ["filter"],
				widgetOptions: {
					filter_functions: {
						2 : orderedRoomFilters
					}
				}	
			});
			$( "#valuehelptable tbody tr" ).on( "click", function() {
				if(multiSelect) {
					if($(this).attr('data-selected') == 'X') {
						$(this).attr('data-selected','');
						$(this).children("td").removeAttr("style"); 	
					}else{
						$(this).attr('data-selected','X');
						$(this).children("td").attr("style", "background: #F39814;");
					};				
				}else{  // single select
					$("tr[data-selected='X']").each(function(){
						$(this).attr('data-selected','');
						$(this).children("td").removeAttr("style"); 							
					});
					$(this).attr('data-selected','X');					
					$(this).children("td").attr("style", "background: #F39814;");
				};	
			});
		});	
	});	
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
		var defaultVal = (fieldComp.default.type == 'const' ? '' : prefix) + fieldComp.default.value; 
		defaultDef = '{type: "' + fieldComp.default.type + '", value: "' + defaultVal + '"}';
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
			+ checkValue + " onchange='defaultCheckChanged(" + fieldNameInBrackets + "," + defaultDef + ")'>";
	if(field.type == "longtext") {
		result += "<textarea rows='5' cols='50' name='" + fieldName + "' id='" + fieldName + "' " 
			+ fieldStyle + " oninput='inputChanged(this," + JSON.stringify(influencedFields) +")' >"
			+ fieldValue + "</textarea>";
	}else{
		result += "<input type='text' name='" + fieldName + "' id='" + fieldName + "' ";
		if(fieldComp.hasOwnProperty("options")){
			result += "list='" + fieldName + "-list' ";
		};
		result += "value='" + fieldValue + "' " 
				+ fieldStyle + " oninput='inputChanged(this," + JSON.stringify(influencedFields) +")' >";
	};	
	// are there options to show?
	if(fieldComp.hasOwnProperty("options")){
		result += "<datalist id='" + fieldName + "-list'>";
		for(var i = 0; i < fieldComp.options.length; i++) {
			result += "<option value='" + fieldComp.options[i] + "'>";
		};	
		result += "</datalist>";
	};	
	// do we have a value help?
	if(field.type == "device" || field.type == "device-reading" || field.type == "icon") {
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
		if(settings[i].value == 'FUIP::Cell' || settings[i].value == 'FUIP::Page') { break; };
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
	var o = JSON.parse(json);
	decodeObject(o);
	return o;
};	

										
function changeSettingsDialog(settingsJson,viewId) {
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
	settingsDialog.dialog("option","buttons",
		[{
			text: 'Ok',
			icon: 'ui-icon-check',
			click: acceptSettings,
			showLabel: false },
		{   text: 'Arrange views (auto-layout)',
			icon: 'ui-icon-calculator',
			click: autoArrange,
			showLabel: false },								
		{   text: 'Add new cell',
			icon: 'ui-icon-plus',
			click: viewAddNew,
			showLabel: false },
		{	text: 'Copy cell',
			icon: 'ui-icon-copy',
			click: copyCurrentCell,
			showLabel: false },
		{   text: 'Delete cell',
			icon: 'ui-icon-trash',
			click: deleteView,
			showLabel: false },	
		{   text: 'Cancel',
			icon: 'ui-icon-close',
			click: function() {	settingsDialog.dialog( "close" ); },
			showLabel: false },
		{	text: 'Toggle editOnly',
			click: function() {
				var easyDrag = $('html').attr('data-editonly');
				if(easyDrag == "0") {
					easyDrag = "1";
				}else{
					easyDrag = "0";
				};
				sendFhemCommandLocal("set " + $("html").attr("data-name") + " editOnly " + easyDrag).
					done(function(){ location.reload(true) });
			} }
		]);
};
					
				
function openSettingsDialog(name, pageId, viewId) {
	var settingsDialog = $( "#viewsettings" );
	// XMLHTTP request to get config options with current values
	var cmd = "get " + name + " cellsettings " + pageId + "_" + viewId;
	sendFhemCommandLocal(cmd).done(function(settingsJson){
		changeSettingsDialog(settingsJson,viewId);
		settingsDialog.attr("data-mode","cell");
		settingsDialog.attr("data-viewid",viewId);
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
				if(!newname.length) { return; }; // don't overwrite home page
				sendFhemCommandLocal("set " + name + " pagecopy " + pageid + " " + newname)
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
	popup.html('<form onsubmit="return false;">'+
					'<label for="newpagename">New page name</label>'+
					'<input type="text" id="newpagename" style="visibility:visible;" value="'+pageid+'_copy"/>'+
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
				click: acceptPageSettings,
				showLabel: false },
			{	text: 'Copy page',
				icon: 'ui-icon-copy',
				click: copyCurrentPage,
				showLabel: false },
			{   text: 'Cancel',
				icon: 'ui-icon-close',
				click: function() {	settingsDialog.dialog( "close" ); },
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
			
			
