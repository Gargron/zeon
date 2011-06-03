var socket = {},
    chat   = $("#chat_box"),
    speech = $("#chat_input"),
    renderChat = function(data) {
        var box = $("<div>"),
            meta = $("<div>"),
            bubble = $("<div>");
            box.addClass("item").addClass("item_" + data.type);
            meta.addClass("item_meta");
            bubble.addClass("item_bubble");
            meta.html((data.client ? '<img src="http://gravatar.com/avatar/' + data.gravatar + '?s=40" width="40" height="40" /><strong class="name tt" title="' + data.client + '">' + (data.client.search(/Guest [\d]+/) != -1 ? data.client.replace(/ [\d]+/, "") : data.client) + "</strong>" : "") + (data.type == "action" ? " " + data.verb + " " : ""));
            bubble.html(data.content);
            box.append(meta).append(bubble);
            chat.prepend(box);
    };

if (typeof io === "undefined") {
    socket.connect = function() {}, socket.on = function() {}, socket.send = function() {};
    renderChat({type: "status", content: "Chat is not available, sorry bro"});
} else {
    socket = new io.Socket(root, {port: 81})
}

socket.connect();
socket.on('connect', function(){
    renderChat({type: "status", content: "We are online"});
});
socket.on('message', function(data){
    renderChat(data);
});
socket.on('disconnect', function(){
    renderChat({type: "status", content: "Oh bugger, we disconnected"});
});

speech.keydown(function(e) {
    if(e.keyCode == '13') {
        e.preventDefault();
        var msg = { text: speech.val() };
        speech.val("");
        if (msg.text.length > 0) { socket.send(msg) } else { }
    }
});
