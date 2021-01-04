// common parts, which are needed for all FUIP pages
// i.e. edit mode and "locked" mode

// overwrite ftui.toast with something better configurable
// data-fuip-toast
//		all: show all messages
//		error: only show messages where parameter error is "error" or "fuip-error"
//				(i.e. error messages from FTUI or FUIP
//		off: only show messages where error = "fuip-error" (this should only
//				happen in maintenance mode)	 
// only replace the original toast function if FUIP config is set
// (compatibility with prior versions)
if($('html').data('fuipToast')) {
	ftui.toast = function (text, error) {
		if(! $.toast) return;  // i.e. jquery toast not loaded
		var tstack = ftui.config.TOAST > 1 ? ftui.config.TOAST : false;
		var fuipToast = $('html').data('fuipToast');
		if (error == 'error' && fuipToast != 'off' || error == 'fuip-error') {
			return $.toast({
					heading: 'Error',
					text: text,
					hideAfter: 20000, // in milli seconds
					icon: 'error',
					loader: false,
					position: ftui.config.toastPosition,
					stack: tstack
			});
		};
		if(fuipToast != 'all') return null;
		return $.toast({
				text: text,
				loader: false,
				position: ftui.config.toastPosition,
				stack: tstack
		});
	};
};


// auto-return (or rather auto-navigation)
if($('html').data('fuipReturnAfter')) {
	var fuipReturnTimer;
	
	function fuipReturn() {
		var newPage = $("html").data('fuipReturnTo');
		window.location = ftui.config.basedir + "page/" + newPage;
	}
	
	function fuipResetTimer() {
		clearTimeout(fuipReturnTimer);
		fuipReturnTimer = setTimeout(fuipReturn, $('html').data('fuipReturnAfter') * 1000);
	}
		
	$(window).on("load", fuipResetTimer); 
	$(document).on("mousemove", fuipResetTimer);
	$(document).on("keypress", fuipResetTimer);
	$(document).on("click", fuipResetTimer);
	$(document).on("mousedown", fuipResetTimer);
};


// log/trace handling
function fuipGetLogs() {
	// get all entries in localStorage
	var log = new Object;
	for (var i = 0; i < localStorage.length; i++) {
		var key = localStorage.key(i);
		if(!key.match(/^ftui\.log\./)) 
			continue;
		var logid = key.substr(9);
		logid = logid.substr(0,logid.length - 9);
		if(!log[logid]) {
			log[logid] = [];
		};	
		log[logid].push({index: key.substr(-8), content: localStorage.getItem(key)});
	}
	var logIds = [];
	for(var logid in log) {
		logIds.push(logid);
		log[logid].sort(function (a,b) { return parseInt(a.index) - parseInt(b.index) });
	};
	logIds.sort();

	var result = "";
	for(var i = 0; i < logIds.length; i++) {
		result += logIds[i] + "\n";
		for(var j = 0; j < log[logIds[i]].length; j++) {
			var entry = log[logIds[i]][j];
			result += entry.index + " " + entry.content + "\n";
		};
	};	
	return result;
};


function fuipDeleteOldLogs() {
	// remove all logs except the current one
	var keys2remove = [];
	for (var i = 0; i < localStorage.length; i++) {
		var key = localStorage.key(i);
		if(!key.startsWith("ftui.log."))
			continue;
		if(ftui.logid && key.startsWith("ftui.log." + ftui.logid)) 
			continue;
		keys2remove.push(key);	
	};
	for (var i = 0; i < keys2remove.length; i++) {
		localStorage.removeItem(keys2remove[i]);	
	};	
};


// In case there is already a log written when the page is called,
// this log is sent to FHEM (if possible)
function fuipPostLogs() {
	// check if there are logs (only send the first log for now)
	var logs = fuipGetLogs();
	// anything?
	if(!logs.length){
		return;
	};
	// send logs to FHEM
	let url = location.origin + ftui.config.basedir + 'fuip/logupload';
	$.ajax({
		async: true,
		cache: false,
		method: 'POST',
		dataType: 'text',
		url: url,
		data: encodeURIComponent(logs),
		error: function (jqXHR, textStatus, errorThrown) {
			ftui.log(1,"FUIP: Log upload failed" + jqXHR.status + " " + textStatus + ": " + errorThrown);
		}
	}).done(function(result) {
		if(result == "OK") {
					fuipDeleteOldLogs();
		};	
	});
};

// do this once when page loads
fuipPostLogs();


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
	if(/^rgb/.test(value)) {  // like rgb(0,80,255)
		let parts = value.substr(4,value.length - 5).split(",");
		for(let i = 0; i < 3; i++) {
			result[i] = parseInt(parts[i]);
		};	
		result[3] = 1;
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


