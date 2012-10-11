response.setHeader 'Content-Type', 'text/json'

if request.method is 'POST'
	try
		state = JSON.parse request.data.state
	catch err
		error = err

	if not error?
		code = request.data.code

		submission = {
			file: {
				filename: 'code.txt'
				data: code
			},
			metadata: {
				state: state
			}
		}

		# set submission data
		try
			submissionData = OpenLearning.activity.saveSubmission request.user, submission, 'file'
			view.url = submissionData.url
			submitSuccess = OpenLearning.activity.submit request.user
		catch err
			view.error = 'Something went wrong: Unable to save data'
		
		response.writeJSON { success: true }

if error?
	response.writeJSON { success: false, error: error }
