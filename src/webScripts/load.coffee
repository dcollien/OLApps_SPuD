response.setHeader 'Content-Type', 'application/json'

submissionData = {}

try
	submissionPage = (OpenLearning.activity.getSubmission request.user)
	submission = submissionPage.submission
	if submission.file
		submissionData.code = submission.file.data

	if submission.metadata
		submissionData.state = submission.metadata.state
	
	submissionData.url = submissionPage.url
	response.writeJSON submissionData
catch err
	error = 'Something went wrong: Unable to load data: ' + err
	response.writeJSON { error: error }


