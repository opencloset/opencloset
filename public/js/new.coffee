$ ->
  $('#input-phone').ForceNumericOnly()
  $('.clickable.label').click ->
    $('#input-purpose').val($(@).text())
