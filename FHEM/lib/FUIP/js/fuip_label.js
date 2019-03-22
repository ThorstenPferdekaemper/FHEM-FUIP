
function fuip_label_resize(id) {
	// called when the widget is resized (this is the idea...)
	// console.log("resize: " + id);	
	var elem = $("#"+id);
	// search for something with a size
	// the issue here is that we might sit within a popup widget,
	// which does not really have a size 
	var elemWithSize = elem;
	var targetHeight = 0;
	while(true) {
		targetHeight = elemWithSize.prop("clientHeight");
		if(targetHeight) break;  // found
		if(typeof(elemWithSize.attr("data-viewid")) !== "undefined") break; // don't go further than the view container
		elemWithSize = elemWithSize.parent();
	};
	var size = Math.round(targetHeight * 150 / 25);
	elem.children().css("font-size",size.toString() + "%");
};

fuip_resize_register("fuip-label-humidity",fuip_label_resize);
fuip_resize_register("fuip-label-temperature",fuip_label_resize);

