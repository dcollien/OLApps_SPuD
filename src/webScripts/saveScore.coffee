response.setHeader 'Content-Type', 'application/json'

if request.method is 'POST' and request.data.action == 'saveScore'
	try
		result = JSON.parse request.data.result
	catch err
		error = err

	if not error?
		submission = {
			metadata: {
				busybeaver: result
			}
		}

		# set submission data
		try
			submissionData = OpenLearning.activity.saveSubmission request.user, submission, 'file'
		catch err
			error = 'Something went wrong: Unable to save submission'

		try			
			if (result.terminated)
				scoreData = {
					size: result.size,
					score: result.state.output.length,
					user: request.user
				}
				
				OpenLearning.page.setUserData request.user, 'busybeaver' + size, scoreData

		catch err
			error = 'Something went wrong: Unable to save to scoreboard'
else
	error = 'Provide post data'

if error?
	response.writeJSON { success: false, error: error }
else
	response.writeJSON { success: true }
