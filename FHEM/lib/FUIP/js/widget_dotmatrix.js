
"use strict";

var Modul_dotmatrix = function () {

	var namespace = "http://www.w3.org/2000/svg";
	var code = {};  

    function init_attr(elem) {

        //init standard attributes
        _base.init_attr.call(me, elem);

        elem.initData('columns', '60');
		elem.initData('rows', '8');
		elem.initData('shape', 'circle'); // or square
		elem.initData('color', '#00FF00');
		elem.initData('text', '');

		me.addReading(elem, 'get-color');

    }


	function createDotCircle(elem,col,row) {
		var circle = document.createElementNS(namespace, "circle");
		circle.setAttribute("cx", 10 + col*20);
		circle.setAttribute("cy", 10 + row*20);
		circle.setAttribute("r", 9);
		circle.setAttribute("fill",elem.data('color'));
		circle.setAttribute("fill-opacity", "0.05");
		return circle;
	};
	
	
	function createDotSquare(elem,col,row) {
		var dot = document.createElementNS(namespace, "rect");
		dot.setAttribute("x", col*20);
		dot.setAttribute("y", row*20);
		dot.setAttribute("width", 16);
		dot.setAttribute("height", 16);
		dot.setAttribute("fill",elem.data('color'));
		dot.setAttribute("fill-opacity", "0.05");
		return dot;
	};
	
	
	function createDot(elem,col,row) {
		if(elem.data('shape') == 'square') {
		    return createDotSquare(elem,col,row);
		}else{
		    return createDotCircle(elem,col,row);
		};	
	};	


	function createPanel(elem, numCols, numRows) {
		var dots = [];
		var svg = document.createElementNS(namespace, "svg");
		svg.setAttribute("viewBox", "0 0 " + 20 * numCols + " " + 20 * numRows);
		svg.style.position = 'absolute';
		svg.style.left = '0'; 
		svg.style.top = '0';  //width:100%; height:100%
		elem.append(svg);
		for(var yi = 0; yi < numRows; yi++) {
			dots[yi] = [];
			for(var xi = 0; xi < numCols; xi++) {
				dots[yi][xi] = createDot(elem,xi,yi);
				svg.appendChild(dots[yi][xi]);
			};	
		};
		elem.data('dots',dots);
	};


    function init_ui(elem) {
		createPanel(elem, elem.data('columns'), elem.data('rows'));
		setString(elem,elem.data('text'));
    };


	function getValue(elem,parameter,device,reading) {
		if (!elem.matchDeviceReading(parameter,device,reading)) return null;
        var value = elem.getReading(parameter).val;
        if (value === undefined || value === null) return null;
        return value;
	};


	function writeChar(elem, c, pos) {
		var dots = elem.data('dots');
		var codePoint = code[c];
		if(!codePoint) codePoint = code['#'];
		// determine row and col in grid
		var gridRow = Math.trunc(pos / dots[0].length) * 8;
		var gridCol = pos % dots[0].length; 
		var mask = 0b100000;
		for(var col = 0; col < 6; col++) {
			if(col + gridCol >= dots[0].length) {
				gridRow += 8;
				gridCol = 0 - col;
			};	
			for(var row = 0; row < 7; row++) {
				if(col + gridCol >= 0 && col + gridCol < dots[row].length
					&& row + gridRow >= 0 && row + gridRow < dots.length ) {
					if(codePoint[row] & mask) {
						dots[row + gridRow][col + gridCol].setAttribute("fill-opacity", 1);
					}else{
						dots[row + gridRow][col + gridCol].setAttribute("fill-opacity", 0.05);
					};
				};
			};
			mask = mask >> 1;
		};	
	};
	
	
	function writeString(elem,s,pos) {
		// determine max number of characters
		var dots = elem.data('dots');
		// number of rows where a character can at least begin
		var charRows = Math.ceil(dots.length / 8); 
		// total number of columns
		var columns = dots[0].length * charRows;
		// maximum number of characters which can at least begin
		var maxChars = Math.ceil(columns / 6) + 1;
		
		var begin = Math.trunc(pos / 6);
		if(begin >= s.length){
			// TODO: remove everything?
			return;
		};	
		var end = begin + maxChars;   
		for(var i = begin; i < end; i++) {
			if(i >= s.length) {
				if(elem.data('scrolling')) {
				    writeChar(elem,s.charAt(i - s.length),i * 6 - pos);
				}else{	
					writeChar(elem,' ',i * 6 - pos);
				};	
			}else{
				writeChar(elem,s.charAt(i),i * 6 - pos);
			};	
		};
	};
	
	
	function setString(elem,s) {

		// in any case, we write the string
		// TODO: really? maybe we should only if it changes
		writeString(elem,s,0);

		// do we need scrolling?
		// determine max number of characters
		var dots = elem.data('dots');
		// number of complete rows
		var charRows = Math.floor(dots.length / 8); 
		// number of complete columns
		var charCols = Math.floor(dots[0].length / 6);
		// maximum number of characters which fit completely
		var maxChars = charRows * charCols;
		
		if(s.length <= maxChars) {
			elem.data('scrolling',false);
		    return;
		};

		// enable scrolling
		elem.data('currString',s + "   ");
		elem.data('currPos',0);	
		elem.data('scrolling',true);
		elem.data('scrollStart',0);
		window.requestAnimationFrame(scroll);
	};	
	
	
	var nexttimestamp = null;
		
	function scroll(timestamp) {

		if(!nexttimestamp) {
			nexttimestamp = timestamp;	
		}else if(timestamp < nexttimestamp) {
			window.requestAnimationFrame(scroll);
			return;
		};	
	
		nexttimestamp += 100;
		//If the current timestamp is still "later" than the next
		//requested time, then we are really a bit late and should
		//use the current timestamp. This can e.g. happen when the
		//page has not been visible for a while
		if(nexttimestamp < timestamp) {
			nexttimestamp = timestamp + 100;
		};	

		me.elements.each(function (index) {
            var elem = $(this);
			if(!elem.data('scrolling')) return;

			if(!elem.data('scrollStart')) {
				elem.data('scrollStart',timestamp + 2500);
				return;
			};
			if(timestamp < elem.data('scrollStart')) return;
			
			var currPos = elem.data('currPos');
			var currString = elem.data('currString');
			writeString(elem,currString,currPos);
			
			if(currPos / 6 < currString.length) {
				currPos++;
			}else{
				currPos = 0;
			};			
			elem.data('currPos',currPos);
        });
		
		window.requestAnimationFrame(scroll);
	};


	function setColor(elem,color) {
		var dots = elem.data('dots');
		for(var row of dots) {
			for(var dot of row) {
				dot.setAttribute("fill",color);
			};
		};	
	};	


    function update(dev, par) {
        me.elements.each(function (index) {
            var elem = $(this);
			var value = getValue(elem,'get',dev,par);
			if(value !== null) {
				setString(elem,value);
			}else{
				setString(elem,elem.data('text'));	
			};	
			value = getValue(elem,'get-color',dev,par);
			if(value !== null) {
				setColor(elem,value);
			};	
        });
    }


    // public
	initCode();
    // inherit all public members from base class
    var base = new Modul_widget();
    var _base = {};
    _base.init_attr = base.init_attr;
    var me = $.extend(base, {
        //override our own public members
        widgetname: 'dotmatrix',
        init_attr: init_attr,
        init_ui: init_ui,
        update: update,
    });

    return me;
	
	
	
	
	function initCode() {
		code = {
		"A" : [0b011100,
			   0b100010,
			   0b100010,
			   0b100010,
			   0b111110,
			   0b100010,
			   0b100010],
		"B" : [0b111100,
               0b100010,
			   0b100010,
			   0b111100,
               0b100010,
			   0b100010,
			   0b111100],
		"C" : [0b011100,
               0b100010,
			   0b100000,
			   0b100000,
               0b100000,
			   0b100010,
			   0b011100],
		"D" : [0b111000,
               0b100100,
			   0b100010,
			   0b100010,
               0b100010,
			   0b100100,
			   0b111000],	  
		"E" : [0b111110,
               0b100000,
			   0b100000,
			   0b111100,
               0b100000,
			   0b100000,
			   0b111110],	   
		"F" : [0b111110,
               0b100000,
			   0b100000,
			   0b111100,
               0b100000,
			   0b100000,
			   0b100000],	 
		"G" : [0b011100,
               0b100010,
			   0b100000,
			   0b101110,
               0b100010,
			   0b100010,
			   0b011110],	
		"H" : [0b100010,
               0b100010,
			   0b100010,
			   0b111110,
               0b100010,
			   0b100010,
			   0b100010],	   			   			   			   			   
		"I" : [0b011100,
               0b001000,
			   0b001000,
			   0b001000,
               0b001000,
			   0b001000,
			   0b011100],	   
		"J" : [0b001110,
               0b000100,
			   0b000100,
			   0b000100,
               0b000100,
			   0b100100,
			   0b011000],	   					   
		"K" : [0b100010,
               0b100100,
			   0b101000,
			   0b110000,
               0b101000,
			   0b100100,
			   0b100010],	   					   			   
		"L" : [0b100000,
               0b100000,
			   0b100000,
			   0b100000,
               0b100000,
			   0b100000,
			   0b111110],	   					   			   			   
		"M" : [0b100010,
               0b110110,
			   0b101010,
			   0b101010,
               0b100010,
			   0b100010,
			   0b100010],	   					   			   			   
		"N" : [0b100010,
               0b100010,
			   0b110010,
			   0b101010,
               0b100110,
			   0b100010,
			   0b100010],	   					   			   			   			   
		"O" : [0b011100,
               0b100010,
			   0b100010,
			   0b100010,
               0b100010,
			   0b100010,
			   0b011100],			   			   			   			   			   
		"P" : [0b111100,
               0b100010,
			   0b100010,
			   0b111100,
               0b100000,
			   0b100000,
			   0b100000],  			   			   			   			   			   
		"Q" : [0b011100,
               0b100010,
			   0b100010,
			   0b100010,
               0b101010,
			   0b100100,
			   0b011010],			   			   			   			   			   
		"R" : [0b111100,
               0b100010,
			   0b100010,
			   0b111100,
               0b101000,
			   0b100100,
			   0b100010],  			   			   			   			   			   
		"S" : [0b011110,
               0b100000,
			   0b100000,
			   0b011100,
               0b000010,
			   0b000010,
			   0b111100],  
		"T" : [0b111110,
               0b001000,
			   0b001000,
			   0b001000,
               0b001000,
			   0b001000,
			   0b001000],  	
		"U" : [0b100010,
               0b100010,
			   0b100010,
			   0b100010,
               0b100010,
			   0b100010,
			   0b011100],
		"V" : [0b100010,
               0b100010,
			   0b100010,
			   0b100010,
               0b100010,
			   0b010100,
			   0b001000], 
		"W" : [0b100010,
               0b100010,
			   0b100010,
			   0b101010,
               0b101010,
			   0b101010,
			   0b010100],  					   
		"X" : [0b100010,
               0b100010,
			   0b010100,
			   0b001000,
               0b010100,
			   0b100010,
			   0b100010],  					   
		"Y" : [0b100010,
               0b100010,
			   0b100010,
			   0b010100,
               0b001000,
			   0b001000,
			   0b001000],  					   
		"Z" : [0b111110,
               0b000010,
			   0b000100,
			   0b001000,
               0b010000,
			   0b100000,
			   0b111110],  		
		"a" : [0b000000,
               0b000000,
			   0b011100,
			   0b000010,
               0b011110,
			   0b100010,
			   0b011110],  
		"b" : [0b100000,
               0b100000,
			   0b101100,
			   0b110010,
               0b100010,
			   0b100010,
			   0b111100],  
		"c" : [0b000000,
               0b000000,
			   0b011100,
			   0b100000,
               0b100000,
			   0b100010,
			   0b011100],  	
		"d" : [0b000010,
               0b000010,
			   0b011010,
			   0b100110,
               0b100010,
			   0b100010,
			   0b011110],  	
		"e" : [0b000000,
               0b000000,
			   0b011100,
			   0b100010,
               0b111110,
			   0b100000,
			   0b011100],  
		"f" : [0b001100,
               0b010010,
			   0b010000,
			   0b111000,
               0b010000,
			   0b010000,
			   0b010000],  
		"g" : [0b000000,
               0b011110,
			   0b100010,
			   0b100010,
               0b011110,
			   0b000010,
			   0b011100], 
		"h" : [0b100000,
               0b100000,
			   0b101100,
			   0b110010,
               0b100010,
			   0b100010,
			   0b100010],  
		"i" : [0b001000,
               0b000000,
			   0b011000,
			   0b001000,
               0b001000,
			   0b001000,
			   0b011100], 
		"j" : [0b000100,
               0b000000,
			   0b001100,
			   0b000100,
               0b000100,
			   0b100100,
			   0b011000],
		"k" : [0b100000,
               0b100000,
			   0b100100,
			   0b101000,
               0b110000,
			   0b101000,
			   0b100100],  
		"l" : [0b011000,
               0b001000,
			   0b001000,
			   0b001000,
               0b001000,
			   0b001000,
			   0b011100],  
		"m" : [0b000000,
               0b000000,
			   0b110100,
			   0b101010,
               0b101010,
			   0b100010,
			   0b100010], 
		"n" : [0b000000,
               0b000000,
			   0b101100,
			   0b110010,
               0b100010,
			   0b100010,
			   0b100010], 
		"o" : [0b000000,
               0b000000,
			   0b011100,
			   0b100010,
               0b100010,
			   0b100010,
			   0b011100], 
		"p" : [0b000000,
               0b000000,
			   0b111100,
			   0b100010,
               0b111100,
			   0b100000,
			   0b100000],  
		"q" : [0b000000,
               0b000000,
			   0b011110,
			   0b100010,
               0b011110,
			   0b000010,
			   0b000010], 
		"r" : [0b000000,
               0b000000,
			   0b101100,
			   0b110010,
               0b100000,
			   0b100000,
			   0b100000],  
		"s" : [0b000000,
               0b000000,
			   0b011100,
			   0b100000,
               0b011100,
			   0b000010,
			   0b111100],
		"t" : [0b010000,
               0b010000,
			   0b111000,
			   0b010000,
               0b010000,
			   0b010010,
			   0b001100],  
		"u" : [0b000000,
               0b000000,
			   0b100010,
			   0b100010,
               0b100010,
			   0b100110,
			   0b011010], 
		"v" : [0b000000,
               0b000000,
			   0b100010,
			   0b100010,
               0b100010,
			   0b010100,
			   0b001000],
		"w" : [0b000000,
               0b000000,
			   0b100010,
			   0b100010,
               0b101010,
			   0b101010,
			   0b010100], 
		"x" : [0b000000,
               0b000000,
			   0b100010,
			   0b010100,
               0b001000,
			   0b010100,
			   0b100010],
		"y" : [0b000000,
               0b000000,
			   0b100010,
			   0b100010,
               0b011110,
			   0b000010,
			   0b011100],  
		"z" : [0b000000,
               0b000000,
			   0b111110,
			   0b000100,
               0b001000,
			   0b010000,
			   0b111110], 
		"0" : [0b011100,
               0b100010,
			   0b100110,
			   0b101010,
               0b110010,
			   0b100010,
			   0b011100],
		"1" : [0b001000,
               0b011000,
			   0b001000,
			   0b001000,
               0b001000,
			   0b001000,
			   0b011100],
		"2" : [0b011100,
               0b100010,
			   0b000010,
			   0b000100,
               0b001000,
			   0b010000,
			   0b111110],
		"3" : [0b111110,
               0b000100,
			   0b001000,
			   0b000100,
               0b000010,
			   0b100010,
			   0b011100],
		"4" : [0b000100,
               0b001100,
			   0b010100,
			   0b100100,
               0b111110,
			   0b000100,
			   0b000100],
		"5" : [0b111110,
               0b100000,
			   0b111100,
			   0b000010,
               0b000010,
			   0b100010,
			   0b011100],
		"6" : [0b001100,
               0b010000,
			   0b100000,
			   0b111100,
               0b100010,
			   0b100010,
			   0b011100],
		"7" : [0b111110,
               0b000010,
			   0b000100,
			   0b001000,
               0b010000,
			   0b010000,
			   0b010000],
		"8" : [0b011100,
               0b100010,
			   0b100010,
			   0b011100,
               0b100010,
			   0b100010,
			   0b011100],
		"9" : [0b011100,
               0b100010,
			   0b100010,
			   0b011110,
               0b000010,
			   0b000100,
			   0b011000],
		"<" : [0b000010,
               0b000100,
			   0b001000,
			   0b010000,
               0b001000,
			   0b000100,
			   0b000010],
		"=" : [0b000000,
               0b000000,
			   0b111110,
			   0b000000,
               0b111110,
			   0b000000,
			   0b000000],
		">" : [0b100000,
               0b010000,
			   0b001000,
			   0b000100,
               0b001000,
			   0b010000,
			   0b100000],
		"!" : [0b001000,
               0b001000,
			   0b001000,
			   0b001000,
               0b000000,
			   0b000000,
			   0b001000],
		"\"": [0b010100,
               0b010100,
			   0b010100,
			   0b000000,
               0b000000,
			   0b000000,
			   0b000000],			   
		"#" : [0b010100,
               0b010100,
			   0b111110,
			   0b010100,
               0b111110,
			   0b010100,
			   0b010100],
		"%" : [0b110000,
               0b110010,
			   0b000100,
			   0b001000,
               0b010000,
			   0b100110,
			   0b000110],
		"&" : [0b011000,
               0b100100,
			   0b101000,
			   0b010000,
               0b101010,
			   0b100100,
			   0b011010],
		"'" : [0b011000,
               0b001000,
			   0b010000,
			   0b000000,
               0b000000,
			   0b000000,
			   0b000000],
		"(" : [0b000100,
               0b001000,
			   0b010000,
			   0b010000,
               0b010000,
			   0b001000,
			   0b000100],
		")" : [0b010000,
               0b001000,
			   0b000100,
			   0b000100,
               0b000100,
			   0b001000,
			   0b010000],
		"*" : [0b000000,
               0b001000,
			   0b101010,
			   0b011100,
               0b101010,
			   0b001000,
			   0b000000],
		"+" : [0b000000,
               0b001000,
			   0b001000,
			   0b111110,
               0b001000,
			   0b001000,
			   0b000000],
		"-" : [0b000000,
               0b000000,
			   0b000000,
			   0b111110,
               0b000000,
			   0b000000,
			   0b000000],
		"." : [0b000000,
               0b000000,
			   0b000000,
			   0b000000,
               0b000000,
			   0b011000,
			   0b011000],
		"," : [0b000000,
               0b000000,
			   0b000000,
			   0b000000,
               0b011000,
			   0b001000,
			   0b010000],
		"?" : [0b011100,
               0b100010,
			   0b000010,
			   0b000100,
               0b001000,
			   0b000000,
			   0b001000],
		"/" : [0b000000,
               0b000010,
			   0b000100,
			   0b001000,
               0b010000,
			   0b100000,
			   0b000000],
		":" : [0b000000,
               0b011000,
			   0b011000,
			   0b000000,
               0b011000,
			   0b011000,
			   0b000000],
		";" : [0b000000,
               0b011000,
			   0b011000,
			   0b000000,
               0b011000,
			   0b001000,
			   0b010000],
		"_" : [0b000000,
               0b000000,
			   0b000000,
			   0b000000,
               0b000000,
			   0b000000,
			   0b111110],
		"^" : [0b001000,
               0b010100,
			   0b100010,
			   0b000000,
               0b000000,
			   0b000000,
			   0b000000],				   
		" " : [0b000000,
               0b000000,
			   0b000000,
			   0b000000,
               0b000000,
			   0b000000,
			   0b000000],
		"°" : [0b111000,
               0b101000,
			   0b111000,
			   0b000000,
               0b000000,
			   0b000000,
			   0b000000],
		"@" : [0b011100,
               0b000010,
			   0b000010,
			   0b011010,
               0b101010,
			   0b101010,
			   0b011100] 			   
		};
	};	
	
};
