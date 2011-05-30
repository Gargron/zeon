var fugue = require('fugue'),
    http = require('http'),
    redis_server = require('redis'),
    redis_client = redis_server.createClient(),
    sys = require('sys'),
    io = require('socket.io'),

server = http.createServer(function(req, res){
  res.writeHead(200, {'Content-Type': 'text/html'});
  res.end('<h1>Hello world</h1>');
});

server.listen(81);

redis_client.on("error", function (err) {
    console.log("Error " + err);
});

// socket.io
var socket = io.listen(server);

//fugue.start(server, 81, null, 1, {verbose : true});

socket.on('connection', function(client){
  var user = {},
      cookies = {},
      message = {
      type: "message",
      verb: null,
      client: null,
      object: null,
      content: null
    };
  client.request.headers.cookie && client.request.headers.cookie.split(';').forEach(function( cookie ) {
    var parts = cookie.split('=');
    cookies[ parts[ 0 ].trim() ] = ( parts[ 1 ] || '' ).trim();
  });
  var session_id = cookies['rack.session'];
  redis_client.GET(session_id, function(error, string) {
    var data = JSON.parse(string);
    if (typeof data !== "undefined" && data != null) {
      user.id = data.id;
      user.name = data.name;
      user.email = data.email;
    }
  });
  client.broadcast({type: "status", client: "God", content: (user.name ? user.name : "Guest " + client.sessionId) + " is now among us"});

  client.on('message', function(data){
    if (typeof data.text === "undefined") {

    } else {
        var type_match = data.text.match(/^\/[\w]+/i);
        if(type_match) {
          message.type = "action";
          message.verb = String(type_match).replace(/\//, "");
          data.text = data.text.replace(type_match, "");
        } else {
          message.type = "message";
        }
        message.client = (user.name ? user.name : "Guest " + client.sessionId);
        message.content = data.text.replace(/(<([^>]+)>)/ig, "").replace(/(\b(https?|ftp|file):\/\/[-A-Z0-9+&@#\/%?=~_|!:,.;]*[-A-Z0-9+&@#\/%=~_|])/ig, "<a href='$1' target='_blank'>$1</a>");
        client.send(message);
        client.broadcast(message);
    }
  });

  client.on('disconnect', function(){
    client.broadcast({type: "status", client: "God", content: (user.name ? user.name : "Guest " + client.sessionId) + " left us to a better place"});
  });
});