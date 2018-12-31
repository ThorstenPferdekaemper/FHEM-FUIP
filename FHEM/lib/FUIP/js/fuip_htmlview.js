
function renderHtmlView(html,variables) {
	// replace variables
	// find matches for <fuip-field>...</fuip-field>
	let fieldStrings = html.match(/<fuip-field.*?<\/fuip-field>/g);
	// something wrong?
	// TODO: error message or so
	if(!fieldStrings) fieldStrings = [];  // null if no match
	for(let fieldString of fieldStrings){
		// TODO: The following checks partially mean that a field def was found,
		//		but something is wrong. Maybe proper error message and do not 
		//		change anything
		let fieldDef = $(fieldString);
		if(!fieldDef) continue;
		let id = fieldDef.attr("fuip-name");
		if(!id) continue;
		if(!variables.hasOwnProperty(id)) continue;
		html = html.replace(fieldString,variables[id]);
	}; 
	// create DOM node
	// the following is supposed not to break the whole
	// document in case something is wrong
	let elem = document.createElement("div");
	elem.innerHTML = html;
	document.write(elem.innerHTML);
};
