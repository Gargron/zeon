$.fn.intercept = (callback) ->
  form = $(this)
  form.submit ->
    $.ajax({
      url: form.attr('action') + '.json',
      type: form.attr('method'),
      data: form.serialize()
    }).success ->
      callback()
    .error (data) ->
      flash("error", jQuery.parseJSON(data.responseText).error)
    false

flash = (kind, message) ->
  $("#flash").remove()
  $("<div/>", id: "flash").appendTo("body")
  $("<div/>", class: kind, text: message).appendTo("#flash")
  $("#flash").hide(0).slideDown(500).delay(1500).slideUp(500)

################################################

$("#flash").delay(1500).slideUp(500)

$("#login").intercept ->
  location.href = "/"

$("#settings").intercept ->
  flash("success", "Your profile data has been updated.")
