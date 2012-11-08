response.setHeader 'Content-Type', 'application/json'

size = request.args.size
if not size?
	size = 3

response.writeJSON OpenLearning.page.getUserDataList ('busybeaver' + size), 'score', 0, null
