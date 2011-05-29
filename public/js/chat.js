var socket = new io.Socket("v3.thecolorless.net", {port: 81}),
    chat   = $("#chat_box"),
    speech = $("#chat_input");

socket.connect();
socket.on('connect', function(){
    renderChat({message: "We are online"});
});
socket.on('message', function(data){
    renderChat(data);
});
socket.on('disconnect', function(){
    renderChat({message: "Oh bugger, we disconnected"});
});

speech.keydown(function(e) {
    if(e.keyCode == '13') {
        e.preventDefault();
        var msg = { message: speech.val() };
        speech.val("");
        socket.send(msg);
        renderChat(msg);
    }
});

var renderChat = function(data) {
    var box = $("<div>");
        box.html((data.client ? data.client + ": " : "") + data.message);

        chat.append(box);
}