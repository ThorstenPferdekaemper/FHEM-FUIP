
"use strict";

var Modul_fuip_thermostat = function () {

    function drawDesiredTemp(elem) {
        var desiredTemp = elem.data('desiredTempVal');
        var textElem = elem.find('#main-temp');
		desiredTemp = parseFloat(desiredTemp).toFixed(1);
        textElem.text(desiredTemp);
		updateTicks(elem);
    }

    function onClicked(elem, factor) {

        if (elem.hasClass('lock')) {
            elem.addClass('fail-shake');
            setTimeout(function () {
                elem.removeClass('fail-shake');
            }, 500);
            return;
        }

		// Signal that we are now setting the temperature
		// to avoid that update interferes
		elem.clicked = true;

		// switch desired and measured temp in the display
		switchToSettingDisplay(elem);

        var step = parseFloat(elem.data('step'));
        var min = parseFloat(elem.data('min'));
        var max = parseFloat(elem.data('max'));
        var value = parseFloat(elem.data('desiredTempVal'));
        clearTimeout(elem.delayTimer);
        var changeValue = function () {
            value = value + factor * step;
            if (value < min) value = min;
            if (value > max) value = max;
            elem.data('desiredTempVal', value);
            drawDesiredTemp(elem);
        };
        // short press
        changeValue();
        elem.delayTimer = setTimeout(function () {
            elem.repeatTimer = setInterval(function () {
                // long press
                changeValue();
            }, elem.data('shortdelay'));
        }, elem.data('longdelay'));
    }

    function onReleased(elem) {
        clearTimeout(elem.repeatTimer);
        clearTimeout(elem.delayTimer);
        elem.delayTimer = setTimeout(function () {
			elem.data('value',elem.data('desiredTempVal'));
            elem.transmitCommand();
			// allow updates again
			elem.clicked = false;
            elem.delayTimer = 0;
        }, elem.data('longdelay'));
    }

	function switchToNormalDisplay(elem) {
		// switch desired and measured temp in the display (if needed)
		if(elem.data('main-display') == 'measured-temp'){
		    elem.find("#status-temp").text(elem.data('desiredTempVal'));
		    elem.find("#main-temp").text(elem.data('measuredTempVal'));
		    elem.find("#status-temp-icon").removeClass("fa fa-thermometer-2").addClass("fa fa-dot-circle-o");
		};
		elem.data('displaySwitchTimer', null);
	};

	function showDesiredTemp(elem) {
	    elem.find("#main-temp").text(elem.data('desiredTempVal'));
		elem.find("#status-temp").text(elem.data('measuredTempVal'));
		elem.find("#status-temp-icon").removeClass("fa fa-dot-circle-o").addClass("fa fa-thermometer-2");
	};

	function switchToSettingDisplay(elem) {
		// avoid switching back too early
		clearTimeout(elem.data('displaySwitchTimer'));
		// switch desired and measured temp in the display
		showDesiredTemp(elem);
		// care for switching back to normal display
		elem.data('displaySwitchTimer', setTimeout(function() { switchToNormalDisplay(elem) }, 5000));
	};

    function init_attr(elem) {

        //init standard attributes
        _base.init_attr.call(me, elem);

        elem.initData('left-color', 'blue');
        elem.initData('right-color', 'red');
        elem.initData('shortdelay', 80);
        elem.initData('longdelay', 500);
		elem.initData('transmitdelay', 1000);
        elem.initData('desired-temp', 'desired-temp');
		elem.initData('measured-temp','measured-temp');
        elem.initData('min', '10');
        elem.initData('max', '30');
        elem.initData('step', '0.5');
        elem.initData('fix', ftui.precision(elem.data('step')));
        elem.initData('unit', '');
		// main-display determines what is shown in the main display
		// currently supported:
		// - measured-temp: Measured temperature is usually shown, switches
		//                  to desired temperatur when the widget is touched
		// - desired-temp:  Always display the desired temperature
		elem.initData('main-display', 'measured-temp');
		elem.initData('show-btn-lock', 'off');
		elem.initData('show-boost', 'off');
		elem.initData('show-control-mode', 'off');
		elem.initData('btn-lock-device',elem.data('device'));
		elem.initData('boost-device',elem.data('device'));
		elem.initData('control-mode-device',elem.data('device'));
		// HM-IP support: device type can be HM-CLASSIC or HM-IP
		elem.initData('device-type','HM-CLASSIC');

		me.addReading(elem, 'desired-temp');
		me.addReading(elem, 'measured-temp');
		me.addReading(elem, 'humidity');
		me.addReading(elem, 'valve');

		if(elem.data('show-control-mode') == 'on') {
			// HM-IP support
			var controlModeReading;
			if(elem.data('device-type') == 'HM-CLASSIC') {
				controlModeReading = 'controlMode';
			}else{  // HM-IP
				controlModeReading = 'SET_POINT_MODE';
			};		
			elem.initData('control-mode-reading',elem.data('control-mode-device') + ':' + controlModeReading);
			me.addReading(elem, 'control-mode-reading');
		};	
		if(elem.data('show-boost') == 'on') {
			// HM-IP support
			// We could use BOOST_MODE or BOOST_TIME. The latter looks "safer"
			var boostReading;
			if(elem.data('device-type') == 'HM-CLASSIC') {
				boostReading = 'controlMode';
			}else{  // HM-IP
				boostReading = 'BOOST_TIME';
			};		
			elem.initData('boost-reading',elem.data('boost-device') + ':' + boostReading);
			me.addReading(elem, 'boost-reading');
		};	
		if(elem.data('show-btn-lock') == 'on') {
			// It looks like HM-IP does not have a lock, so just keep it as it is
			// (Or rather leave it to the user not to use it.)
			elem.initData('btn-lock-reading',elem.data('btn-lock-device') + ':R-btnLock');
			me.addReading(elem, 'btn-lock-reading');
		};	

    }


	function colorFromCSS(name) {
		var tmp = document.createElement("div"), color;
		tmp.style.cssText = "position:fixed;left:-100px;top:-100px;width:1px;height:1px;background-color:"+name;
		document.body.appendChild(tmp);  // required in some browsers
		color = getComputedStyle(tmp).getPropertyValue("background-color");
		document.body.removeChild(tmp);
		return color
	}
	
	
	function setBackground(elem,activity) {
		// activity: on,off,/set/
		if(activity == 'off' || activity == '' || !activity) {
			elem.css('backgroundColor','');
			return;
		};	
		var col = colorFromCSS("var(--fuip-color-symbol-active)");
		if(/set/.test(activity)) {	
			col = colorToRgbaArray(col); 
			col[3] = 0.3;
			col = colorToRgbaString(col);
		};
		elem.css('backgroundColor',col);	
	};


	function drawValvePosition(elem,canvas) {

		var valves = elem.data('valves');
		var numValves = valves.length;

        var c = canvas.getContext("2d"); // context
		c.fillStyle = colorFromCSS("var(--fuip-color-symbol-active)");

		// left arc
		c.beginPath();
		c.moveTo(32,32);
		c.arc(32, 32, 28, Math.PI, 1.5 * Math.PI , false);
		c.closePath();
		c.fill();

		// right arc
		c.beginPath();
		c.moveTo(canvas.width - 32,32);
		c.arc(canvas.width - 32, 32, 28, 0, 1.5 * Math.PI, true);
		c.closePath();
		c.fill();

		// main part between the arcs
		c.fillRect(32, 4, canvas.width - 64, canvas.height);
		c.fillRect(4, 32, 28, 32);
		c.fillRect(canvas.width - 32, 32, 28, 32);

		// now remove the parts which are not needed
		var partWidth = canvas.width / numValves;
		for(var i = 0; i < numValves; i++) {
			// The area of each valve starts at
			// partWidth * i  and ends at partWidth * (i+1) (-1)
			// The area to clear starts at
			// partWidth * i + partWidth * valve / 100
			c.clearRect(partWidth * ( i + valves[i] / 100), 0, partWidth * (1 - valves[i] / 100), canvas.height);
		};
	};


	function drawTicks(elem,canvas,desired,actual) {

        var c = canvas.getContext("2d");
        c.clearRect(0, 0, canvas.width, canvas.height);
        c.lineWidth = elem.lineWidth;
        c.lineCap = "square";
 		var step = elem.data('step');
        var maxcolor = '#ff0000';
        var mincolor = '#4477ff';
        var actcolor = "var(--fuip-color-foreground)";

		var max = elem.data('max');
		var min = elem.data('min');
		var width = canvas.width - 10;
		var start = 5;
		// how many ticks?
		var numTicks = (max - min) / step;
		var maxTicks = width / 32;
		if(numTicks > maxTicks) {
			numTicks = maxTicks;
		};

        // draw ticks
        for (var tick = 0; tick <= numTicks; tick++) {

			var temp = min + (max - min) * tick / numTicks

            c.beginPath();
			var col = false;
            if (( temp >= desired && temp <= actual ) || (temp <= desired && temp >= actual)) {
                // draw diff range in gradient color
				col = true;
                c.strokeStyle = ftui.getGradientColor(mincolor, maxcolor, tick / numTicks);
            } else {
                // draw normal ticks
                c.strokeStyle = colorFromCSS(actcolor);
            }

			var w;
            // thicker lines every 10 ticks
            if (Math.round(temp / step) % 10 == 0) {
                w = col ? 3 : 2;
            } else {
                w = col ? 2 : 1;
            }
			c.lineWidth = w * 8;

			c.moveTo(start + Math.round(tick * width / numTicks),0);
			c.lineTo(start + Math.round(tick * width / numTicks), canvas.height * 0.6);
            c.stroke();
        }

        // draw target temp cursor
        c.beginPath();
        c.strokeStyle = ftui.getGradientColor(mincolor, maxcolor, (desired - min) / (max - min));
        c.lineWidth = 40;
		c.lineCap = 'round';
		c.moveTo(start + Math.round((desired - min) / (max - min) * width), canvas.height * 0.4);
		c.lineTo(start + Math.round((desired - min) / (max - min) * width),  canvas.height);
        c.stroke();

        return false;
    }


	function updateTicks(elem) {
		var levelCanvas = elem.find("#desiredCanvas");
		var desiredTemp = elem.data('desiredTempVal');
		var measuredTemp = elem.data('measuredTempVal');
		drawTicks(elem,levelCanvas.get(0),desiredTemp,measuredTemp);
	};


	function transformDimension(value,minInp,maxInp,minRes,maxRes) {
		var result = (value - minInp) * (maxRes - minRes) / (maxInp - minInp) + minRes;
		if(result > maxRes) result = maxRes;
		if(result < minRes) result = minRes;
		return result;
	};


    function init_ui(elem) {

		var view = elem.closest("[data-viewid]");
		var width = view.width();
		var height = view.height();

        // prepare container element
        var elemWrapper = $('<div/>')
            .css({
				width: width + 'px',
                height: height + 'px',
                color: "var(--fuip-color-foreground)",
                backgroundColor: "var(--fuip-color-background-transparent)",
				borderStyle: 'solid', borderColor: '#6a6a6a', borderWidth: '1px',
				borderRadius: '4px'
            });

		var label = elem.data('label');

		// Determine sizes (heights)
		// Min 150x75, Max 300x150
		// Valve display max 8, min 4 px
		var valveHeight = transformDimension(height,75,150,4,8);
		var ticksHeight = transformDimension(height,75,150,8,15);
		var titleHeight = 0;
		if(label) {
			titleHeight = height * 0.2;
			if(titleHeight < 15) titleHeight = 15;
		};
		var statusHeight = height * 0.15;
		if(statusHeight < 15) statusHeight = 15;
		var statusWidthFactor = 7;
		if($.isArray(elem.data('valve'))) {
			statusWidthFactor += 4 * elem.data('valve').length;
		}else if(elem.data('valve')) {
			statusWidthFactor += 4;
		};
		if(statusHeight * statusWidthFactor > width) statusHeight = width / statusWidthFactor;
		var valveTop = 0;
		var ticksTop = valveHeight + 2;
		var titleTop = ticksTop + ticksHeight;
		var contentTop = label ? titleTop + titleHeight : titleTop + 2;
		var contentHeight = height - ( contentTop + statusHeight );    // height * 0.4;
		var controlHeight = 0;
		var controlTop = 0;
		var numControls = ( elem.data('show-btn-lock') == 'on' ? 1 : 0) 
						+ ( elem.data('show-boost') == 'on' ? 1 : 0)	
						+ ( elem.data('show-control-mode') == 'on' ? 1: 0);
		if(numControls){
			controlHeight = contentHeight * 0.35;
			contentHeight = contentHeight - controlHeight;
			controlTop = contentTop + contentHeight;
		};	   
		var statusBottom = transformDimension(height,75,150,1,2);
		var tempFontSize = contentHeight * 0.7;
		var tempWidth = (width -8) * 0.5;
		if(tempWidth / tempFontSize < 12 / 5) {
			tempFontSize = tempWidth * 5 / 12;
		};
		var iconWidth = (width -8) * 0.25;
		var iconFontSize = contentHeight * 0.8;
		if(iconFontSize > iconWidth * 1.5) iconFontSize = iconWidth * 1.5;

		var valveCanvas = $('<canvas style="width:' + width +'px;height:' + valveHeight + 'px;position:absolute;left:0px;top:'+valveTop+'px;" id="valveCanvas" width="' + width * 8 +'" height="'+(valveHeight * 8)+'"></canvas>').appendTo(elemWrapper);

		var ticksCanvas = $('<canvas id="desiredCanvas" style="position:absolute;top:'+ticksTop+'px;left:5px;width:'+(width -10)+'px;height:'+ticksHeight+'px;" width="' + (width -10) * 8 +'" height="'+(ticksHeight*8)+'"></canvas>').appendTo(elemWrapper);
		drawTicks(elem,ticksCanvas.get(0),undefined,undefined);

		if(label) {
			$('<div>' + label + '</td>')
				.css({ height: titleHeight + 'px',
						fontSize: (titleHeight * 0.8) + 'px', textAlign: 'left',
						padding: '0',
						paddingLeft: '10px',
						position: 'absolute', top: titleTop+'px' })
				.appendTo(elemWrapper);
		};

		var contentLine = $('<div/>')
		                      .css({ width : (width - 8) + 'px', height: contentHeight + 'px',
									 position: 'absolute', top: contentTop + 'px', left: '4px',
									 borderTopStyle: 'solid', borderColor: '#6a6a6a', borderWidth: '1px',
									 borderBottomStyle: 'solid', borderColor: '#6a6a6a', borderWidth: '1px',
									 })
				              .appendTo(elemWrapper);

		// prepare left icon
        var elemLeftIcon = $('<div/>')
            .css({
                color: elem.mappedColor('left-color'),
				width: iconWidth + 'px',
				height: (contentHeight-8)+'px',
				lineHeight: (contentHeight-8)+'px',
				fontSize: iconFontSize + 'px',
				fontWeight: 'bold',
				fontFamily: 'sans serif',
				position: 'absolute', top: '3px'
            })
            .appendTo(contentLine);
        elemLeftIcon.html('&minus;');

        // prepare main temperature element
        var levelArea = $('<div id="main-temp"/>').css({
			    display: 'inline-block',
                width: tempWidth + 'px',
				height: (contentHeight-8)+'px',
				lineHeight: (contentHeight-8)+'px',
			    fontSize: tempFontSize + 'px',
				padding: '0',
				borderLeftStyle: 'solid', borderRightStyle: 'solid', borderColor: '#6a6a6a', borderLeftWidth: '1px', borderRightWidth: '1px',
			    position: 'absolute', top: '3px', left: ((width -8) * 0.25) + 'px'
            })
            .appendTo(contentLine);

        // prepare right icon
        var elemRightIcon = $('<div/>')
            .css({
                color: elem.mappedColor('right-color'),
				width: iconWidth + 'px',
				height: (contentHeight-8)+'px',
				lineHeight: (contentHeight-8)+'px',
				fontSize: iconFontSize + 'px',
				fontWeight: 'bold',
				fontFamily: 'sans serif',
				position: 'absolute', top: '3px', right: '0px'
            })
            .appendTo(contentLine);
        elemRightIcon.html('&plus;');

		if(numControls) {
			// font size: 
			// controlHeight * 0.5 if this is >= 16
			// controlHeight * 0.8 if this is <= 8
			// in between linear
			var factor = 0.8 - 0.3 * ( controlHeight - 10 ) / 22;
			if(factor < 0.5) factor = 0.5;
			if(factor > 0.8) factor = 0.8;
			var controlFontSize = controlHeight * factor;
			var controlAreaWidth = (numControls == 2) ? (width - 8) / 2 : (width - 8) / 3;
			var textFontSize = controlFontSize;
			if(textFontSize * 3 > controlAreaWidth) {
				textFontSize = controlAreaWidth / 3;
			};	
			var controlLine = $('<div/>')
		                      .css({ width : (width - 8) + 'px', height: controlHeight + 'px',
									 position: 'absolute', top: controlTop + 'px', left: '4px',
									 borderBottomStyle: 'solid', borderColor: '#6a6a6a', borderWidth: '1px',
									 })
				              .appendTo(elemWrapper);

			// only one control: Put it in the middle like the levelArea
			// two controls: Split 50/50
			// three controls: Split 1/3	
			var leftPos; 
			if(elem.data('show-control-mode') == 'on') {
				leftPos = (numControls == 1) ? (width - 8) / 3 : 0;
				var showControlModeArea = $('<div id="control-mode" />').css({
						width: controlAreaWidth + 'px',
						height: (controlHeight-8)+'px',
						lineHeight: (controlHeight-8)+'px',
						fontSize: textFontSize + 'px',
						padding: '0',
						borderLeftStyle: ((numControls == 1) ? 'solid' : 'none') , borderRightStyle: 'solid', 
						borderColor: '#6a6a6a', borderLeftWidth: '1px', borderRightWidth: '1px',
						position: 'absolute', top: '3px', left: leftPos + 'px'
					}).appendTo(controlLine);
				showControlModeArea.on(ftui.config.clickEventType, function (e) {
					showControlModeArea.fadeTo("fast", 0.5);
					e.preventDefault();
					e.stopPropagation();
					// get current content
					var mode = elem.getReading('control-mode-reading').val;
					if(/auto/.test(mode)) {
						mode = 'manual';
					}else{
						mode = 'auto';
					};
					// HM-IP support
					if(elem.data('device-type') == 'HM-CLASSIC') {
						ftui.sendFhemCommand('set ' + elem.data('control-mode-device') + ' controlMode ' + mode);	
					}else{
						if(mode == 'manual') mode = 'manu';
						ftui.sendFhemCommand('set ' + elem.data('control-mode-device') + ' ' + mode);	
					};	
					
				});
				showControlModeArea.on(ftui.config.releaseEventType + ' ' + ftui.config.leaveEventType, function (e) {
					showControlModeArea.fadeTo("fast", 1);
					e.preventDefault();
					e.stopPropagation();
				});			
			};
			
			if(elem.data('show-boost') == 'on') {
				leftPos = 0;  // if 2 and not controlMode
				if(numControls != 2){
					leftPos = (width - 8) / 3;
				}else if(elem.data('show-control-mode') == 'on'){
					leftPos = (width - 8) / 2;
				};	
				var showBoostArea = $('<div id="boost">boost</div>').css({
					width: controlAreaWidth + 'px',
					height: (controlHeight-8)+'px',
					lineHeight: (controlHeight-8)+'px',
					fontSize: textFontSize + 'px',
					padding: '0',
					borderLeftStyle: ((numControls == 1) ? 'solid' : 'none') , 
					borderRightStyle: ((numControls != 2 || elem.data('show-control-mode') == 'off') ? 'solid' : 'none'), 
					borderColor: '#6a6a6a', borderLeftWidth: '1px', borderRightWidth: '1px',
					position: 'absolute', top: '3px', 
					left: leftPos + 'px'
				})
				.appendTo(controlLine);
				showBoostArea.on(ftui.config.clickEventType, function (e) {
					showBoostArea.fadeTo("fast", 0.5);
					e.preventDefault();
					e.stopPropagation();
					// HM-IP support
					if(elem.data('device-type') == 'HM-CLASSIC') {
						ftui.sendFhemCommand('set ' + elem.data('boost-device') + ' controlMode boost');	
					}else{
						ftui.sendFhemCommand('set ' + elem.data('boost-device') + ' boost');
					};	
						
				});
				showBoostArea.on(ftui.config.releaseEventType + ' ' + ftui.config.leaveEventType, function (e) {
					showBoostArea.fadeTo("fast", 1);
					e.preventDefault();
					e.stopPropagation();
				});			
			};		
			
			if(elem.data('show-btn-lock') == 'on') {
				if(numControls == 1){
					leftPos = (width - 8) / 3;
				}else if(numControls == 2){
					leftPos = (width - 8) / 2;
				}else{
					leftPos = (width - 8) * 2 / 3;	
				};	
				var showLockArea = $('<div id="btn-lock" />').css({
					width: controlAreaWidth + 'px',
					height: (controlHeight-8)+'px',
					lineHeight: (controlHeight-8)+'px',
					fontSize: controlFontSize + 'px',
					padding: '0',
					borderLeftStyle: ((numControls == 1) ? 'solid' : 'none') , borderRightStyle: ((numControls == 1) ? 'solid' : 'none'), 
					borderColor: '#6a6a6a', borderLeftWidth: '1px', borderRightWidth: '1px',
					position: 'absolute', top: '3px', 
					left: leftPos + 'px'
				})
				.appendTo(controlLine);
				showLockArea.on(ftui.config.clickEventType, function (e) {
					showLockArea.fadeTo("fast", 0.5);
					e.preventDefault();
					e.stopPropagation();
					var lockValue = elem.getReading('btn-lock-reading').val;
					if(/on/.test(lockValue)) {
						lockValue = 'off';
					}else{
						lockValue = 'on';
					};
					ftui.sendFhemCommand('set ' + elem.data('btn-lock-device') + ' regSet btnLock ' + lockValue);	
				});
				showLockArea.on(ftui.config.releaseEventType + ' ' + ftui.config.leaveEventType, function (e) {
					showLockArea.fadeTo("fast", 1);
					e.preventDefault();
					e.stopPropagation();
				});			
			};		 			
							  
		};

		var statusContainer = $('<div/>')
							.css({padding: '0px', height: statusHeight + 'px',
								  fontSize:(statusHeight * 0.8) + 'px',
							      width: width + 'px',
								  position: 'absolute', bottom: 0
								  })
							.appendTo(elemWrapper);
		var statusCell = $('<div/>')
							.css( { margin: 0, position: "absolute", top: "50%", left: "50%",
									transform: "translate(-50%, -50%)", width: width + 'px' })
							.appendTo(statusContainer);

		var statusHtml = '<i class="fuip-color" id="status-temp-icon"></i> <span id="status-temp"></span>'+elem.data('unit');  
		if(elem.data('humidity')) {
			statusHtml += '&nbsp;&nbsp;<i class="wi wi-raindrop fuip-color"></i>&nbsp;<span id="humidity"></span>%';
		};
		var valveArr = elem.data('valve');
		if(!valveArr) {
			valveArr = [];
		}else if(!$.isArray(valveArr)){
			valveArr = [ valveArr ];
		};
		for(var i = 0; i < valveArr.length; i++) {
			statusHtml += '&nbsp;&nbsp;<i class="fa fa-gear fuip-color"></i>&nbsp;<span id="valve-' + i + '"></span>%';
		};
		statusCell.html(statusHtml);

        // event handler
        // UP button
        elemRightIcon.on(ftui.config.clickEventType, function (e) {
            elemRightIcon.fadeTo("fast", 0.5);
            e.preventDefault();
            e.stopPropagation();
            onClicked(elem, 1);
        });
        elemRightIcon.on(ftui.config.releaseEventType + ' ' + ftui.config.leaveEventType, function (e) {
            elemRightIcon.fadeTo("fast", 1);
            if (elem.delayTimer)
                onReleased(elem);
            e.preventDefault();
            e.stopPropagation();
        });
        elemRightIcon.on('click', function (e) {
            e.preventDefault();
            e.stopPropagation();
            return false;
        });

        // DOWN button
        elemLeftIcon.on(ftui.config.clickEventType, function (e) {
            elemLeftIcon.fadeTo("fast", 0.5);
            e.preventDefault();
            e.stopPropagation();
            onClicked(elem, -1);
        });
        elemLeftIcon.on(ftui.config.releaseEventType + ' ' + ftui.config.leaveEventType, function (e) {
            elemLeftIcon.fadeTo("fast", 1);
            if (elem.delayTimer)
                onReleased(elem);
            e.preventDefault();
        });
        elemLeftIcon.on('click', function (e) {
            e.preventDefault();
            e.stopPropagation();
            return false;
        });

		// click on the temperature in the big area should show desired temperature
        levelArea.on(ftui.config.clickEventType, function() { switchToSettingDisplay(elem) } );

        //Overlay
        elem.append($('<div/>', {
            class: 'overlay'
        }));

        //Wrapper
        elem.html(elemWrapper);

		// It can happen that this is called again, e.g. when a popup is opening
		// In this case, we need to fix some stuff
		if(elem.data('main-display') == 'desired-temp' || elem.data('displaySwitchTimer')){ 
	        showDesiredTemp(elem);
		}else{
			switchToNormalDisplay(elem);
		};	
    };


	function getValue(elem,parameter,device,reading) {
		if (!elem.matchDeviceReading(parameter,device,reading)) return null;
        var value = elem.getReading(parameter).val;
        if (value === undefined || value === null) return null;
        return value;
	};


    function update(dev, par) {

        me.elements.each(function (index) {
            var elem = $(this);

			updateElem(elem,dev,par);

            //extra reading for reachable
            me.updateReachable(elem, dev, par);

            //extra reading for hide
            me.updateHide(elem, dev, par);

            //extra reading for lock
            me.updateLock(elem, dev, par);

        });
    }


	function updateElem(elem, dev, par) {

 		// desiredTemp appears in the status line, if it comes from the backend
		// otherwise (if changing it), it appears in the big area, but this 
		// is not done here, as it would otherwise interfere with the user changing
		// it
		// (displaySwitchTimer is also used when the main display always shows
		// the desired temperature. In this case it is only used to avoid that
		// it is reset from the backend while the user is changing it.)
		if(!elem.data('displaySwitchTimer')) {
			var desiredTemp = getValue(elem,'desired-temp',dev,par);
			if(desiredTemp !== null) {
				desiredTemp = parseFloat(desiredTemp).toFixed(1);
				elem.data('desiredTempVal', desiredTemp);
				if(elem.data('main-display') == 'desired-temp') {
				    elem.find("#main-temp").text(desiredTemp);
				}else{				
				    elem.find("#status-temp").text(desiredTemp);
				};	
				updateTicks(elem);
			};
		};

		// measuredTemp usually appears in the big area, but when the desired-temp
		// is changed, the measuredTemp goes to the status area
		var measuredTemp = getValue(elem,'measured-temp',dev,par);
		if (measuredTemp != null) {
			measuredTemp = parseFloat(measuredTemp).toFixed(1);
			elem.data('measuredTempVal', measuredTemp);
			updateTicks(elem);
			if(elem.data('main-display') != 'measured-temp' || elem.data('displaySwitchTimer')) {
				elem.find("#status-temp").text(measuredTemp);
			}else{
				elem.find("#main-temp").text(measuredTemp);
			};
        };

		// humidity
		var humidity = getValue(elem,'humidity',dev,par);
		if(humidity != null){
		    humidity = parseFloat(humidity).toFixed(0);
		    elem.find("#humidity").text(humidity);
		};
		
		// control mode
		var controlMode = getValue(elem,'control-mode-reading',dev,par);
		if(controlMode != null){
		    var controlModeArea = elem.find("#control-mode");
			if(/set/.test(controlMode)) {
				setBackground(controlModeArea, 'set');
				controlMode = controlMode.substring(4);
			}else{
				setBackground(controlModeArea);
			};		
			controlModeArea.text(controlMode);
		};
		
		// boost
		var boostValue = getValue(elem,'boost-reading',dev,par);
		if(boostValue != null){
			var boostArea = elem.find("#boost");	
			// HM-IP support	
			// HM-CLASSIC: The reading contains something with "boost"
			// HM-IP: The reading contains a number (seconds) where != 0 means "boost active"
			if(/boost/.test(boostValue) || elem.data('device-type') == 'HM-IP' && boostValue != '0') {
				setBackground(boostArea,boostValue);
			}else{
				setBackground(boostArea);
			};	
		};
		
		// lock
		var lockValue = getValue(elem,'btn-lock-reading',dev,par);
		if(lockValue != null){
			var lockArea = elem.find("#btn-lock");
			if(/on/.test(lockValue)) {
				lockArea.html('<i class="fa fa-lock fuip-color" />');
			}else{	
				lockArea.html('<i class="fa fa-lock-open fuip-color" />');
			};
			if(/set/.test(lockValue)) {
				setBackground(lockArea,'set');
			}else{
				setBackground(lockArea);
			};	
		};

		// valve
		var idx = elem.matchDeviceReadingIndex('valve',dev,par);
		if(idx < 0) return;
        var value = elem.getReading('valve',idx).val;
        if (value === undefined || value === null) return;
		value = parseFloat(value).toFixed(0);
		elem.find("#valve-"+idx).text(value);
		var valves = elem.data('valves');
		if(!valves) valves = [];
		valves[idx] = value;
		elem.data('valves',valves);
		var valveCanvas = elem.find('#valveCanvas').get(0);
		drawValvePosition(elem,valveCanvas);
    }


	function resize(id) {
		// called when the widget is resized
		var elem = $("#"+id);
		if(!elem.data('updateAfterResizeTimeout')) {
			elem.data('updateAfterResizeTimeout', setTimeout(function() { init_ui(elem); updateAfterResize(elem) }, 40));
		};
    };


	function updateAfterResize(elem) {
		var module;
		for(var i = 0; i < plugins.modules.length;i++) {
			if(plugins.modules[i].widgetname === 'fuip_thermostat') {
				module = plugins.modules[i];
				break;
			}
		};
		if(!module) return;
		for (var key in module.subscriptions) {
            updateElem(elem, module.subscriptions[key].device, module.subscriptions[key].reading)
		};
		elem.data('updateAfterResizeTimeout',0)
	};


    // public
    // inherit all public members from base class
    var base = new Modul_widget();
    var _base = {};
    _base.init_attr = base.init_attr;
    var me = $.extend(base, {
        //override our own public members
        widgetname: 'fuip_thermostat',
        init_attr: init_attr,
        init_ui: init_ui,
        update: update,
    });

	fuip_resize_register("fuip-thermostat",resize);

    return me;
};
