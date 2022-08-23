// general mechanism to properly call resize functions
// the weird file name should make sure that it is loaded before other js files

// fuipType / resizeFunc / initialized
var fuip_resizers = [];

function fuip_resize_all(event) {
	// if this comes up with a fuip-resizable as a target,
	// then this is probably the "early bubbling" of the jquery
	// ui resizable
	if($(event.target).hasClass("fuip-resizable")) 
		return;
	for(var i = 0; i < fuip_resizers.length; i++) {
		if(!fuip_resizers[i].initialized) continue;  // not yet initialized
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
			setTimeout(fuip_resize_init,100);
			// $(fuip_resize_init); // i.e. do it a bit later
			return;
		};	
	};	
	// do we have uninitialized swipers?
	var initialized = true;
	$('[data-type="swiper"]').each(function() {
		if(!$(this).hasClass('swiper-container')) {
			initialized = false;
			return false;
		};	
	});
	if(!initialized) {
		console.log("not initialized - trying later");
		setTimeout(fuip_resize_init,100);
		// $(fuip_resize_init); // i.e. do it a bit later
		return;		
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
	$(".dialog").on("fadein",function(event) {  setTimeout(fuip_resize_all(event), 10 ) } );  // TODO: not for all of them!	
});	


// helpers

function fuip_getTargetDimensions(elem) {
	// search for something with a size
	// is this currently being resized?
	var resize = elem.closest(".fuip-resizable").data("fuipResize");
	if(resize) {
		return { ...resize };
	};	
	// the issue here is that we might sit within a popup widget,
	// which does not really have a size 
	var elemWithSize = elem.parent();  // don't use the table itself
	var targetHeight = 0;
	var targetWidth = 0;
	while(true) {
		// ignore dialog-starter and fuip_popup
		if(elemWithSize.hasClass("dialog-starter") || elemWithSize.data("type") == "fuip_popup") {
			elemWithSize = elemWithSize.parent();
			continue;
		};	
		targetHeight = elemWithSize.prop("clientHeight");
		targetWidth = elemWithSize.prop("clientWidth");
		if(targetHeight && targetWidth) break;  // found
		if(typeof(elemWithSize.attr("data-viewid")) !== "undefined") break; // don't go further than the view container
		elemWithSize = elemWithSize.parent();
	};
	return { height: targetHeight, width: targetWidth };
};


function fuip_getTargetHeight(elem) {
	return fuip_getTargetDimensions(elem).height;
};



