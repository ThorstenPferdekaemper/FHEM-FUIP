/* FTUI/FUIP Plugin
 * Thorsten Pferdekaemper 
 *    with lots of credits to
 * Mario Stephan <mstephan@shared-files.de>
 * Under MIT License (http://www.opensource.org/licenses/mit-license.php)
 */
 
 /* 
	special select widget for numeric values (maybe a bit optimized for shutters)
	A list of n Alias names like [Open, 10%, 20%, 30% ..., 90%, Closed] 
	is mapped to n values of the device. If the device value falls in between two 
	values from the list, the closer one is displayed. If it is just in the middle, 
	the first (of the two) in the list is used.
	
	Parameters:
		alias: the list of values to display (e.g. the list shown above)
		items: the list of "internal" values (e.g. [0,10,20,...,100])
		get, set, cmd: like in the FTUI select widget	
 */
 

"use strict";

var Modul_fuip_numselect = function () {

    function fillList(elem) {
        var select_elem = elem.find('select');
        if (select_elem) {
            var items = elem.data('items') || '';
            var alias = elem.data('alias') || elem.data('items');
            select_elem.empty();
            for (var i = 0, len=items.length; i < len; i++) {
                select_elem.append('<option value="' + items[i] + '">' + (alias && alias[i] || items[i]) + '</option>');
            }
        }
    }

    function setCurrentItem(elem) {
		
		function getValue(elem) {
			var value = elem.getReading('get').val;
			// find the closest value from the list
			// the following might not look very smart, but there should not
			// be that many entries after all
			var items = elem.data('items') || false;
			// don't do anything if we don't have any items
			if(!items) return value;
			var len = items.length;
			// if there is only one entry...
			if(len == 1) return items[0];
			len--;
			for (var i = 0; i < len; i++) {
				if(items[i] < items[i+1]) {
					if(value > items[i+1]) continue;
				}else{
					if(value < items[i+1]) continue;
				};	
				// now we know that value is in between the two
				// decide which of the two
				if(Math.abs(value - items[i+1]) < Math.abs(value - items[i])){
					return items[i+1];
				}else{
					return items[i];
				};	
			};
			// if we come here, we haven't found it. I.e. must be "behind" the whole list
			return items[len];
		};	
		
		
        var value = getValue(elem);
        elem.find('select').val(value);
        elem.data('value', value);
    }

	
    function init_attr(elem) {
        elem.initData('get', 'STATE');
        elem.initData('set', ((elem.data('get') !== 'STATE') ? elem.attr('data-get') : ''));
        elem.initData('cmd', 'set');     
        elem.initData('color', ftui.getClassColor(elem) || ftui.getStyle('.' + me.widgetname, 'color') || '#222');
        elem.initData('background-color', ftui.getStyle('.' + me.widgetname, 'background-color') || 'transparent');
        elem.initData('text-color', ftui.getStyle('.' + me.widgetname, 'text-color') || '#ddd');
        elem.initData('width', '100%');
        elem.initData('height', '100%');
        elem.initData('delay', 1000);

        me.addReading(elem, 'get');
		
		// if hide reading is defined, set defaults for comparison
        if (elem.isValidData('hide')) {
            elem.initData('hide-on', 'true|1|on');
        }
        elem.initData('hide', elem.data('get'));
        if (elem.isValidData('hide-on')) {
            elem.initData('hide-off', '!on');
        }
        me.addReading(elem, 'hide');
    }

    function init_ui(elem) {
        // prepare select element
        elem.addClass('select');
        var wrap_elem = $('<div/>', {}).addClass('select_wrapper').appendTo(elem);
        var select_elem = $('<select/>', {})
            .on('change', function (e) {
                var value = $("option:selected", this).val();
                elem.data('value', value);
                $(this).blur();
                elem.transmitCommand();
                elem.trigger('changedValue');
            })
            .attr('size',elem.data('size'))
            .appendTo(wrap_elem);
        fillList(elem);
        elem.data('value', $("option:selected", select_elem).val());
    }

    function update(dev, par) {
        // update from normal state reading
        me.elements.filterDeviceReading('get', dev, par)
            .each(function (index) {
                me.setCurrentItem($(this));
            });

		//extra reading for hide
        me.update_hide(dev, par);
    }

    // public
    // inherit all public members from base class
    var me = $.extend(new Modul_widget(), {
        //override or own public members
        widgetname: 'fuip_numselect',
        init_attr: init_attr,
        init_ui: init_ui,
        update: update,
        fillList: fillList,
        setCurrentItem: setCurrentItem
    });

    return me;
};