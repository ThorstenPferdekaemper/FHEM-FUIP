"use strict";

var Modul_7segment = function () {
    var items = [];

    // Definition of segments per number 0-9. Index 10 is "-"
    const number_segments = [
        ["a", "b", "c", "d", "e", "f"],
        ["b", "c"],
        ["a", "b", "g", "e", "d"],
        ["a", "b", "c", "d", "g"],
        ["b", "c", "f", "g"],
        ["a", "c", "d", "f", "g"],
        ["a", "c", "d", "e", "f", "g"],
        ["a", "b", "c"],
        ["a", "b", "c", "d", "e", "f", "g"],
        ["a", "b", "c", "d", "f", "g"],
        ["g"]
    ];

    function init() {
        console.log("init")
        me.elements = $('div[data-type="' + me.widgetname + '"]', me.area);
        me.elements.each(function (index) {

            console.log("init widget 7segment index " + index);

            var elem = $(this);
            items.push({ myID: uuidv4() })
            items[index].idx = index;
            items[index].oldvalues = {};
            items[index].limits = [];
            items[index].limit_colors = [];

            elem.initData('color-fg', 'red');
            items[index].fgcolor = getFtuiColor(elem.data('color-fg'));
            elem.initData('color-bg', ftui.getStyle('.card', 'background-color') || '#2A2A2A');
            items[index].bgcolor = elem.data('color-bg');

            elem.initData('view', '');
            if (elem.data('view') == "clock4" || elem.data('view') == "clockview4") {
                items[index].clockmode = 4;
                items[index].no_digits = 4;
                items[index].decimals = 2;
            } else if (elem.data('view') == "clock6" || elem.data('view') == "clockview6") {
                items[index].clockmode = 6;
                items[index].no_digits = 6;
                items[index].decimals = 2;
            } else {
                elem.initData('digits', '5');
                items[index].no_digits = elem.data('digits');
                elem.initData('decimals', '0');
                items[index].decimals = elem.data('decimals');

                elem.initData('limits', '');
                var limits = (elem.data('limits') != "") ? elem.data('limits') : []

                limits.forEach(function (item) {
                    items[index].limits.push(parseFloat(item));
                });
                elem.initData('limit-colors', '');
                items[index].limit_colors = (elem.data('limit-colors') != "") ? elem.data('limit-colors') : []

                console.log(items[index].limits);
                console.log(items[index].limit_colors);

                // if less colors than limits - fill colors with fg color
                while (items[index].limit_colors.length < items[index].limits.length) {
                    items[index].limit_colors.push(items[index].fgcolor);
                }

                // Device reading for value
                if (elem.isDeviceReading('get-value')) {
                    me.addReading(elem, 'get-value');
                }
            }

            createDigitArray(index);
            items[index].svgobj = createSVG(index, elem);

            if (items[index].clockmode > 0) {
                items[index].clockinterval = setInterval(function clock() {
                    var d = new Date();
                    var timestring = "" + d.getHours() + d.getMinutes().toString().padStart(2, "0");
                    timestring = items[index].clockmode === 6 ? timestring + d.getSeconds().toString().padStart(2, "0") : timestring;
                    setString(index, timestring);
                    return clock;
                }(), 500);
            }

        });
    }

    function update(device, reading) {
        me.elements.each(function (index) {
            var elem = $(this);

            if (elem.matchDeviceReading('get-value', device, reading)) {
                var value = elem.getReading('get-value').val
                if (items[index].oldvalues['get-value'] !== value) {
                    setColor(index, value);
                    setNumber(index, value);
                    items[index].oldvalues['get-value'] = value;
                }
            }

        });
    }

    function getFtuiColor(color) {
        return ftui.getStyle('.' + color, 'color') || color;
    }

    function setColor(itm_index, value) {
        var _value = parseFloat(value);
        for (var i = items[itm_index].limits.length - 1; i > -1; i--) {
            if (_value >= items[itm_index].limits[i]) {
                setDPColor(itm_index, getFtuiColor(items[itm_index].limit_colors[i]));
                for (var j = 0; j < items[itm_index].no_digits; j++) {
                    var g = items[itm_index].svgobj.getElementById("digit" + j);
                    g.setAttribute("fill", getFtuiColor(items[itm_index].limit_colors[i]));
                }
                return;
            }
        }
        // no matches in limits
        setDPColor(itm_index, items[itm_index].fgcolor);
        for (var j = 0; j < items[itm_index].no_digits; j++) {
            var g = items[itm_index].svgobj.getElementById("digit" + j);
            g.setAttribute("fill", getFtuiColor(items[itm_index].fgcolor));
        }
    }

    function setDPColor(itm_index, color) {
        if ((items[itm_index].decimals == 1 && items[itm_index].no_digits >= 2) || (items[itm_index].decimals == 2 && items[itm_index].no_digits >= 3)) {
            if (items[itm_index].clockmode === 4) {
                var dp = items[itm_index].svgobj.getElementById("dp1");
                dp.setAttribute("fill", color);
                dp = items[itm_index].svgobj.getElementById("dp2");
                dp.setAttribute("fill", color);
            } else {
                var dp = items[itm_index].svgobj.getElementById("dp1");
                dp.setAttribute("fill", color);
            }
        }
    }

    function setDigit(index, digit, value, justclear) {
        var _digitsegments = items[index].digit_number_segments[digit];
        var segments = _digitsegments[8];
        segments.forEach(function (item) {
            var segment = items[index].svgobj.getElementById(item);
            segment.setAttribute("fill-opacity", "0.05");
        });

        if (justclear || value == -1) return;

        segments = _digitsegments[value]
        segments.forEach(function (item) {
            var segment = items[index].svgobj.getElementById(item)
            segment.setAttribute("fill-opacity", "1");
        });
    }

    function setString(itm_index, value) {
        var numbers = [];
        // fill with spaces
        for (var i = 0; i < items[itm_index].no_digits; i++) {
            numbers.push(-1);
        }

        // read value backwards into array
        for (var i = 0; i < items[itm_index].no_digits && i < value.length; i++) {
            numbers[i] = parseInt(value.charAt(value.length - 1 - i));
        }

        numbers.forEach(function (item, index) {
            setDigit(itm_index, index, item);
        });
    }

    function setNumber(itm_index, value) {
        var numbers = [];
        for (var i = 0; i < items[itm_index].no_digits; i++) {
            numbers.push(-1);
        }
        var number = parseFloat(value)
        var isnegative = number < 0 ? true : false;
        number = isnegative ? number * -1 : number;
        if (items[itm_index].decimals == 2) {
            number = parseFloat(Math.round(number * 100) / 100).toFixed(2);
        } else if (items[itm_index].decimals == 1) {
            number = parseFloat(Math.round(number * 10) / 10).toFixed(1);
        } else {
            number = parseInt(number);
        }
        number = "" + number;
        number = number.replace(".", "");

        for (var i = 0; i < items[itm_index].no_digits; i++) {
            if (number.length > i) {
                numbers[i] = parseInt(number.charAt(number.length - 1 - i));
            } else {
                numbers[i] = isnegative ? 10 : -1;
                numbers.forEach(function (item, index) {
                    setDigit(itm_index, index, item);
                });
                return
            }
        }
        numbers.forEach(function (item, index) {
            setDigit(itm_index, index, item);
        });
    }

    function createSVG(index, elem) {

        var id = items[index].myID;

        var xmlns = "http://www.w3.org/2000/svg";
        var boxWidth;
        if (items[index].clockmode === 4) {
            boxWidth = (11 * items[index].no_digits) + 4;
        } else if (items[index].clockmode === 6) {
            boxWidth = (11 * items[index].no_digits) + 6;
        } else {
            boxWidth = (11 * items[index].no_digits) + 2;
        }

        var boxHeight = 18;

        var svgElem = document.createElementNS(xmlns, "svg");
        svgElem.setAttributeNS(null, "viewBox", "0 0 " + boxWidth + " " + boxHeight);
        svgElem.setAttributeNS(null, "id", id);
        //svgElem.setAttributeNS(null, "width", boxWidth);
        //svgElem.setAttributeNS(null, "height", boxHeight);
        svgElem.style.display = "block";

        var r = document.createElementNS(xmlns, "rect");
        r.style.fill = items[index].bgcolor;
        r.style.width = "100%";
        r.style.height = "100%";
        svgElem.appendChild(r);

        for (var i = 0; i < items[index].no_digits; i++) {
            var g = document.createElementNS(xmlns, "g");

            if (items[index].clockmode > 0 && (i == 2 || i == 3)) {
                g.setAttributeNS(null, "transform", "translate(" + ((boxWidth - ((i + 1) * 11)) - 2) + ",0) skewX(-5)");
            } else if (items[index].clockmode === 6 && (i == 4 || i == 5)) {
                g.setAttributeNS(null, "transform", "translate(" + ((boxWidth - ((i + 1) * 11)) - 4) + ",0) skewX(-5)");
            } else {
                g.setAttributeNS(null, "transform", "translate(" + (boxWidth - ((i + 1) * 11)) + ",0) skewX(-5)");
            }

            g.setAttributeNS(null, "id", "digit" + i);
            g.setAttributeNS(null, "fill", items[index].fgcolor);
            g.setAttributeNS(null, "style", "fill-rule:evenodd; stroke:" + items[index].bgcolor + "; stroke-width:0.25; stroke-opacity:1; stroke-linecap:butt; stroke-linejoin:miter;");

            var p = document.createElementNS(xmlns, "polygon");
            p.setAttributeNS(null, "id", i + "a");
            p.setAttributeNS(null, "points", " 1, 1  2, 0  8, 0  9, 1  8, 2  2, 2");
            g.appendChild(p);

            p = document.createElementNS(xmlns, "polygon");
            p.setAttributeNS(null, "id", i + "b");
            p.setAttributeNS(null, "points", " 9, 1 10, 2 10, 8  9, 9  8, 8  8, 2");
            g.appendChild(p);

            p = document.createElementNS(xmlns, "polygon");
            p.setAttributeNS(null, "id", i + "c");
            p.setAttributeNS(null, "points", " 9, 9 10,10 10,16  9,17  8,16  8,10");
            g.appendChild(p);

            p = document.createElementNS(xmlns, "polygon");
            p.setAttributeNS(null, "id", i + "d");
            p.setAttributeNS(null, "points", " 9,17  8,18  2,18  1,17  2,16  8,16");
            g.appendChild(p);

            p = document.createElementNS(xmlns, "polygon");
            p.setAttributeNS(null, "id", i + "e");
            p.setAttributeNS(null, "points", " 1,17  0,16  0,10  1, 9  2,10  2,16");
            g.appendChild(p);

            p = document.createElementNS(xmlns, "polygon");
            p.setAttributeNS(null, "id", i + "f");
            p.setAttributeNS(null, "points", " 1, 9  0, 8  0, 2  1, 1  2, 2  2, 8");
            g.appendChild(p);

            p = document.createElementNS(xmlns, "polygon");
            p.setAttributeNS(null, "id", i + "g");
            p.setAttributeNS(null, "points", " 1, 9  2, 8  8, 8  9, 9  8,10  2,10");
            g.appendChild(p);

            svgElem.appendChild(g);
        }

        if (items[index].clockmode === 4) {
            var c = document.createElementNS(xmlns, "circle");
            c.setAttributeNS(null, "r", "1");
            c.setAttributeNS(null, "cx", (boxWidth - (items[index].decimals * 11) - 2.6));
            c.setAttributeNS(null, "cy", boxHeight - (boxHeight / 3));
            c.setAttributeNS(null, "fill", items[index].fgcolor);
            c.setAttributeNS(null, "id", "dp1");
            svgElem.appendChild(c);
            c = document.createElementNS(xmlns, "circle");
            c.setAttributeNS(null, "r", "1");
            c.setAttributeNS(null, "cx", (boxWidth - (items[index].decimals * 11) - 1.9));
            c.setAttributeNS(null, "cy", (boxHeight / 3));
            c.setAttributeNS(null, "fill", items[index].fgcolor);
            c.setAttributeNS(null, "id", "dp2");
            svgElem.appendChild(c);
        } else if (items[index].clockmode === 6) {
            var c = document.createElementNS(xmlns, "circle");
            c.setAttributeNS(null, "r", "1");
            c.setAttributeNS(null, "cx", (boxWidth - (items[index].decimals * 11) - 2.6));
            c.setAttributeNS(null, "cy", boxHeight - (boxHeight / 3));
            c.setAttributeNS(null, "fill", items[index].fgcolor);
            c.setAttributeNS(null, "id", "dp1");
            svgElem.appendChild(c);
            c = document.createElementNS(xmlns, "circle");
            c.setAttributeNS(null, "r", "1");
            c.setAttributeNS(null, "cx", (boxWidth - (items[index].decimals * 11) - 1.9));
            c.setAttributeNS(null, "cy", (boxHeight / 3));
            c.setAttributeNS(null, "fill", items[index].fgcolor);
            c.setAttributeNS(null, "id", "dp2");
            svgElem.appendChild(c);
            var c = document.createElementNS(xmlns, "circle");
            c.setAttributeNS(null, "r", "1");
            c.setAttributeNS(null, "cx", (boxWidth - ((items[index].decimals + 2) * 11) - 4.6));
            c.setAttributeNS(null, "cy", boxHeight - (boxHeight / 3));
            c.setAttributeNS(null, "fill", items[index].fgcolor);
            c.setAttributeNS(null, "id", "dp3");
            svgElem.appendChild(c);
            c = document.createElementNS(xmlns, "circle");
            c.setAttributeNS(null, "r", "1");
            c.setAttributeNS(null, "cx", (boxWidth - ((items[index].decimals + 2) * 11) - 3.9));
            c.setAttributeNS(null, "cy", (boxHeight / 3));
            c.setAttributeNS(null, "fill", items[index].fgcolor);
            c.setAttributeNS(null, "id", "dp4");
            svgElem.appendChild(c);
        } else {
            if ((items[index].decimals == 1 && items[index].no_digits >= 2) || (items[index].decimals == 2 && items[index].no_digits >= 3)) {
                var c = document.createElementNS(xmlns, "circle");
                c.setAttributeNS(null, "r", "1");
                c.setAttributeNS(null, "cx", (boxWidth - (items[index].decimals * 11) - 1.9));
                c.setAttributeNS(null, "cy", boxHeight - 1.1);
                c.setAttributeNS(null, "fill", items[index].fgcolor);
                c.setAttributeNS(null, "id", "dp1");
                svgElem.appendChild(c);
            }
        }

        $(svgElem).appendTo(elem);
        return document.getElementById(id);
    }

    function createDigitArray(itm_index) {
        items[itm_index].digit_number_segments = [];
        for (var i = 0; i < items[itm_index].no_digits; i++) {
            var digarray = [];
            number_segments.forEach(function (item) {
                var subitems = [];
                item.forEach(function (subitem) {
                    subitems.push(i + subitem);
                });
                digarray.push(subitems);
            });
            items[itm_index].digit_number_segments.push(digarray);
        }
    }

    function uuidv4() {
        return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, function (c) {
            var r = Math.random() * 16 | 0, v = c == 'x' ? r : (r & 0x3 | 0x8);
            return v.toString(16);
        });
    }

    function init_ui(elem) { }

    function init_attr(elem) { }

    var me = $.extend(new Modul_widget(), {
        widgetname: '7segment',
        init: init,
        update: update,
        init_attr: init_attr,
        init_ui: init_ui
    });

    return me;
}