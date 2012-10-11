response.setHeader 'Content-Type', 'text/json'

submission = OpenLearning.activity.getSubmission request.user
state = submission.metadata
code = submission.file.data

response.writeJSON {
	state: state,
	code: code
}

