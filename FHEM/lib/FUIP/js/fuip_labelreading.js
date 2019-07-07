
function fuip_labelreading_resize(id) {
	// called when the widget is resized (this is the idea...)
	// console.log("resize: " + id);	
	var elem = $("#"+id);
	// search for something with a size
	// the issue here is that we might sit within a popup widget,
	// which does not really have a size 
	var elemWithSize = elem.parent();  // don't use the table itself
	var targetHeight = 0;
	while(true) {
		targetHeight = elemWithSize.prop("clientHeight");
		if(targetHeight) break;  // found
		if(typeof(elemWithSize.attr("data-viewid")) !== "undefined") break; // don't go further than the view container
		elemWithSize = elemWithSize.parent();
	};
	// elem has up to 4 children: an icon, a label, the reading and a timestamp
	var icon = elem.find("i");
	var label = elem.find("[data-fuip-type='fuip-labelreading-label']");
	var reading = elem.find("[data-fuip-type='fuip-labelreading-reading']");
	var timestamp = elem.find("[data-fuip-type='fuip-labelreading-timestamp']");
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

fuip_resize_register("fuip-labelreading",fuip_labelreading_resize);

