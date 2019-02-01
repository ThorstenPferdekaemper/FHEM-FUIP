
function fuip_label_resize_all() {
	$('[data-fuip-type|="fuip-label"]').each(function() {
		$(this).uniqueId();
		fuip_label_resize($(this).attr("id"));	
	});
};	


function fuip_label_resize(id) {
	// called when the widget is resized (this is the idea...)
	// console.log("resize: " + id);	
	var elem = $("#"+id);
	var targetHeight = elem.prop("clientHeight");
	var size = Math.round(targetHeight * 150 / 25);
	elem.children().css("font-size",size.toString() + "%");
};


$(function() { $(fuip_label_resize_all) });
$(window).on("resize",fuip_label_resize_all);
$(".dialog").on("fadein",function() { setTimeout(fuip_label_resize_all, 20 ) } );  // TODO: not for all of them!	
