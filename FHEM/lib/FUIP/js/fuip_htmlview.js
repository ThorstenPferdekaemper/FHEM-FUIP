
function renderHtmlView(html,variables) {
	// replace variables
	// find matches for <fuip-field>...</fuip-field>
	var fieldStrings = html.match(/<fuip-field(.|\s)*?<\/fuip-field>/g);
	// something wrong?
	// TODO: error message or so
	if(!fieldStrings) fieldStrings = [];  // null if no match
	for(var i = 0; i < fieldStrings.length; i++){
		// TODO: The following checks partially mean that a field def was found,
		//		but something is wrong. Maybe proper error message and do not 
		//		change anything
		var fieldDef = $(fieldStrings[i]);
		if(!fieldDef) continue; 
		var id = fieldDef.attr("fuip-name");
		if(!id) continue;
		var value;
		if(variables.hasOwnProperty(id)) {
			value = variables[id];
		}else{
			value = fieldDef.text();
		};		
		html = html.replace(fieldStrings[i],value);
	}; 
	// create DOM node
	// the following is supposed not to break the whole
	// document in case something is wrong
	var elem = document.createElement("div");
	elem.innerHTML = html;
	document.write(elem.innerHTML);
};
