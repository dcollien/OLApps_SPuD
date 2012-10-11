response.setHeader 'Content-Type', 'text/json'

if request.method is 'POST'
	try
		state = JSON.parse request.data.state
	catch err
		error = err

	if not error?
		code = request.data.code

		submission =
			file: 'code.txt'
			data: code
			metadata: state
		
		OpenLearning.activity.saveSubmission request.user, submission, 'file'

		response.writeJSON { success: true }

if error?
	response.writeJSON { success: false, error: error }
