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
    alert: (cls, msg, target) ->
      unless msg
        msg = cls
        cls = 'info'
      unless target
        target = '.main-content'
      # error, success, info
      $(target).prepend("<div class=\"alert alert-#{cls}\"><button class=\"close\" type=\"button\" data-dismiss=\"alert\">&times;</button>#{msg}</div>")

      #
      # scroll to element
      #
      # http://stackoverflow.com/questions/6677035/jquery-scroll-to-element#answer-6677069
      #
      $('html, body').animate({ scrollTop: $(target).offset().top }, 0)

      setTimeout ->
        $('.alert').remove()
      , 8000
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
      '방문안함':   { id: 12, css: 'label-warning'   }
      '방문':       { id: 13, css: 'label-warning'   }
      '방문예약':   { id: 14, css: 'label-info'      }
      '배송예약':   { id: 15, css: 'label-info'      }
      '치수측정':   { id: 16, css: 'label-inverse'   }
      '의류준비':   { id: 17, css: 'label-inverse'   }
      '포장':       { id: 18, css: 'label-inverse'   }
      '결제대기':   { id: 19, css: 'label-inverse'   }
      '탈의01':     { id: 20, css: 'label-inverse'   }
      '탈의02':     { id: 21, css: 'label-inverse'   }
      '탈의03':     { id: 22, css: 'label-inverse'   }
      '탈의04':     { id: 23, css: 'label-inverse'   }
      '탈의05':     { id: 24, css: 'label-inverse'   }
      '탈의06':     { id: 25, css: 'label-inverse'   }
      '탈의07':     { id: 26, css: 'label-inverse'   }
      '탈의08':     { id: 27, css: 'label-inverse'   }
      '탈의09':     { id: 28, css: 'label-inverse'   }
      '탈의10':     { id: 29, css: 'label-inverse'   }
      '탈의11':     { id: 30, css: 'label-inverse'   }
      '대여안함':   { id: 40, css: 'label-inverse'   }
    category:
      jacket:    { str: '재킷',     price: 10000 }
      pants:     { str: '바지',     price: 10000 }
      skirt:     { str: '치마',     price: 10000 }
      shirt:     { str: '셔츠',     price: 5000  }
      blouse:    { str: '블라우스', price: 5000  }
      shoes:     { str: '신발',     price: 5000  }
      tie:       { str: '넥타이',   price: 2000  }
      onepiece:  { str: '원피스',   price: 10000 }
      coat:      { str: '코트',     price: 10000 }
      waistcoat: { str: '조끼',     price: 5000  }
      belt:      { str: '벨트',     price: 2000  }
      bag:       { str: '가방',     price: 5000  }
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
      black:  '검정'
      navy:   '남색'
      gray:   '회색'
      white:  '흰색'
      brown:  '갈색'
      blue:   '파랑'
      red:    '빨강'
      orange: '주황'
      yellow: '노랑'
      green:  '초록'
      purple: '보라'
      pink:   '분홍'
      etc:    '기타'
      staff:  '직원추천'
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
    sendSMSValidation: (name, to, success_cb, error_cb) ->
      $.ajax "/api/sms/validation.json",
        type: 'POST'
        data:
          name: name
          to:   to
        success: (data, textStatus, jqXHR) ->
          success_cb( data, textStatus, jqXHR )
        error: (jqXHR, textStatus, errorThrown) ->
          error_cb( jqXHR, textStatus, errorThrown )

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
