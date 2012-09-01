response.setHeader "Content-Type", "application/javascript"

openURL mediaURL('js/spudEmu.js'), { 'Accept': 'application/javascript', 'Connection': 'close' }, null, (responseData) ->
	response.writeData responseData
