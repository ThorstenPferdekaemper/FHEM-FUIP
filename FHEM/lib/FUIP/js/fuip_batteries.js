
function fuip_batteries_resize_all() {
	$('[data-fuip-type="fuip-batteries"]').each(function() {
		$(this).uniqueId();
		if(!$(this).attr("data-maxtextlen")){
			var maxtextlen = 0;
			$(this).find(".fuip-devname").each(function() {
				if($(this).width() > maxtextlen) maxtextlen = $(this).width();
			});
			$(this).attr("data-maxtextlen",maxtextlen + 5);
		};	
		fuip_batteries_resize($(this).attr("id"));	
	});
};	


function fuip_batteries_resize(id) {
	// called when the widget is resized (this is the idea...)
	// console.log("resize: " + id);	
	var elem = $("#"+id);
	// it seems that the "overflow" needs some help as well
	if(elem.children("table").outerHeight() > elem.innerHeight()) {
		elem.css("overflow","auto");
	}else{
		elem.css("overflow","visible");
	};	
	// determine how big one element should be
	var targetWidth = elem.prop("clientWidth");
	// var targetHeight = elem.height();
	// get size of the tables
	var numTabs = 0;
	var innerHeight = 0;
	elem.find("table").each(function() {
		numTabs++;
	});
	if(numTabs <= 1) return;
	numTabs--;
	var tabWidth = 138 * numTabs + 25 * (numTabs -1);
	var textWidth = Math.floor((targetWidth - tabWidth) / numTabs);
	if(textWidth < 40){
		textWidth = 40;
	}else if(textWidth > elem.attr("data-maxtextlen")) 
		textWidth = elem.attr("data-maxtextlen");	
	elem.find(".fuip-devname").width(textWidth);
};


$(function() { $(fuip_batteries_resize_all) });
$(window).on("resize",fuip_batteries_resize_all);
$(".dialog").on("fadein",function() { setTimeout(fuip_batteries_resize_all, 250 ) } );  // TODO: not for all of them!	
