/* FTUI Plugin
 * Copyright (c) 2018 by Bruchbude
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
			elem.initData('device', "noWFineDeviceDefined");
			elem.initData('detail', ["clock", "chOfRain", "rain", "wind", "windDir", "temp", "weather"]);
			elem.initData('overview', []);   // sun,uv,frost
			elem.initData('days', 4);
			elem.initData('layout',"normal");
			elem.initData('lastConnection', 'lastConnection');
			me.addReading(elem, "lastConnection"); // if this value changes, update() is called.
			// build a string with all keywords we want to receive from the fhem weather device
			for (var day = 0; day < elem.data("days"); day++) { // forecast: 4 days
				strDaten += "fc" + day + "_date ";
				strDaten += "fc" + day + "_weatherDayIcon ";
				if (elem.data('overview').indexOf('text') >= 0) strDaten += "fc" + day + "_weatherDay ";
				strDaten += "fc" + day + "_tempMin ";
				strDaten += "fc" + day + "_tempMax ";
				if (elem.data('overview').indexOf('sun') >= 0) strDaten += "fc" + day + "_sun ";
				if (elem.data('overview').indexOf('uv') >= 0) strDaten += "fc" + day + "_uv ";
				if (elem.data('overview').indexOf('frost') >= 0) strDaten += "fc" + day + "_frost ";
				
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
		});
	}
	
	
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
			myHtml += "<td><div style='width:40px;'><div class='large inline weatherValue' style='margin:0 !important;'>" + res.Readings['fc' + tabDay + '_sun'].Value + "</div>"
			myHtml += "<div class='inline small weatherValue' style='margin:0 !important;'>%</div></div></td></tr>";
		};
		if(uv) {	
			myHtml += "<tr><td><div class='cell gray' style='margin:0 !important;'>UV</div></td>";
			myHtml += "<td><div style='width:40px;'><div class='large weatherValue' style='margin:0 !important;'>" + res.Readings['fc' + tabDay + '_uv'].Value + "</div></div></td></tr>";
		};
		if(frost) {	
			myHtml += "<tr><td><div class='cell large gray wi wi-snowflake-cold' style='margin:0 !important;'></div></td>";
			myHtml += "<td><div style='width:40px;'><div class='large weatherValue' style='margin:0 !important;'>" + res.Readings['fc' + tabDay + '_frost'].Value + "</div></div></td></tr>"
		};	
		if(sunUvFrost) myHtml += "</table></td></tr></table>";
		return myHtml;
	};	
	

	function addTab(tabDay, res, pathImage, elem) {
		var cellWidth = 100 / elem.data("days");
		
		var datum = res.Readings['fc' + tabDay + '_date'].Value
		var myHtml = "<button id='tabId" + tabDay + "' class='white tablinks' style='width:" + cellWidth+ "%;' onclick=\"wtabClicked('" + tabDay + "')\">"
		myHtml += "<div class='big compressed'>" + datum + "</div>"
		myHtml += "<div class='large gray'>" + (!tabDay ? 'Heute' : datum.toDate().ee()) + "</div>"
		var imgFile = getImgFilename(res.Readings['fc' + tabDay + '_weatherDayIcon'].Value, true);
		var weatherHtml = "<img style='width:100%' src='" + pathImage + imgFile + "'/>";	
		if(elem.data('overview').indexOf('text') >= 0) {
			weatherHtml = "<table cellpadding='0'><tr><td>"+weatherHtml+"</td></tr>" +
							"<tr><td><div class='large weatherValue' style='margin:0 !important;'>" + res.Readings['fc' + tabDay + '_weatherDay'].Value + "</div></td></tr></table>";
		};		
		myHtml += addSunUvFrost(weatherHtml,tabDay,res,elem);
		myHtml += "<div class='bigger inline blue weatherValue'>" + res.Readings['fc' + tabDay + '_tempMin'].Value + "</div>"
		myHtml += "<div class='normal inline blue weatherUnit'>&#x2103</div>"
		myHtml += "<div class='bigger inline orange weatherValue'>" + res.Readings['fc' + tabDay + '_tempMax'].Value + "</div>"
		myHtml += "<div class='normal inline orange weatherUnit'>&#x2103</div>"
		
		myHtml += "<div class='tiny'><br></div></button>"
		return myHtml;
	}
	
	
	function addWithoutTab(tabDay, res, pathImage, elem) {
		var days = elem.data("days");
		var layout = elem.data("layout");
		var cellWidth = 100 / days;
		
		var datum = res.Readings['fc' + tabDay + '_date'].Value;
		var myHtml = "<div style='float:left;cursor:auto;width:" + cellWidth+ "%;'>";
		if(layout != "small") {
			myHtml += "<div class='big compressed'>" + datum + "</div>";
		};
		myHtml += "<div class='large gray'>" + (!tabDay ? 'Heute' : datum.toDate().ee()) + "</div>";
		var hasText = (elem.data('overview').indexOf('text') >= 0);
		var imgFile = getImgFilename(res.Readings['fc' + tabDay + '_weatherDayIcon'].Value, true);
		if(layout == "small") {
			if((elem.data('overview').indexOf('sun') >= 0) || (elem.data('overview').indexOf('uv') >= 0) || (elem.data('overview').indexOf('frost') >= 0)) {
				var picAndTemp = "<table cellpadding='0' cellspacing='0'><tr><td><img style='display:block;width:";
				if(hasText) {
					picAndTemp += "45";
				}else{
					picAndTemp += "65";
				};	
				picAndTemp += "%;margin:auto;' src='" + pathImage + imgFile + "'/></td></tr>";
				if(hasText) {
					picAndTemp += "<tr><td><div class='normal weatherValue' style='margin:0 !important;'>" + res.Readings['fc' + tabDay + '_weatherDay'].Value + "</div></td></tr>";
				};	
				picAndTemp += "<tr><td><div class='big inline blue weatherValue'>" + res.Readings['fc' + tabDay + '_tempMin'].Value + "</div>"
				picAndTemp += "<div class='small inline blue weatherUnit'>&#x2103</div>"
				picAndTemp += "<div class='big inline orange weatherValue'>" + res.Readings['fc' + tabDay + '_tempMax'].Value + "</div>"
				picAndTemp += "<div class='small inline orange weatherUnit'>&#x2103</div></td></tr></table>"
				myHtml += addSunUvFrost(picAndTemp,tabDay,res,elem);
			}else{	
				var weatherHtml = "<img style='width:50%;' src='" + pathImage + imgFile + "'/>";	
				if(hasText) {
					weatherHtml = "<table style='width:45%;margin:0 !important;' class='inline' cellspacing='0' cellpadding='0'><tr style='padding:0;margin:0;'><td><img  style='display:block;width:100%;' src='" + pathImage + imgFile + "'/></td></tr>" +
							"<tr><td><div class='normal weatherValue' style='margin:0 !important;'>" + res.Readings['fc' + tabDay + '_weatherDay'].Value + "</div></td></tr></table>";
				};					
				myHtml += weatherHtml;
				myHtml += "<div class='inline'><div>";
				myHtml += "<div class='big inline blue weatherValue'>" + res.Readings['fc' + tabDay + '_tempMin'].Value + "</div>"
				myHtml += "<div class='small inline blue weatherUnit'>&#x2103</div></div>"
				myHtml += "<div><div class='big inline orange weatherValue'>" + res.Readings['fc' + tabDay + '_tempMax'].Value + "</div>"
				myHtml += "<div class='small inline orange weatherUnit'>&#x2103</div></div>"
				myHtml += "</div>";
			};	
		}else{
			var weatherHtml = "<img style='width:100%' src='" + pathImage + imgFile + "'/>";	
			if(elem.data('overview').indexOf('text') >= 0) {
				weatherHtml = "<table cellpadding='0'><tr><td>"+weatherHtml+"</td></tr>" +
							"<tr><td><div class='large weatherValue' style='margin:0 !important;'>" + res.Readings['fc' + tabDay + '_weatherDay'].Value + "</div></td></tr></table>";
			};		
			myHtml += addSunUvFrost(weatherHtml,tabDay,res,elem);
			myHtml += "<div class='bigger inline blue weatherValue'>" + res.Readings['fc' + tabDay + '_tempMin'].Value + "</div>"
			myHtml += "<div class='normal inline blue weatherUnit'>&#x2103</div>"
			myHtml += "<div class='bigger inline orange weatherValue'>" + res.Readings['fc' + tabDay + '_tempMax'].Value + "</div>"
			myHtml += "<div class='normal inline orange weatherUnit'>&#x2103</div>"
		};	
		myHtml += "</div>"
		return myHtml;
	}
	

	function addWeatherRow(elem, res, token, name, icon, unit) {
		const colsPerDay = 8;
		if (elem.data('detail').indexOf(name) == -1) return "";
		var myHtml = "<div class='row'><div class='cell large gray " + icon + "'></div>"
		for (var i = 0; i < colsPerDay; i++) {
			myHtml += "<div class='cell-12'>"
			if (name == 'weather') {
				if (elem.data('detail').indexOf('icons') >= 0) {
					var icon = getImgFilename(res.Readings['fc' + token + '_weather' + toStr2(i * 3) + 'Icon'].Value, false);
					myHtml += "<div class='weather'><div class='weather-icon meteocons' data-icon='" + icon + "'></div></div>"
				} else {
					const pathImage = ftui.config.fhemDir + "images/default/weather/";
					var imgFile = pathImage + getImgFilename(res.Readings['fc' + token + '_weather' + toStr2(i * 3) + 'Icon'].Value, true);
					myHtml += "<img style='width:100%' src='" + imgFile + "'/>"
				}
			} else if (name=='windDir') {
				var deg = res.Readings[token + toStr2(i * 3)].Value;
				myHtml += "<div class='inline large wi wi-wind " + windArray[Math.floor(deg / 22.5)] + "'></div>" ;
				var val = res.Readings[unit + toStr2(i * 3)].Value;
				myHtml += "<div class='inline "  + (val.length > 4 ? 'normal' : 'big') + "'>" + val+ "</div>" ;
			} else {
				var val = (token == '' ? toStr2(i * 3) : res.Readings[token + toStr2(i * 3)].Value);
				myHtml += "<div class='inline " + (val.length > 4 ? 'normal' : 'big') + " weatherValue'>" + val + "</div>";
				if(unit) {
					myHtml += "<div class='inline small weatherValue'>" + unit + "</div>";
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
			const pathImage = ftui.config.fhemDir + "images/default/weather/";
			var elem = $(this);
			var myHtml = elem.data('detail').length ? "<div class='tab'>" : "<div>";
			var fhemJSON = ftui.sendFhemCommand("jsonlist2 WEB," + device + strDaten).done(function(fhemJSON) {
				var res = fhemJSON.Results[1]; // 0 = Arg, 1 =Results
				for (var i = 0; i < elem.data("days"); i++) {
					if(elem.data('detail').length) {
						myHtml += addTab(i, res, pathImage, elem);
					}else{	
						myHtml += addWithoutTab(i, res, pathImage, elem);
					};
				};	
				myHtml += "</div>"; 
				if(elem.data('detail').length) {
				for (var day = 0; day < elem.data("days"); day++) {
					myHtml += "<div id='conId" + day + "' class='sheet tabContent' style='display:none;'>";
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
				myHtml += "function wtabClicked(actTab){"
				myHtml += "var tabs = document.getElementsByClassName('tablinks');"
				myHtml += "var cont = document.getElementsByClassName('tabContent');"
				myHtml += "for (var i=0; i< tabs.length; i++){ "
				myHtml += "  tabs[i].className = tabs[i].className.replace(' active','');"
				myHtml += "  cont[i].style.display='none';   };"
				myHtml += "document.getElementById('tabId'+actTab).className+= ' active';"
				myHtml += "document.getElementById('conId'+actTab).style.display='block';"
				myHtml += "};"
				myHtml += "$(function(){wtabClicked(0)});"
				// myHtml += "document.getElementById('tabId0').click();" // default: weather of today is selected
				myHtml += "</script>"
				};
				elem.html(myHtml);
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
