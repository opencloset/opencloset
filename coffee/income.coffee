$.fn.ForceNumericOnly = ->
  @each ->
    $(@).keydown (e) ->
      key = e.charCode or e.keyCode or 0
      key == 8 ||
      key == 9 ||
      key == 46 ||
      key == 110 ||
      key == 190 ||
      (key >= 35 && key <= 40) ||
      (key >= 48 && key <= 57) ||
      (key >= 96 && key <= 105)

commify = (num) ->
  num += ''
  regex = /(^[+-]?\d+)(\d{3})/
  while (regex.test(num))
    num = num.replace(regex, '$1' + ',' + '$2')
  return num

$ ->
  $('input.income-xs').ForceNumericOnly()
  $('input.income-xs').on 'change', ->
    total = 0
    $table = $(@).closest('table')
    $table.find('input.income-xs').each (i, el) ->
      fee = $(el).val() or 0
      total += parseInt(fee)
    $table.find('.income-xs.sum').text(commify(total))

    total = 0
    $('input.income-xs').each (i, el) ->
      fee = $(el).val() or 0
      total += parseInt(fee)
    $('#input-income-sum').text(commify(total))
