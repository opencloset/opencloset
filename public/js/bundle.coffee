$ ->
  Window::alert = (cls, msg) ->
    unless msg
      msg = cls
      cls = 'info'
    # error, success, info
    $("<div class=\"alert alert-#{cls}\">#{msg}</div>")
      .insertAfter('#clothe-search-form')
    setTimeout ->
      $('.alert').remove()
    , 3000
  
  pathname = location.pathname
  $('.navbar .nav > li').each (i, el) ->
    if pathname is $(el).children('a').attr('href') then $(el).addClass('active')
