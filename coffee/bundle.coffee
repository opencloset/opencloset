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
  # facebox settings
  #
  $.facebox.settings.loadingImage = '/lib/facebox/loading.gif'
  $.facebox.settings.closeImage = '/lib/facebox/closelabel.png'

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
      '포장취소':   { id: 41, css: 'label-inverse'   }
      '환불':       { id: 42, css: 'label-inverse'   }
      '사이즈없음': { id: 43, css: 'label-inverse'   }
      '포장완료':   { id: 44, css: 'label-inverse'   }
      '재활용(옷캔)': { id: 45, css: 'label-inverse' }
      '재활용(비백)': { id: 46, css: 'label-inverse' }
      '사용못함':    { id: 47, css: 'label-inverse' }
      '의류선택':    { id: 48, css: 'label-inverse' }
      '주소선택':    { id: 49, css: 'label-inverse' }
      '결제완료':    { id: 50, css: 'label-inverse' }
      '입금확인':    { id: 51, css: 'label-inverse' }
      '발송대기':    { id: 52, css: 'label-inverse' }
      '배송중':     { id: 53, css: 'label-inverse' }
      '배송완료':    { id: 54, css: 'label-inverse' }
      '반송신청':    { id: 55, css: 'label-inverse' }
      '입금대기':    { id: 56, css: 'label-inverse' }
    category:
      jacket:    { str: '자켓',     price: 10000 }
      pants:     { str: '팬츠',     price: 10000 }
      skirt:     { str: '스커트',     price: 10000 }
      shirt:     { str: '셔츠',     price: 5000  }
      blouse:    { str: '블라우스', price: 5000  }
      shoes:     { str: '구두',     price: 5000  }
      tie:       { str: '타이',   price: 0     }
      onepiece:  { str: '원피스',   price: 10000 }
      coat:      { str: '코트',     price: 10000 }
      waistcoat: { str: '조끼',     price: 5000  }
      belt:      { str: '벨트',     price: 2000  }
      bag:       { str: '가방',     price: 5000  }
      misc:      { str: '기타',     price: 0     }
    measurement:
      height:   '키'
      weight:   '몸무게'
      neck:     '목 둘레'
      bust:     '가슴 둘레'
      waist:    '허리 둘레'
      hip:      '엉덩이 둘레'
      topbelly: '윗배 둘레'
      belly:    '배꼽 둘레'
      thigh:    '허벅지 둘레'
      arm:      '팔 길이'
      leg:      '다리 길이'
      knee:     '무릎 길이'
      foot:     '발 크기'
      pants:    '바지 길이'
    color:
      black:        '블랙'
      navy:         '네이비'
      gray:         '그레이'
      white:        '화이트'
      brown:        '브라운'
      blue:         '블루'
      red:          '레드'
      orange:       '오렌지'
      yellow:       '옐로우'
      green:        '그린'
      purple:       '퍼플'
      pink:         '핑크'
      charcoalgray: '차콜그레이'
      dark:         '어두운계열'
      etc:          '기타'
      staff:        '직원추천'
    payWith: [
      '현금',
      '카드',
      '계좌이체',
      '현금영수증',
      '세금계산서',
      '미납',
      '쿠폰',
      '쿠폰+현금',
      '쿠폰+카드'
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
    sendSMS: (to, text, cb, from) ->
      data = {to: to, text: text}
      data['from'] = from if from
      $.ajax "/api/sms.json",
        type: 'POST'
        data: data
        success: (data, textStatus, jqXHR) ->
          cb(data, textStatus, jqXHR) if cb
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
    charScreenWidth: (ch) ->
      return 0 if ch is null || ch.length == 0

      charCode = ch.charCodeAt(0)
      return 1 if charCode <= 0x00007F # 1 bytes
      return 2 if charCode <= 0x0007FF # 2 bytes
      return 2 if charCode <= 0x00FFFF # 3 bytes
      return 2
    strScreenWidth: (str) ->
      return 0 if str is null || str.length == 0

      size = 0
      for i in [ 0..str.length ]
        size += OpenCloset.charScreenWidth( str.charAt(i) )
      return size

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
