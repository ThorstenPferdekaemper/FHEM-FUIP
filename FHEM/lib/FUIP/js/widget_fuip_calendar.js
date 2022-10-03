/*

Thorsten Pferdekaemper 2019

*/

"use strict";

var Modul_fuip_calendar = function () {
	
	function data2eventlist(data) {
		var result = [];
		var lines = data.split(/\r|\n/);
		for(var i = 0; i < lines.length; i++) {
			if(!lines[i].length)
				continue;
			try {
				var event = JSON.parse(lines[i]);
				event.summary = decodeURIComponent(event.summary);
				event.description = decodeURIComponent(event.description);
				event.startSec = parseInt(event.startSec);
				event.endSec = parseInt(event.endSec);
				event.duration = event.duration;
				result.push(event);
			}catch(e) {
				console.log(lines[i]);
			};	
		};
		return result;		
	};	
	
	
	function renderList(elem,data) {
		var events = data2eventlist(data);
		var html = "<table style='border-collapse:collapse;'>";
		html += "<tr><th>Start</th><th>Dur.</th><th>Summary</th><th>Description</th><th>Location</th><th>Classification</th><th>Mode</th></tr>"
		for(var i = 0; i < events.length; i++) {
			html += "<tr>";
			var event = events[i];
			html += "<td style='border:1px solid lightgrey;'>"+event.start+"</td>";
			html += "<td style='border:1px solid lightgrey;'>"+event.duration+"</td>";
			html += "<td style='border:1px solid lightgrey;text-align:left;'>"+event.summary+"</td>";
			html += "<td style='border:1px solid lightgrey;text-align:left;'>"+event.description+"</td>";
			html += "<td style='border:1px solid lightgrey;text-align:left;'>"+event.location+"</td>"; 
			html += "<td style='border:1px solid lightgrey;text-align:left;'>"+event.classification+"</td>"; 
			html += "<td style='border:1px solid lightgrey;text-align:left;'>"+event.mode+"</td>";
			html += "</tr>";
		};	
		html += "</table>";
		elem.html(html);
	};	
	
	
	function popNextEventInInterval(events,start,end) {
		for(var i = 0; i < events.length; i++) {
			if(events[i].startSec < start) 
				continue;
			if(end && events[i].endSec > end)
				continue;
			var result = events[i];
			events.splice(i,1);
			return result;	
		};
		return false;	
	};	
	

	function getFullDayEvents(events,startOfWeek,endOfWeek) {
		// returns list of full day events in this week
		// these are also removed from original event list
		// in addition, events which have nothing to do with this week
		// are also removed
		// for events which start at 00:00 and end at 00:00, we assume that they are 
		// full-day events. 
		var result = [];
		for(var i = 0; i < events.length; i++) {
			// remove events which are not in this week
			if(events[i].startSec >= endOfWeek || events[i].endSec < startOfWeek) {
				events.splice(i,1);
				i--;
				continue;
			};	
			// does this start at 00:00 and end at 00:00 ?
			var dStart = new Date(events[i].startSec * 1000);
			var dEnd = new Date(events[i].endSec * 1000);
			if(dStart.getHours() || dStart.getMinutes() || dStart.getSeconds() ||
			   dEnd.getHours() || dEnd.getMinutes() || dEnd.getSeconds()) {
				continue;	
			};	 
			// now, dStart should be 00:00 of a day dEnd Should be
			// 00:00 of the day after the last day of the event
			// restrict on the week we are looking at
			if(events[i].startSec < startOfWeek) events[i].startSec = startOfWeek;
			if(events[i].endSec > endOfWeek) events[i].endSec = endOfWeek;
			result.push(events[i]);
			events.splice(i,1);
			i--;
		};	
		return result;
	};	
	
	
	function splitMultiDayEvents(events) {
		// changes events so that all events are within one day
		// i.e. events which span over midnight are split
		// TODO: We might need the original start/end/duration in order to display it properly
		for(var i = 0; i < events.length; i++) {
			var eStart = new Date(events[i].startSec * 1000);
			eStart.setHours(0,0,0,0);
			var endOfDay = eStart.valueOf() / 1000 + 86400;
			if(events[i].endSec > endOfDay) {
				var newEntry = Object.assign({}, events[i]);
				newEntry.startSec = endOfDay;
				newEntry.durationSec = newEntry.endSec - newEntry.startSec;
				events.push(newEntry);
				events[i].endSec = endOfDay;
				events[i].durationSec = events[i].endSec - events[i].startSec;
			};	
		};
	};	

	
	function isToday(t) {
		var now = new Date();
		now.setHours(0,0,0,0);
		var startOfDay = now.valueOf() / 1000;
		var endOfDay = startOfDay + 86400;
		return t >= startOfDay && t < endOfDay;		
	};	
	
	
	function renderDayGap(start,end) {
		var result = "";
		for(var t = start; t < end; t += 86400) {
			result += '<td style="border-style:none solid none solid; border-width:1px; border-color:lightgrey; height:1em;"';
			if(isToday(t)) {
				result += ' class="fuip-calendar-today"';
			};	
			result += '></td>';
		};	
		return result;
	};	
	
	
	function renderFullDayEvents(events,startOfWeek,endOfWeek) {
		var start = endOfWeek;
		var html = "";
		while(events.length) {
			// new line?
			if(start >= endOfWeek) {
				if(html.length) {
					html += "</tr>";
				};	
				html += '<tr><td style="border-right:1px solid lightgrey;height:1em;"></td>'; 
				start = startOfWeek;
			};	
			// get next event which might fit
			var event = popNextEventInInterval(events,start,endOfWeek);
			if(!event) {
				// none found but there are events: open next line
				html += renderDayGap(start, endOfWeek);
				start = endOfWeek;
				continue;
			};
			// we have an event
			// gap?
			html += renderDayGap(start,event.startSec);
			// render event itself
			var width = Math.round((event.endSec - event.startSec) / 86400);
			if(width) {  // TODO: what if not?
				html += '<td colspan="'+width+'" style="padding:0px 2px 0px 2px;border-style:none solid none solid; border-width:1px;border-color:lightgrey;"';
				if(isToday(event.startSec) && width == 1) {
					html += ' class="fuip-calendar-today"';
				};	
				var title = event.summary.replace(/"/g, '&quot;');
				html += '><div class="fuip-color-symbol-foreground" style="background-color:var(--fuip-color-symbol-active);border:1px solid lightgrey;border-radius:10px;padding:0px 2px 0px 4px;overflow:hidden;white-space:nowrap;text-overflow:ellipsis;" title="'+title+'">'+event.summary+'</div></td>';
			};
			start = event.endSec;
		};	
		return html + renderDayGap(start, endOfWeek) + "</tr>";	
	};	
	
	
	function overlap(event1,event2) {
		return event1.startSec < event2.endSec 
			&& event2.startSec < event1.endSec;
	}	
	
	
	function extractOverlapping(events,event) {
		var result = [];
		for(var i = 0; i < events.length; i++) {
			if(overlap(event,events[i])) {
				result.push(events[i]);
				events.splice(i,1);
				i--;
			};
		};	
		return result;	
	};	
	
	
	function extractNextOverlapComponent(events,event) {
		if(event) {
			var overlaps = extractOverlapping(events,event);
			var result = [event];
			for(var i = 0; i < overlaps.length; i++) {
				result = result.concat(extractNextOverlapComponent(events,overlaps[i]));
			};			
			return result;
		}else{
			var ev = events.shift();
			return extractNextOverlapComponent(events,ev);
		};
	};
	
	
	function solveConflicts(events) {
		// returns an array of array of events
		// so that each "column" contains only non-overlapping
		// events
		// ...and this is done per "component" of conflicting events
		// i.e. result is [component][column][row]
		var result = [];
		events.sort(function(a, b){return a.startSec - b.startSec});
		for(var compNum = 0; events.length; compNum++) {	
			result[compNum] = [];
			var component = extractNextOverlapComponent(events);
			for(var column = 0; component.length; column++) {
				result[compNum][column] = [];
				var start = 0;
				for(var row = 0; true; row++) {
					var event = popNextEventInInterval(component,start);
					if(!event) break;
					result[compNum][column][row] = event;
					start = event.endSec;
				}
			}	
		}
		return result;
	};	
		
	
	function determineFreeWidth(evtAr,evCol,event) {
		// checks how many cols "right" of event 
		// are without overlaps (result is then +1)
		// evCol is the col of the event itself
		var result = 1;	
		for(var col = evCol + 1; col < evtAr.length; col++) {
			for(var row = 0; row < evtAr[col].length; row++) {
				if(overlap(event,evtAr[col][row])) 
					return result;	
			}	
			result++;
		};	
		return result;
	};	
		
	
	function prevWeek(elem) {
		elem.data("weekOffset",elem.data("weekOffset")-1);
		refresh(elem);
	};	
		

	function nextWeek(elem) {
		elem.data("weekOffset",elem.data("weekOffset")+1);
		refresh(elem);
	};	


	function renderWeekHeader(elem,startOfWeek, endOfWeek) {
		var tr = $('<tr><td style="width:4em;"></td></tr>');
		var arrow = $('<div class="fa fa-arrow-circle-left big" style="cursor:pointer;" title="Vorherige Woche"></div>');
		arrow.click(function(){prevWeek(elem)});
		tr.append($('<td></td>').append(arrow));
		arrow = $('<div class="fa fa-arrow-circle-right big" style="cursor:pointer;" title="N&auml;chste Woche"></div>');
		arrow.click(function(){nextWeek(elem)});
		tr.append($('<td></td>').append(arrow));
		var dStart = new Date(startOfWeek * 1000);
		var dEnd = new Date(endOfWeek * 1000);
		var monthStr = "";
		if(dStart.getFullYear() != dEnd.getFullYear()) {
			monthStr = dStart.toLocaleDateString(navigator.language, { month: 'short', year: 'numeric' }) + " &ndash; " + dEnd.toLocaleDateString(navigator.language, { month: 'short', year: 'numeric' }); 
		}else if(dStart.getMonth() != dEnd.getMonth()) {
			monthStr = dStart.toLocaleDateString(navigator.language, { month: 'short' }) + " &ndash; " + dEnd.toLocaleDateString(navigator.language, { month: 'short' }) + " " + dStart.toLocaleDateString(navigator.language, { year: 'numeric' }); 
		}else{
			monthStr = dStart.toLocaleDateString(navigator.language, { month: 'long', year: 'numeric' });
		};	
			
		tr.append('<td style="font-size:1.2em;padding-left:2em;"><b>' + monthStr + '</b></td>');
		return $('<div style="height:25px;overflow-y:hide;"></div>').append($('<table></table>').append(tr));
	};	

	
	function markHolidays(elem,date){
		// red background for elem if date is a weekend or holiday
		var str = date.toISOString().substr(0,10);
		var cmd = '{ IsWe("'+str+'") }';
		ftui.sendFhemCommand(cmd,elem)
		.done(function(data ) {
			if(data.substr(0,1) == '1') {
				elem.css("background-color","rgba(255,0,0,0.2)");
			};	
		});
	};	
	
	
	function renderWeek(elem,data) {
		// table from 08:00 - 20:30
		// for each day of the week
		var weekOffset = elem.data("weekOffset");
		var now = Date.now() + weekOffset * 7 * 86400000;
		var dNow = new Date(now);
		var dayOfWeek = (dNow.getDay() + 6) % 7;
		// determine Monday of this week
		var monday = now - dayOfWeek * 86400000;
		var startOfWeek = new Date(monday);
		startOfWeek.setHours(0,0,0,0);
		startOfWeek = startOfWeek.valueOf() / 1000;
		var endOfWeek = startOfWeek + 7 * 86400;
		elem.empty();
		elem.append(renderWeekHeader(elem,startOfWeek,endOfWeek));
		var tr = $('<tr><th style="width:4em;"></th></tr>');
		for(var i = 0; i < 7; i++) {
			var d = new Date(monday + i * 86400000);	
			var th = $("<th style='border:1px solid lightgrey;white-space:nowrap;overflow-x:hidden;'>" + d.getDate() + " " + d.toLocaleDateString(navigator.language, { weekday: 'long' }) + "</th>");
			if(weekOffset == 0 && i == dayOfWeek) {
				th.addClass('fuip-calendar-today');	
			};	
			tr.append(th);
			markHolidays(th,d);
		};	
		elem.append($("<div style='width:calc( 100% - 17px );height:20px;overflow-y:hide;'></div>")
					.append($("<table style='width:100%;border-collapse:collapse;table-layout:fixed;'></table>").append(tr)));
		var html = "<div style='width:100%;max-height:75px;overflow-y:scroll;'><table style='width:100%;border-collapse:collapse;table-layout:fixed;'>";
		html += '<colgroup><col style="width:4em;"></colgroup>';
		var events = data2eventlist(data);
		var fullDayEvents = getFullDayEvents(events,startOfWeek,endOfWeek);
		html += renderFullDayEvents(fullDayEvents,startOfWeek,endOfWeek);
		// we'll do the rest by dynamically adding elements
		html += "</table></div>"
		var fullDayArea = $(html);
		elem.append(fullDayArea);
		var hoursTableHeight = 45 + fullDayArea.height();	
		var theTable = $("<table style='width:100%;border-collapse:collapse;table-layout:fixed;'>");
		theTable.append('<colgroup><col style="width:4em;"></colgroup>');
		var eventDiv = $("<div id='eventDiv' style='width:100%;height:calc(100% - "+hoursTableHeight+"px); overflow-y:scroll'>");
		eventDiv.append(theTable);
		elem.append(eventDiv);
		var theGrid = [];
		// now render one line for each half hour
		for(var hour = 0; hour < 48; hour++) {
			theGrid[hour] = [];
			d.setHours(hour);
			var tr = $("<tr>");
			theTable.append(tr);
			html = "<td style='border:1px solid lightgrey;'><div style='height:1em;width:4em;'>" 
			if(!(hour%2)) {
				html += ("0" + hour/2).slice(-2) + ":00";
			};
			html += "</div></td>";
			tr.append(html);
			// insert event texts
			var start = new Date(monday);
			start.setHours((hour-hour%2)/2,hour%2 * 30,0,0);
			start = start.valueOf() / 1000;
			for(var day = 0; day < 7; day++) {
				html = "<td style='position:relative;padding:0;border:1px solid lightgrey;'></td>";
				theGrid[hour][day] = $(html);
				if(weekOffset == 0 && day == dayOfWeek) {
					theGrid[hour][day].addClass('fuip-calendar-today');	
				};	
				tr.append(theGrid[hour][day]);
			};
		};
		// now place the events
		splitMultiDayEvents(events);
		var evtAr = solveConflicts(events);
		for(var compNum = 0; compNum < evtAr.length; compNum++) {
			var width = 100 / evtAr[compNum].length;
			for(var col = 0; col < evtAr[compNum].length; col++) {
				for(var i = 0; i < evtAr[compNum][col].length; i++) {
					var event = evtAr[compNum][col][i];
					// find out start day
					var startDay = Math.floor((event.startSec - startOfWeek) / 86400);
					// get first cell
					var firstCell = theGrid[0][startDay];
					var lastCell = theGrid[47][startDay];
					var fullHeight = lastCell.position().top + lastCell.outerHeight() - firstCell.position().top +2;
					var gridIndex = Math.floor((event.startSec - startOfWeek - startDay * 86400) / 1800);
					// var eventTop = (event.startSec - startOfWeek - startDay * 86400) * fullHeight / 86400 -1;
					var eventTop = ((event.startSec - startOfWeek) % 1800) * fullHeight / 86400 -1;
					var eventHeight = event.durationSec * fullHeight / 86400;
					var title = event.summary.replace(/"/g, '&quot;');
					var eventDiv = $("<div class='fuip-color-symbol-foreground' style='background-color:var(--fuip-color-symbol-active);position:absolute;border:1px solid lightgrey;border-radius:10px;z-index:1000;top:"+eventTop+"px;left:"+width*col+"%;height:"+eventHeight+"px;width:"+width*determineFreeWidth(evtAr[compNum],col,event)+"%;overflow:hidden;' title=\""+title+"\">"+event.summary+"</div>");
					theGrid[gridIndex][startDay].append(eventDiv);	
				};	
			};
		};
		elem.find("#eventDiv")[0].scrollTop = theGrid[16][0].position().top - theGrid[0][0].position().top;
		// make "today" color transparent
		var todayColor = $(".fuip-calendar-today").css("background-color");
		if(todayColor) {
			todayColor = colorToRgbaArray(todayColor);
			todayColor[3] /= 5;
			todayColor = colorToRgbaString(todayColor);
			$(".fuip-calendar-today").css("background-color",todayColor);
		};
	};	
	
	
	function refresh(elem) { 
		var device = elem.data('device');
		var offset = elem.data('weekOffset') * 7;
		var include = "";
		if(Array.isArray(device)) {
			if(device.length > 1) {
			    include = " include:" + device.join(',');	
			};	
			device = device[0];
		};	
		var from = offset - 7;
		var to = offset + 7;
		var cmd = "get " + device + ' events limit:from='+from+'d,to='+to+'d format:custom={ sprintf(\'{"startSec":"%s", "start":"%s", "endSec":"%s", "end":"%s", "durationSec":"%s", "duration":"%s", "summary":"%s", "description":"%s", "location":"%s", "classification":"%s", "mode":"%s"}\', $t1, $T1, $t2, $T2, $d, $D, main::urlEncode($S), main::urlEncode($DS), $L, $CL,$M) }' + include; 
		ftui.sendFhemCommand(cmd,elem)
		.done(function(data ) {
			render(elem,data);
		})
	};
	
	
	function init_attr(elem) {
			elem.initData('trigger', 'state');
			elem.initData('weekOffset', 0);
			elem.initData('layout', 'week');
			// allow multiple devices with the same trigger
			var devices = elem.data("device");
			if(!Array.isArray(devices)) 
				devices = [devices];
			var trigger = elem.data("trigger");
			var triggers = [];
			for(var i = 0; i < devices.length; i++) {
				triggers[i] = devices[i] + ":" + trigger;	
			};	
			elem.initData("triggers",triggers);
			me.addReading(elem, 'triggers');
	};
	
	
    function update(dev,par) {
		me.elements.filterDeviceReading('triggers', dev, par)
		.each(function (index) {
			ftui.log(3, 'calendar '+dev+' triggered: ' + par);
			refresh($(this));			
		});	
    };
	
	
	function render(elem,data) {
		if(elem.data('layout') == 'list') {
			renderList(elem,data);
		}else{
			renderWeek(elem,data);
		};	
	};	
	
	
	function init_ui(elem) {
		render(elem,"");
    }
	

    var me = $.extend(new Modul_widget(), {
        widgetname: 'fuip_calendar',
        init_attr:init_attr,
		init_ui: init_ui,
		update: update,
    });

	return me;

};