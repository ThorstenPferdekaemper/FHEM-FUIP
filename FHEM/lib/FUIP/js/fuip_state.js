
function fuip_state_resize(id) {
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
	// elem has up to 3 children: an icon, the label and the state field itself
	var icon = elem.find("i");
	var label = elem.find("[data-fuip-type='fuip-state-label']");
	var field = elem.find("[data-fuip-type='fuip-state-field']");
	// compute sizes
	// font is 13px, icon is 26px when targetHeight is 48px
	targetHeight -= 2;
	if(targetHeight < 0) targetHeight = 0;
	var lines = elem.data("fuipLines");
	if(lines <= 0) lines = 3;
	if(lines > 6) lines = 6;
	var fontSize = Math.floor(targetHeight * 39 / 46 / lines);  // 13/46 for 3 lines 
	var iconSize = Math.round(targetHeight * 13 / 23);  // 26/46
	icon.css({
		"font-size":iconSize.toString() + "px" 
	});
	label.css({
		"font-size":fontSize.toString() + "px"
	});
	field.css({
		"font-size":fontSize.toString() + "px",
		"overflow":"hidden"
	});
};

fuip_resize_register("fuip-state",fuip_state_resize);

