response.setHeader 'Content-Type', 'application/json'
response.writeJSON OpenLearning.page.getUserDataList 'busybeaver', ['size', 'score'], 0, null
