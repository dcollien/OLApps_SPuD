response.setHeader 'Content-Type', 'application/json'

user = request.args.user

try
	response.writeJSON OpenLearning.getUserData user
catch err
	response.writeJSON {error: err}
