// common parts, which are needed for all FUIP pages
// i.e. edit mode and "locked" mode

// overwrite ftui.toast with something better configurable
// data-fuip-toast
//		all: show all messages
//		error: only show messages where parameter error is "error" or "fuip-error"
//				(i.e. error messages from FTUI or FUIP
//		off: only show messages where error = "fuip-error" (this should only
//				happen in maintenance mode)	 
// only replace the original toast function if FUIP config is set
// (compatibility with prior versions)
if($('html').data('fuipToast')) {
	ftui.toast = function (text, error) {
		if(! $.toast) return;  // i.e. jquery toast not loaded
		var tstack = ftui.config.TOAST > 1 ? ftui.config.TOAST : false;
		var fuipToast = $('html').data('fuipToast');
		if (error == 'error' && fuipToast != 'off' || error == 'fuip-error') {
			return $.toast({
					heading: 'Error',
					text: text,
					hideAfter: 20000, // in milli seconds
					icon: 'error',
					loader: false,
					position: ftui.config.toastPosition,
					stack: tstack
			});
		};
		if(fuipToast != 'all') return null;
		return $.toast({
				text: text,
				loader: false,
				position: ftui.config.toastPosition,
				stack: tstack
		});
	};
};