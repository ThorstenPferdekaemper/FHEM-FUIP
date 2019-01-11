
function FW_cmd(cmd) {
	return $.ajax({
		async: true,
		cache: false,
		method: 'GET',
		dataType: 'text',
		url: cmd + '&fwcsrf=' + fuip.csrf,
		error: function (jqXHR, textStatus, errorThrown) {
				console.log("FUIP command: " + cmd);
				console.log("FUIP: Local FHEM command failed: " + jqXHR.status + " " + textStatus + " " + errorThrown);
				ftui.toast("FUIP: Local FHEM command failed: " + jqXHR.status + " " + textStatus + " " + errorThrown,"error");
		}
	});
};
