var socket = new io.Socket("v3.thecolorless.net", {port: 81}),
    chat   = $("#chat_box"),
    speech = $("#chat_input");

socket.connect();
socket.on('connect', function(){
    renderChat({content: "We are online"});
});
socket.on('message', function(data){
    renderChat(data);
});
socket.on('disconnect', function(){
    renderChat({content: "Oh bugger, we disconnected"});
});

speech.keydown(function(e) {
    if(e.keyCode == '13') {
        e.preventDefault();
        var msg = { text: speech.val() };
        speech.val("");
        socket.send(msg);
    }
});

var renderChat = function(data) {
    var box = $("<div>");
        box.addClass("item");
        box.html((data.client ? '<strong class="name">' + data.client + "</strong>" : "") + (data.type == "action" ? " " + data.verb + " " : (data.client ? ": " : "")) + data.content);

        chat.prepend(box);
}