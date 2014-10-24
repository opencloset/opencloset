$ ->
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
    alert: (cls, msg) ->
      unless msg
        msg = cls
        cls = 'info'
      # error, success, info
      $('.main-content').prepend("<div class=\"alert alert-#{cls}\">#{msg}</div>")
      setTimeout ->
        $('.alert').remove()
      , 3000
    status:
      '대여가능':   { id: 1,  css: 'label-success'   }
      '대여중':     { id: 2,  css: 'label-important' }
      '대여불가':   { id: 3,  css: 'label-inverse'   }
      '예약':       { id: 4,  css: 'label-inverse'   }
      '세탁':       { id: 5,  css: 'label-inverse'   }
      '수선':       { id: 6,  css: 'label-inverse'   }
      '분실':       { id: 7,  css: 'label-inverse'   }
      '폐기':       { id: 8,  css: 'label-inverse'   }
      '반납':       { id: 9,  css: 'label-inverse'   }
      '부분반납':   { id: 10, css: 'label-warning'   }
      '반납배송중': { id: 11, css: 'label-warning'   }
    category:
      belt:      { str: '벨트',     price: 2000  }
      blouse:    { str: '블라우스', price: 5000  }
      coat:      { str: '코트',     price: 10000 }
      hat:       { str: '모자',     price: 2000  }
      jacket:    { str: '재킷',     price: 10000 }
      onepiece:  { str: '원피스',   price: 10000 }
      pants:     { str: '바지',     price: 10000 }
      shirt:     { str: '셔츠',     price: 5000  }
      shoes:     { str: '신발',     price: 5000  }
      skirt:     { str: '치마',     price: 10000 }
      tie:       { str: '넥타이',   price: 2000  }
      waistcoat: { str: '조끼',     price: 5000  }
    measurement:
      height: '키'
      weight: '몸무게'
      bust:   '가슴 둘레'
      waist:  '허리 둘레'
      hip:    '엉덩이 둘레'
      belly:  '배 둘레'
      thigh:  '허벅지 둘레'
      arm:    '팔 길이'
      leg:    '다리 길이'
      knee:   '무릎 길이'
      foot:   '발 크기'
    color:
      red:    '빨강'
      orange: '주황'
      yellow: '노랑'
      green:  '초록'
      blue:   '파랑'
      navy:   '남색'
      purple: '보라'
      white:  '흰색'
      black:  '검정'
      pink:   '분홍'
      gray:   '회색'
      brown:  '갈색'
    payWith: [
      '현금',
      '카드',
      '계좌이체',
      '현금영수증',
      '세금계산서',
    ]
    trimClothesCode: (code) ->
      code = code.replace /^\s+/, ''
      code = code.replace /\s+$/, ''
      code = code.replace /^0/, ''
      return code
    commify: (num) ->
      num += ''
      regex = /(^[+-]?\d+)(\d{3})/
      while (regex.test(num))
        num = num.replace(regex, '$1' + ',' + '$2')
      return num
    sendSMS: (to, text) ->
      $.ajax "/api/sms.json",
        type: 'POST'
        data:
          to:   to
          text: text
        success: (data, textStatus, jqXHR) ->
        error: (jqXHR, textStatus, errorThrown) ->
    sendSMSValidation: (to) ->
      $.ajax "/api/sms/validation.json",
        type: 'POST'
        data:
          to:   to
        success: (data, textStatus, jqXHR) ->
        error: (jqXHR, textStatus, errorThrown) ->

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
