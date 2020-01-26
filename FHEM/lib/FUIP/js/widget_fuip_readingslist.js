/*

Thorsten Pferdekaemper 2020

TODO: 
	Allow multiple readings / different readings per device
	Formatting of timestamp
*/

/* 
Data fields
	device	: Can be one device or a list (array) of devices
	alias	: List of alias-names for all devices
				Must have the same number of entries as device
	reading	: Can be one reading or a list (array) of readings
				Default is "state"
	value	: Regex. Only entries are displayed where value
				matches the value of the reading
				Default is empty, i.e. display does not depend
				on value.
	detail	: List of "device", "reading", "value", "timestamp"
				These are the columns which are displayed
				Default is device and value
				
Which lines are displayed?
	All combinations of device:reading according to the lists in 
	data-device and data-reading. I.e. if there are 5 entries in 
	data-device and 4 in data-reading, up to 20 lines are displayed.
	However, only combinations which really exist are displayed.
	The list is also filtered according to data-value.
	
Which columns are displayed?
	Columns are according to data-detail. If data-alias is filled,
	then the alias is displayed and not the device name.

When does it refresh?	
	It does a refresh (update) whenever a device:reading "triggers". 
	However, the combination must have existed already at the first 
	update, i.e. the last browser refresh or initial loading of the page.
	
In which order?
	If alias is given, then sorted by alias. Otherwise by device name.
	If multiple readings per device, then also ordered by reading name.
	The columns are ordered as given in data-detail.	
	
*/



"use strict";

var Modul_fuip_readingslist = function () {
	
	function refresh(elem) {
		// The following should ensure that the first refresh after a while
		// is done immediately, but that there is at least one second between
		// two refreshes.
		var timeToNextRefresh = 1000 - (Date.now() - elem.data("lastRefresh"));
		if(timeToNextRefresh <= 0) {
			refreshNow(elem);
			return;
		};	
		// ...not yet
		if(!elem.data("timer")) {
			// only start timer if not anyway running
			elem.data("timer",setTimeout(refresh,timeToNextRefresh,elem));
		};
	};
	
	
	function refreshNow(elem) {	
		elem.data("lastRefresh",Date.now());
		if(elem.data("timer")) {
			clearTimeout(elem.data("timer"));
			elem.data("timer",0);
		};	
		// now really do it
		elem.empty();
		var readings = elem.data('triggers');
		var regex = new RegExp(elem.data('value'));
		var alias = elem.data('alias');
		var detail = elem.data('detail');
		var html = '<div style="width:100%;height:100%;overflow-x:hidden;overflow-y:auto;"> <table>';
		for(var i = 0; i < readings.length; i++) {
			var entry = elem.getReading('triggers',i);
			if($.isEmptyObject(entry)) continue;
			if(!entry.valid) continue;
			if(!regex.test(entry.val)) continue;	
			var reading = readings[i].split(':');
			html += '<tr>';
			for(var j = 0; j < detail.length; j++) {
				html += '<td style="padding-right:10px;padding-bottom:5px;"><div class="fuip-color big" style="white-space:nowrap;text-align:left;">'; 
				switch(detail[j]) {
					case 'device':
						html += alias[reading[0]];
						break;
					case 'reading':
						html += reading[1];
						break;
					case 'value':
						html += entry.val;
						break;
					case 'timestamp':
						html += entry.date;
						break;
					default:
						html += detail[j];
				};
				html += '</div></td>';
			};
			html += '</tr>';
		};	
		html += '</table></div>';
		elem.append($(html));
	};	
	
	
	function initDataAndReturnArray(elem,name,defVal) {
		elem.initData(name,defVal);
		var result = elem.data(name);
		if(Array.isArray(result)) return result;
		if(result){
			result = [result];
		}else{	
			result = [];
		};
		elem.data(name,result);
		return result;	
	};	
	
	
	function init_attr(elem) {
		var devices = initDataAndReturnArray(elem,'device',false);
		var aliasAr = initDataAndReturnArray(elem,'alias',devices);
		var readings = initDataAndReturnArray(elem,'reading','state');
		elem.initData('value','');
		initDataAndReturnArray(elem,'detail',['device','value']);
		var aliasObj = {};
		for(var i = 0; i < devices.length; i++) {
			if(i < aliasAr.length) {
				aliasObj[devices[i]] = aliasAr[i];
			}else{
				aliasObj[devices[i]] = devices[i];
			};	
		};	
		elem.data('alias',aliasObj);
		// make sure this is sorted by alias|reading
		devices.sort(function(a,b) {
			return aliasObj[a].localeCompare(aliasObj[b]); 
		});	
		readings.sort();  
		var triggers = [];
		var k = 0;
		for(var i = 0; i < devices.length; i++) {
			for(var j = 0; j < readings.length; j++) {
				triggers[k++] = devices[i] + ":" + readings[j];
			};				
		};	
		elem.initData("triggers",triggers);
		me.addReading(elem, 'triggers');
		elem.data("lastRefresh",0);
		elem.data("timer",0); 
		$(document).on("updateDone", function() { refreshNow(elem); });
	};
	
	
    function update(dev,par) {
		me.elements.filterDeviceReading('triggers', dev, par)
		.each(function (index) {
			refresh($(this));			
		});	
    };
	
	
	/* function init_ui(elem) {
    }*/
	

    var me = $.extend(new Modul_widget(), {
        widgetname: 'fuip_readingslist',
        init_attr:init_attr,
	//	init_ui: init_ui,
		update: update,
    });

	return me;

};