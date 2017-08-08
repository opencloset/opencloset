$ ->
  $('.chosen-select').chosen()
  $('input[name="gender"]').on 'change', (e) ->
    gender = $(@).val()
    $('.gender-size').hide()
    $(".#{gender}-only").show()
