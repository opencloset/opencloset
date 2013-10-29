$ ->
  $('#input-target-date').datepicker
    format: 'yyyy-mm-dd'
    autoclose: true
    startDate: new Date()
    language: 'kr'
  .on 'changeDate', (e) ->
    console.log overdue_calc(new Date(), $('#input-target-date').datepicker('getDate'))

  overdue_calc = (target_dt, return_dt) ->
    DAY_AS_SECONDS = 60 * 60 * 24
    dur = return_dt.getTime() - target_dt.getTime()
    return 0 if dur < 0
    parseInt(dur / 1000)
