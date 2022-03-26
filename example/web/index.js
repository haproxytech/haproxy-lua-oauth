const express = require('express')
const app = express()
const port = 80

var hamsters = [
    "robo-hamster",
    "space-hamster",
    "commando-hamster",
    "pirate-hmaster"
]

app.get('/api/myapp', function (req, res) {
    console.log('GET /api/myapp')
    res.send(hamsters)
})

app.post('/api/myapp/:name', function (req, res) {
    console.log('POST /api/myapp')
  hamsters.push(req.params.name)
  res.send(hamsters)
})

app.delete('/api/myapp/:name', function(req, res) {
    console.log('DELETE /api/myapp')
    var index = hamsters.indexOf(req.params.name)

    if (index > -1) {
        hamsters.splice(index, 1)
    }

    res.send(hamsters)
})

app.listen(port, () => console.log(`Listening on port ${port}`))