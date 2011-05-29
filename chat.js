var http = require('http'),
    io = require('socket.io'),

server = http.createServer(function(req, res){
  res.writeHead(200, {'Content-Type': 'text/html'});
  res.end('<h1>Hello world</h1>');
});

server.listen(81);

// socket.io
var socket = io.listen(server);

socket.on('connection', function(client){
  client.broadcast({client: "God", message: client.sessionId + " is now among us"});

  client.on('message', function(data){
    if (typeof data.message === "undefined") {

    } else {
        data.client = client.sessionId;
        client.broadcast(data);
    }
  });

  client.on('disconnect', function(){
    client.broadcast({client: "God", message: client.sessionId + " left us to a better place"});
  });
});