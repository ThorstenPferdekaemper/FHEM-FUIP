
function fuip_label_resize(id) {
	// called when the widget is resized (this is the idea...)
	// console.log("resize: " + id);	
	var elem = $("#"+id);
	var targetHeight = elem.prop("clientHeight");
	var size = Math.round(targetHeight * 150 / 25);
	elem.children().css("font-size",size.toString() + "%");
};

fuip_resize_register("fuip-label-humidity",fuip_label_resize);
fuip_resize_register("fuip-label-temperature",fuip_label_resize);

