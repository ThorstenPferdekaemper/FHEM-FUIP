
function fuip_simpleswitch_resize(id) {
	// called when the widget is resized (this is the idea...)
	// console.log("resize: " + id);	
	// ftui.gridster.instances['html']
	
	var elem = $("#"+id);
	
	// only if visible, i.e. not on inactive popups
	// otherwise, the sizing will be based on a "zero size" element
	if(elem.is(":hidden")) return;
	
	var targetDimensions = fuip_getTargetDimensions(elem);
	var targetWidth = targetDimensions.width - 4;
	if(targetWidth < 8) targetWidth = 8;
	var targetHeight = targetDimensions.height - 4;
	if(elem.data('has-label') == 'yes') {
		targetHeight -= 22;
	};	
	if(targetHeight < 8) targetHeight = 8;
	var size = (targetWidth > targetHeight) ? targetHeight : targetWidth;
	size /= 4;	
	
	elem.find('[data-type="switch"]').data("size",size.toString() + "px");
	elem.find('[data-type="switch"]').css("font-size",size.toString() + "px");
};

fuip_resize_register("fuip-simpleswitch",fuip_simpleswitch_resize);

