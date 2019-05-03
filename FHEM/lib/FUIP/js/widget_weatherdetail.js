/* FTUI Plugin
 * Copyright (c) 2018 by Bruchbude
 * ...weiterentwickelt fuer FUIP by Thorsten Pferdekaemper
 * Under MIT License (http://www.opensource.org/licenses/mit.license.php)
 */
 
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////// 
// widget_weatherdetail.js
// shows a 4 days detailed weather forcast based on proplanta data.
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////// 
// [choose your table details (case sensitive)]
// clock:    shows the time
// chOfRain: shows the chance of rain in %
// rain:     shows the rain in mm
// temp:     shows the temperature in °C
// weather:  shows png pictures of the weather
// icons:    shows icons of the weather (replacing the png pictures)
// wind:     shows the speed of wind in km/h
// windDir:  shows the winddirection and speed (without unit)
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////// 
// [Example html]
//	<div class="cell" data-type="weatherdetail" data-device="Proplanta" data-detail='["clock","chOfRain","rain","temp","weather","wind","windDir","icons"]'</div>
// [Example fhem-tablet-ui-user.css]
// <todo>
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////// 

// 2018-08-03 updgrade from pre alpha to alpha

"use strict";
var strDaten = " STATE longpoll lastConnection ";
var windArray = ["wi-from-n","wi-from-nne","wi-from-ne","wi-from-ene","wi-from-e","wi-from-ese","wi-from-se","wi-from-sse",
		 "wi-from-s","wi-from-ssw","wi-from-sw","wi-from-wsw","wi-from-w","wi-from-wnw","wi-from-nw","wi-from-nnw"];
var iconArray = [ // [meteocons, kleinklima]
	['B', 'sunny.png'], //t1
	['H', 'partly_cloudy.png'], //t2
	['H', 'partly_cloudy.png'], //t3
	['N', 'mostlycloudy.png'], //t4
	['Y', 'cloudy.png'], //t5
	['Q', 'chance_of_rain.png'], //t6
	['R', 'showers.png'], //t7
	['S', 'chance_of_storm.png'], //t8
	['U', 'chance_of_snow.png'], //t9
	['V', 'rainsnow.png'], //t10
	['W', 'snow.png'], //t11
	['L', 'haze.png'], //t12 (Dunst)
	['L', 'haze.png'], //t13
	['R', 'rain.png'], //t14
	['C', 'sunny_night.png'], //n1
	['I', 'partlycloudy_night.png'], //n2
	['I', 'partlycloudy_night.png'], //n3
	['N', 'mostlycloudy_night.png'], //n4
	['Y', 'overcast.png'], //n5 (Bedeckt)
	['Q', 'chance_of_rain_night.png'], //n6
	['R', 'showers_night.png'], //n7
	['S', 'chance_of_storm_night.png'], //n8
	['U', 'sleet.png'], //n9 (Graupel)
	['V', 'rainsnow.png'], //n10
	['W', 'snow.png'], //n11
	['L', 'haze_night.png'], //n12
	['L', 'haze_night.png'], //n13
	['R', 'rain.png'], //n14
];

function toStr2(integer) {
	return String("00" + integer).slice(-2);
}
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Convert filename of proplanta icon to our loacal pictures filename
// Picture path must be added by caller
// (Proplanta filenames: t1.gif ... t14.gif and n1.gif ... n14.gif)
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
function getImgFilename(iconFilename, usePNG) {
	var start = iconFilename.lastIndexOf("/") + 1; // end of filename-path
	var stop = iconFilename.length - 4; // ".png"
	var daytime = iconFilename.substring(start, start + 1);
	var iconNr = (parseInt(iconFilename.substring(start + 1, stop)) - 1) >>> 0; // ">>>0" makes iconNr unsigned
	if (daytime == 'n') {
		iconNr += 14;
	}
	if (iconNr >= 28) {
		return "na.png";
	}
	return (usePNG ? iconArray[iconNr][1] : iconArray[iconNr][0])
}
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// If we want to see the weather icons, we must add the .css file
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
function depends_weatherdetail() {
	$('head').append('<link rel="stylesheet" href="' + ftui.config.basedir + 'lib/weather-icons.min.css" type="text/css" />');
	$('head').append('<link rel="stylesheet" href="' + ftui.config.basedir + 'lib/weather-icons-wind.min.css" type="text/css" />');
}

