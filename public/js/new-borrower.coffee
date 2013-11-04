$ ->
  $('#input-phone').ForceNumericOnly()
  $('.clickable.label').click ->
    $('#input-purpose').val($(@).text())
  $('#input-target-date').datepicker
    startDate: "-0d"
    language: 'kr'
    format: 'yyyy-mm-dd'
    autoclose: true
