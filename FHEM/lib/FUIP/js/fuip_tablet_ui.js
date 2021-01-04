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
            elem.attr("data-ready", "");
            me.init_attr(elem);
            elem = me.init_ui(elem);
        });
    }

    function addReading(elem, key) {
        var data = elem.data(key);

        if (ftui.isValid(data)) {

            if ($.isArray(data) || !data.toString().match(/^[#\.\[][^:]*$/)) {
                var device = elem.data('device');
                if (!$.isArray(data)) {
                    data = new Array(data.toString());
                }
                var i = data.length;
                while (i--) {
                    var reading = data[i];
                    // fully qualified readings => DEVICE:READING
                    if (reading.match(/:/)) {
                        var fqreading = reading.split(':');
                        device = fqreading[0].replace('[', '');
                        reading = fqreading[1].replace(']', '');
                    }
                    // fill objects for mapping from FHEMWEB paramid to device + reading
                    me.addSubscription(device, reading);

                }
            }
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

        if (ftui.isValid(data)) {

            if ($.isArray(data) || !data.toString().match(/^[#\.\[][^:]*$/)) {
                if (!$.isArray(data)) {
                    data = new Array(data.toString());
                }
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
                    me.addSubscription(device, reading);
                }
            }
        }
    }

    function update(dev, par) {
        ftui.log(1, 'warning: ' + me.widgetname + ' has not implemented update function',"base.widget");
    }

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
        ftui.devs = [];
        ftui.reads = [];
        var i = this.modules.length;
        while (i--) {
            var module = this.modules[i];
            for (var key in module.subscriptions) {
                ftui.subscriptions[key] = module.subscriptions[key];
                ftui.subscriptionTs[key + '-ts'] = module.subscriptions[key];
                var d = ftui.subscriptions[key].device;
                if (ftui.devs.indexOf(d) < 0) {
                    ftui.devs.push(d);
                }
                var r = ftui.subscriptions[key].reading;
                if (ftui.reads.indexOf(r) < 0) {
                    ftui.reads.push(r);
                }
            }
        }

        // build filter
        var devicelist = (ftui.devs.length) ? $.map(ftui.devs, $.trim).join() : '.*';
        var readinglist = (ftui.reads.length) ? $.map(ftui.reads, $.trim).join(' ') : '';

        if (!ftui.config.longPollFilter) {
            ftui.poll.long.filter = devicelist + ', ' + readinglist;
        } else {
            ftui.poll.long.filter = ftui.config.longPollFilter;
        }

        if (!ftui.config.shortPollFilter) {
            ftui.poll.short.filter = devicelist + ' ' + readinglist;
        } else {
            ftui.poll.short.filter = ftui.config.shortPollFilter;
        }

        // force shortpoll
        ftui.states.lastShortpoll = 0;
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

    poll: {
        short: {
            timer: null,
            request: null
        },
        long: {
            currLine: 0,
            lastEventTimestamp: Date.now(),
            timer: null
        },
		// PFE
		status: 0,   // 0: DISCONNECTED, 1: CONNECTING, 2: CONNECTED
		healthCheckTimer: null,
		lastConnectTime: 0,
		connectWaitTime: 0,  // at first fail, we don't wait, then 50ms, then 100ms, then 200ms etc. max. wait is 5 secs
		connectRetryTimer: null,
		initialized: false  // set to true after initWidgetsDone
    },

    states: {
        width: 0,
        lastShortpoll: 0,
        inits: []
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
        ftui.config.shortPollFilter = $("meta[name='shortpoll_filter']").attr("content");
        ftui.config.longPollFilter = $("meta[name='longpoll_filter']").attr("content");
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
        ftui.reads = [];

        var cssReadyDeferred = $.Deferred();
        var initDeferreds = [cssReadyDeferred];

        // Get CSFS Token
        initDeferreds.push(
            ftui.getCSrf()
        );

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

        // init Page after css is ready and CSFS Token has been retrieved
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
			if(!ftui.poll.initialized && event.type !== "initWidgetsDone") 
				return true;
			ftui.poll.initialized = true;
			if(ftui.poll.status == 0) 
				ftui.conditionalConnect(true);
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
			ftui.disconnect();
			setTimeout(function() {	ftui.conditionalConnect(true) }, 250);
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

 
	shortPoll: function () {
		var deferred = $.Deferred();
        var ltime = Date.now() / 1000;
        ftui.log(1, 'start shortpoll', "base.poll");
        // invalidate all readings for detection of outdated ones
        var i = ftui.devs.length;
        while (i--) {
            var params = ftui.deviceStates[ftui.devs[i]];
            for (var reading in params) {
                params[reading].valid = false;
            }
        }
        ftui.poll.short.request =
            ftui.sendFhemCommand('jsonlist2 ' + ftui.poll.short.filter)
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
                                checkReading(devName, res.Internals);
                                checkReading(devName, res.Attributes);
                                checkReading(devName, res.Readings);
                            }
                        }

                        // finished
                        ftui.log(1, 'shortPoll: Done', "base.poll");
                        ftui.states.lastShortpoll = ltime;
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
                    var err = textStatus + ", " + error;
                    ftui.log(1, "shortPoll: request failed: " + err, "base.poll");
                    ftui.saveStatesLocal();
                    if (textStatus.indexOf('parsererror') < 0) {
						// it is relatively likely that this is because FHEM restarted
						ftui.getCSrf();
                    };
					deferred.reject("ShortPoll request failed " + err);
                });
		return deferred.promise();		
    },
	
	// PFE
	getWebsocketCloseText: function (event) {
        if (event.code == 1000)
			return "Normal closure, meaning that the purpose for which the connection was established has been fulfilled.";
        else if (event.code == 1001)
            return "An endpoint is \"going away\", such as a server going down or a browser having navigated away from a page.";
        else if (event.code == 1002)
            return  "An endpoint is terminating the connection due to a protocol error";
        else if (event.code == 1003)
            return "An endpoint is terminating the connection because it has received a type of data it cannot accept (e.g., an endpoint that understands only text data MAY send this if it receives a binary message).";
        else if (event.code == 1004)
             return "Reserved. The specific meaning might be defined in the future.";
        else if (event.code == 1005)
            return "No status code was actually present.";
        else if (event.code == 1006)
            return "The connection was closed abnormally, e.g., without sending or receiving a Close control frame";
        else if (event.code == 1007)
            return "An endpoint is terminating the connection because it has received data within a message that was not consistent with the type of the message (e.g., non-UTF-8 [http://tools.ietf.org/html/rfc3629] data within a text message).";
        else if (event.code == 1008)
            return "An endpoint is terminating the connection because it has received a message that \"violates its policy\". This reason is given either if there is no other sutible reason, or if there is a need to hide specific details about the policy.";
        else if (event.code == 1009)
             return "An endpoint is terminating the connection because it has received a message that is too big for it to process.";
        else if (event.code == 1010) // Note that this status code is not used by the server, because it can fail the WebSocket handshake instead.
            return "An endpoint (client) is terminating the connection because it has expected the server to negotiate one or more extension, but the server didn't return them in the response message of the WebSocket handshake. <br /> Specifically, the extensions that are needed are: " + event.reason;
        else if (event.code == 1011)
            return "A server is terminating the connection because it encountered an unexpected condition that prevented it from fulfilling the request.";
        else if (event.code == 1015)
            return "The connection was closed due to a failure to perform a TLS handshake (e.g., the server certificate can't be verified).";
        else
             return "Unknown reason";
	},	
	

	// PFE
    createWebsocket: function () {
        ftui.log(2, "WebSocket creation started", "base.poll");
        ftui.poll.long.URL = ftui.config.fhemDir.replace(/^http/i, "ws") + "?XHR=1&inform=type=status;filter=" +
            ftui.poll.long.filter + ";since=" + ftui.poll.long.lastEventTimestamp + ";fmt=JSON" +
            "&timestamp=" + Date.now();
        ftui.log(2, 'WebSocket URL=' + ftui.poll.long.URL, "base.poll");
        ftui.poll.long.websocket = new WebSocket(ftui.poll.long.URL);
		ftui.poll.long.websocket.onopen = function() { 
			ftui.showErrorOverlay(false);
			ftui.poll.connectWaitTime = 0;
			// start health check timer
			ftui.poll.healthCheckTimer = setInterval(ftui.healthCheck, 60000);
			// start shortpoll timer
			ftui.poll.short.timer = setInterval(function () {
				ftui.shortPoll().then(null,ftui.conditionalConnect);
			}, ftui.config.shortpollInterval * 1000);
			// log and status
			ftui.log(1, "CONNECTED","base.poll");	
			ftui.poll.status = 2;  // connected
		};
        ftui.poll.long.websocket.onclose = function (event) {
			ftui.showErrorOverlay(true);
			var reason = ftui.getWebsocketCloseText(event);
			ftui.log(1, "Websocket closed ("+event.code+" " + reason + "), restarting...","base.poll");	
			ftui.conditionalConnect();
        };
        ftui.poll.long.websocket.onerror = function (event) {
            ftui.log(1, "Websocket error", "base.poll");
        };
        ftui.poll.long.websocket.onmessage = function (msg) {
			ftui.log(5, "Websocket received " + msg.data, "base.poll");
            ftui.handleUpdates(msg.data);
        };
    },

    handleUpdates: function (data) {
		// set "timestamp of last event" to 5 seconds before
		// this should make sure that we do not lose anything when restarting
		// the connection
		ftui.poll.long.lastEventTimestamp = Date.now() - 5000;
        var lines = data.split(/\n/);
        for (var i = ftui.poll.long.currLine, len = lines.length; i < len; i++) {
            ftui.log(5, lines[i], "base.update");
            ftui.poll.long.lastLine = lines[i];
            var lastChar = lines[i].slice(-1);
            if (ftui.isValid(lines[i]) && lines[i] !== '' && lastChar === "]") {
                try {
                    var dataJSON = JSON.parse(lines[i]);
                    var params = null;
                    var param = null;
                    var isSTATE = (dataJSON[1] !== dataJSON[2]);
                    var isTrigger = (dataJSON[1] === '' && dataJSON[2] === '');

                    ftui.log(4, dataJSON, "base.update");

                    var pmap = ftui.paramIdMap[dataJSON[0]];
                    var tmap = ftui.timestampMap[dataJSON[0]];
                    var subscription = ftui.subscriptions[dataJSON[0]];
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
                        if (ftui.subscriptionTs[dataJSON[0]]) {
                            plugins.update(tmap.device, tmap.reading);
                        }
                    }
                    // it is just a trigger
                    if (isTrigger && subscription) {
                        plugins.update(subscription.device, subscription.reading);
                    }
                } catch (err) {
                    ftui.poll.long.lastError = err;
                    ftui.log(1, "longpoll: Error=" + err, "base.update");
                    ftui.log(1, "longpoll: Bad line=" + lines[i], "base.update");
                }
            }
        }
        ftui.updateBindElements('ftui.poll');
    },

    setFhemStatus: function (cmdline) {
        ftui.sendFhemCommand(cmdline);
    },

    sendFhemCommand: function (cmdline) {
        cmdline = cmdline.replace('  ', ' ');
        var dataType = (cmdline.substr(0, 8) === 'jsonlist') ? 'json' : 'text';
        ftui.log(1, 'send to FHEM: ' + cmdline, "base.command");
        return $.ajax({
            async: true,
            cache: false,
            method: 'GET',
            dataType: dataType,
            url: ftui.config.fhemDir,
            username: ftui.config.username,
            password: ftui.config.password,
            data: {
                cmd: cmdline,
                fwcsrf: ftui.config.csrf,
                XHR: "1"
            },
            error: function (jqXHR, textStatus, errorThrown) {
                ftui.log(1, "FHEM Command failed" + textStatus + ": " + errorThrown + " cmd=" + cmdline, 'base.command');
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


	// PFE
	connect: function() {
		// this assumes that we are disconnected and that no timers are running
		// TODO: handle csrf errors better
		
		ftui.log(1, 'CONNECTING', "base.poll");
		ftui.poll.status = 1;  // connecting
		// if shortpoll is due (check via real time)
		var ltime = Date.now() / 1000;
        if (ltime - ftui.states.lastShortpoll >= ftui.config.shortpollInterval) {
			ftui.poll.long.lastEventTimestamp = Date.now();
		//		start shortpoll
		//			fail: like onclose (conditionalConnect)
		//			success: handle results
			ftui.shortPoll().then(ftui.createWebsocket, ftui.conditionalConnect);
		}else{
			ftui.createWebsocket();
		};	
	},	
	
	
	// PFE
	disconnect: function() {
		// if websocket exists
		//		remove onclose handler
		//		close websocket
		//		throw away websocket
		if (ftui.poll.long.websocket) {
			// avoid trying to open again immediately via close event
			ftui.poll.long.websocket.onclose = function() {
				ftui.log(2, 'Websocket stopped, probably by disconnect', "base.poll");
			};
			// avoid any messages coming via the "old" websocket
			ftui.poll.long.websocket.onmessage = function (msg) {
				if(msg.data.length > 30) msg.data = msg.data.substring(0,27) + "...";
				ftui.log(2, "Closing websocket received " + msg.data, "base.poll");
			};
            ftui.poll.long.websocket.close();
            ftui.poll.long.websocket = undefined;
		};
		// stop healthcheck timer
		clearInterval(ftui.poll.healthCheckTimer);
		// stop shortpoll timer
		clearInterval(ftui.poll.short.timer);
		// abort shortpoll, if needed
		if(ftui.poll.short.request) {
			ftui.poll.short.request.abort();
			ftui.poll.short.request = null;
		};	
		ftui.log(1, 'DISCONNECTED', "base.poll");
		ftui.poll.status = 0;  // disconnected
	},
	
	
	// PFE
	conditionalConnect: function(immediately) {
		// always disconnect first to start in a clean state
		ftui.disconnect();
		// avoid that we do this multiple times
		if(ftui.poll.connectRetryTimer) {
			clearTimeout(ftui.poll.connectRetryTimer);
			ftui.poll.connectRetryTimer = null;
		};
		// if not visible, don't try to connect
		// There used to be a check on navigator.onLine as well, but this does not
		// seem to work properly
		if(document.visibilityState !== 'visible') {
			ftui.log(1, 'Staying DISCONNECTED: invisible or offline', "base.poll");
			ftui.poll.connectWaitTime = 0; // immediately connect when becoming visible or online 
			return;
		};	
		// if we have tried to connect less than n seconds ago, 
		// then wait a bit
		if(immediately) {
			ftui.poll.connectWaitTime = 0;  
		};
		if(ftui.poll.connectWaitTime > 0) { 
			var lastConnectAge = Date.now() - ftui.poll.lastConnectTime;
			if(lastConnectAge < ftui.poll.connectWaitTime) { 
				ftui.log(4, 'Connect wait time ' + ftui.poll.connectWaitTime + " ...waiting", "base.poll");
				ftui.poll.connectRetryTimer = setTimeout(ftui.conditionalConnect, ftui.poll.connectWaitTime - lastConnectAge);
				return;
			};	
		};
		// determine next time: 50,100,200,400,...,3200,5000
		if(ftui.poll.connectWaitTime) {
			ftui.poll.connectWaitTime *= 2;
			if(ftui.poll.connectWaitTime > 5000) ftui.poll.connectWaitTime = 5000;
		}else{
			ftui.poll.connectWaitTime = 50;
		};	
		ftui.poll.lastConnectTime = Date.now();
		ftui.connect();
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

    getCSrf: function () {

        return $.ajax({
            'url': ftui.config.fhemDir,
            'type': 'GET',
            cache: false,
            username: ftui.config.username,
            password: ftui.config.password,
            data: {
                XHR: "1"
            }
        }).done(function (data, textStatus, jqXHR) {
            ftui.config.csrf = jqXHR.getResponseHeader('X-FHEM-csrfToken');
            ftui.log(1, 'Got csrf from FHEM:' + ftui.config.csrf, "base.init");
        }).fail(function (jqXHR, textStatus, errorThrown) {
            ftui.log(1, "Failed to get csrfToken: " + textStatus + ": " + errorThrown, "base.init");
        });
    },

    healthCheck: function () {
		ftui.log(1,"health check","base.poll");
        var timeDiff = Date.now() - ftui.poll.long.lastEventTimestamp;
        if (timeDiff / 1000 > ftui.config.maxLongpollAge &&
            ftui.config.maxLongpollAge > 0) {
            ftui.log(1, 'No longpoll event since ' + timeDiff / 1000 + 'secondes -> restart polling', "base.poll");
            ftui.conditionalConnect(true);
        }
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

	showErrorOverlay: function (showIt) {
		if(showIt)
			$("#ftui-error-shade").show();
		else
			$("#ftui-error-shade").hide();
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
        return [$(this).data('type'), ($(this).data('device') ? $(this).data('device').replace(' ', 'default') : 'default'), $(this).data('get'), $(this).index()].join('.');
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

    $.fn.matchDeviceReading = function (key, device, param) {
        var elem = $(this);
        var value = elem.data(key);
        return (String(value) === param && String(elem.data('device')) === device) ||
            (value === device + ':' + param || value === '[' + device + ':' + param + ']') ||
            ($.inArray(param, value) > -1 && String(elem.data('device')) === device) ||
            ($.inArray(device + ':' + param, value) > -1);
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
        var state = String(ftui.getPart(value, elm.data(key + '-part')));
        var onData = elm.data(key + '-on');
        var offData = elm.data(key + '-off');
        var on = String(onData);
        var temp, device, reading, param;
        if (on.match(/:/)) {
            temp = on.split(':');
            device = temp[0].replace('[', '');
            reading = temp[1].replace(']', '');
            param = ftui.getDeviceParameter(device, reading);
            if (param && ftui.isValid(param)) {
                on = param.val;
            }
        }
        var off = String(offData);
        if (off.match(/:/)) {
            temp = off.split(':');
            device = temp[0].replace('[', '');
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
        var devName = String($(this).data('device'));
        var paraName = $(this).data(key);
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
            var params = ftui.deviceStates[devName];
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
        if ($(this).hasClass('notransmit')) return;
        var cmdl = [$(this).valOfData('cmd'), $(this).valOfData('device') + $(this).valOfData('filter'), $(this).valOfData('set'), $(
            this).valOfData('value')].join(' ');
        ftui.setFhemStatus(cmdl);
        ftui.toast(cmdl);
    };

    $.fn.otherThen = function (elem) {
        return $(this).filter(function () {
            var eq1 = $(this).wgid(),
                eq2 = elem.wgid();
            return eq1 !== eq2;
        });
    };
}


// PFE log/trace settings
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
