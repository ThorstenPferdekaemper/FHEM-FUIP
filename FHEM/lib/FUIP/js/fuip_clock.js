
function fuip_clock_resize(id) {
	// called when the widget is resized (this is the idea...)
	// console.log("resize: " + id);	
	// ftui.gridster.instances['html']
	
	var elem = $("#"+id);
	var targetWidth = elem.prop("clientWidth");
	var targetHeight = elem.prop("clientHeight");
	// aspect ratio is 0,6, normal width is 110, normal height is 31 + 15 + 20 = 66
	// the "20" of the height is fixed
	// (height + 20) * 5 = width *3
	// height = width * 3/5 - 20
	if(targetHeight > targetWidth * 3 / 5) targetHeight = targetWidth * 3 / 5;
	targetHeight -= 20;
	var size = targetHeight * 100 / 46;
	var sizeBig = Math.round(2 * size);  // like 200%
	var sizeSmall = Math.round(size);	// like 100%
	elem.find(":nth-child(1)").css("font-size",sizeBig.toString() + "%");
	elem.find(":nth-child(2)").css("font-size",sizeSmall.toString() + "%");
};

fuip_resize_register("fuip-clock",fuip_clock_resize);