var Modul_weatherdetail = function() {
	function init() {
		me.elements = $('div[data-type="' + me.widgetname + '"]', me.area);
		// We can can more then one widget, so init all of them
		me.elements.each(function(index) {
			var elem = $(this);
			elem.uniqueId();  // needed in case there are multiple weatherdetail instances
			elem.initData('device', "noWFineDeviceDefined");
			elem.initData('detail', ["clock", "chOfRain", "rain", "wind", "windDir", "temp", "weather"]);
			elem.initData('overview', []);   // sun,uv,frost
			elem.initData('startday',0);     // day offset to start with
			elem.initData('days', 4);        // number of days
			if(elem.data("detail").length) {
				if(elem.data("startday") > 6){ elem.data("startday",6) };
				if(elem.data("startday") + elem.data("days") > 7){ elem.data("days",7 - elem.data("startday")) };
			}else{	
				if(elem.data("startday") > 13){ elem.data("startday",13) };
				if(elem.data("startday") + elem.data("days") > 14){ elem.data("days",14 - elem.data("startday")) };
			};	
			elem.initData('layout',"normal");
			elem.initData('lastConnection', 'lastConnection');
			me.addReading(elem, "lastConnection"); // if this value changes, update() is called.
			// build a string with all keywords we want to receive from the fhem weather device
			for (var day = elem.data("startday"); day < elem.data("startday") + elem.data("days"); day++) { // forecast: 4 days
				strDaten += "fc" + day + "_date ";
				if(day > 6) {
					strDaten += "fc" + day + "_weatherIcon ";
					if (elem.data('overview').indexOf('text') >= 0) strDaten += "fc" + day + "_weather ";
				}else{					
					strDaten += "fc" + day + "_weatherDayIcon ";
					if (elem.data('overview').indexOf('text') >= 0) strDaten += "fc" + day + "_weatherDay ";
					if (elem.data('overview').indexOf('sun') >= 0) strDaten += "fc" + day + "_sun ";
					if (elem.data('overview').indexOf('uv') >= 0) strDaten += "fc" + day + "_uv ";
					if (elem.data('overview').indexOf('frost') >= 0) strDaten += "fc" + day + "_frost ";
				};	
				strDaten += "fc" + day + "_tempMin ";
				strDaten += "fc" + day + "_tempMax ";
				
				for (var hour = 0; hour < 24; hour += 3) { // resolution: 3h
					strDaten += "fc" + day + "_weather" + toStr2(hour) + "Icon ";
					if (elem.data('detail').indexOf('text') >= 0) strDaten += "fc" + day + "_weather" + toStr2(hour) + " ";
					if (elem.data('detail').indexOf('temp') >= 0) strDaten += "fc" + day + "_temp" + toStr2(hour) + " ";
					if (elem.data('detail').indexOf('rain') >= 0) strDaten += "fc" + day + "_rain" + toStr2(hour) + " ";
					if (elem.data('detail').indexOf('wind')  >= 0 || (elem.data('detail').indexOf('windDir')  >= 0 )) strDaten += "fc" + day + "_wind" + toStr2(hour) + " ";
					if (elem.data('detail').indexOf('windDir') >= 0) strDaten += "fc" + day + "_windDir" + toStr2(hour) + " ";
					if (elem.data('detail').indexOf('chOfRain') >= 0) strDaten += "fc" + day + "_chOfRain" + toStr2(hour) + " ";
				}
			}
			// register resize event
			var id = elem.attr("id");
			$(window).on("resize",function() { resize(id) } );
			$(".dialog").on("fadein",function() { setTimeout( function() { resize(id) }, 250 ) } );  // TODO: not for all of them!
		});
	}
	
	
	function getElemDims(elem) {
		var columns = elem.find(".ftuiWeatherDetailOverviewColumn");  // overview / without detail
		var content = false;
		if(!columns.length) {
			columns = elem.find(".ftuiWeatherdetailTablinks");        // tabs with detail
			content = elem.find(".ftuiWeatherdetailTabcontent");      // detail content
		};	
		if(!columns.length) return { width: 0, height: 0 };
		
		var w = 0;
		columns.each(function() {
			w += $(this).outerWidth();
		});	
		var h = columns.outerHeight();
		if(content.length) h += content.outerHeight();
		return {width: w, height: h};
	};	
	
	
	function resize(id) {
		// called when the widget is resized (this is the idea...)
		// console.log("resize: " + id);	

 		var elem = $("#"+id);
		// determine how big one element should be
		// var targetWidth = elem.width();
		// var targetHeight = elem.height();
		var view = elem.closest("[data-viewid]");
		var targetWidth = view.width();
		var targetHeight = view.height();
		// are there detail graphics?
		var detailSymbols = elem.find(".ftuiWeatherdetailSymbolDetail");
		var maxDetSymHeight = Math.floor(((elem.width() - 20) / 8) * 120 / 175);	
		if(maxDetSymHeight < 0) maxDetSymHeight = 0;
		// first make sure that the detail pics fit in etc. and are not bigger than the overview symbols
		var picHeight = elem.find(".ftuiWeatherdetailSymbolOverview").height();
		var picWidth = Math.round(picHeight * 175 / 120);
		elem.find(".ftuiWeatherdetailSymbolOverview").width(picWidth);
		elem.find(".ftuiWeatherdetailSymbolDetail").width(picHeight < maxDetSymHeight ? picWidth : maxDetSymHeight * 175 / 120)
												.height(picHeight < maxDetSymHeight ? picHeight : maxDetSymHeight);	
		while(true) {
			// how big is it currently?
			var actDim = getElemDims(elem);
			// console.log("resize: " + actDim.width.toString() + "  " + actDim.height.toString());
			if(actDim.width <= 0 || actDim.height <=0) break;  // happens at the beginning
			// too large?
			if(actDim.width > targetWidth || actDim.height > targetHeight) {
				// try to make it smaller
				// always use the height to begin with
				elem.find(".ftuiWeatherdetailSymbolOverview").height(picHeight-1).width(Math.round((picHeight-1) * 175 / 120));
				elem.find(".ftuiWeatherdetailSymbolDetail").width(picHeight-1 < maxDetSymHeight ? (picHeight-1) * 175 / 120 : maxDetSymHeight * 175 / 120).height(picHeight-1 < maxDetSymHeight ? picHeight-1 : maxDetSymHeight);	
				var newDim = getElemDims(elem);
				// stop if it is ok now (otherwise it might oscillate between too small and too big)
				if(newDim.width <= targetWidth && newDim.height <= targetHeight) break; 
				// stop if this has not really made a difference 
				if((actDim.width <= targetWidth || newDim.width == actDim.width) && (actDim.height <= targetHeight || newDim.height == actDim.height)){
					elem.find(".ftuiWeatherdetailSymbolOverview").height(picHeight).width(Math.round(picHeight * 175 / 120));
					elem.find(".ftuiWeatherdetailSymbolDetail").width(picHeight < maxDetSymHeight ? picHeight * 175 / 120 : maxDetSymHeight * 175 / 120)
														.height(picHeight < maxDetSymHeight ? picHeight : maxDetSymHeight);	
					break;
				};	
				picHeight--;
			// too small?	
			}else if(actDim.width < targetWidth || actDim.height < targetHeight) {
				picHeight++;
				elem.find(".ftuiWeatherdetailSymbolOverview").height(picHeight).width(Math.round(picHeight * 175 / 120));
				elem.find(".ftuiWeatherdetailSymbolDetail").width(picHeight < maxDetSymHeight ? picHeight * 175 / 120 : maxDetSymHeight * 175 / 120)
														.height(picHeight < maxDetSymHeight ? picHeight : maxDetSymHeight);	
			// exact match	
			}else {
				break; 
			}
		};	
		// line to "close" the tabs
		var h = elem.find(".ftuiWeatherdetailTablinks").outerHeight();
		if(h) {  // otherwise this is "overview" and not "detail" and there are no tabs
			var w = elem.width() - elem.find(".ftuiWeatherdetailTablinks").outerWidth();
			if(w < 0) w = 0;
			elem.find(".ftuiWeatherDetailSpacerLine").height(h).width(w);
		};	
	};	

	
	function addSunUvFrost(weatherHtml,tabDay,res,elem) {
		var sun = (elem.data('overview').indexOf('sun') >= 0);
		var uv = (elem.data('overview').indexOf('uv') >= 0);
		var frost = (elem.data('overview').indexOf('frost') >= 0);
		var sunUvFrost = sun || uv || frost;
		var myHtml = "";
		if(sunUvFrost) myHtml += "<table cellspacing='0' cellpadding='0'><tr><td>";
		myHtml += weatherHtml;
		if(sunUvFrost) myHtml += "</td><td>";
		if(sunUvFrost) myHtml += "<table cellspacing='0' cellpadding='0'>";
		if(sun) {
			myHtml += "<tr><td><div class='cell large gray wi wi-day-sunny' style='margin:0 !important;'></div></td>"
			myHtml += "<td><div style='width:40px;'><div class='large inline ftuiWeatherdetailWeatherValue' style='margin:0 !important;'>" + res.Readings['fc' + tabDay + '_sun'].Value + "</div>"
			myHtml += "<div class='inline small ftuiWeatherdetailWeatherValue' style='margin:0 !important;'>%</div></div></td></tr>";
		};
		if(uv) {	
			myHtml += "<tr><td><div class='cell gray' style='margin:0 !important;'>UV</div></td>";
			myHtml += "<td><div style='width:40px;'><div class='large ftuiWeatherdetailWeatherValue' style='margin:0 !important;'>" + res.Readings['fc' + tabDay + '_uv'].Value + "</div></div></td></tr>";
		};
		if(frost) {	
			myHtml += "<tr><td><div class='cell large gray wi wi-snowflake-cold' style='margin:0 !important;'></div></td>";
			myHtml += "<td><div style='width:40px;'><div class='large ftuiWeatherdetailWeatherValue' style='margin:0 !important;'>" + res.Readings['fc' + tabDay + '_frost'].Value + "</div></div></td></tr>"
		};	
		if(sunUvFrost) myHtml += "</table></td></tr></table>";
		return myHtml;
	};	


	function addSunUvFrostFlex(weatherHtml,tabDay,res,elem) {
		if(tabDay > 6) return weatherHtml;
		var sun = (elem.data('overview').indexOf('sun') >= 0);
		var uv = (elem.data('overview').indexOf('uv') >= 0);
		var frost = (elem.data('overview').indexOf('frost') >= 0);
		var sunUvFrost = sun || uv || frost;
		if(!sunUvFrost) return weatherHtml;
		var myHtml = "<div style='display:flex;align-items:center;'><div style='display:flex;flex-direction:column;'>" + weatherHtml + "</div>";
		myHtml += "<table cellspacing='0' cellpadding='0'>";
		if(sun) {
			myHtml += "<tr><td><div class='cell large gray wi wi-day-sunny' style='margin:0 !important;'></div></td>"
			myHtml += "<td><div style='width:40px;'><div class='large inline ftuiWeatherdetailWeatherValue' style='margin:0 !important;'>" + res.Readings['fc' + tabDay + '_sun'].Value + "</div>"
			myHtml += "<div class='inline small ftuiWeatherdetailWeatherValue' style='margin:0 !important;'>%</div></div></td></tr>";
		};
		if(uv) {	
			myHtml += "<tr><td><div class='cell gray' style='margin:0 !important;'>UV</div></td>";
			myHtml += "<td><div style='width:40px;'><div class='large ftuiWeatherdetailWeatherValue' style='margin:0 !important;'>" + res.Readings['fc' + tabDay + '_uv'].Value + "</div></div></td></tr>";
		};
		if(frost) {	
			myHtml += "<tr><td><div class='cell large gray wi wi-snowflake-cold' style='margin:0 !important;'></div></td>";
			myHtml += "<td><div style='width:40px;'><div class='large ftuiWeatherdetailWeatherValue' style='margin:0 !important;'>" + res.Readings['fc' + tabDay + '_frost'].Value + "</div></div></td></tr>"
		};	
		myHtml += "</table></div>";
		return myHtml;
	};	
	

	function addTab(tabDay, res, pathImage, elem) {
		var datum = res.Readings['fc' + tabDay + '_date'].Value
		var myHtml = "<button id='tabId" + tabDay + "' class='ftuiWeatherdetailTablinks' onclick=\"wtabClicked('" + elem.attr("id") + "','" + tabDay + "')\">"
		myHtml += "<div class='big compressed'>" + datum + "</div>"
		myHtml += "<div class='large gray'>" + (!tabDay ? 'Heute' : datum.toDate().ee()) + "</div>"
		var imgFile = getImgFilename(res.Readings['fc' + tabDay + '_weatherDayIcon'].Value, true);
		var weatherHtml = "<img class='ftuiWeatherdetailSymbolOverview' width=105 height=72 src='" + pathImage + imgFile + "'/>";	
		if(elem.data('overview').indexOf('text') >= 0) {
			weatherHtml = "<table cellpadding='0'><tr><td>"+weatherHtml+"</td></tr>" +
							"<tr><td><div class='large ftuiWeatherdetailWeatherValue' style='white-space:nowrap;margin:0 !important;'>" + res.Readings['fc' + tabDay + '_weatherDay'].Value + "</div></td></tr></table>";
		};		
		myHtml += addSunUvFrost(weatherHtml,tabDay,res,elem);
		myHtml += "<div style='white-space:nowrap;'>";
		myHtml += "<div class='bigger inline blue ftuiWeatherdetailWeatherValue'>" + res.Readings['fc' + tabDay + '_tempMin'].Value + "</div>"
		myHtml += "<div class='normal inline blue ftuiWeatherdetailWeatherUnit'>&#x2103</div>"
		myHtml += "<div class='bigger inline orange ftuiWeatherdetailWeatherValue'>" + res.Readings['fc' + tabDay + '_tempMax'].Value + "</div>"
		myHtml += "<div class='normal inline orange ftuiWeatherdetailWeatherUnit'>&#x2103</div>"
		myHtml += "</div>";
		myHtml += "<div class='tiny'><br></div></button>"
		return myHtml;
	}
	
	
	function addWithoutTab(tabDay, res, pathImage, elem) {
		var layout = elem.data("layout");
		var datum = res.Readings['fc' + tabDay + '_date'].Value;
		var	myHtml = "<div class='ftuiWeatherDetailOverviewColumn' style='display:inline-flex;flex-direction:column;cursor:auto;'>";
		myHtml += "<div class='large gray'>" + (!tabDay ? 'Heute' : datum.toDate().ee()) + "</div>";
		var hasText = (elem.data('overview').indexOf('text') >= 0);
		var imgFile = getImgFilename(res.Readings['fc' + tabDay + (tabDay > 6 ? '_weatherIcon':'_weatherDayIcon')].Value, true);
		if(layout == "small") {
			if((elem.data('overview').indexOf('sun') >= 0) || (elem.data('overview').indexOf('uv') >= 0) || (elem.data('overview').indexOf('frost') >= 0)) {
				var picAndTemp = "<img class='ftuiWeatherdetailSymbolOverview'  width=70 height=48 src='" + pathImage + imgFile + "'/>";	
				if(elem.data('overview').indexOf('text') >= 0) {
					picAndTemp += "<div class='normal ftuiWeatherdetailWeatherValue' style='margin:0 !important;'>" + res.Readings['fc' + tabDay + (tabDay > 6 ? '_weather':'_weatherDay')].Value + "</div>";
				};		
				picAndTemp += "<div><div class='big inline blue ftuiWeatherdetailWeatherValue'>" + res.Readings['fc' + tabDay + '_tempMin'].Value + "</div>";
				picAndTemp += "<div class='small inline blue ftuiWeatherdetailWeatherUnit'>&#x2103</div>";
				picAndTemp += "<div class='big inline orange ftuiWeatherdetailWeatherValue'>" + res.Readings['fc' + tabDay + '_tempMax'].Value + "</div>";
				picAndTemp += "<div class='small inline orange ftuiWeatherdetailWeatherUnit'>&#x2103</div></div>";
				myHtml += addSunUvFrostFlex(picAndTemp,tabDay,res,elem);
			}else{	
				myHtml += "<div style='display:flex;align-items:center;'>";
				myHtml += '<div>';
				myHtml += "<img class='ftuiWeatherdetailSymbolOverview'  width=70 height=48 src='" + pathImage + imgFile + "'/>";	
				if(elem.data('overview').indexOf('text') >= 0) {
					myHtml += "<div class='normal ftuiWeatherdetailWeatherValue' style='margin:0 !important;'>" + res.Readings['fc' + tabDay + (tabDay > 6 ? '_weather':'_weatherDay')].Value + "</div>";
				};		
				myHtml += "</div>";
				myHtml += "<div><div>";
				myHtml += "<div class='big inline blue ftuiWeatherdetailWeatherValue'>" + res.Readings['fc' + tabDay + '_tempMin'].Value + "</div>"
				myHtml += "<div class='small inline blue ftuiWeatherdetailWeatherUnit'>&#x2103</div></div>"
				myHtml += "<div><div class='big inline orange ftuiWeatherdetailWeatherValue'>" + res.Readings['fc' + tabDay + '_tempMax'].Value + "</div>"
				myHtml += "<div class='small inline orange ftuiWeatherdetailWeatherUnit'>&#x2103</div></div>"
				myHtml += "</div>";
				myHtml += "</div>";
			};	
		}else{
			myHtml = "<div class='ftuiWeatherDetailOverviewColumn' style='display:inline-flex;flex-direction:column;cursor:auto;'>";
			myHtml += "<div class='big compressed'>" + datum + "</div>";
			myHtml += "<div class='large gray'>" + (!tabDay ? 'Heute' : datum.toDate().ee()) + "</div>";
			var weatherHtml = "<img class='ftuiWeatherdetailSymbolOverview'  width=105 height=72 src='" + pathImage + imgFile + "'/>";	
			if(elem.data('overview').indexOf('text') >= 0) {
				weatherHtml += "<div class='large ftuiWeatherdetailWeatherValue' style='margin:0 !important;'>" + res.Readings['fc' + tabDay + (tabDay > 6 ? '_weather':'_weatherDay')].Value + "</div>";
			};		
			myHtml += addSunUvFrostFlex(weatherHtml,tabDay,res,elem);
			myHtml += "<div><div class='bigger inline blue ftuiWeatherdetailWeatherValue'>" + res.Readings['fc' + tabDay + '_tempMin'].Value + "</div>"
			myHtml += "<div class='normal inline blue ftuiWeatherdetailWeatherUnit'>&#x2103</div>"
			myHtml += "<div class='bigger inline orange ftuiWeatherdetailWeatherValue'>" + res.Readings['fc' + tabDay + '_tempMax'].Value + "</div>"
			myHtml += "<div class='normal inline orange ftuiWeatherdetailWeatherUnit'>&#x2103</div></div>"
		};	
		myHtml += "</div>"
		return myHtml;
	}
	
	
	function getImgPath() {
		// try to make this safe if someone omits trailing "/"
		// or fhemDir is completely empty
		var fhemDir = ftui.config.fhemDir;
		if(fhemDir.length) {
			if(fhemDir.slice(-1) != "/") 
				fhemDir += "/";
		}else{
			fhemDir = "/";
		};	
		return fhemDir + "images/default/weather/";
	};	
	

	function addWeatherRow(elem, res, token, name, icon, unit) {
		var colsPerDay = 8;
		if (elem.data('detail').indexOf(name) == -1) return "";
		var myHtml = "<div class='row'><div class='cell large gray " + icon + "'></div>"
		for (var i = 0; i < colsPerDay; i++) {
			myHtml += "<div class='cell-12' style='white-space:nowrap;'>"
			if (name == 'weather') {
				if (elem.data('detail').indexOf('icons') >= 0) {
					var icon = getImgFilename(res.Readings['fc' + token + '_weather' + toStr2(i * 3) + 'Icon'].Value, false);
					myHtml += "<div class='weather'><div class='weather-icon meteocons' data-icon='" + icon + "'></div></div>"
				} else {
					var imgFile = getImgPath() + getImgFilename(res.Readings['fc' + token + '_weather' + toStr2(i * 3) + 'Icon'].Value, true);
					myHtml += "<img class='ftuiWeatherdetailSymbolDetail' src='" + imgFile + "'/>"
				}
			} else if (name=='windDir') {
				var deg = res.Readings[token + toStr2(i * 3)].Value;
				myHtml += "<div class='inline large wi wi-wind " + windArray[Math.floor(deg / 22.5)] + "'></div>" ;
				var val = res.Readings[unit + toStr2(i * 3)].Value;
				myHtml += "<div class='inline "  + (val.length > 4 ? 'normal' : 'big') + "'>" + val+ "</div>" ;
			} else {
				var val = (token == '' ? toStr2(i * 3) : res.Readings[token + toStr2(i * 3)].Value);
				myHtml += "<div class='inline " + (val.length > 4 ? 'normal' : 'big') + " ftuiWeatherdetailWeatherValue'>" + val + "</div>";
				if(unit) {
					myHtml += "<div class='inline small ftuiWeatherdetailWeatherValue'>" + unit + "</div>";
				};
			}
			myHtml += "</div>"
		}
		myHtml += "</div>"
		return myHtml;
	}

	function update(device, reading) {
		// we need only updates for our device, so filter out all other widgets
		me.elements.filter('div[data-device="' + device + '"]').each(function(index) {
			var pathImage = getImgPath();
			var elem = $(this);
			var myHtml = elem.data('detail').length ? "<div class='ftuiWeatherdetailTab' style='white-space:nowrap;text-align:left;'>" : "<div style='white-space:nowrap;height:100%;float:left'>";
			var fhemJSON = ftui.sendFhemCommand("jsonlist2 WEB," + device + strDaten).done(function(fhemJSON) {
				var res = fhemJSON.Results[1]; // 0 = Arg, 1 =Results
				for (var i = elem.data("startday"); i < elem.data("startday") + elem.data("days"); i++) {
					if(elem.data('detail').length) {
						myHtml += addTab(i, res, pathImage, elem);
					}else{	
						myHtml += addWithoutTab(i, res, pathImage, elem);
					};
				};	
				if(elem.data('detail').length)
					myHtml += '<div class="ftuiWeatherDetailSpacerLine" style="vertical-align:top;display:inline-block;height:100px;width:100px;border-width:1px;border-style:none none solid none;"></div>';
				myHtml += "</div>"; 
				if(elem.data('detail').length) {
				for (var day = elem.data("startday"); day < elem.data("startday") + elem.data("days"); day++) {
					myHtml += "<div id='conId" + day + "' class='ftuiWeatherdetailSheet ftuiWeatherdetailTabcontent' style='width:auto;height:auto;display:none;'>";
					myHtml += addWeatherRow(elem, res, '', 'clock', 'wi wi-time-4', 'Uhr');
					myHtml += addWeatherRow(elem, res, day, 'weather', 'wi wi-cloud');
					myHtml += addWeatherRow(elem, res, 'fc' + day + '_weather', 'text', 'wi wi-cloud');
					myHtml += addWeatherRow(elem, res, 'fc' + day + '_temp', 'temp', 'wi wi-thermometer', '&deg;C');
					myHtml += addWeatherRow(elem, res, 'fc' + day + '_chOfRain', 'chOfRain', 'wi wi-umbrella', '%');
					myHtml += addWeatherRow(elem, res, 'fc' + day + '_rain', 'rain', 'wi wi-raindrops', 'mm');
					myHtml += addWeatherRow(elem, res, 'fc' + day + '_wind', 'wind', 'wi wi-small-craft-advisory', 'km/h');
					myHtml += addWeatherRow(elem, res, 'fc' + day + '_windDir', 'windDir', 'wi wi-small-craft-advisory', 'fc' + day +'_wind');
					myHtml += "</div>"
				}
				myHtml += "<script>"
				myHtml += "function wtabClicked(id,actTab){"
				myHtml += "$(\"#\"+id).find('.ftuiWeatherdetailTablinks').removeClass('active');"
				myHtml += "$(\"#\"+id).find('.ftuiWeatherdetailTabcontent').css('display','none');"
				myHtml += "$(\"#\"+id).find('#tabId'+actTab).addClass('active');"
				myHtml += "$(\"#\"+id).find('#conId'+actTab).css('display', 'block');"
				myHtml += "};"
				myHtml += "$(function(){wtabClicked('"+elem.attr("id")+"'," + elem.data("startday") + ")});"
				myHtml += "</script>"
				};
				elem.html(myHtml);
				$(function() { resize(elem.attr("id")) });  // care for correct sizing 
			});
			//extra reading for hide
			me.update_hide(device, reading);
		});
	};
	// public
	// inherit all public members from base class
	var me = $.extend(new Modul_widget(), {
		//override or own public members
		widgetname: 'weatherdetail',
		init: init,
		update: update,
	});
	return me;
};
