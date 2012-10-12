response.setHeader 'Content-Type', 'text/json'

marksObject = {}

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
else
	error = 'Use POST'

response.writeJSON {
	error: error,
	success: (not error),
	marks: marksObject
}
