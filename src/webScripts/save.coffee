response.setHeader 'Content-Type', 'text/json'

if request.method is 'POST'
	state = JSON.parse request.data.state
	code = request.data.code

	submission =
		file: 'code.txt'
		data: code
		metadata: state
	
	OpenLearning.activity.saveSubmission request.user, submission, 'file'

response.writeJSON { success: true }
