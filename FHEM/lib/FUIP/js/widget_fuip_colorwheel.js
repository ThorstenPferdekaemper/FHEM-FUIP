/* FUIP colorwheel
* Thorsten Pferdekaemper 2019  
  
* Based on...
*	FTUI Plugin by Mario Stephan <mstephan@shared-files.de>
* 	Under MIT License (http://www.opensource.org/licenses/mit-license.php)
* and
*	farbtastic.js (Farbtastic 2.0.0-alpha.1)
*	2014 by Matt Farina
*	2015 by Mario Stephan
*/	
	
/* Farbtastic */

(function ($) {

var __debug = false;

$.fn.fuip_farbtastic = function (options) {
  $.fuip_farbtastic(this, options);
  return this;
};

$.fuip_farbtastic = function (container, options) {
  var container = $(container)[0];
  return container.fuip_farbtastic || (container.fuip_farbtastic = new $._fuip_farbtastic(container, options));
}

$._fuip_farbtastic = function (container, options) {
  var fb = this;

  /////////////////////////////////////////////////////

  /**
   * Link to the given element(s) or g.
   */
  fb.linkTo = function (callback) {
    // Unbind previous nodes
    if (typeof fb.callback == 'object') {
      $(fb.callback).unbind('keyup', fb.updateValue);
    }

    // Reset color
    fb.color = null;

    // Bind callback or elements
    if (typeof callback == 'function') {
      fb.callback = callback;
    }
    else if (typeof callback == 'object' || typeof callback == 'string') {
      fb.callback = $(callback);
      fb.callback.bind('keyup', fb.updateValue);
      if (fb.callback[0].value) {
        fb.setColor(fb.callback[0].value);
      }
    }
    return this;
  }
  fb.updateValue = function (event) {
    if (this.value && this.value != fb.color) {
      fb.setColor(this.value);
    }
  }

  /**
   * Change color with HTML syntax #123456
   */
  fb.setColor = function (color) {
    var unpack = fb.unpack(color);
    if (fb.color != color && unpack) {
      fb.color = color;
      fb.rgb = unpack;
      fb.hsl = fb.RGBToHSL(fb.rgb);
      fb.updateDisplay();
    }
    return this;
  }

  /**
   * Change color with HSL triplet [0..1, 0..1, 0..1]
   */
  fb.setHSL = function (hsl) {
    fb.hsl = hsl;
    fb.rgb = fb.HSLToRGB(hsl);
    fb.color = fb.pack(fb.rgb);
    fb.updateDisplay();
    return this;
  }

  /////////////////////////////////////////////////////

  /**
   * Initialize the color picker widget.
   */
  fb.initWidget = function () {
		$(container).html(
			'<div class="farbtastic" style="position: relative">' +
				'<div class="farbtastic-solid"></div>' +
				'<canvas class="farbtastic-mask"></canvas>' +
				'<canvas class="farbtastic-overlay"></canvas>' +
			'</div>'
		)
		.find('div>*').css('position', 'absolute');
		fb.repaint(options.width);
  }

	/* repaint / resize widget */
  fb.repaint = function (width) {

    // Insert markup and size accordingly.
    var dim = {
      width: width,
      height: width
    };
	var wheelWidth = width / 10;  // TODO: in principle, wheelWidth is an option
    $(container).find('*').attr(dim).css(dim);

    // Determine layout
    fb.radius = (width - wheelWidth) / 2 - 1;
    fb.square = Math.floor((fb.radius - wheelWidth / 2) * 0.7) - 1;
    fb.mid = Math.floor(width / 2);
    fb.markerSize = wheelWidth * 0.3;
    fb.solidFill = $('.farbtastic-solid', container).css({
      width: fb.square * 2 - 1,
      height: fb.square * 2 - 1,
      left: fb.mid - fb.square,
      top: fb.mid - fb.square
    });

    // Set up drawing context.
    fb.cnvMask = $('.farbtastic-mask', container);
    fb.ctxMask = fb.cnvMask[0].getContext('2d');
    fb.cnvOverlay = $('.farbtastic-overlay', container);
    fb.ctxOverlay = fb.cnvOverlay[0].getContext('2d');
    fb.ctxMask.translate(fb.mid, fb.mid);
    fb.ctxOverlay.translate(fb.mid, fb.mid);

    // Draw widget base layers.
    fb.drawCircle(wheelWidth);
    fb.drawMask();
	if(fb.color) fb.updateDisplay();
  }
  
  
  /**
   * Draw the color wheel.
   */
  fb.drawCircle = function (wheelWidth) {
    var tm = +(new Date());
    // Draw a hue circle with a bunch of gradient-stroked beziers.
    // Have to use beziers, as gradient-stroked arcs don't work.
    var n = 24,
        r = fb.radius,
        w = wheelWidth,
        nudge = 8 / r / n * Math.PI, // Fudge factor for seams.
        m = fb.ctxMask,
        angle1 = 0, color1, d1;
    m.save();
    m.lineWidth = w / r;
    m.scale(r, r);
    // Each segment goes from angle1 to angle2.
    for (var i = 0; i <= n; ++i) {
      var d2 = i / n,
          angle2 = d2 * Math.PI * 2,
          // Endpoints
          x1 = Math.sin(angle1), y1 = -Math.cos(angle1);
          x2 = Math.sin(angle2), y2 = -Math.cos(angle2),
          // Midpoint chosen so that the endpoints are tangent to the circle.
          am = (angle1 + angle2) / 2,
          tan = 1 / Math.cos((angle2 - angle1) / 2),
          xm = Math.sin(am) * tan, ym = -Math.cos(am) * tan,
          // New color
          color2 = fb.pack(fb.HSLToRGB([d2, 1, 0.5]));
      if (i > 0) {
        /* if ($.browser.msie || false) {
          // IE's gradient calculations mess up the colors. Correct along the diagonals.
          var corr = (1 + Math.min(Math.abs(Math.tan(angle1)), Math.abs(Math.tan(Math.PI / 2 - angle1)))) / n;
          color1 = fb.pack(fb.HSLToRGB([d1 - 0.15 * corr, 1, 0.5]));
          color2 = fb.pack(fb.HSLToRGB([d2 + 0.15 * corr, 1, 0.5]));
          // Create gradient fill between the endpoints.
          var grad = m.createLinearGradient(x1, y1, x2, y2);
          grad.addColorStop(0, color1);
          grad.addColorStop(1, color2);
          m.fillStyle = grad;
          // Draw quadratic curve segment as a fill.
          var r1 = (r + w / 2) / r, r2 = (r - w / 2) / r; // inner/outer radius.
          m.beginPath();
          m.moveTo(x1 * r1, y1 * r1);
          m.quadraticCurveTo(xm * r1, ym * r1, x2 * r1, y2 * r1);
          m.lineTo(x2 * r2, y2 * r2);
          m.quadraticCurveTo(xm * r2, ym * r2, x1 * r2, y1 * r2);
          m.fill();
        }
        else { */
          // Create gradient fill between the endpoints.
          var grad = m.createLinearGradient(x1, y1, x2, y2);
          grad.addColorStop(0, color1);
          grad.addColorStop(1, color2);
          m.strokeStyle = grad;
          // Draw quadratic curve segment.
          m.beginPath();
          m.moveTo(x1, y1);
          m.quadraticCurveTo(xm, ym, x2, y2);
          m.stroke();
       /* } */
      }
      // Prevent seams where curves join.
      angle1 = angle2 - nudge; color1 = color2; d1 = d2;
    }
    m.restore();
    __debug && $('body').append('<div>drawCircle '+ (+(new Date()) - tm) +'ms');
  };

  /**
   * Draw the saturation/luminance mask.
   */
  fb.drawMask = function () {
    var tm = +(new Date());

    // Iterate over sat/lum space and calculate appropriate mask pixel values.
    var size = fb.square * 2, sq = fb.square;
    function calculateMask(sizex, sizey, outputPixel) {
      var isx = 1 / sizex, isy = 1 / sizey;
      for (var y = 0; y <= sizey; ++y) {
        var l = 1 - y * isy;
        for (var x = 0; x <= sizex; ++x) {
          var s = 1 - x * isx;
          // From sat/lum to alpha and color (grayscale)
          var a = 1 - 2 * Math.min(l * s, (1 - l) * s);
          var c = (a > 0) ? ((2 * l - 1 + a) * .5 / a) : 0;
          outputPixel(x, y, c, a);
        }
      }
    }

    // Method #1: direct pixel access (new Canvas).
    // #1 disabled due to problems on tablet screen
    /* if (fb.ctxMask.getImageData && false) { 
      // Create half-resolution buffer.
      var sz = Math.floor(size / 2);
      var buffer = document.createElement('canvas');
      buffer.width = buffer.height = sz + 1;
      var ctx = buffer.getContext('2d');
      var frame = ctx.getImageData(0, 0, sz + 1, sz + 1);

      var i = 0;
      calculateMask(sz, sz, function (x, y, c, a) {
        frame.data[i++] = frame.data[i++] = frame.data[i++] = c * 255;
        frame.data[i++] = a * 255;
      });

      ctx.putImageData(frame, 0, 0);
      fb.ctxMask.drawImage(buffer, 0, 0, sz + 1, sz + 1, -sq, -sq, sq * 2, sq * 2);
    }
    // Method #2: drawing commands (old Canvas).
    else if (!($.browser.msie || false)) { */
      // Render directly at half-resolution
      var sz = Math.floor(size / 2);
      calculateMask(sz, sz, function (x, y, c, a) {
        c = Math.round(c * 255);
        fb.ctxMask.fillStyle = 'rgba(' + c + ', ' + c + ', ' + c + ', ' + a +')';
        fb.ctxMask.fillRect(x * 2 - sq - 1, y * 2 - sq - 1, 2, 2);
      });
    /* } */
    // Method #3: vertical DXImageTransform gradient strips (IE).
    /* else {
      var cache_last, cache, w = 6; // Each strip is 6 pixels wide.
      var sizex = Math.floor(size / w);
      // 6 vertical pieces of gradient per strip.
      calculateMask(sizex, 6, function (x, y, c, a) {
        if (x == 0) {
          cache_last = cache;
          cache = [];
        }
        c = Math.round(c * 255);
        a = Math.round(a * 255);
        // We can only start outputting gradients once we have two rows of pixels.
        if (y > 0) {
          var c_last = cache_last[x][0],
              a_last = cache_last[x][1],
              color1 = fb.packDX(c_last, a_last),
              color2 = fb.packDX(c, a),
              y1 = Math.round(fb.mid + ((y - 1) * .333 - 1) * sq),
              y2 = Math.round(fb.mid + (y * .333 - 1) * sq);
          $('<div>').css({
            position: 'absolute',
            filter: "progid:DXImageTransform.Microsoft.Gradient(StartColorStr="+ color1 +", EndColorStr="+ color2 +", GradientType=0)",
            top: y1,
            height: y2 - y1,
            // Avoid right-edge sticking out.
            left: fb.mid + (x * w - sq - 1),
            width: w - (x == sizex ? Math.round(w / 2) : 0)
          }).appendTo(fb.cnvMask);
        }
        cache.push([c, a]);
      });
    } */
    __debug && $('body').append('<div>drawMask '+ (+(new Date()) - tm) +'ms');
  }

  /**
   * Draw the selection markers.
   */
  fb.drawMarkers = function () {
    // Determine marker dimensions
    var lw = Math.ceil(fb.markerSize / 4), r = fb.markerSize - lw + 1;
    var angle = fb.hsl[0] * 6.28,
        x1 =  Math.sin(angle) * fb.radius,
        y1 = -Math.cos(angle) * fb.radius,
        x2 = 2 * fb.square * (.5 - fb.hsl[1]),
        y2 = 2 * fb.square * (.5 - fb.hsl[2]),
        c1 = fb.invert ? '#fff' : '#000',
        c2 = fb.invert ? '#000' : '#fff';
    var circles = [
      { x: x1, y: y1, r: r,             c: '#000', lw: lw + 1 },
      { x: x1, y: y1, r: fb.markerSize, c: '#fff', lw: lw },
      { x: x2, y: y2, r: r,             c: c2,     lw: lw + 1 },
      { x: x2, y: y2, r: fb.markerSize, c: c1,     lw: lw },
    ];

    // Update the overlay canvas.
    fb.ctxOverlay.clearRect(-fb.mid, -fb.mid, fb.ctxOverlay.canvas.width, fb.ctxOverlay.canvas.height);

    for (var i = 0; i < circles.length; i++) {
      var c = circles[i];
      fb.ctxOverlay.lineWidth = c.lw;
      fb.ctxOverlay.strokeStyle = c.c;
      fb.ctxOverlay.beginPath();
      fb.ctxOverlay.arc(c.x, c.y, c.r, 0, Math.PI * 2, true);
      fb.ctxOverlay.stroke();
    }
  }

  /**
   * Update the markers and styles
   */
  fb.updateDisplay = function () {
    // Determine whether labels/markers should invert.
    fb.invert = (fb.rgb[0] * 0.3 + fb.rgb[1] * .59 + fb.rgb[2] * .11) <= 0.6;

    // Update the solid background fill.
    fb.solidFill.css('backgroundColor', fb.pack(fb.HSLToRGB([fb.hsl[0], 1, 0.5])));

    // Draw markers
    fb.drawMarkers();

    // Linked elements or callback
    if (typeof fb.callback == 'object') {
      // Set background/foreground color
      $(fb.callback).css({
        backgroundColor: fb.color,
        color: fb.invert ? '#fff' : '#000'
      });

      // Change linked value
      $(fb.callback).each(function() {
        if ((typeof this.value == 'string') && this.value != fb.color) {
          this.value = fb.color;
        }
      }).change();
    }
    else if (typeof fb.callback == 'function') {
      fb.callback.call(fb, fb.color);
    }
  }

  /**
   * Helper for returning coordinates relative to the center.
   */
  fb.widgetCoords = function (event) {

      var e = event.originalEvent;
      var eX =  e.touches ? e.touches[0].clientX :event.pageX;
      var eY =  e.touches ? e.touches[0].clientY :event.pageY;
      return {
      x: eX - fb.offset.left - fb.mid,
      y: eY - fb.offset.top - fb.mid
    };
  }

  /**
   * Mousedown handler
   */
  fb.mousedown = function (event) {
    // Capture mouse
    if (!$._fuip_farbtastic.dragging) {
        var moveEventType=((document.ontouchmove!==null)?'mousemove':'touchmove');
        var releaseEventType=((document.ontouchend!==null)?'mouseup':'touchend');
      $(document).bind(moveEventType, fb.mousemove).bind(releaseEventType, fb.mouseup);
      $._fuip_farbtastic.dragging = true;
    }

    // Update the stored offset for the widget.
    fb.offset = $(this).offset();

    // Check which area is being dragged
    var pos = fb.widgetCoords(event);
    fb.circleDrag = Math.max(Math.abs(pos.x), Math.abs(pos.y)) > (fb.square + 2);

    // Process
    fb.mousemove(event);
    return false;
  }

  /**
   * Mousemove handler
   */
  fb.mousemove = function (event) {
    // Get coordinates relative to color picker center
    var pos = fb.widgetCoords(event);

    if (!fb.color) fb.setHSL([1,1,1]);

    // Set new HSL parameters
    if (fb.circleDrag) {
      var hue = Math.atan2(pos.x, -pos.y) / 6.28;
      fb.setHSL([(hue + 1) % 1, fb.hsl[1], fb.hsl[2]]);
    }
    else {
      var sat = Math.max(0, Math.min(1, -(pos.x / fb.square / 2) + .5));
      var lum = Math.max(0, Math.min(1, -(pos.y / fb.square / 2) + .5));
      fb.setHSL([fb.hsl[0], sat, lum]);
    }
    return false;
  }

  /**
   * Mouseup handler
   */
  fb.mouseup = function () {
    // Uncapture mouse
    var moveEventType=((document.ontouchmove!==null)?'mousemove':'touchmove');
    var releaseEventType=((document.ontouchend!==null)?'mouseup':'touchend');
    $(document).unbind(moveEventType, fb.mousemove);
    $(document).unbind(releaseEventType, fb.mouseup);
    $._fuip_farbtastic.dragging = false;
    // trigger release event
      console.log('fb.release:',typeof fb.release);
    if (typeof fb.release == 'function') {
        fb.release.call(fb, fb.color);
    }
  }

  /* Various color utility functions */
  fb.dec2hex = function (x) {
    return (x < 16 ? '0' : '') + x.toString(16);
  }

  fb.packDX = function (c, a) {
    return '#' + fb.dec2hex(a) + fb.dec2hex(c) + fb.dec2hex(c) + fb.dec2hex(c);
  };

  fb.pack = function (rgb) {
    var r = Math.round(rgb[0] * 255);
    var g = Math.round(rgb[1] * 255);
    var b = Math.round(rgb[2] * 255);
    return '#' + fb.dec2hex(r) + fb.dec2hex(g) + fb.dec2hex(b);
  };

  fb.unpack = function (color) {
    if (color.length == 7) {
      function x(i) {
        return parseInt(color.substring(i, i + 2), 16) / 255;
      }
      return [ x(1), x(3), x(5) ];
    }
    else if (color.length == 4) {
      function x(i) {
        return parseInt(color.substring(i, i + 1), 16) / 15;
      }
      return [ x(1), x(2), x(3) ];
    }
  };

  fb.HSLToRGB = function (hsl) {
    var m1, m2, r, g, b;
    var h = hsl[0], s = hsl[1], l = hsl[2];
    m2 = (l <= 0.5) ? l * (s + 1) : l + s - l * s;
    m1 = l * 2 - m2;
    return [
      this.hueToRGB(m1, m2, h + 0.33333),
      this.hueToRGB(m1, m2, h),
      this.hueToRGB(m1, m2, h - 0.33333)
    ];
  };

  fb.hueToRGB = function (m1, m2, h) {
    h = (h + 1) % 1;
    if (h * 6 < 1) return m1 + (m2 - m1) * h * 6;
    if (h * 2 < 1) return m2;
    if (h * 3 < 2) return m1 + (m2 - m1) * (0.66666 - h) * 6;
    return m1;
  };

  fb.RGBToHSL = function (rgb) {
    var r = rgb[0], g = rgb[1], b = rgb[2],
        min = Math.min(r, g, b),
        max = Math.max(r, g, b),
        delta = max - min,
        h = 0,
        s = 0,
        l = (min + max) / 2;
    if (l > 0 && l < 1) {
      s = delta / (l < 0.5 ? (2 * l) : (2 - 2 * l));
    }
    if (delta > 0) {
      if (max == r && max != g) h += (g - b) / delta;
      if (max == g && max != b) h += (2 + (b - r) / delta);
      if (max == b && max != r) h += (4 + (r - g) / delta);
      h /= 6;
    }
    return [h, s, l];
  };

  // Parse options.
  if (!options.callback) {
    options = { callback: options };
  }
  options = $.extend({
    width: 300,
    // wheelWidth: (options.width || 300) / 10,
    callback: null,
    release: null,
  }, options);

  // Initialize.
  fb.initWidget();

  // Install mousedown handler (the others are set on the document on-demand)
  var clickEventType=((document.ontouchstart!==null)?'mousedown':'touchstart');
  $('canvas.farbtastic-overlay', container).bind(clickEventType,fb.mousedown);

  // Set linked elements/callback
  if (options.callback) {
    fb.linkTo(options.callback);
  }
  fb.release = options.release;
  // Set to gray.
  //if (!fb.color) fb.setColor('#44bbcc');
 }

})(jQuery);


	
/* FTUI Plugin */

