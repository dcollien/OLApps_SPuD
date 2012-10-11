response.setHeader 'Content-Type', 'text/json'

submissionData = {}

try
	submissionPage = (OpenLearning.activity.getSubmission request.user)
	submission = submissionPage.submission
	if submission.file
		submissionData.code = submission.file.data
		submissionData.state = JSON.parse submission.metadata.state
		submissionData.url = submissionPage.url
catch err
	error = 'Something went wrong: Unable to load data: ' + err

response.writeJSON submissionData

