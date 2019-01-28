
function fuip_clock_resize_all() {
	$('[data-fuip-type="fuip-clock"]').each(function() {
		$(this).uniqueId();
		fuip_clock_resize($(this).attr("id"));	
	});
};	


function fuip_clock_resize(id) {
	// called when the widget is resized (this is the idea...)
	// console.log("resize: " + id);	
	var elem = $("#"+id);
	// it seems that the "overflow" needs some help as well
	//if(elem.children("table").outerHeight() > elem.innerHeight()) {
	//	elem.css("overflow","auto");
	//}else{
	//	elem.css("overflow","visible");
	//};	
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


$(function() { $(fuip_clock_resize_all) });
$(window).on("resize",fuip_clock_resize_all);
$(".dialog").on("fadein",function() { setTimeout(fuip_clock_resize_all, 20 ) } );  // TODO: not for all of them!	
