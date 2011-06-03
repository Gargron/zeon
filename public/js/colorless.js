(function() {
  $("#password").showPassword('.box', {text: 'Check your password twice', className: 'check_password'});
  $(".tt").tipTip({delay: 100, maxWidth: "auto"});
  $(".tt_form").tipTip({delay: 100, defaultPosition: "right", attribute: "data-tooltip"});
  $(".choose_type a").click(function(e) {
    e.preventDefault();
    var $this = $(this);
    if($this.is(".active")) {

    } else {
      $this.addClass("active").siblings().removeClass("active");
      var type = $this.attr("data-value");
      $("#type").val(type);
      switch(type) {
        case "post":
          $(".title, .text").removeClass("inactive").addClass("active");
          $(".url, .file").removeClass("active").addClass("inactive");
          break;
        case "image":
          $(".file, .url, .text").removeClass("inactive").addClass("active");
          $(".title").removeClass("active").addClass("inactive");
          break;
        case "video":
          $(".title, .url, .text").removeClass("inactive").addClass("active");
          $(".file").removeClass("active").addClass("inactive");
          break;
        case "link":
          $(".title, .url, .text").removeClass("inactive").addClass("active");
          $(".file").removeClass("active").addClass("inactive");
          break;
      }
    }
  });
  if(giveChat) {
    $.getScript("http://" + root + ":81/socket.io/socket.io.js", function() {
      $.getScript("/js/chat.js");
    });
  }
}).call(this);