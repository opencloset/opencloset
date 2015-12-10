$ ->
  $('input[name=phone]').mask('00000000000')
  $('input[name=user-target-date]').datepicker
    format: 'yyyy-mm-dd'
    startDate: new Date()
    todayHighlight: true
    autoclose: true
    daysOfWeekDisabled: '0'    # sunday
