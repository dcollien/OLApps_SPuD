response.setHeader 'Content-Type', 'text/json'

if request.method is 'POST'
	marksObject[request.user] = {
		completed: request.data.completed
		comment: request.data.comment
	}
	
	try
		OpenLearning.activity.submit request.user
		OpenLearning.activity.setMarks marksObject
	catch err
		error = 'Something went wrong: Unable to save data'

response.writeJSON {
	error: error,
	success: (not error)
}
