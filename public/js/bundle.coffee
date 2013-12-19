$ ->
  Window::_alert = Window::alert
  Window::alert = (cls, msg) ->
    unless msg
      msg = cls
      cls = 'info'
    # error, success, info
    $('.main-content').prepend("<div class=\"alert alert-#{cls}\">#{msg}</div>")
    setTimeout ->
      $('.alert').remove()
    , 3000
  
  pathname = location.pathname
  $('.navbar .nav > li').each (i, el) ->
    if pathname is $(el).children('a').attr('href') then $(el).addClass('active')

  #
  # sidebar active open
  #
  $('.sidebar li').each (i, el) ->
    $(el).addClass('active open') if $(el).find('li.active').length > 0

  #
  # common fuction for OpenCloset
  #
  Window::OpenCloset =
    getStatusCss: (status) ->
      switch status
        when '대여가능'   then css = 'label-success'
        when '대여중'     then css = 'label-important'
        when '대여불가'   then css = 'label-inverse'
        when '예약'       then css = 'label-inverse'
        when '세탁'       then css = 'label-inverse'
        when '수선'       then css = 'label-inverse'
        when '분실'       then css = 'label-inverse'
        when '폐기'       then css = 'label-inverse'
        when '반납'       then css = 'label-inverse'
        when '부분반납'   then css = 'label-warning'
        when '반납배송중' then css = 'label-warning'
        else                   css = ''
      return css
    getStatusId: (status) ->
      switch status
        when '대여가능'   then id = 1
        when '대여중'     then id = 2
        when '대여불가'   then id = 3
        when '예약'       then id = 4
        when '세탁'       then id = 5
        when '수선'       then id = 6
        when '분실'       then id = 7
        when '폐기'       then id = 8
        when '반납'       then id = 9
        when '부분반납'   then id = 10
        when '반납배송중' then id = 11
        else                   id = undef
      return id
    getCategoryStr: (category) ->
      switch category
        when "belt"      then str = "벨트"
        when "blouse"    then str = "블라우스"
        when "coat"      then str = "코트"
        when "hat"       then str = "모자"
        when "jacket"    then str = "재킷"
        when "onepiece"  then str = "원피스"
        when "pants"     then str = "바지"
        when "shirts"    then str = "셔츠"
        when "shoes"     then str = "신발"
        when "skirt"     then str = "치마"
        when "tie"       then str = "넥타이"
        when "waistcoat" then str = "조끼"
        else                  str = undef
      return str

  #
  # return nothing
  #
  return

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

$.extend
  putUrlVars: (hashes) ->
    vars = ''
    unless hashes.legnth is 0
      params = []
      regex = /^\d+$/
      for key of hashes
        params.push key + "=" + hashes[key]  unless regex.test(key)
      vars += params.join("&")
    vars
