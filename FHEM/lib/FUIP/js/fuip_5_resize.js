// general mechanism to properly call resize functions
// the weird file name should make sure that it is loaded before other js files

// fuipType / resizeFunc / initialized
var fuip_resizers = [];

function fuip_resize_all() {
	for(var i = 0; i < fuip_resizers.length; i++) {
		$('[data-fuip-type="' + fuip_resizers[i].fuipType + '"]').each(function() {
			fuip_resizers[i].resizeFunc($(this).attr("id"));	
		});
	};
};	


function fuip_resize_init() {
	// we need to "wait" until FTUI has configured gridster, if layout is gridster
	if($(".gridster").length) {
		// gridster
		if(!ftui.gridster.instances['html']) {
			$(fuip_resize_init); // i.e. do it a bit later
			return;
		};	
	};	
	// now really do it
	for(var i = 0; i < fuip_resizers.length; i++) {
		if(fuip_resizers[i].initialized) continue;  // already done
		$('[data-fuip-type="' + fuip_resizers[i].fuipType + '"]').each(function() {
			$(this).uniqueId();
			fuip_resizers[i].resizeFunc($(this).attr("id"));	
		});
		fuip_resizers[i].initialized = true;
	};
};	


function fuip_resize_register(fuipType,resizeFunc) {
	fuip_resizers.push({fuipType: fuipType, resizeFunc: resizeFunc, initialized: false});
	$(fuip_resize_init);
};

// register resize events
$(window).on("resize",fuip_resize_all);
$(function() {
	$(".dialog").on("fadein",function() {  setTimeout(fuip_resize_all, 10 ) } );  // TODO: not for all of them!	
});	

