/* FTUI Plugin
 * originally created by Thomas Nesges,
 * enhanced by Mario Stephan <mstephan@shared-files.de> 2016
 * Made working (not exclusively) for FUIP by Thorsten Pferdekaemper 2019
 * Under MIT License (http://www.opensource.org/licenses/mit-license.php)
 */
 
 /* Attributes
	data-device: ReadingsGroup
	data-max-update: Number of seconds after which a change in a reading
					causes a complete update
	(data-get: this attribute is ignored)	

	Attribute alwaysTrigger of the readingsGroup needs to be set
	
*/					

"use strict";

var Modul_readingsgroup = function () {

    function init_attr(elem) {
		// 'get' is more or less a dummy here to
		// get the device in at all
		elem.data('get',['STATE']);
		// max-update means the time to a full update of the
		// widget. Updates of single readings are done immediately
        elem.initData('max-update', 60);
		// multi-columns 
		// 1 => no change
		// 2,3,4 : Distribute to 2,3,4 columns
		// everything else: like 1
		elem.initData('columns',1);
        me.addReading(elem, 'get');
    }

    function update(dev, par) {
        me.elements.each(function (index) {
            var elem = $(this);
			// we do not use filterDeviceReading, as we anyway
			// take everything from the device
			// in addition, the correct readings are not there 
			// with the first call
			if(elem.data('device') != dev) 
					return true;
			// complete or partial update?
			if(me.checkForCompleteUpdate(elem)) {
				me.doCompleteUpdate(elem);
			}else{
				me.doPartialUpdate(elem,dev,par);
			};	
        });
    };
	
	// check whether we have to update the whole thing
	function checkForCompleteUpdate(elem) {
		var lMaxUpdate = parseInt(elem.data('max-update'));
		// always update?
		if(lMaxUpdate == 0) return true;
		// never update?
		if(lMaxUpdate < 0) return false;
		var dNow = new Date();
        var lUpdate = elem.data('lastUpdate') || null;
        if(isNaN(lMaxUpdate)) lMaxUpdate = 60;  // use default
        if(dNow - lUpdate > lMaxUpdate * 1000){
			elem.data('lastUpdate',dNow);
			return true;
		};
		return false;
	};	

	
	function multiColumns(elem,newContent) {
		var columns = elem.data('columns');
		// only do anything for 2,3 or 4
		if(columns < 2 || columns > 4) return;
		var theTable = newContent.find("table#readingsGroup-"+elem.data('device'));
		var innerTables = new Array();
		for(var i = 0; i < columns; i++) {
			innerTables[i] = $("<table></table>");
		};	
		var i = 0;
		theTable.find("tr").each(function() {
			$(this).detach().appendTo(innerTables[i]);
			i++;
			if(i >= columns) i = 0;
		});
		var newLine = $("<tr></tr>");
		for(var i = 0; i < columns; i++) {
			if(i > 0) newLine.append($("<td><div style='width:15px'></div></td>"));
			newLine.append($("<td'></td>").append(innerTables[i]));
		};	
		theTable.empty().append(newLine);
	};	
	
	
	// do a complete update
	function doCompleteUpdate(elem) {
		var cmd = [ 'get', elem.data('device'), "html" ].join(' ');
        ftui.log('readingsgroup update', cmd);
        ftui.sendFhemCommand(cmd).done(function (data, dev) {
			var newElem = $(data);
			multiColumns(elem,newElem);
			elem.empty().append(newElem);
			var getList = {'STATE':1};					
			elem.find("[informId]").each(function() {
				var informId = $(this).attr('informId');
				var parts = informId.split('-');
				if( parts[1] === undefined )
					return;
				// is this a timestamp? Remove the -ts
				if(parts.length > 2 && parts[parts.length-1] == 'ts') {
					parts.pop();
					informId = informId.slice(0, -3);
				};	
				parts[1] = parts.splice(1).join('-');
				ftui.timestampMap[informId + '-ts'] = {device: parts[0], reading:parts[1]};
				ftui.paramIdMap[informId] = {device: parts[0], reading:parts[1]};
				getList[parts[0] + ':' + parts[1]] = 1;
			} );
			// check if this has changed anything, only then "restart" ftui
			var oldArray = elem.data('get');
			var newArray = Object.keys(getList);
			if(JSON.stringify(oldArray) != JSON.stringify(newArray)) {
				elem.data('get',newArray);
				me.addReading(elem,'get');
				plugins.updateParameters();		
			};	
        });
	};	
	
	
	// update only for one reading
	function doPartialUpdate(elem,dev,par) {
		if( par === 'STATE' ) return;
		try{  // it happens that this is called for stuff which does not exist
			var val = ftui.deviceStates[dev][par].val;
			elem.find("[informId='"+ dev+"-"+par+"']").each(function() {
				if(this.setValueFn)
					this.setValueFn(val);   
				else
					$(this).html(val);
			});
		} catch (err) { };
	};	
	

    // public
    // inherit all public members from base class
    var me = $.extend(new Modul_widget(), {
        //override or own public members
        widgetname: 'readingsgroup',
        init_attr: init_attr,
        update: update,
		// own functions
		checkForCompleteUpdate: checkForCompleteUpdate,
		doCompleteUpdate: doCompleteUpdate,
		doPartialUpdate: doPartialUpdate
    });
    return me;
};
