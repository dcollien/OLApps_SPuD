response.setHeader 'Content-Type', 'text/json'

submission = (OpenLearning.activity.getSubmission request.user)

response.writeJSON submission