"use strict";

function depends_fuip_colorwheel() {
	var css = $('head').find("[href$='widget_fuip_wdtimer.css']");
	if(!css.length) {
		$('head').append('<link rel="stylesheet" href="' + ftui.config.basedir + 'css/widget_fuip_colorwheel.css" type="text/css" />');
    };
}

var Modul_fuip_colorwheel = function () {

    function onChange(elem, color) {
        elem.find('.colorIndicator').css({
            backgroundColor: color,
        });
    }

    function onRelease(elem, color) {
        ftui.log(2,me.widgetname + ' set color to:' + color);
        var value = (typeof color === 'string') ? color.replace('#', '') : color;
        elem.data('value', value);
        elem.transmitCommand();
    }

    function init_attr(elem) {
        elem.initData('get', 'STATE');
        elem.initData('set', '');
        elem.initData('cmd', 'set');
        elem.initData('width', 150);
        if (elem.hasClass('big')) {
            elem.data('width', 210);
        }
        if (elem.hasClass('large')) {
            elem.data('width', 150);
        }
        if (elem.hasClass('small')) {
            elem.data('width', 100);
        }
        if (elem.hasClass('mini')) {
            elem.data('width', 52);
        }
        elem.initData('mode', 'rgb');
        me.addReading(elem, 'get');
    }

    function init_ui(elem) {
		var colorArea = $(
			'<div class="colorArea">' +
				'<div class = "colorIndicator"></div>' + 
			'</div>');	
		var colorWheel = $('<div class="colorWheel"></div>')
			.css({ width: elem.data('width')})
            .appendTo(colorArea);
        var farbtastic = $.fuip_farbtastic(colorWheel, {
            width: elem.data('width'),
            mode: elem.data('mode'),
            callback: function (color) {
                onChange(elem, color);
            },
            release: function (color) {
                onRelease(elem, color);
            },
        });
		elem.append(colorArea);
        return elem;
    }

    function update(dev, par) {

        me.elements.filterDeviceReading('get', dev, par)
            .each(function (index) {
                var elem = $(this);
                var value = elem.getReading('get').val;
                var color = elem.find('.colorWheel');
                if (value && color) {
                    if (elem.data('isInit')) {
                        $.fuip_farbtastic(color).setColor('#' + value);
                    } else {
                        setTimeout(function () {
                            elem.data('isInit', true);
                            $.fuip_farbtastic(color).setColor('#' + value);
                        }, 2000);
                    }
                }
            });
    }

    // public
    // inherit members from base class
    var me = $.extend(new Modul_widget(), {
        //override members
        widgetname: 'fuip_colorwheel',
        init_ui: init_ui,
        init_attr: init_attr,
        update: update,
    });

    return me;
};


function fuip_colorwheel_resize(id) {
	// called when the widget is resized (this is the idea...)
	// console.log("resize: " + id);	
	// ftui.gridster.instances['html']
	
	var elem = $("#"+id);
	var targetWidth = elem.prop("clientWidth") -10;
	var targetHeight = elem.prop("clientHeight");
	// if this is on a popup (dialog), which has not opened yet, we get negative values
	// we don't need to resize in this case
	if(targetWidth <= 0 || targetHeight <= 0) return;
	// the whole thing is width:height = 3:4
	if(targetWidth * 4 > targetHeight * 3) targetWidth = targetHeight * 3 / 4;
	var colorArea = elem.find(".colorArea");
	colorArea.css("width",targetWidth+10);
	var colorIndicator = elem.find(".colorIndicator");
	var indicatorSize = targetWidth / 3;
	colorIndicator.css({ width: indicatorSize, height: indicatorSize});
	var colorWheel = elem.find(".colorWheel");
	if(!colorWheel) return;
	colorWheel.css("width",targetWidth);
	$.fuip_farbtastic(colorWheel).repaint(targetWidth);
};

fuip_resize_register("fuip-colorwheel",fuip_colorwheel_resize);
