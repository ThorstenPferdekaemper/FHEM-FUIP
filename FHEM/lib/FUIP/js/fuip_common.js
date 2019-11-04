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
		var name = $("html").attr("data-name");
		var newPage = $("html").data('fuipReturnTo');
		window.location = "/fhem/" + name.toLowerCase() +"/page/"+newPage;
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
	let url = location.origin + '/fhem/' + $("html").attr("data-name").toLowerCase() + '/fuip/logupload';
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


