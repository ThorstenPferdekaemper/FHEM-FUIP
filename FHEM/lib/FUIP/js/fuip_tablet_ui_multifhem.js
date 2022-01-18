/* FHEM tablet ui */

/** FUIP version by Thorsten Pferdekaemper
 * based on... see below
 */

/**
 * UI builder framework for FHEM
 *
 * Version: 2.7.14
 *
 * Copyright (c) 2015-2019 Mario Stephan <mstephan@shared-files.de>
 * Under MIT License (http://www.opensource.org/licenses/mit-license.php)
 * https://github.com/knowthelist/fhem-tablet-ui
 */

/* global Framework7:true, jQuery:true, Dom7:true */

"use strict";

// -------- Widget Base---------
var Modul_widget = function () {

    var subscriptions = {};
    var elements = [];

    function update_lock(dev, par) {
        ['lock', 'lock-on', 'lock-off'].forEach(function (key) {
            me.elements.filterDeviceReading(key, dev, par)
                .each(function (idx) {
                    var elem = $(this);
                    var value = elem.getReading('lock').val;
                    if (elem.matchingState('lock', value) === 'on') {
                        elem.addClass('lock');
                    }
                    if (elem.matchingState('lock', value) === 'off') {
                        elem.removeClass('lock');
                    }
                });
        });
    }

    function update_hide(dev, par) {
        ['hide', 'hide-on', 'hide-off'].forEach(function (key) {
            me.elements.filterDeviceReading(key, dev, par)
                .each(function (idx) {
                    var elem = $(this);
                    var value = elem.getReading('hide').val;
                    if (elem.matchingState('hide', value) === 'on') {
                        if (ftui.isValid(elem.data('hideparents'))) {
                            elem.parents(elem.data('hideparents')).addClass('hide');
                        } else {
                            elem.addClass('hide');
                        }
                    }
                    if (elem.matchingState('hide', value) === 'off') {
                        if (ftui.isValid(elem.data('hideparents'))) {
                            elem.parents(elem.data('hideparents')).removeClass('hide');
                        } else {
                            elem.removeClass('hide');
                        }
                    }
                });
        });
    }

    function updateHide(elem, dev, par) {
        ['hide', 'hide-on', 'hide-off'].forEach(function (key) {
            if (elem.matchDeviceReading(key, dev, par)) {
                var value = elem.getReading('hide').val;
                if (elem.matchingState('hide', value) === 'on') {
                    if (ftui.isValid(elem.data('hideparents'))) {
                        elem.parents(elem.data('hideparents')).addClass('hide');
                    } else {
                        elem.addClass('hide');
                    }
                }
                if (elem.matchingState('hide', value) === 'off') {
                    if (ftui.isValid(elem.data('hideparents'))) {
                        elem.parents(elem.data('hideparents')).removeClass('hide');
                    } else {
                        elem.removeClass('hide');
                    }
                }
            }
        });

    }

    function updateLock(elem, dev, par) {
        ['lock', 'lock-on', 'lock-off'].forEach(function (key) {
            if (elem.matchDeviceReading(key, dev, par)) {
                var value = elem.getReading('lock').val;
                if (elem.matchingState('lock', value) === 'on') {
                    elem.addClass('lock');
                }
                if (elem.matchingState('lock', value) === 'off') {
                    elem.removeClass('lock');
                }
            }
        });

    }

    function updateReachable(elem, dev, par) {
        ['reachable', 'reachable-on', 'reachable-off'].forEach(function (key) {
            if (elem.matchDeviceReading(key, dev, par)) {
                var value = elem.getReading('reachable').val;
                if (elem.matchingState('reachable', value) === 'on') {
                    elem.removeClass('unreachable');
                }
                if (elem.matchingState('reachable', value) === 'off') {
                    elem.addClass('unreachable');
                }
            }
        });
    }

    function update_reachable(dev, par) {
        ['reachable', 'reachable-on', 'reachable-off'].forEach(function (key) {
            me.elements.filterDeviceReading(key, dev, par)
                .each(function (idx) {
                    var elem = $(this);
                    var value = elem.getReading('reachable').val;
                    if (elem.matchingState('reachable', value) === 'on') {
                        elem.removeClass('unreachable');
                    }
                    if (elem.matchingState('reachable', value) === 'off') {
                        elem.addClass('unreachable');
                    }
                });
        });

    }

    function substitution(value, subst) {
        if (ftui.isValid(subst) && ftui.isValid(value)) {
            if ($.isArray(subst)) {
                for (var i = 0, len = subst.length; i < len; i += 2) {
                    if (i + 1 < len) {
                        value = value.replace(new RegExp(String(subst[i]), "g"), String(subst[i + 1]));
                    }
                }
            } else if (subst.match(/^s/)) {
                var f = subst.substr(1, 1);
                var sub = subst.split(f);
                return (value) ? value.replace(new RegExp(sub[1], sub[3]), sub[2]) : '';
            } else if (subst.match(/weekdayshort/))
                return ftui.dateFromString(value).ee();
            else if (subst.match(/.*\(.*\)/))
                return eval('value.' + subst);
        }
        return value;
    }


    function round(value, precision) {
        return ($.isNumeric(value) && precision) ? ftui.round(Number(value), precision) : value;
    }

    function fix(value, len) {
        return ($.isNumeric(value) && len >= 0) ? Number(value).toFixed(len) : value;
    }

    function factor(value, fac) {
        return ($.isNumeric(value) && fac >= 0) ? Number(value) * fac : value;
    }

    function map(mapObj, readval, defaultVal) {
        if ((typeof mapObj === 'object') && (mapObj !== null)) {
            for (var key in mapObj) {
                if (readval === key || readval.match(new RegExp('^' + key + '$'))){
                    return mapObj[key];
                }
            }
        }
        return defaultVal;
    }

    function init_attr(elem) {

        elem.initData('get', 'STATE');
        var get = elem.data('get');
        elem.initData('set', (get !== 'STATE') ? get : '');
        elem.initData('cmd', 'set');
        elem.initData('get-on', '(true|1|on|open|ON)');
        elem.initData('get-off', '!on');

        me.addReading(elem, 'get');
        if (elem.isDeviceReading('get-on')) {
            me.addReading(elem, 'get-on');
        }
        if (elem.isDeviceReading('get-off')) {
            me.addReading(elem, 'get-off');
        }


        // reachable parameter
        elem.initData('reachable-on', '!off');
        elem.initData('reachable-off', '(false|0)');
        me.addReading(elem, 'reachable');

        // if hide reading is defined, set defaults for comparison
        if (elem.isValidData('hide')) {
            elem.initData('hide-on', '(true|1|on)');
        }
        elem.initData('hide', 'STATE');
        if (elem.isValidData('hide-on')) {
            elem.initData('hide-off', '!on');
        }
        me.addReading(elem, 'hide');

        // if lock reading is defined, set defaults for comparison
        if (elem.isValidData('lock')) {
            elem.initData('lock-on', '(true|1|on)');
        }
        elem.initData('lock', elem.data('get'));
        if (elem.isValidData('lock-on')) {
            elem.initData('lock-off', '!on');
        }
        me.addReading(elem, 'lock');
    }

    function init_ui(elem) {
        elem.text(me.widgetname);
    }

    function reinit() { }

    function init() {
        ftui.log(1, "Init widget: name=" + me.widgetname + " area=" + me.area,"base.widget");
        me.elements = $('[data-type="' + me.widgetname + '"]:not([data-ready])', me.area);
        me.elements.each(function (index) {
            var elem = $(this);
			// store elem globally in order to find out 
			// the system id if needed
			ftui.currentElem = elem;			
			try {
				elem.attr("data-ready", "");
				me.init_attr(elem);
				elem = me.init_ui(elem);
			}finally{
				// invalidate current element to avoid getting the 
				// wrong element later
				ftui.currentElem = null;
			};	
        });
    }

    function addReading(elem, key) {
        var data = elem.data(key);

        if (!ftui.isValid(data)) {
			return;
		};	

        if (!$.isArray(data) && data.toString().match(/^[#\.\[][^:]*$/)) {
			return;
		};	
          
		var devices = elem.data('device');
		// allow multiple devices
		if (!$.isArray(devices)) {
			if (ftui.isValid(devices)) {
				devices = new Array(devices.toString());
			}else{			
                devices = new Array();
			};	
        }
        if (!$.isArray(data)) {
            data = new Array(data.toString());
        }
		
		var sysid = ftui.findSysidByElem(elem);
        var i = data.length;
        while (i--) {
            var reading = data[i];
            // fully qualified readings => DEVICE:READING
            if (reading.match(/:/)) {
                var fqreading = reading.split(':');
                var device = fqreading[0].replace('[', '');
                reading = fqreading[1].replace(']', '');
				// No device -> ignore this entry
				if (!ftui.isValid(device)) {
					continue;
				};
				if(ftui.isMultifhem()) {
				    me.addSubscription(sysid + '-' + device, reading);	
				}else{
				    me.addSubscription(device, reading);	
				}
            }else{
				for(var j = 0; j < devices.length; j++) {
					if(ftui.isMultifhem()) {
					    me.addSubscription(sysid + '-' + devices[j], reading);
					}else{
						me.addSubscription(devices[j], reading);
					};
				};	
			};
        }
    }

    function addSubscription(device, reading) {
        if (ftui.isValid(device) && ftui.isValid(reading) &&
            device !== '' && reading !== '' &&
            device !== ' ' && reading !== ' ') {
            device = device.toString();
            var paramid = (reading === 'STATE') ? device : [device, reading].join('-');
            subscriptions[paramid] = {};
            subscriptions[paramid].device = device;
            subscriptions[paramid].reading = reading;
        }
    }

    function extractReadings(elem, key) {
        var data = elem.data(key);

        if (!ftui.isValid(data)) {
			return;
		};	

        if (!$.isArray(data) && data.toString().match(/^[#\.\[][^:]*$/)) {
			return;
		};	
        
        if (!$.isArray(data)) {
            data = new Array(data.toString());
        }
		
		var sysid = ftui.findSysidByElem(elem);
        var i = data.length;
        while (i--) {
            var device, reading, item = data[i];
            // only fully qualified readings => DEVICE:READING
            if (item.match(/:/)) {
                var fqreading = item.split(':');
                device = fqreading[0].replace('[', '');
                reading = fqreading[1].replace(']', '');
            }
            // fill objects for mapping from FHEMWEB paramid to device + reading
			if(ftui.isMultifhem()) {
				me.addSubscription(sysid + '-' + device, reading);
			}else{
				me.addSubscription(device, reading);
			};			
        }
    }

    function update(dev, par) {
        ftui.log(1, 'warning: ' + me.widgetname + ' has not implemented update function',"base.widget");
    }
	
	
	// getFhemCallinfo
	// Determines how to call FHEM 
	// The parameter is either an object or a string
	//   If it is an object, we assume that it is a widget. In this case, try to get the
	//   sysid from the element
	//   If it is a string, we assume that it is the sysid or it starts with the sysid and a '-'
	// The return value is an object with...
	//   url: The FHEM Url
	//   csrf: The csrf token	
	function getFhemCallinfo(param) {
		if(!ftui.isMultifhem) {
			return {
				url: ftui.getFhemUrl(ftui.getDefaultSystemId()),
				csrf: ftui.config[ftui.getDefaultSystemId()].csrf
			};		
		};	
		
		var sysid;
		if(typeof param === 'object') {
			sysid = ftui.findSysidByElem(param);
		}else{
			sysid = param.split('-')[0];
		};	
		if(!sysid) 
			// TODO: Some kind of error handling?
			return null;	
		return {
			url: ftui.getFhemUrl(sysid),
			csrf: ftui.config[sysid].csrf
		};	
	};	
	

    var me = {
        widgetname: 'widget',
        area: '',
        init: init,
        reinit: reinit,
        init_attr: init_attr,
        init_ui: init_ui,
        update: update,
        update_lock: update_lock,
        update_reachable: update_reachable,
        update_hide: update_hide,
        updateHide: updateHide,
        updateLock: updateLock,
        updateReachable: updateReachable,
        substitution: substitution,
        fix: fix,
        factor: factor,
        round: round,
        map: map,
        addReading: addReading,
        addSubscription: addSubscription,
        extractReadings: extractReadings,
		getFhemCallinfo: getFhemCallinfo,
        subscriptions: subscriptions,
        elements: elements
    };

    return me;
};

// ------- Plugins --------
var plugins = {
    modules: [],

    addModule: function (module) {
        this.modules.push(module);
    },

    removeArea: function (area) {
        var i = this.modules.length;
        while (i--) {
            if (this.modules[i].area === area) {
                this.modules.splice(i, 1);
            }
        }
    },

    updateParameters: function () {
        ftui.subscriptions = {};
        ftui.subscriptionTs = {};
		// all devices
        ftui.devs = [];
		// devices and readings by sysid
        var devices = [];
		var readings = [];
		var systemIds = ftui.getSystemIds();
		for(var i = 0; i < systemIds.length; i++) {
			devices[systemIds[i]] = [];
			readings[systemIds[i]] = [];
		};
		
        var i = this.modules.length;
        while (i--) {
            var module = this.modules[i];
            for (var key in module.subscriptions) {
                ftui.subscriptions[key] = module.subscriptions[key];
                ftui.subscriptionTs[key + '-ts'] = module.subscriptions[key];
                var d = $.trim(ftui.subscriptions[key].device);
                if (ftui.devs.indexOf(d) < 0) {
                    ftui.devs.push(d);
                }
				// determine system id and system specific device id
				var dev = ftui.splitDeviceKey(d);
				if(devices[dev.sysid].indexOf(dev.device) < 0) {
					devices[dev.sysid].push(dev.device);
				};
                var reading = $.trim(ftui.subscriptions[key].reading);
				if(readings[dev.sysid].indexOf(reading) < 0) {
					readings[dev.sysid].push(reading);
				};			
            }
        }

        // build filters by sysid
		for(var i = 0; i < systemIds.length; i++) {
			var poll = ftui.poll[systemIds[i]];
			// do we have devices or readings at all?
			if( devices[systemIds[i]].length == 0 && 
			    readings[systemIds[i]].length == 0 ) {
				poll.hasSubscriptions = false;
                continue;				
			};		
			poll.hasSubscriptions = true;
			// build filters
			var devicelist = devices[systemIds[i]].join();
			var readinglist = readings[systemIds[i]].join(' ');
			poll.long.filter = devicelist + ', ' + readinglist;
			poll.short.filter = devicelist + ' ' + readinglist;
			// force shortpoll
			poll.short.lastTime = 0;
		};
    },

    load: function (name, area) {
        ftui.log(1, 'Load plugin "' + name + '" for area "' + area + '"',"base.widget");
        return ftui.loadPlugin(name, area);
    },

    reinit: function () {
        var i = this.modules.length;
        while (i--) {
            // Iterate each module and run reinit function if module is available
            if (typeof this.modules[i] === 'object') {
                this.modules[i].reinit();
            }
        }
    },

    update: function (device, reading) {
        var i = this.modules.length;
        while (i--) {
            // Iterate each module and run update function if module is available
            if (typeof this.modules[i] === 'object') {
                this.modules[i].update(device, reading);
            }
        }
        // update data-bind elements
        ftui.updateBindElements('ftui.deviceStates');

        ftui.log(1, 'call "plugins.update" done for "' + device + ':' + reading + '"',"base.widget");
    }
};

// -------- FTUI ----------

var ftui = {

    version: 'FUIP',
    config: {
        ICONDEMO: false,
        dir: '',
        filename: '',
        basedir: '',
        fhemDir: '',
        debuglevel: 0,
        lang: 'de',
        toastPosition: 'bottom-left',
        shortpollInterval: 0,
        styleCollection: {},
        stdColors: ["green", "orange", "red", "ligthblue", "blue", "gray", "white", "mint"]
    },

    poll: [], // array of sysids, i.e. one entry for each fhem backend

	// create default entry for poll array
	getPollDefaultEntry : function () {
		// TODO: check whether this always returns the same instance or new instances
		return {  
			short: {
				timer: null,
				request: null,
				lastTime: 0,  // formerly ftui.states.lastShortpoll
			},
			long: {
				xhr: null,  
				currLine: 0,
				lastEventTimestamp: Date.now(),
				openTimer: null  // timer to measure until connection is assumed as stable
			},
			status: 0,   // 0: DISCONNECTED, 1: CONNECTING, 2: CONNECTED, 3: DISCONNECTING
			healthCheckTimer: null,
			lastConnectTime: 0,
			connectWaitTime: 0,  // at first fail, we don't wait, then 50ms, then 100ms, then 200ms etc. max. wait is 5 secs
			connectRetryTimer: null,
		};
	},
	
	initialized: false,  // set to true after initWidgetsDone (formerly ftui.poll.initialized)

    states: {
        width: 0,
    },

    deviceStates: {},
    paramIdMap: {},
    timestampMap: {},
    subscriptions: {},
    subscriptionTs: {},
    scripts: [],
    gridster: {
        instances: {},
        instance: null,
        baseX: 0,
        baseY: 0,
        margins: 5,
        mincols: 0,
        cols: 0,
        rows: 0
    },

    init: function () {

        ftui.hideWidgets();

        ftui.paramIdMap = {};
        ftui.timestampMap = {};
        ftui.config.ICONDEMO = ($("meta[name='icondemo']").attr("content") == '1');
        ftui.config.fadeTime = $("meta[name='fade_time']").attr("content") || 200;
        if (ftui.config.fadeTime === '0') {
            ftui.log(1, 'fadeTime=0 => disable jQuery animation',"base.init");
            jQuery.fx.off = true;
        }
        ftui.config.maxLongpollAge = $("meta[name='longpoll_maxage']").attr("content") || 240;
        ftui.config.TOAST = $("meta[name='toast']").attr("content") || 8; //1,2,3...= n Toast-Messages, 0: No Toast-Messages
        ftui.config.toastPosition = $("meta[name='toast_position']").attr("content") || 'bottom-left';
		ftui.config.shortpollInterval = $("meta[name='shortpoll_interval']").attr("content") || 15 * 60; // 15 minutes
        //self path
        var url = window.location.pathname;
        ftui.config.filename = url.substring(url.lastIndexOf('/') + 1);
        ftui.log(1, 'Filename: ' + ftui.config.filename,"base.init");
        var fhemUrl = $("meta[name='fhemweb_url']").attr("content");
        ftui.config.fhemDir = fhemUrl || location.origin + "/fhem/";
        if (fhemUrl && new RegExp("^((?!http:\/\/|https:\/\/).)*$").test(fhemUrl)) {
            ftui.config.fhemDir = location.origin + "/" + fhemUrl + "/";
        }
        ftui.config.fhemDir = ftui.config.fhemDir.replace('///', '//');
		// change the meta tag because some widgets are using it (chart at least)
		$("meta[name='fhemweb_url']").attr("content",ftui.config.fhemDir);
        ftui.log(1, 'FHEM dir: ' + ftui.config.fhemDir,"base.init");
        // lang
        var userLang = navigator.language || navigator.userLanguage;
        ftui.config.lang = $("meta[name='lang']").attr("content") || ((ftui.isValid(userLang)) ? userLang.split('-')[0] : 'de');
        // credentials
        ftui.config.username = $("meta[name='username']").attr("content");
        ftui.config.password = $("meta[name='password']").attr("content");
        // subscriptions
        ftui.devs = [];

        var cssReadyDeferred = $.Deferred();
        var initDeferreds = [cssReadyDeferred];

		// stuff for each connected fhem
		var systemIds = ftui.getSystemIds();
		for(var i = 0; i < systemIds.length; i++) {
			// Get CSRF Token
			initDeferreds.push(
				ftui.getCSrf(systemIds[i])
			);
			// initialize poll array
			ftui.poll[systemIds[i]] = ftui.getPollDefaultEntry();
		};

        // init Toast
        function configureToast() {
            if ($.toast && !$('link[href$="lib/jquery.toast.min.css"]').length)
                $('head').append('<link rel="stylesheet" href="' + ftui.config.basedir +
                    'lib/jquery.toast.min.css" type="text/css" />');
        }

        if (!$.fn.toast) {
            ftui.dynamicload(ftui.config.basedir + "lib/jquery.toast.min.js", false).done(function () {
                configureToast();
            });
        } else {
            configureToast();
        }

        try {
            // try to use localStorage
            localStorage.setItem('ftui_version', ftui.version);
            localStorage.removeItem('ftui_version');
        } catch (e) {
            // there was an error so...
            ftui.toast('You are in Privacy Mode<br>Please deactivate Privacy Mode and then reload the page.', 'error');
        }

        // detect clickEventType
        var android = ftui.getAndroidVersion();
        var iOS = /iPad|iPhone|iPod/.test(navigator.userAgent) && !window.MSStream;
        var onlyTouch = ((android && parseFloat(android) < 5) || iOS);
        ftui.config.clickEventType = (onlyTouch) ? 'touchstart' : 'touchstart mousedown';
        ftui.config.moveEventType = ((onlyTouch) ? 'touchmove' : 'touchmove mousemove');
        ftui.config.releaseEventType = ((onlyTouch) ? 'touchend' : 'touchend mouseup');
        ftui.config.leaveEventType = ((onlyTouch) ? 'touchleave' : 'touchleave mouseout');
        ftui.config.enterEventType = ((onlyTouch) ? 'touchenter' : 'touchenter mouseenter');

        // add background for modal dialogs
        $("<div id='shade' />").prependTo('body').hide();
        $('#shade').on(ftui.config.clickEventType, function (e) {
            $(document).trigger("shadeClicked");
        });
		
		// add error overlay
		$("<div id='ftui-error-shade' style='position:fixed;z-index:9999;background-color:#AA0000;opacity:0.5;height:100%;width:100%;top:0px;left:0px;text-align: center;padding-top:20%;font-size:300%;font-weight:bold;'>Disconnected from FHEM, reconnecting</div>")
				.prependTo('body').hide();

        ftui.readStatesLocal();


        // init FTUI CSS if not already loaded
        if ($('link[href$="css/fhem-tablet-ui.css"]').length === 0 &&
            $('link[href$="css/fhem-tablet-ui.min.css"]').length === 0) {
            var cssUrl = ftui.config.basedir + 'css/fhem-tablet-ui.css';
            $.when($.get(cssUrl, function () {
                $('<link>', {
                    rel: 'stylesheet',
                    type: 'text/css',
                    'href': cssUrl
                }).prependTo('head');
            })).then(function () {
                var ii = 0;
                var cssListener = setInterval(function () {
                    ftui.log(1, 'fhem-tablet-ui.css dynamically loaded. Waiting until it is ready to use...',"base.init");
                    if ($("body").css("text-align") === "center") {
                        ftui.log(1, 'fhem-tablet-ui.css is ready to use.',"base.init");
                        clearInterval(cssListener);
                        cssReadyDeferred.resolve();
                    }
                    ii++;
                    if (ii > 120) {
                        clearInterval(cssListener);
                        ftui.toast("fhem-tablet-ui.css not ready to use", 'error');
                    }
                }, 50);
            });
        } else {
            cssReadyDeferred.resolve();
        }

        // init Page after css is ready and CSRF Token has been retrieved
        $.when.apply(this, initDeferreds).then(function () {
            ftui.loadStyleSchema();
            ftui.initPage();
        });

        $(document).on("changedSelection", function () {

            $(
                '.gridster li > header ~ .hbox:only-of-type, ' +
                '.dialog > header ~ .hbox:first-of-type:nth-last-of-type(1), ' +
                '.gridster li > header ~ .center:not([data-type]):only-of-type, ' +
                '.card > header ~ div:not([data-type]):only-of-type, ' +
                '.gridster li header ~ div:first-of-type:nth-last-of-type(1)'
            ).each(function (index) {
                var heightHeader = $(this).siblings('header').outerHeight();
                if (heightHeader > 0) {
                    $(this).css({
                        'height': 'calc(100% - ' + $(this).siblings('header').outerHeight() + 'px)'
                    });
                }
            });
        });

		
		// visibilitychange, online, initWidgetsDone
		//		if disconnected -> conditional connect
		// I have never seen the "online" event, but it probably does not do any harm to 
		// check whether we can connect
		$(document).on("initWidgetsDone visibilitychange online", function (event) {
			ftui.log(1, 'Event: ' + event.type,"base.poll");   
			// make sure that iniWidgetsDone is the first
			// sometimes visibilitychange comes before widgets are ready
			if(!ftui.initialized && event.type !== "initWidgetsDone") 
				return true;
			ftui.initialized = true;
			// connect to backends
			for(var i = 0; i < systemIds.length; i++) {
				if(ftui.poll[systemIds[i]].status == 0) 
					ftui.conditionalConnect(systemIds[i],true);
			};	
		});	
		// beforeunload
		//		disconnect
		// There was also the event "offline". However, I have never seen any 
		// "online" event when the connection came back. 
		// "beforeunload" seems to be triggered if the page is really "almost dead"
		// or when a mobile device sleeps for a while. 
		$(window).on("beforeunload", function (event) {
			ftui.log(1, 'Event: ' + event.type,"base.poll"); 
			// The following might look a bit weird. It is here to solve the following
			// issue: Some browsers (Chrome Mobile) trigger a beforeunload after sleeping
			// for a while. When coming back, the page is shown, but there are no
			// events (like visibilitychange, online, focus etc.) triggered. 
			// It also seems that after beforeunload, nothing is processed until the
			// page is really back. This means that we do not have to try the connect
			// multiple times or so.
			// Put this a little bit into the future to avoid immediate reconnect for 
			// real "beforeunload".
			// 250 ms should be ok. 100ms is a bit short, it sometimes tries to 
			// reconnect.
			for(var i = 0; i < systemIds.length; i++) {
				ftui.disconnect(systemIds[i]);
				setTimeout(function() {	ftui.conditionalConnect(systemIds[i],true) }, 250);
			};	
		});	
				
        $(document).on("initWidgetsDone", function () {

            ftui.initHeaderLinks();

            // calculate full line height
            $(".line-full").each(function () {
                $(this).css({
                    'line-height': $(this).parent().height() + 'px'
                });
            });

            // trigger refreshs
            $(document).trigger('changedSelection');
            if (!ftui.config.ICONDEMO) {
                ftui.disableSelection();
            }
        });

        // dont show focus frame
        $("*:not(select):not(textarea)").focus(function () {
			$(this).blur();
        });
    },

    initGridster: function (area) {

        ftui.gridster.minX = parseInt($("meta[name='widget_min_width'],meta[name='gridster_min_width']").attr("content") || 0);
        ftui.gridster.minY = parseInt($("meta[name='widget_min_height'],meta[name='gridster_min_height']").attr("content") || 0);
        ftui.gridster.baseX = parseInt($("meta[name='widget_base_width'],meta[name='gridster_base_width']").attr("content") || 0);
        ftui.gridster.baseY = parseInt($("meta[name='widget_base_height'],meta[name='gridster_base_height']").attr("content") || 0);
        ftui.gridster.cols = parseInt($("meta[name='gridster_cols']").attr("content") || 0);
        ftui.gridster.rows = parseInt($("meta[name='gridster_rows']").attr("content") || 0);
        ftui.gridster.resize = parseInt($("meta[name='gridster_resize']").attr("content") || (ftui.gridster.baseX + ftui.gridster.baseY) >
            0 ? 0 : 1);
        if ($("meta[name='widget_margin'],meta[name='gridster_margin']").attr("content"))
            ftui.gridster.margins = parseInt($("meta[name='widget_margin'],meta[name='gridster_margin']").attr("content"));

        function configureGridster() {

            var highestCol = -1;
            var highestRow = -1;
            var baseX = 0;
            var baseY = 0;
            var cols = 0;
            var rows = 0;

            $(".gridster > ul > li").each(function () {
                var colVal = $(this).data("col") + $(this).data("sizex") - 1;
                if (colVal > highestCol)
                    highestCol = colVal;
                var rowVal = $(this).data("row") + $(this).data("sizey") - 1;
                if (rowVal > highestRow)
                    highestRow = rowVal;
            });

            cols = (ftui.gridster.cols > 0) ? ftui.gridster.cols : highestCol;
            rows = (ftui.gridster.rows > 0) ? ftui.gridster.rows : highestRow;

            var colMargins = 2 * cols * ftui.gridster.margins;
            var rowMargins = 2 * rows * ftui.gridster.margins;

            baseX = (ftui.gridster.baseX > 0) ? ftui.gridster.baseX : (window.innerWidth - colMargins) / cols;
            baseY = (ftui.gridster.baseY > 0) ? ftui.gridster.baseY : (window.innerHeight - rowMargins) / rows;

            if (baseX < ftui.gridster.minX) {
                baseX = ftui.gridster.minX;
            }
            if (baseY < ftui.gridster.minY) {
                baseY = ftui.gridster.minY;
            }

            ftui.gridster.mincols = parseInt($("meta[name='widget_min_cols'],meta[name='gridster_min_cols']").attr("content") ||
                cols);

            if (ftui.gridster.instances[area])
                ftui.gridster.instances[area].destroy();

            ftui.gridster.instances[area] = $(".gridster > ul", area).gridster({
                widget_base_dimensions: [baseX, baseY],
                widget_margins: [ftui.gridster.margins, ftui.gridster.margins],
                draggable: {
                    handle: '.gridster li > header'
                },
                min_cols: parseInt(ftui.gridster.mincols),
            }).data('gridster');

            if (ftui.gridster.instances[area]) {
                if ($("meta[name='gridster_disable']").attr("content") == '1') {
                    ftui.gridster.instances[area].disable();
                }
                if ($("meta[name='gridster_starthidden']").attr("content") == '1') {
                    $('.gridster').hide();
                }
            }
            // corrections for gridster in gridster element
            $('.gridster > ul > li:has(* .gridster)').each(function () {
                var gridgrid = $(this);
                gridgrid.css({
                    'background-color': 'transparent',
                    'margin': '-' + ftui.gridster.margins + 'px'
                });
            });

            $('.gridster > ul > li >.center', area).parent().addClass('has_center');
            // max height for inner boxes
            $('.gridster > ul > li > .vbox', area).parent().addClass('has_vbox');

        }

        if ($('.gridster', area).length) {

            if (!$('link[href$="lib/jquery.gridster.min.css"]').length)
                $('head').append('<link rel="stylesheet" href="' + ftui.config.basedir +
                    'lib/jquery.gridster.min.css" type="text/css" />');

            if (!$.fn.gridster) {
                ftui.dynamicload(ftui.config.basedir + "lib/jquery.gridster.min.js", false).done(function () {
                    configureGridster();
                });
            } else {
                configureGridster();
            }

            if (ftui.gridster.resize) {
                $(window).on('resize', function () {
                    if (ftui.states.width !== window.innerWidth) {
                        clearTimeout(ftui.states.delayResize);
                        ftui.states.delayResize = setTimeout(configureGridster, 500);
                        ftui.states.width = window.innerWidth;
                    }
                });
            }
        }
    },

    initPage: function (area) {

        // hideWidgets
        ftui.hideWidgets(area);

        // init gridster
        area = (ftui.isValid(area)) ? area : 'html';

        ftui.states.startTime = new Date();
        ftui.log(2, 'initPage - area=' + area, "base.init");

        ftui.initGridster(area);

        // include extern html code
        var deferredArr = $.map($('[data-template]', area), function (templ, i) {
            var templElem = $(templ);
            return $.get(
                templElem.data('template'), {},
                function (data) {
                    var parValues = templElem.data('parameter');
                    for (var key in parValues) {
                        data = data.replace(new RegExp(key, 'g'), parValues[key]);
                    }
                    templElem.html(data);
                }
            );
        });

        // get current values of readings not before all widgets are loaded
        $.when.apply(this, deferredArr).then(function () {
            //continue after loading the includes
            ftui.log(1, 'init templates - Done', "base.init");
            ftui.initWidgets(area).done(function () {
                var dur = 'initPage (' + area + '): in ' + (new Date() - ftui.states.startTime) + 'ms';
                ftui.log(1, dur, "base.init");
            });
        });
    },

    initWidgets: function (area) {

        var defer = new $.Deferred();
        area = (ftui.isValid(area)) ? area : 'html';
        var types = [];
        ftui.log(2, 'initWidgets before- area=' + area, "base.init");
        ftui.log(2, $.map(plugins.modules, function (m) {
            return (m.area + ':' + m.widgetname);
        }).join('  '), "base.init");
        plugins.removeArea(area);
        ftui.log(2, 'initWidgets after removed- area=' + area, "base.init");
        ftui.log(2, $.map(plugins.modules, function (m) {
            return (m.area + ':' + m.widgetname);
        }).join('  '), "base.init");

        // collect required widgets types
        $('[data-type] ', area).each(function (index) {
            var type = $(this).data("type");
            if (types.indexOf(type) < 0) {
                types.push(type);
            }
        });

        // init widgets
        var allWidgetsDeferred = $.map(types, function (type, i) {
            return plugins.load(type, area);
        });

        // get current values of readings not before all widgets are loaded
        $.when.apply(this, allWidgetsDeferred).then(function () {
            plugins.updateParameters();
            ftui.log(1, 'initWidgets - Done', "base.init");
            $(document).trigger("initWidgetsDone", [area]);
            defer.resolve();
        });
        return defer.promise();
    },

    initHeaderLinks: function () {

        if (($('[class*=fa-]').length ||
            $('[data-type="select"]').length ||
            $('[data-type="homestatus"]').length) &&
            !$('link[href$="lib/font-awesome.min.css"]').length
        )
            $('head').append('<link rel="stylesheet" href="' + ftui.config.basedir + 'lib/font-awesome.min.css" type="text/css" />');
        if ($('[class*=oa-]').length && !$('link[href$="lib/openautomation.css"]').length)
            $('head').append('<link rel="stylesheet" href="' + ftui.config.basedir + 'lib/openautomation.css" type="text/css" />');
        if ($('[class*=fs-]').length && !$('link[href$="lib/fhemSVG.css"]').length)
            $('head').append('<link rel="stylesheet" href="' + ftui.config.basedir + 'lib/fhemSVG.css" type="text/css" />');
        if ($('[class*=mi-]').length && !$('link[href$="lib/material-icons.min.css"]').length)
            $('head').append('<link rel="stylesheet" href="' + ftui.config.basedir +
                'lib/material-icons.min.css" type="text/css" />');
        if ($('[class*=wi-]').length && !$('link[href$="lib/weather-icons.min.css"]').length)
            $('head').append('<link rel="stylesheet" href="' + ftui.config.basedir +
                'lib/weather-icons.min.css" type="text/css" />');
        if ($('[class*=wi-wind]').length && !$('link[href$="lib/weather-icons-wind.min.css"]').length)
            $('head').append('<link rel="stylesheet" href="' + ftui.config.basedir +
                'lib/weather-icons-wind.min.css" type="text/css" />');
    },

	
	// isMultifhem
	// returns true if there are multiple backend systems
	isMultifhem: function() {
		var sysids =  ftui.getSystemIds();
		return sysids.length > 1;
	},	
	
 
	shortPoll: function (sysid) {
		var deferred = $.Deferred();
        var ltime = Date.now() / 1000;
        ftui.log(1, 'start shortpoll ' + sysid, "base.poll");
        // invalidate all readings for detection of outdated ones
        var i = ftui.devs.length;
        while (i--) {
			// correct sysid (backend)?
			if(ftui.isMultifhem() && ftui.splitDeviceKey(ftui.devs[i]).sysid != sysid) {
				continue;
			}
            var params = ftui.deviceStates[ftui.devs[i]];
            for (var reading in params) {
                params[reading].valid = false;
            }
        };
        ftui.poll[sysid].short.request =
            ftui.sendFhemCommandWithSysid('jsonlist2 ' + ftui.poll[sysid].short.filter,sysid)
                .done(function (fhemJSON) {
                    ftui.log(3, 'fhemJSON: 0=' + Object.keys(fhemJSON)[0] + ' 1=' + Object.keys(fhemJSON)[1], "base.poll");

                    // function to import data
                    function checkReading(device, section) {
                        for (var reading in section) {
                            var isUpdated = false;
                            var paramid = (reading === 'STATE') ? device : [device, reading].join('-');
                            var newParam = section[reading];
                            if (typeof newParam !== 'object') {
                                //ftui.log(5,'paramid='+paramid+' newParam='+newParam);

                                newParam = {
                                    "Value": newParam,
                                    "Time": ""
                                };
                            }

                            // is there a subscription, then check and update widgets
                            if (ftui.subscriptions[paramid]) {
                                var oldParam = ftui.getDeviceParameter(device, reading);
                                isUpdated = (!oldParam || oldParam.val !== newParam.Value || oldParam.date !== newParam.Time);
                                // ftui.log(5, 'isUpdated=' + isUpdated);
                             
                                // write into internal cache object
                                var params = ftui.deviceStates[device] || {};
                                var param = params[reading] || {};
                                param.date = newParam.Time;
                                param.val = newParam.Value;
                                // console.log('*****',device);
                                param.valid = true;
                                params[reading] = param;
                                ftui.deviceStates[device] = params;

                                ftui.paramIdMap[paramid] = {};
                                ftui.paramIdMap[paramid].device = device;
                                ftui.paramIdMap[paramid].reading = reading;
                                ftui.timestampMap[paramid + '-ts'] = {};
                                ftui.timestampMap[paramid + '-ts'].device = device;
                                ftui.timestampMap[paramid + '-ts'].reading = reading;

                                // update widgets only if necessary
                                if (isUpdated) {
                                    ftui.log(5, '[shortPoll] do update for ' + device + ',' + reading, "base.update");
                                    plugins.update(device, reading);
                                }
                            }
                          }
                    }

                    // import the whole fhemJSON
                    if (fhemJSON && fhemJSON.Results) {
                        var i = fhemJSON.Results.length;
                        ftui.log(2, 'shortpoll: fhemJSON.Results.length=' + i, "base.poll");
                        var results = fhemJSON.Results;
                        while (i--) {
                            var res = results[i];
                            var devName = res.Name;
                            if (devName.indexOf('FHEMWEB') < 0 && !devName.match(/WEB_\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}_\d{5}/)) {
								if(ftui.isMultifhem()) {
									devName = sysid + '-' + devName;
								};	
                                checkReading(devName, res.Internals);
                                checkReading(devName, res.Attributes);
                                checkReading(devName, res.Readings);
                            }
                        }

                        // finished
                        ftui.log(1, 'shortPoll: Done', "base.poll");
                        ftui.poll[sysid].short.lastTime = ltime;
                        ftui.saveStatesLocal();
                        ftui.updateBindElements('ftui.');
                        ftui.onUpdateDone();
						deferred.resolve();
                    } else {
                        var err = "request failed: Result is null";
                        ftui.log(1, "shortPoll: " + err, "base.poll");
						deferred.reject("ShortPoll: no result");
                    }
                })
                .fail(function (jqxhr, textStatus, error) {
					ftui.showErrorOverlay(true,sysid);
                    var err = textStatus + ", " + error;
                    ftui.log(1, "shortPoll: request failed: " + err, "base.poll");
                    ftui.saveStatesLocal();
                    if (textStatus.indexOf('parsererror') < 0) {
						// it is relatively likely that this is because FHEM restarted
						ftui.getCSrf(sysid);
                    };
					deferred.reject("ShortPoll request failed " + err);
                });
		return deferred.promise();		
    },
	
	
	setConnected: function(sysid) {
		if(ftui.poll[sysid].status != 1)
			return;
		ftui.showErrorOverlay(false);
		if(ftui.poll[sysid].long.openTimer) {
			clearTimeout(ftui.poll[sysid].long.openTimer);
			ftui.poll[sysid].long.openTimer = null;
		};	
		ftui.poll[sysid].connectWaitTime = 0;
		// start health check timer
		ftui.poll[sysid].healthCheckTimer = setInterval(ftui.healthCheck, 60000);
		// start shortpoll timer
		ftui.poll[sysid].short.timer = setInterval(function () {
				ftui.shortPoll(sysid).fail(function() { ftui.conditionalConnect(sysid); } );
			}, ftui.config.shortpollInterval * 1000);
		// log and status
		ftui.log(1, "CONNECTED","base.poll");	
		ftui.poll[sysid].status = 2;  // connected	
	},	
	

    createLongpoll: function (sysid) {
        ftui.log(2, "Longpoll creation started", "base.poll");
		
		// TODO: is the below really needed?
		//		If we come here and xhr or request still exist, then
		//      something has gone (very?) wrong.
		if (ftui.poll[sysid].long.xhr) {
			ftui.log(1, 'longpoll: valid ftui.poll.long.xhr found', "base.poll");
			return;
		}
		if (ftui.poll[sysid].long.request) {
			ftui.log(1, 'longpoll: valid ftui.poll.long.request found', "base.poll");
			return;
		}
		
		ftui.poll[sysid].long.currLine = 0;

		ftui.poll[sysid].long.request = $.ajax({
			url: ftui.getFhemUrl(sysid),
			cache: false,
			async: true,
			method: 'GET',
			data: {
				XHR: 1,
				inform: 'type=status;filter=' + ftui.poll[sysid].long.filter + ';since=' +
						ftui.poll[sysid].long.lastEventTimestamp + ';fmt=JSON',
				fwcsrf: ftui.config[sysid].csrf
			},
			username: ftui.config.username,
			password: ftui.config.password,
			xhr: function () {
					ftui.poll[sysid].long.xhr = new window.XMLHttpRequest();
					ftui.poll[sysid].long.xhr.addEventListener('readystatechange', function (e) {
						if(e.target.readyState === 1) {  // opened
							ftui.poll[sysid].long.openTimer = setTimeout(function() { ftui.setConnected(sysid); } ,1500);
						};
						if (e.target.readyState === 2) {  // received headers
							ftui.setConnected(sysid);
						};	
						if (e.target.readyState === 3) { // loading, i.e. data received
							ftui.setConnected(sysid);
							ftui.handleUpdates(sysid, e.target.responseText);
						}
						if (e.target.readyState === 4) { // done or failure
							if(ftui.poll[sysid].long.openTimer) {
								clearTimeout(ftui.poll[sysid].long.openTimer);
								ftui.poll[sysid].long.openTimer = null;
							};	
						};
					}, false);
					return ftui.poll[sysid].long.xhr;
			}
		})
		.always(function() {
			if (ftui.poll[sysid].long.xhr) {
				ftui.poll[sysid].long.xhr.abort();
				ftui.poll[sysid].long.xhr = null;
			}
			ftui.poll[sysid].long.request = null;
		})
        .done(function (data) {
            ftui.log(1, 'Longpoll done ' + data, "base.poll");
        })
        .fail(function (jqXHR, textStatus, errorThrown) {	
			switch(ftui.poll[sysid].status) {
				case 0:
					// Intentionally disconnected anyway. It is a bit weird 
					// that we come here, but it probably does not do much harm
					ftui.log(2, "Longpoll for " + sysid + " failed (" + textStatus + ", " + 
								errorThrown + "), but anyway disconnected","base.poll");	
					break;			
				case 3:
					// We are disconnecting, so this is kind of normal
					ftui.log(3, "Disconnecting, longpoll for " + sysid + " stopped","base.poll");
					break;
				default:	
					// Otherwise, the connection has failed somehow, se we should show the user
					// and try to restart later
					ftui.showErrorOverlay(true,sysid);
					ftui.log(1, "Longpoll for " + sysid + " failed (" + textStatus + ", " + 
								errorThrown + "), trying to restart","base.poll");	
			};			
        })
		.always(function(){
			// Reconnect, but only if we are not disconnected or disconnecting 
			if(ftui.poll[sysid].status != 0 && ftui.poll[sysid].status != 3) 
			    ftui.conditionalConnect(sysid, false)
		});
    },

	
    handleUpdates: function (sysid, data) {
		// set "timestamp of last event" to 5 seconds before
		// this should make sure that we do not lose anything when restarting
		// the connection
		ftui.poll[sysid].long.lastEventTimestamp = Date.now() - 5000;
        var lines = data.split(/\n/);
        for (var i = ftui.poll[sysid].long.currLine, len = lines.length; i < len; i++) {
            ftui.log(5, lines[i], "base.update");
            ftui.poll[sysid].long.lastLine = lines[i];
            var lastChar = lines[i].slice(-1);
            if (ftui.isValid(lines[i]) && lines[i] !== '' && lastChar === "]") {
                try {
                    var dataJSON = JSON.parse(lines[i]);	
                    var params = null;
                    var param = null;
                    var isSTATE = (dataJSON[1] !== dataJSON[2]);
                    var isTrigger = (dataJSON[1] === '' && dataJSON[2] === '');

                    ftui.log(4, dataJSON, "base.update");

					var paramId = dataJSON[0];	
					if(ftui.isMultifhem()) {
						paramId = sysid + '-' + paramId;	
					};	
                    var pmap = ftui.paramIdMap[paramId];
                    var tmap = ftui.timestampMap[paramId];
                    var subscription = ftui.subscriptions[paramId];
                    // update for a parameter
                    if (pmap) {
                        if (isSTATE) {
                            pmap.reading = 'STATE';
                        }
                        params = ftui.deviceStates[pmap.device] || {};
                        param = params[pmap.reading] || {};
                        param.val = dataJSON[1];
                        param.valid = true;
                        params[pmap.reading] = param;
                        ftui.deviceStates[pmap.device] = params;
                        // dont wait for timestamp for STATE paramters
                        if (isSTATE && subscription) {
                            plugins.update(pmap.device, pmap.reading);
                        }
                    }
                    // update for a timestamp
                    // STATE updates has no timestamp
                    if (tmap && !isSTATE) {
                        params = ftui.deviceStates[tmap.device] || {};
                        param = params[tmap.reading] || {};
                        param.date = dataJSON[1];
                        params[tmap.reading] = param;
                        ftui.deviceStates[tmap.device] = params;
                        // paramter + timestamp update now completed -> update widgets
                        if (ftui.subscriptionTs[paramId]) {
                            plugins.update(tmap.device, tmap.reading);
                        }
                    }
                    // it is just a trigger
                    if (isTrigger && subscription) {
                        plugins.update(subscription.device, subscription.reading);
                    }
                } catch (err) {
                    ftui.poll[sysid].long.lastError = err;
                    ftui.log(1, "longpoll: Error=" + err, "base.update");
                    ftui.log(1, "longpoll: Bad line=" + lines[i], "base.update");
                }
            }
        }
        ftui.updateBindElements('ftui.poll');
		
		// Ajax longpoll 
		// cumulative data -> remember last line 
		// restart after 9999 lines to avoid overflow
		ftui.poll[sysid].long.currLine = lines.length - 1;
		if (ftui.poll[sysid].long.currLine > 9999) {
			ftui.log(1, "Longpoll line overflow, restarting", "base.update");
			ftui.conditionalConnect(sysid,true);
		}
    },

	//findSysid
	//Try to find current system id. These are only heuristics...
	//TODO: Heuristics?
	//TODO: Once this is all a bit more mature, replace defaulting 
	//      by some error management
	findSysid: function() {
		var defaultId = ftui.getDefaultSystemId();
		if(!ftui.isMultifhem) 
			return defaultId;
	
		// If this is called by an event handler...
		var result = ftui.findSysidByEvent();
		if(result) return result;
		
		// Do we have a "current" element?
		var result = ftui.findSysidByElem(ftui.currentElem);
		if(result) return result;

		return defaultId;  // not found
	},	
	
		
	// findSysidByEvent
	// Try to find the system id using the current event (if any)
	findSysidByEvent() {
		if(!ftui.isMultifhem) 
			return ftui.getDefaultSystemId();
		// Somewhere in the path, we should
		// find the view, which has a system id
		if(window.event === undefined) 
			return null;
		// TODO: If we have an event, but without a path, shouldn't 
		//       this lead to some error message?
		if(window.event.path === undefined)
			return null;
		for(var i = 0; i < window.event.path.length; i++) {
			var sysid = $(window.event.path[i]).data('sysid');
			if(sysid) {
				ftui.validateSysid(sysid,$(window.event.path[i]));
				return sysid;
			};	
		};	
		return null;  // not found
	},	
	
	
	// findSysidByElem
	// Try to find a system id in the current element or "above"
	findSysidByElem: function(elem) {
		if(!ftui.isMultifhem) 
			return ftui.getDefaultSystemId();
		for(;elem && elem.length;elem = elem.parent()) {
			var sysid = elem.data('sysid');
			if(sysid) {
				ftui.validateSysid(sysid,elem);
				return sysid;
			};	
		};	
		return null;  // not found
	},	
	
	
	//getFhemUrl
	// Finds the URL to call the backend of a system id
	getFhemUrl: function(sysid) {
		// getSystemUrl is generated by FUIP directly into the HTML head
		// it returns ftui.config.fhemDir by default
		return ftui.getSystemUrl(sysid);
	},	
	
	
	validateSysid(sysid,elem) {
		var sysids =  ftui.getSystemIds();
		if(sysids.indexOf(sysid) >= 0) 
			// ok
			return;
		
		// not ok
		if(sysid) {
			ftui.toast('Unkown system id: ' + sysid, 'error');
		}else{	
			ftui.toast('Empty system id','error');
		}	
	},	
	
	
	//splitDeviceKey
	// ...into sysid and device
	// TODO: Do we need anything for the case where there is no "-"?
	splitDeviceKey: function(device) {
		if(ftui.isMultifhem()) {
			var split = device.split('-');
			var result = {};
			result.sysid = split.shift();
			result.device = split.join('-');
			return result;
		}else{
			return { sysid : ftui.getDefaultSystemId(), device : device };
		};	
	},
	
	
    setFhemStatus: function (cmdline) {
        ftui.sendFhemCommand(cmdline);
    },
	

	// sendFhemCommand
	// elem is optional	
	sendFhemCommand: function (cmdline, elem) {
		// This is the "old" call, where we do not have a system id
		var sysid = ftui.findSysidByElem(elem);
		if(!sysid) 
			sysid = ftui.findSysid();
		return ftui.sendFhemCommandWithSysid(cmdline,sysid);
	},	
		
		
	sendFhemCommandWithSysid: function (cmdline,sysid) {	
        cmdline = cmdline.replace('  ', ' ');
        var dataType = (cmdline.substr(0, 8) === 'jsonlist') ? 'json' : 'text';
		var url = ftui.getFhemUrl(sysid);
        ftui.log(1, 'send to FHEM: ' + cmdline, "base.command");
        return $.ajax({
            async: true,
            cache: false,
            method: 'GET',
            dataType: dataType,
            url: url,
            username: ftui.config.username,
            password: ftui.config.password,
            data: {
                cmd: cmdline,
                fwcsrf: ftui.config[sysid].csrf,
                XHR: "1"
            },
            error: function (jqXHR, textStatus, errorThrown) {
                ftui.log(1, "FHEM Command failed " + textStatus + ": " + errorThrown + " cmd=" + cmdline, 'base.command');
            }
        });

    },

    loadStyleSchema: function () {

        $.each($('link[href$="-ui.css"],link[href$="-ui.min.css"]'), function (index, thisSheet) {
            if (!thisSheet || !thisSheet.sheet || !thisSheet.sheet.cssRules || thisSheet.getAttribute('disabled')) return;
            var rules = thisSheet.sheet.cssRules;
            for (var r in rules) {
                if (rules[r].style) {
                    var styles = rules[r].style.cssText.split(';');
                    styles.pop();
                    var elmName = rules[r].selectorText;
                    var params = {};
                    for (var s in styles) {
                        var param = styles[s].toString().split(':');
                        if (param[0].match(/color/)) {
                            params[$.trim(param[0])] = ftui.rgbToHex($.trim(param[1]).replace('! important', '').replace(
                                '!important', ''));
                        }
                    }
                    if (Object.keys(params).length)
                        ftui.config.styleCollection[elmName] = params;
                }
            }
        });
    },

    onUpdateDone: function () {
        $(document).trigger("updateDone");
        ftui.checkInvalidElements();
        ftui.updateBindElements();
    },

    checkInvalidElements: function () {
        $('.autohide[data-get]').each(function (index) {
            var elem = $(this);
            var valid = elem.getReading('get').valid;
            if (valid && valid === true)
                elem.removeClass('invalid');
            else
                elem.addClass('invalid');
        });
    },

    updateBindElements: function (filter) {
        $('[data-bind*="' + filter + '"]').each(function (index) {
            var elem = $(this);
            var variable = elem.data('bind');
            if (variable) {
                elem.text(eval(variable));
            }
        });
    },


	connect: function(sysid) {
		// this assumes that we are disconnected and that no timers are running
		// TODO: handle csrf errors better
		
		ftui.log(1, 'CONNECTING ' + sysid, "base.poll");
		ftui.poll[sysid].status = 1;  // connecting
		// if shortpoll is due (check via real time)
		var ltime = Date.now() / 1000;
        if (ltime - ftui.poll[sysid].short.lastTime >= ftui.config.shortpollInterval) {
			ftui.poll[sysid].long.lastEventTimestamp = Date.now();
		//		start shortpoll
		//			fail: like onclose (conditionalConnect)
		//			success: handle results
		// TODO: read system id
			ftui.shortPoll(sysid).then(
				function() { ftui.createLongpoll(sysid) }, 
				function() { ftui.conditionalConnect(sysid) }
			);
		}else{
			ftui.createLongpoll(sysid);
		};	
	},	
	
	
	disconnect: function(sysid) {
		var poll = ftui.poll[sysid];
		poll.status = 3;  // disconnecting
		if (poll.long.request)
			poll.long.request.abort();
		// stop healthcheck timer
		clearInterval(poll.healthCheckTimer);
		// stop shortpoll timer
		clearInterval(poll.short.timer);
		// abort shortpoll, if needed
		if(poll.short.request) {
			poll.short.request.abort();
			poll.short.request = null;
		};	
		ftui.log(1, 'DISCONNECTED ' + sysid, "base.poll");
		poll.status = 0;  // disconnected
	},
	
	
	conditionalConnect: function(sysid, immediately) {
		// This seems to be called sometimes with not yet initialized
		// or already cleared data
		var poll = ftui.poll[sysid];
		if(!poll) return;
		if(!poll.hasSubscriptions) return;
		
		// disconnect first to start in a clean state
		ftui.disconnect(sysid);
		// avoid that we do this multiple times
		if(poll.connectRetryTimer) {
			clearTimeout(poll.connectRetryTimer);
			poll.connectRetryTimer = null;
		};
		// if not visible, don't try to connect
		// There used to be a check on navigator.onLine as well, but this does not
		// seem to work properly
		if(document.visibilityState !== 'visible') {
			ftui.log(1, 'Staying DISCONNECTED: invisible or offline', "base.poll");
			poll.connectWaitTime = 0; // immediately connect when becoming visible or online 
			return;
		};	
		// if we have tried to connect less than n seconds ago, 
		// then wait a bit
		if(immediately) {
			poll.connectWaitTime = 0;  
		};
		if(poll.connectWaitTime > 0) { 
			var lastConnectAge = Date.now() - poll.lastConnectTime;
			if(lastConnectAge < poll.connectWaitTime) { 
				ftui.log(4, 'Connect wait time ' + poll.connectWaitTime + " ...waiting", "base.poll");
				poll.connectRetryTimer = setTimeout(function() { ftui.conditionalConnect(sysid); }, poll.connectWaitTime - lastConnectAge);
				return;
			};	
		};
		// determine next time: 50,100,200,400,...,3200,5000
		if(poll.connectWaitTime) {
			poll.connectWaitTime *= 2;
			if(poll.connectWaitTime > 5000) poll.connectWaitTime = 5000;
		}else{
			poll.connectWaitTime = 50;
		};	
		poll.lastConnectTime = Date.now();
		ftui.connect(sysid);
	},	
		
	
	readStatesLocal: function () {
        ftui.deviceStates = JSON.parse(localStorage.getItem('ftui.deviceStates')) || {};
    },

    saveStatesLocal: function () {
        //save variables into localStorage
        try {
			localStorage.setItem("ftui.deviceStates", JSON.stringify(ftui.deviceStates));
        } catch (e) {
			ftui.log(1, 'Unable to save device states to localStorage', "base");
		}
    },

    getDeviceParameter: function (devname, paraname) {
        if (devname && devname.length) {
            var params = ftui.deviceStates[devname];
            return (params && params[paraname]) ? params[paraname] : null;
        }
        return null;
    },

    loadPlugin: function (name, area) {

        var deferredLoad = new $.Deferred();
        ftui.log(2, 'Start load plugin "' + name + '" for area "' + area + '"', "base.widget");

        // get the plugin
        ftui.dynamicload(ftui.config.basedir + "js/widget_" + name + ".js", true).done(function () {

            // get all dependencies of this plugin
            var depsPromises = [];
            var getDependencies = window["depends_" + name];

            // load all dependencies recursive before
            if ($.isFunction(getDependencies)) {

                var deps = getDependencies();
                if (deps) {
                    deps = ($.isArray(deps)) ? deps : [deps];
                    $.map(deps, function (dep, i) {
                        if (dep.match(new RegExp('^.*\.(js|css)$'))) {
                            depsPromises.push(ftui.dynamicload(dep, false));
                        } else {
                            depsPromises.push(ftui.loadPlugin(dep));
                        }
                    });
                }
            } else {
                ftui.log(2, "function depends_" + name + " not found (maybe ok)", "base.widget");
            }

            $.when.apply(this, depsPromises).always(function () {
                var module = (window["Modul_" + name]) ? new window["Modul_" + name]() : null;
                if (module) {
                    if (area !== void 0) {

                        // add only real widgets not dependencies
                        plugins.addModule(module);
                        if (ftui.isValid(area))
                            module.area = area;

                        ftui.log(1, 'Try to init plugin: ' + name, "base.widget");
                        module.init();

                        // update all what we have until now
                        for (var key in module.subscriptions) {
                            module.update(module.subscriptions[key].device, module.subscriptions[key].reading);
                        }
                    }
                    ftui.log(1, 'Finished load plugin "' + name + '" for area "' + area + '"', "base.widget");
                    $('[data-type="' + name + '"]', area).removeClass('widget-hide');

                } else {
                    ftui.log(1, 'Failed to load plugin "' + name + '" for area "' + area + '"', "base.widget");
                }

                deferredLoad.resolve();
            });

        })
            .fail(function () {
                ftui.toast('Failed to load plugin : ' + name);
                ftui.log(1, 'Failed to load plugin : ' + name + '  - add <script src="js/widget_' + name +
                    '.js" defer></script> do your page, to see more informations about this failure', "base.widget");
                deferredLoad.resolve();
            });

        // return with promise to deliver the plugin deferred
        return deferredLoad.promise();
    },

    dynamicload: function (url, async) {

        ftui.log(3, 'dynamic load file:' + url + ' / async:' + async, "base.init");

        var deferred = new $.Deferred();
        var isAdded = false;

        // check if it is already included
        var i = ftui.scripts.length;
        while (i--) {
            if (ftui.scripts[i].url === url) {
                isAdded = true;
                break;
            }
        }

        if (!isAdded) {
            // not yet -> load
            if (url.match(new RegExp('^.*\.(js)$'))) {

                var script = document.createElement("script");
                script.type = "text/javascript";
                script.async = (async) ? true : false;
                script.src = url;
                script.onload = function () {
                    ftui.log(3, 'dynamic load done:' + url, "base.init");
                    deferred.resolve();
                };
                document.getElementsByTagName('head')[0].appendChild(script);
            } else {
                var link = document.createElement('link');
                link.rel = 'stylesheet';
                link.type = 'text/css';
                link.href = url;
                link.media = 'all';
                deferred.resolve();
                document.getElementsByTagName('head')[0].appendChild(link);
            }
            var scriptObject = {};
            scriptObject.deferred = deferred;
            scriptObject.url = url;
            ftui.scripts.push(scriptObject);

        } else {
            // already loaded
            ftui.log(3, 'dynamic load not neccesary for:' + url, "base.init");
            deferred = ftui.scripts[i].deferred;
        }

        return deferred.promise();
    },

    getCSrf: function (sysid) {

		var url = ftui.getSystemUrl(sysid);
	
		if(ftui.config[sysid] === undefined)
			ftui.config[sysid] = {};
	
		// Do not return the ajax result directly. The getCSrf function should always "resolve",
        // regardless whether we could determine a csrf token or not

		var deferred = $.Deferred();	
	
        $.ajax({
            'url': url,
            'type': 'GET',
            cache: false,
            username: ftui.config.username,
            password: ftui.config.password,
            data: {
                XHR: "1"
            }
        }).done(function (data, textStatus, jqXHR) {
            ftui.config[sysid].csrf = jqXHR.getResponseHeader('X-FHEM-csrfToken');
            ftui.log(1, 'Got csrf from FHEM ' + sysid + ' :' + ftui.config[sysid].csrf, "base.init");
        }).fail(function (jqXHR, textStatus, errorThrown) {
            ftui.log(1, "Failed to get csrfToken for " + sysid + " : " + textStatus + ": " + errorThrown, "base.init");
        }).always(function () { deferred.resolve() });
		
		return deferred;
    },

    healthCheck: function () {
		ftui.log(1,"health check","base.poll");
		var systemIds = ftui.getSystemIds();
		for(var i = 0; i < systemIds.length; i++) {
			var timeDiff = Date.now() - ftui.poll[systemIds[i]].long.lastEventTimestamp;
			if (timeDiff / 1000 > ftui.config.maxLongpollAge &&
				ftui.config.maxLongpollAge > 0) {
				ftui.log(1, 'No longpoll event since ' + timeDiff / 1000 + 'seconds -> restart polling ' + systemIds[i], "base.poll");
				ftui.conditionalConnect(systemIds[i],true);
			};
		};
    },

    FS20: {
        'dimmerArray': [0, 6, 12, 18, 25, 31, 37, 43, 50, 56, 62, 68, 75, 81, 87, 93, 100],
        'dimmerValue': function (value) {
            var idx = ftui.indexOfNumeric(this.dimmerArray, value);
            return (idx > -1) ? this.dimmerArray[idx] : 0;
        }
    },

    rgbToHsl: function (rgb) {
        var r = parseInt(rgb.substring(0, 2), 16);
        var g = parseInt(rgb.substring(2, 4), 16);
        var b = parseInt(rgb.substring(4, 6), 16);
        r /= 255;
        g /= 255;
        b /= 255;
        var max = Math.max(r, g, b),
            min = Math.min(r, g, b);
        var h, s, l = (max + min) / 2;

        if (max == min) {
            h = s = 0; // achromatic
        } else {
            var d = max - min;
            s = l > 0.5 ? d / (2 - max - min) : d / (max + min);
            switch (max) {
                case r:
                    h = (g - b) / d + (g < b ? 6 : 0);
                    break;
                case g:
                    h = (b - r) / d + 2;
                    break;
                case b:
                    h = (r - g) / d + 4;
                    break;
            }
            h /= 6;
        }
        return [h, s, l];
    },

    hslToRgb: function (h, s, l) {
        var r, g, b;
        var hex = function (x) {
            return ("0" + parseInt(x).toString(16)).slice(-2);
        };

        var hue2rgb;
        if (s === 0) {
            r = g = b = l; // achromatic
        } else {
            hue2rgb = function (p, q, t) {
                if (t < 0) t += 1;
                if (t > 1) t -= 1;
                if (t < 1 / 6) return p + (q - p) * 6 * t;
                if (t < 1 / 2) return q;
                if (t < 2 / 3) return p + (q - p) * (2 / 3 - t) * 6;
                return p;
            };
            var q = l < 0.5 ? l * (1 + s) : l + s - l * s;
            var p = 2 * l - q;
            r = hue2rgb(p, q, h + 1 / 3);
            g = hue2rgb(p, q, h);
            b = hue2rgb(p, q, h - 1 / 3);
        }
        return [hex(Math.round(r * 255)), hex(Math.round(g * 255)), hex(Math.round(b * 255))].join('');
    },

    rgbToHex: function (rgb) {
        var tokens = rgb.match(/^rgba?[\s+]?\([\s+]?(\d+)[\s+]?,[\s+]?(\d+)[\s+]?,[\s+]?(\d+)[\s+]?/i);
        return (tokens && tokens.length === 4) ? "#" +
            ("0" + parseInt(tokens[1], 10).toString(16)).slice(-2) +
            ("0" + parseInt(tokens[2], 10).toString(16)).slice(-2) +
            ("0" + parseInt(tokens[3], 10).toString(16)).slice(-2) : rgb;
    },

    getGradientColor: function (start_color, end_color, percent) {
        // strip the leading # if it's there
        start_color = this.rgbToHex(start_color).replace(/^\s*#|\s*$/g, '');
        end_color = this.rgbToHex(end_color).replace(/^\s*#|\s*$/g, '');

        // convert 3 char codes --> 6, e.g. `E0F` --> `EE00FF`
        if (start_color.length == 3) {
            start_color = start_color.replace(/(.)/g, '$1$1');
        }

        if (end_color.length == 3) {
            end_color = end_color.replace(/(.)/g, '$1$1');
        }

        // get colors
        var start_red = parseInt(start_color.substr(0, 2), 16),
            start_green = parseInt(start_color.substr(2, 2), 16),
            start_blue = parseInt(start_color.substr(4, 2), 16);

        var end_red = parseInt(end_color.substr(0, 2), 16),
            end_green = parseInt(end_color.substr(2, 2), 16),
            end_blue = parseInt(end_color.substr(4, 2), 16);

        // calculate new color
        var diff_red = end_red - start_red;
        var diff_green = end_green - start_green;
        var diff_blue = end_blue - start_blue;

        diff_red = ((diff_red * percent) + start_red).toString(16).split('.')[0];
        diff_green = ((diff_green * percent) + start_green).toString(16).split('.')[0];
        diff_blue = ((diff_blue * percent) + start_blue).toString(16).split('.')[0];

        // ensure 2 digits by color
        if (diff_red.length == 1)
            diff_red = '0' + diff_red;

        if (diff_green.length == 1)
            diff_green = '0' + diff_green;

        if (diff_blue.length == 1)
            diff_blue = '0' + diff_blue;

        return '#' + diff_red + diff_green + diff_blue;
    },

    getPart: function (value, part) {
        if (ftui.isValid(part)) {
            if ($.isNumeric(part)) {
                var tokens = (ftui.isValid(value)) ? value.toString().split(" ") : '';
                return (tokens.length >= part && part > 0) ? tokens[part - 1] : value;
            } else {
                var ret = '';
                if (ftui.isValid(value)) {
                    var matches = value.match(new RegExp('^' + part + '$'));
                    if (matches) {
                        for (var i = 1, len = matches.length; i < len; i++) {
                            ret += matches[i];
                        }
                    }
                }
                return ret;
            }
        }
        return value;
    },

    showModal: function (modal) {
        if (modal)
            $("#shade").fadeIn(ftui.config.fadeTime);
        else
            $("#shade").fadeOut(ftui.config.fadeTime);
    },

	showErrorOverlay: function (showIt, sysid) {
		if(showIt){
			// Disconnected from FHEM (sysid), reconnecting
		    var message = 'Disconnected from FHEM';
			if(sysid != undefined && ftui.isMultifhem) {
				message += ' (' + sysid + ')';
			};
			message += ', reconnecting';
			var elem = $("#ftui-error-shade");
			elem.html(message);
			elem.show();
		}else{
			$("#ftui-error-shade").hide();
		};
	},	
		
    precision: function (a) {
        var s = a + "",
            d = s.indexOf('.') + 1;
        return !d ? 0 : s.length - d;
    },

    // 1. numeric, 2. regex, 3. negation double, 4. indexof 
    indexOfGeneric: function (array, find) {
        if (!array) return -1;
        for (var i = 0, len = array.length; i < len; i++) {
            // leave the loop on first none numeric item
            if (!$.isNumeric(array[i]))
                return ftui.indexOfRegex(array, find);
        }
        return ftui.indexOfNumeric(array, find);
    },

    indexOfNumeric: function (array, val) {
        var ret = -1;
        for (var i = 0, len = array.length; i < len; i++) {
            if (Number(val) >= Number(array[i]))
                ret = i;
        }
        return ret;
    },

    indexOfRegex: function (array, find) {
        var len = array.length;
        for (var i = 0; i < len; i++) {
            try {
                var match = find.match(new RegExp('^' + array[i] + '$'));
                if (match)
                    return i;
            } catch (e) { }
        }

        // negation double
        if (len === 2 && array[0] === '!' + array[1] && find !== array[0]) {
            return 0;
        }
        if (len === 2 && array[1] === '!' + array[0] && find !== array[1]) {
            return 1;
        }

        // last chance: index of
        return array.indexOf(find);
    },

    isValid: function (v) {
        return (v !== void 0 && typeof v !== typeof notusedvar);
    },

    // global date format functions
    dateFromString: function (str) {
        var m = str.match(/(\d+)-(\d+)-(\d+)[_\sT](\d+):(\d+):(\d+).*/);
        var m2 = str.match(/^(\d+)$/);
        var m3 = str.match(/(\d\d).(\d\d).(\d\d\d\d)/);

        var offset = new Date().getTimezoneOffset();
        return (m) ? new Date(+m[1], +m[2] - 1, +m[3], +m[4], +m[5], +m[6]) :
            (m2) ? new Date(70, 0, 1, 0, 0, m2[1], 0) :
                (m3) ? new Date(+m3[3], +m3[2] - 1, +m3[1], 0, -offset, 0, 0) : new Date();
    },

    diffMinutes: function (date1, date2) {
        var diff = new Date(date2 - date1);
        return (diff / 1000 / 60).toFixed(0);
    },

    diffSeconds: function (date1, date2) {
        var diff = new Date(date2 - date1);
        return (diff / 1000).toFixed(1);
    },

    durationFromSeconds: function (time) {
        var hrs = Math.floor(time / 3600);
        var mins = Math.floor((time % 3600) / 60);
        var secs = time % 60;
        var ret = "";
        if (hrs > 0) {
            ret += "" + hrs + ":" + (mins < 10 ? "0" : "");
        }
        ret += "" + mins + ":" + (secs < 10 ? "0" : "");
        ret += "" + secs;
        return ret;
    },

    mapColor: function (value) {
        return ftui.getStyle('.' + value, 'color') || value;
    },

    round: function (number, precision) {
        var shift = function (number, precision, reverseShift) {
            if (reverseShift) {
                precision = -precision;
            }
            var numArray = ("" + number).split("e");
            return +(numArray[0] + "e" + (numArray[1] ? (+numArray[1] + precision) : precision));
        };
        return shift(Math.round(shift(number, precision, false)), precision, true);
    },

    parseJsonFromString: function (str) {
        return JSON.parse(str);
    },

    getAndroidVersion: function (ua) {
        ua = (ua || navigator.userAgent).toLowerCase();
        var match = ua.match(/android\s([0-9\.]*)/);
        return match ? match[1] : false;
    },

    getStyle: function (selector, prop) {
        var props = ftui.config.styleCollection[selector];
        var style = (props && props[prop]) ? props[prop] : null;
        if (style === null) {
            var reverseSelector = '.' + selector.split('.').reverse().join('.');
            reverseSelector = reverseSelector.substring(0, reverseSelector.length - 1);
            props = ftui.config.styleCollection[reverseSelector];
            style = (props && props[prop]) ? props[prop] : null;
        }
        return style;
    },

    getClassColor: function (elem) {
        var i = ftui.config.stdColors.length;
        while (i--) {
            if (elem.hasClass(ftui.config.stdColors[i])) {
                return ftui.getStyle('.' + ftui.config.stdColors[i], 'color');
            }
        }
        return null;
    },

    getIconId: function (iconName) {
        if (!iconName || iconName === '' || !$('link[href$="lib/font-awesome.min.css"]').length)
            return "?";
        var cssFile = $('link[href$="lib/font-awesome.min.css"]')[0];
        if (cssFile && cssFile.sheet && cssFile.sheet.cssRules) {
            var rules = cssFile.sheet.cssRules;
            for (var rule in rules) {
                if (rules[rule].selectorText && rules[rule].selectorText.match(new RegExp(iconName + ':'))) {
                    var id = rules[rule].style.content;
                    if (!id)
                        return iconName;
                    id = id.replace(/"/g, '').replace(/'/g, "");
                    return (/[^\u0000-\u00ff]/.test(id)) ? id :
                        String.fromCharCode(parseInt(id.replace('\\', ''), 16));
                }
            }
        }
    },

    disableSelection: function () {
        $("body").each(function () {
            this.onselectstart = function () {
                return false;
            };
            this.unselectable = "on";
            $(this).css('-moz-user-select', 'none');
            $(this).css('-webkit-user-select', 'none');
        });
    },

    hideWidgets: function (area) {
        $('[data-type]', area).addClass('widget-hide');
    },

    toast: function (text, error) {
        //https://github.com/kamranahmedse/jquery-toast-plugin
        if (ftui.config.TOAST !== 0) {
            var tstack = ftui.config.TOAST;
            if (ftui.config.TOAST == 1)
                tstack = false;
            if (error && error === 'error') {
				if ($.toast) {
                    return $.toast({
                        heading: 'Error',
                        text: text,
                        hideAfter: 20000, // in milli seconds
                        icon: 'error',
                        loader: false,
                        position: ftui.config.toastPosition,
                        stack: tstack
                    });
                }
            } else
                if ($.toast) {
                    return $.toast({
                        text: text,
                        loader: false,
                        position: ftui.config.toastPosition,
                        stack: tstack
                    });
                }

        }
    },

    log: function (level, text, area) {
        if (ftui.config.loglevel < level) return;
		if(!area) area = "unknown";
		if(ftui.config.logareas) {
			var found = false;
			for(var i = 0; i < ftui.config.logareas.length; i++) {
				if(area.match("^" + ftui.config.logareas[i])) {
					found = true;
					break;
				};	
			};	
			if(!found) return;
		};	
		var logtext = (new Date().toISOString()) + " " + level.toString() + " " + area + " " + text;
		switch(ftui.config.logtype) {
			case "localstorage":
				// Is this the first entry since (re)load?
				if(!ftui.logid) {
					ftui.logid = new Date().toISOString();
					ftui.lognextentry = 1;
				};	
				var logitem = "ftui.log." + ftui.logid + "_" + ("00000000" + ftui.lognextentry.toString()).substr(-8);
				localStorage.setItem(logitem, logtext);
				ftui.lognextentry++;
				break;
			default:
				console.log(logtext);
				break;
		};	
    },
};

// global helper functions

String.prototype.toDate = function () {
    return ftui.dateFromString(this);
};

String.prototype.parseJson = function () {
    return ftui.parseJsonFromString(this);
};

String.prototype.toMinFromMs = function () {
    var x = Number(this) / 1000;
    var ss = (Math.floor(x % 60)).toString();
    var mm = (Math.floor(x /= 60)).toString();
    return mm + ":" + (ss[1] ? ss : "0" + ss[0]);
};

String.prototype.toMinFromSec = function () {
    var x = Number(this);
    var ss = (Math.floor(x % 60)).toString();
    var mm = (Math.floor(x /= 60)).toString();
    return mm + ":" + (ss[1] ? ss : "0" + ss[0]);
};

String.prototype.toHoursFromMin = function () {
    var x = Number(this);
    var hh = (Math.floor(x / 60)).toString();
    var mm = (x - (hh * 60)).toString();
    return hh + ":" + (mm[1] ? mm : "0" + mm[0]);
};

String.prototype.toHoursFromSec = function () {
    var x = Number(this);
    var hh = (Math.floor(x / 3600)).toString();
    var ss = (Math.floor(x % 60)).toString();
    var mm = (Math.floor(x / 60) - (hh * 60)).toString();
    return hh + ":" + (mm[1] ? mm : "0" + mm[0]) + ":" + (ss[1] ? ss : "0" + ss[0]);
};

String.prototype.addFactor = function (factor) {
    var x = Number(this);
    return x * factor;
};

Date.prototype.addMinutes = function (minutes) {
    return new Date(this.getTime() + minutes * 60000);
};

Date.prototype.ago = function (format) {
    var now = new Date();
    var ms = (now - this);
    var x = ms / 1000;
    var seconds = Math.floor(x % 60);
    x /= 60;
    var minutes = Math.floor(x % 60);
    x /= 60;
    var hours = Math.floor(x % 24);
    x /= 24;
    var days = Math.floor(x);
    var strUnits = (ftui.config.lang === 'de') ? ['Tag(e)', 'Stunde(n)', 'Minute(n)', 'Sekunde(n)'] : ['day(s)', 'hour(s)', 'minute(s)',
        'second(s)'];
    var ret;
    if (ftui.isValid(format)) {
        ret = format.replace('dd', days);
        ret = ret.replace('hh', (hours > 9) ? hours : '0' + hours);
        ret = ret.replace('mm', (minutes > 9) ? minutes : '0' + minutes);
        ret = ret.replace('ss', (seconds > 9) ? seconds : '0' + seconds);
        ret = ret.replace('h', hours);
        ret = ret.replace('m', minutes);
        ret = ret.replace('s', seconds);
    } else {
        ret = (days > 0) ? days + " " + strUnits[0] + " " : "";
        ret += (hours > 0) ? hours + " " + strUnits[1] + " " : "";
        ret += (minutes > 0) ? minutes + " " + strUnits[2] + " " : "";
        ret += seconds + " " + strUnits[3];
    }
    return ret;
};

Date.prototype.format = function (format) {
    var YYYY = this.getFullYear().toString();
    var YY = this.getYear().toString();
    var MM = (this.getMonth() + 1).toString(); // getMonth() is zero-based
    var dd = this.getDate().toString();
    var hh = this.getHours().toString();
    var mm = this.getMinutes().toString();
    var ss = this.getSeconds().toString();
    var eeee = this.eeee();
    var eee = this.eee();
    var ee = this.ee();
    var ret = format;
    ret = ret.replace('DD', (dd > 9) ? dd : '0' + dd);
    ret = ret.replace('D', dd);
    ret = ret.replace('MM', (MM > 9) ? MM : '0' + MM);
    ret = ret.replace('M', MM);
    ret = ret.replace('YYYY', YYYY);
    ret = ret.replace('YY', YY);
    ret = ret.replace('hh', (hh > 9) ? hh : '0' + hh);
    ret = ret.replace('mm', (mm > 9) ? mm : '0' + mm);
    ret = ret.replace('ss', (ss > 9) ? ss : '0' + ss);
    ret = ret.replace('h', hh);
    ret = ret.replace('m', mm);
    ret = ret.replace('s', ss);
    ret = ret.replace('eeee', eeee);
    ret = ret.replace('eee', eee);
    ret = ret.replace('ee', ee);

    return ret;
};

Date.prototype.yyyymmdd = function () {
    var yyyy = this.getFullYear().toString();
    var mm = (this.getMonth() + 1).toString(); // getMonth() is zero-based
    var dd = this.getDate().toString();
    return yyyy + '-' + (mm[1] ? mm : "0" + mm[0]) + '-' + (dd[1] ? dd : "0" + dd[0]); // padding
};

Date.prototype.ddmmyyyy = function () {
    var yyyy = this.getFullYear().toString();
    var mm = (this.getMonth() + 1).toString(); // getMonth() is zero-based
    var dd = this.getDate().toString();
    return (dd[1] ? dd : "0" + dd[0]) + '.' + (mm[1] ? mm : "0" + mm[0]) + '.' + yyyy; // padding
};

Date.prototype.hhmm = function () {
    var hh = this.getHours().toString();
    var mm = this.getMinutes().toString();
    return (hh[1] ? hh : "0" + hh[0]) + ':' + (mm[1] ? mm : "0" + mm[0]); // padding
};

Date.prototype.hhmmss = function () {
    var hh = this.getHours().toString();
    var mm = this.getMinutes().toString();
    var ss = this.getSeconds().toString();
    return (hh[1] ? hh : "0" + hh[0]) + ':' + (mm[1] ? mm : "0" + mm[0]) + ':' + (ss[1] ? ss : "0" + ss[0]); // padding
};

Date.prototype.ddmm = function () {
    var mm = (this.getMonth() + 1).toString(); // getMonth() is zero-based
    var dd = this.getDate().toString();
    return (dd[1] ? dd : "0" + dd[0]) + '.' + (mm[1] ? mm : "0" + mm[0]) + '.'; // padding
};

Date.prototype.ddmmhhmm = function () {
    var MM = (this.getMonth() + 1).toString(); // getMonth() is zero-based
    var dd = this.getDate().toString();
    var hh = this.getHours().toString();
    var mm = this.getMinutes().toString();
    return (dd[1] ? dd : "0" + dd[0]) + '.' + (MM[1] ? MM : "0" + MM[0]) + '. ' +
        (hh[1] ? hh : "0" + hh[0]) + ':' + (mm[1] ? mm : "0" + mm[0]);
};

Date.prototype.eeee = function () {
    var weekday_de = ['Sonntag', 'Montag', 'Dienstag', 'Mittwoch', 'Donnerstag', 'Freitag', 'Samstag'];
    var weekday = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
    if (ftui.config.lang === 'de')
        return weekday_de[this.getDay()];
    return weekday[this.getDay()];
};

Date.prototype.eee = function () {
    var weekday_de = ['Son', 'Mon', 'Die', 'Mit', 'Don', 'Fre', 'Sam'];
    var weekday = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    if (ftui.config.lang === 'de')
        return weekday_de[this.getDay()];
    return weekday[this.getDay()];
};

Date.prototype.ee = function () {
    var weekday_de = ['So', 'Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa'];
    var weekday = ['Su', 'Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa'];
    if (ftui.config.lang === 'de')
        return weekday_de[this.getDay()];
    return weekday[this.getDay()];
};


function onjQueryLoaded() {

    /*   EVENTS */

    // event "page is loaded" -> start FTUI

    ftui.init();

    $('.menu').on('click', function () {
        $('.menu').toggleClass('show');
    });

    window.onerror = function (msg, url, lineNo, columnNo, error) {
        var file = url.split('/').pop();
        ftui.toast([file + ':' + lineNo, error].join('<br/>'), 'error');
		ftui.log(1, [file + ':' + lineNo, error].join('<br/>'), "base");
        return false;
    };

    $.fn.once = function (a, b) {
        return this.each(function () {
            $(this).off(a).on(a, b);
        });
    };

    // for widget

    $.fn.widgetId = function () {
		var elem = $(this);
		var sysid = ftui.findSysidByElem(elem);
        return [sysid, elem.data('type'), (elem.data('device') ? elem.data('device').replace(' ', 'default') : 'default'), elem.data('get'), elem.index()].join('.');
    };

    $.fn.wgid = function () {
        var elem = $(this);
        if (!elem.isValidData('wgid')) {
            var wgid = elem.data('type') + '_xxxx-xxxx-xxxx'.replace(/[xy]/g, function (c) {
                var r = Math.random() * 16 | 0,
                    v = c == 'x' ? r : (r & 0x3 | 0x8);
                return v.toString(16);
            });
            elem.attr('data-wgid', wgid);
        }
        return elem.data('wgid');
    };

    $.fn.filterData = function (key, value) {
        return this.filter(function () {
            return $(this).data(key) == value;
        });
    };

    $.fn.filterDeviceReading = function (key, device, param) {
        return $(this).filter(function () {
            return $(this).matchDeviceReading(key, device, param);
        });
    };
	
	
	$.fn.filterDevice = function (key, device) {
        return $(this).filter(function () {
            return $(this).matchDevice(key, device);
        });
    };
	
	
	// matchDevice checks whether <device> is in data(key)
	$.fn.matchDevice = function (key, device) {
		var elem = $(this);
		var devices = elem.data(key);
		if (!$.isArray(devices)) {
			if (ftui.isValid(devices)) {
			    devices = new Array(devices.toString());
			}else{
			    devices = new Array();
			};		
        };
		var sysidElem = ftui.findSysidByElem(elem);
		var devToMatch = ftui.splitDeviceKey(device);  // sysid, device
		if(sysidElem != devToMatch.sysid) {
			// system ids do not match
			return false;
		};
		return $.inArray(devToMatch.device, devices) > -1;	
	};	
	

    $.fn.matchDeviceReading = function (key, device, param) {
        var elem = $(this);
        var value = elem.data(key);
		var sysidElem = ftui.findSysidByElem(elem);
		var devToMatch = ftui.splitDeviceKey(device);  // sysid, device
		if(sysidElem != devToMatch.sysid) {
			// system ids do not match
			return false;
		};	
        return (String(value) === param && String(elem.data('device')) === devToMatch.device) ||
            (value === devToMatch.device + ':' + param || value === '[' + devToMatch.device + ':' + param + ']') ||
            ($.inArray(param, value) > -1 && String(elem.data('device')) === devToMatch.device) ||
            ($.inArray(devToMatch.device + ':' + param, value) > -1);
    };
	
	$.fn.matchDeviceReadingIndex = function (key, device, param) {
        var elem = $(this);
        var value = elem.data(key);
		var sysidElem = ftui.findSysidByElem(elem);
		var devToMatch = ftui.splitDeviceKey(device);  // sysid, device
		if(sysidElem != devToMatch.sysid) {
			// system ids do not match
			return -1;
		};	
        if((String(value) === param && String(elem.data('device')) === devToMatch.device) ||
            (value === devToMatch.device + ':' + param || value === '[' + devToMatch.device + ':' + param + ']')) {
			return 0;
		};	
		var idx = $.inArray(param, value);
		if( idx >= 0 && String(elem.data('device')) === devToMatch.device) return idx;
        return $.inArray(devToMatch.device + ':' + param, value);
    };

    $.fn.isValidData = function (key) {
        return ($(this).data(key) !== void 0);
    };

    $.fn.isValidAttr = function (key) {
        return ($(this).attr(key) !== void 0);
    };

    $.fn.initData = function (key, value) {
        var elem = $(this);
        elem.data(key, elem.isValidData(key) ? elem.data(key) : value);
        return elem;
    };

    $.fn.reinitData = function (key, value) {
        var elem = $(this),
            attrKey = 'data-' + key;
        elem.data(key, elem.isValidAttr(attrKey) ? elem.attr(attrKey) : value);
        return elem;
    };

    $.fn.initClassColor = function (key) {
        var elem = $(this),
            value = ftui.getClassColor(elem);
        if (value) elem.attr('data-' + key, value);
    };

    $.fn.mappedColor = function (key) {
        return ftui.getStyle('.' + $(this).data(key), 'color') || $(this).data(key);
    };

    $.fn.matchingState = function (key, value) {

        if (!ftui.isValid(value)) {
            return '';
        }
        var elm = $(this);
		var sysid = ftui.findSysidByElem(elm);
        var state = String(ftui.getPart(value, elm.data(key + '-part')));
        var onData = elm.data(key + '-on');
        var offData = elm.data(key + '-off');
        var on = String(onData);
        var temp, device, reading, param;
        if (on.match(/:/)) {
            temp = on.split(':');
            device = sysid + '-' + temp[0].replace('[', '');
            reading = temp[1].replace(']', '');
            param = ftui.getDeviceParameter(device, reading);
            if (param && ftui.isValid(param)) {
                on = param.val;
            }
        }
        var off = String(offData);
        if (off.match(/:/)) {
            temp = off.split(':');
            device = sysid + '-' + temp[0].replace('[', '');
            reading = temp[1].replace(']', '');
            param = ftui.getDeviceParameter(device, reading);
            if (param && ftui.isValid(param)) {
                off = param.val;
            }
        }
        if (ftui.isValid(onData)) {
            if (state === on) {
                return 'on';
            } else if (state.match(new RegExp('^' + on + '$'))) {
                return 'on';
            }
        }
        if (ftui.isValid(offData)) {
            if (state === off) {
                return 'off';
            } else if (state.match(new RegExp('^' + off + '$'))) {
                return 'off';
            }
        }
        if (ftui.isValid(onData) && ftui.isValid(offData)) {
            if (on === '!off' && !state.match(new RegExp('^' + off + '$'))) {
                return 'on';
            } else if (off === '!on' && !state.match(new RegExp('^' + on + '$'))) {
                return 'off';
            } else if (on === '!' + off && !state.match(new RegExp('^' + off + '$'))) {
                return 'on';
            } else if (off === '!' + on && !state.match(new RegExp('^' + on + '$'))) {
                return 'off';
            }
        }
    };

    $.fn.isUrlData = function (key) {
        var data = $(this).data(key);
        var regExURL = /^(?:http(s)?:\/\/)?[\w.-]+(?:\.[\w\.-]+)+[\w\-\._~:/?#[\]@!\$&'\(\)\*\+,;=.]+$/;
        return data && data.match(regExURL);
    };

    $.fn.isDeviceReading = function (key) {
        var reading = $(this).data(key),
            result = false;

        if (reading) {
            if (!$.isArray(reading)) {
                reading = [reading];
            }
            result = true;
            var i = reading.length;
            while (i--) {
                result = result && !$.isNumeric(reading[i]) && typeof reading[i] === 'string' && reading[i].match(/^[\w\s-.]+:[\w\s-]+$/);
            }
        }
        return result;
    };

    $.fn.isExternData = function (key) {
        var data = $(this).data(key);
        if (!data) return '';
        return (data.match(/^[#\.\[][^:]*$/));
    };

    $.fn.cleanWhitespace = function () {
        var textNodes = this.contents().filter(
            function () {
                return (this.nodeType == 3 && !/\S/.test(this.nodeValue));
            })
            .remove();
        return this;
    };

    $.fn.getReading = function (key, idx) {
		var elem = $(this);
		var sysid = ftui.findSysidByElem(elem);
        var devName = String(elem.data('device')); // local device name
        var paraName = elem.data(key);
        if ($.isArray(paraName)) {
            paraName = paraName[idx];
        }
        paraName = String(paraName);
        if (paraName && paraName.match(/:/)) {
            var temp = paraName.split(':');
            devName = temp[0].replace('[', '');
            paraName = temp[1].replace(']', '');
        }
        if (devName && devName.length) {
			// complete device key is <sysid>-<device>
			var devKey = devName;
			if(ftui.isMultifhem()) {
				devKey = sysid + '-' + devKey;
			};	
            var params = ftui.deviceStates[devKey];
            return (params && params[paraName]) ? params[paraName] : {};
        }
        return {};
    };

    $.fn.valOfData = function (key) {
        var data = $(this).data(key);
        if (!ftui.isValid(data)) return '';
        return (data.toString().match(/^[#\.\[][^:]*$/)) ? $(data).data('value') : data;
    };

    $.fn.transmitCommand = function () {
		var elem = $(this);
        if (elem.hasClass('notransmit')) return;
        var cmd = [elem.valOfData('cmd'), elem.valOfData('device') + elem.valOfData('filter'), elem.valOfData('set'), elem.valOfData('value')].join(' ');
			
		var sysid = ftui.findSysidByElem(elem);	
		ftui.sendFhemCommandWithSysid(cmd,sysid);
		if(ftui.isMultifhem()) {
			cmd = sysid + ' : ' + cmd;
		};	
        ftui.toast(cmd);
    };

    $.fn.otherThen = function (elem) {
        return $(this).filter(function () {
            var eq1 = $(this).wgid(),
                eq2 = elem.wgid();
            return eq1 !== eq2;
        });
    };
}


// log/trace settings
ftui.config.loglevel = $("meta[name='loglevel']").attr("content") || 0;  // 0 => no log/trace, 5 => everything
ftui.config.logtype = $("meta[name='logtype']").attr("content") || "console";  // console, toast, localstorage  
ftui.config.logareas = $("meta[name='logareas']").attr("content") || false;
if(ftui.config.logareas)
	ftui.config.logareas = ftui.config.logareas.split(',');

// detect self location
var src = document.querySelector('script[src*="fhem-tablet-ui"]').getAttribute('src');
var file = src.split('/').pop();
src = src.replace('/' + file, '');
var dir = src.split('/').pop();
ftui.config.basedir = src.replace(dir, '');
if (ftui.config.basedir === '') ftui.config.basedir = './';
ftui.log(3,'Base dir: ' + ftui.config.basedir, "base.init");

// load jQuery lib
if (!ftui.isValid(window.jQuery)) {
    var script = document.createElement('script');
    script.type = 'text/javascript';
    script.onload = function () {
        (function ($) {
            $(document).ready(function () {
                ftui.log(3,'jQuery dynamically loaded', "base.init");
                onjQueryLoaded();
            });
        })(jQuery);

    };
    script.src = ftui.config.basedir + "lib/jquery.min.js";
    document.getElementsByTagName('head')[0].appendChild(script);
} else {
    $(document).ready(function () {
        onjQueryLoaded();
    });
}
