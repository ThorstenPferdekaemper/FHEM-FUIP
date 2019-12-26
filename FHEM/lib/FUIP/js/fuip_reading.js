
function fuip_reading_resize_multiline(elem) {
	var targetHeight = fuip_getTargetHeight(elem);
	// elem has up to 4 children: an icon, a label, the reading and a timestamp
	var icon = elem.find("i");
	var label = elem.find("[data-fuip-type='fuip-reading-label']");
	var reading = elem.find("[data-fuip-type='fuip-reading-reading']");
	var timestamp = elem.find("[data-fuip-type='fuip-reading-timestamp']");
	var lines = 0;
	if(label.length) lines++;
	if(reading.length) lines++;
	if(timestamp.length) lines++;
	// it should not happen, but avoid div by 0
	if(!lines) lines = 1;
	// compute sizes
	// font is 13px, icon is 26px when targetHeight is 48px
	targetHeight -= 2;
	if(targetHeight < 0) targetHeight = 0;
	var fontSize = Math.floor(targetHeight * 39 / 46 / lines);  // 13/46 for 3 lines 
	var iconSize = Math.round(targetHeight * 13 / 23);  // 26/46
	icon.css({
		"font-size":iconSize.toString() + "px" 
	});
	label.css({
		"font-size":fontSize.toString() + "px",
		"overflow":"hidden"
	});
	reading.css({
		"font-size":fontSize.toString() + "px",
		"overflow":"hidden"
	});
	timestamp.css({
		"font-size":fontSize.toString() + "px",
		"overflow":"hidden"
	});
};


function fuip_reading_resize_singleline(elem) {
	var targetHeight = fuip_getTargetHeight(elem);
	var size = Math.round(targetHeight * 6);
	elem.children().css("font-size",size.toString() + "%");
};


function fuip_reading_resize(id) {
	// called when the widget is resized (this is the idea...)
	var elem = $("#"+id);
	if(elem.hasClass("fuip-multiline")) {
		fuip_reading_resize_multiline(elem);
	}else{
		fuip_reading_resize_singleline(elem); 
	};
};
	
	
fuip_resize_register("fuip-reading",fuip_reading_resize); 

