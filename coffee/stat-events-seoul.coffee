$ ->
  $('.daily-stat .btn').click (e) ->
    e.preventDefault()

    $this = $(@)
    collapse = $this.closest('.collapse-group').find('.collapse')
    collapse.collapse('toggle')
