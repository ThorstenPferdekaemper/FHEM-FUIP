
function fuip_batteries_resize(id) {
	// called when the widget is resized (this is the idea...)
	// console.log("resize: " + id);	
	var elem = $("#"+id);
	// only if visible, i.e. not on inactive popups
	// otherwise, the sizing will be based on a "zero size" element
	if(elem.is(":hidden")) return;
	// set max text len if not set yet
	if(!elem.attr("data-maxtextlen")){
		var maxtextlen = 0;
		elem.find(".fuip-devname").each(function() {
			if($(this).width() > maxtextlen) maxtextlen = $(this).width();
		});
		elem.attr("data-maxtextlen",maxtextlen + 5);
	};	
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

fuip_resize_register("fuip-batteries",fuip_batteries_resize); 
