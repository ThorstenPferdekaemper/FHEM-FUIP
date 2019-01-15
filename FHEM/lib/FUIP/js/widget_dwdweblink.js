/* FTUI Plugin
** Zusammenkopiert von Thorsten Pferdekaemper 2019
 */

"use strict";

var Modul_dwdweblink = function () {

    function init_attr(elem) {
        elem.initData('get', 'STATE');
        elem.initData('max-update', 60);

        me.addReading(elem, 'get');
    }

    function update(dev, par) {

        me.elements.filterDeviceReading('get', dev, par)
            .each(function (index) {
                var elem = $(this);
                var value = elem.getReading('get').val;
                if (ftui.isValid(value)) {
                    var dNow = new Date();

                    var lUpdate = elem.data('lastUpdate') || null;
                    var lMaxUpdate = parseInt(elem.data('max-update'));
                    if (isNaN(lMaxUpdate) || (lMaxUpdate < 1))
                        lMaxUpdate = 10;
                    lUpdate = (((dNow - lUpdate) / 1000) > lMaxUpdate) ? null : lUpdate;
                    if (lUpdate === null) {
                        elem.data('lastUpdate', dNow);
                        var cmd = [ 'get', elem.data('device'), "horizontalForecast" ].join(' ');
                        ftui.log('dwdweblink update', dev, ' - ', cmd);                  
                        ftui.sendFhemCommand(cmd)
                            .done(function (data, dev) {
							data = '<link rel="stylesheet" href="' + ftui.config.basedir + 'css/widget_dwdweblink.css" type="text/css" />'
									+ data;
                            elem.html(data);
                        });
                    }
                }
            });
    }

    // public
    // inherit all public members from base class
    var me = $.extend(new Modul_widget(), {
        //override or own public members
        widgetname: 'dwdweblink',
        init_attr: init_attr,
        update: update,
    });

    return me;
};

