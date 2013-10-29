$ ->
  $('.clickable.label').click ->
    $('#input-purpose').val($(@).text())
