# Handlebars helper
Handlebars.registerHelper 'category2hangul', (c) ->
  category = OpenCloset.category[c]?.str or c
  category

Handlebars.registerHelper 'preCategory', (preCategory, gender) ->
  categories = {}
  _.map preCategory.split(','), (c) -> categories[c] = true

  if gender is 'female'
    if not _.has categories, 'skirt' and not _.has categories, 'blouse'
      _.map ['jacket', 'pants', 'skirt', 'shirt', 'blouse', 'shoes', 'belt', 'tie'], (c) ->
        categories[c] = false unless categories[c]
    else
      _.map ['jacket', 'skirt', 'blouse', 'shoes'], (c) ->
        categories[c] = false unless categories[c]
  else
    _.map ['jacket', 'pants', 'shirt', 'shoes', 'belt', 'tie'], (c) ->
      categories[c] = false unless categories[c]
  categories

Handlebars.registerHelper 'preCategoryCnt', (preCategory) ->
  preCategory.split(',').length

$ ->
  $('#clothes-id').focus()
  $('#btn-clear').click (e) ->
    e.preventDefault()
    $('#clothes-table table tbody tr').remove()
    $('#order-table table tbody tr').remove()
    $('#action-buttons').hide()
    $('#clothes-id').focus()
  $('#btn-search').click (e) ->
    $('#search-form').trigger('submit')

  #
  # 대여 희망 품목을 코드가 아닌 레이블로 표시
  #
  category_localize = ($el) ->
    value = $el.html()
    return unless value

    mapped_values = []
    for i in value.split(',')
      item = OpenCloset.category[i]
      continue unless item
      str = item.str.replace /^\s+|\s+$/, ""
      continue if str is ''
      mapped_values.push str
      $el.html( mapped_values.join(',') )

  $('#search-form').submit (e) ->
    e.preventDefault()
    clothes_id = $('#clothes-id').val().toUpperCase()
    $('#clothes-id').val('').focus()
    return unless clothes_id

    #
    # 의류 검색 및 결과 테이블 갱신
    #
    $.ajax "/api/clothes/#{clothes_id}.json",
      type: 'GET'
      dataType: 'json'
      success: (data, textStatus, jqXHR) ->
        data.code        = data.code.replace /^0/, ''
        data.categoryStr = OpenCloset.category[ data.category ].str

        return if $("#clothes-table table tbody tr[data-clothes-code='#{data.code}']").length

        data.count = $("#clothes-table table tbody tr").length + 1
        if data.status is '대여중'
          compiled = _.template($('#tpl-row-checkbox-disabled-with-order').html())
          $html = $(compiled(data))
          if data.order.overdue
            compiled = _.template($('#tpl-overdue-paragraph').html())
            html     = compiled(data)
            $html.find("td:last-child").append(html)
        else if data.status is '대여가능'
          compiled = _.template($('#tpl-row-checkbox-enabled').html())
          $html = $(compiled(data))
          $('#action-buttons').show() if data.status is '대여가능'
        else if data.status in [ '반납', '세탁', '수선', '포장취소', '예약', '대여불가' ]
          compiled = _.template($('#tpl-row-checkbox-readonly-without-order').html())
          $html = $(compiled(data))
        else
          compiled = _.template($('#tpl-row-checkbox-disabled-without-order').html())
          $html = $(compiled(data))

        $html.find('.order-status').addClass OpenCloset.status[ data.status ].css
        $("#clothes-table table tbody").append($html)
      error: (jqXHR, textStatus, errorThrown) ->
        msg = "#{clothes_id}: "
        switch jqXHR.status
          when 400
            msg += '의류 코드가 정확하지 않습니다.'
          when 404
            msg += '의류 코드가 없습니다.'
          else
            msg += '알 수 없는 오류입니다.'
        OpenCloset.alert 'warning', msg
      complete: (jqXHR, textStatus) ->

  #
  # 의류 검색 결과 테이블에서 모든 항목 선택 및 취소
  #
  $('#input-check-all').click (e) ->
    is_checked = $('#input-check-all').is(':checked')
    $(@).closest('thead').next().find(':checkbox:not(:disabled):not([readonly])').prop('checked', is_checked)

  getPreCategory = () ->
    order = $('input[name=id]:checked').val()
    return $("tr[data-order-id=#{order}] td.pre_category").data("pre-category").split(",").sort().join(",")

  getPostCategory = () ->
    category = []
    $('input[name=clothes_code]:checked').each (i, el) ->
      return if $(el).attr('id') is 'input-check-all'
      category.push($(el).data('category'))
    return category.sort().join(",")

  isPrePostCategorySame = () ->
    return getPreCategory() == getPostCategory()

  #
  # 대여 버튼 클릭
  #
  $('#action-buttons').click (e) ->
    order = $('input[name=id]:checked').val()

    clothes = []
    $('input[name=clothes_code]:checked').each (i, el) ->
      return if $(el).attr('id') is 'input-check-all'
      clothes.push($(el).data('clothes-code'))
    clothes = _.uniq(clothes)

    return OpenCloset.alert('danger', '대여할 주문서를 선택해 주세요') unless order
    return OpenCloset.alert('danger', '대여할 옷을 선택해 주세요.')    unless clothes

    if isPrePostCategorySame()
      $('#order-form').submit()
    else
      $("#modal-rental").modal('show')

  #
  # 대여 모달이 열릴 때
  #
  $("#modal-rental").on "show.bs.modal", (e) ->
    pre_category_str  = ( OpenCloset.category[i].str for i in getPreCategory().split(",")  ).join(",")
    post_category_str = ( OpenCloset.category[i].str for i in getPostCategory().split(",") ).join(",")

    $("#modal-rental .pre_category").html(pre_category_str)
    $("#modal-rental .post_category").html(post_category_str)

  #
  # 대여 모달에서 대여 취소
  #
  $("#btn-rental-modal-cancel").click (e) ->
    $("#modal-rental .pre_category").html("")
    $("#modal-rental .post_category").html("")
    $("input[name=id]:checked").prop("checked", false)
    $("#modal-rental").modal("hide")

  #
  # 대여 모달에서 대여 진행
  #
  $("#btn-rental-modal-ok").click (e) ->
    $("#modal-rental .pre_category").html("")
    $("#modal-rental .post_category").html("")
    $("#modal-rental").modal("hide")
    $('#order-form').submit()

  #
  # 착용 버튼 토글
  #
  DOES_WEAR_MAP = { 0: '안입고감', 1: '입고감', 2: '기록요망', 3: '입고감+기록요망' }
  $('#order-table').on 'click', '.btn-wearing:not(.disabled)', (e) ->
    $this = $(@)
    $this.addClass('disabled')

    does_wear = parseInt($this.data('does-wear')) + 1
    does_wear = 0 if does_wear > 3
    order_id = $this.closest('tr').data('order-id')

    $.ajax "/api/order/#{order_id}.json",
      type: 'PUT'
      data:
        id: order_id
        does_wear: does_wear
      success: (data, textStatus, jqXHR) ->
        $this.data('does-wear', does_wear).html(DOES_WEAR_MAP[does_wear])
      error: (jqXHR, textStatus, errorThrown) ->
        OpenCloset.alert('danger', "착용여부 변경에 실패했습니다: #{jqXHR.responseJSON.error.str}")
      complete: (jqXHR, textStatus) ->
        $this.removeClass('disabled')

  $("#clothes-table table tbody").on 'click', 'input[type=checkbox][readonly=readonly]', (e) ->
    e.preventDefault()

    return unless confirm "대여가능 상태로 변경하시겠습니까?"

    $this = $(@)
    clothes_code = $this.closest('tr').data('clothes-code')
    category = $this.closest('tr').data('category')
    $.ajax "/api/clothes/#{clothes_code}",
      type: 'PUT'
      data: { status_id: OpenCloset['status']['대여가능']['id'] }
      dataType: 'json'
      success: (data, textStatus, jqXHR) ->
        OpenCloset.alert 'info', "#{clothes_code} 의류 상태가 대여가능으로 변경되었습니다"
        $this.closest('td').nextAll().slice(2, 3).find('span').text('대여가능').removeClass('label-inverse').addClass(OpenCloset.status["대여가능"].css)
        $this.data('clothes-code', clothes_code).data('category', category).prop('value', clothes_code).prop('name', 'clothes_code').prop('checked', true)
        $('#action-buttons').show()
      error: (jqXHR, textStatus, errorThrown) ->
        OpenCloset.alert('danger', "의류 상태변경에 실패했습니다: #{jqXHR.responseJSON.error.str}")
      complete: ->
        $this.prop('readonly',false)

  #
  # 탈의 -> 포장, 수선 -> 포장 버튼
  #
  $('#list-fitting-room-repair').on 'click', '.btn-update-status:not(.disabled)', (e) ->
    e.preventDefault()
    $this = $(@)
    $this.addClass('disabled')

    order_id = $this.closest('li').data('order-id')
    $.ajax $this.prop('href'),
      type: 'PUT'
      data: { status_id: OpenCloset.status['포장'].id }
      dataType: 'json'
      success: (data, textStatus, jqXHR) ->
        $.ajax "/rental/order/#{order_id}",
          type: 'GET'
          dataType: 'json'
          success: (data, textStatus, jqXHR) ->
            data.order.does_wear     = parseInt(data.order.does_wear)
            data.order.does_wear_str = DOES_WEAR_MAP[data.order.does_wear]
            template = JST['rental/order-table-item']
            html     = template(data)
            $('#order-table tbody').append(html)
            $editable = $('#order-table tbody tr:last-child .editable')
            editableOn($editable)
          error: (jqXHR, textStatus, errorThrown) ->
          complete: (jqXHR, textStatus) ->
            $this.closest('li').remove()

      error: (jqXHR, textStatus, errorThrown) ->
      complete: (jqXHR, textStatus) ->
        $this.removeClass('disabled')

  #
  # 탈의/수선 목록의 실시간 갱신
  #
  REPAIR_RANGE = [6]
  ROOM_RANGE   = [20..39]
  RANGE = []
  RANGE.push i for i in REPAIR_RANGE
  RANGE.push i for i in ROOM_RANGE
  ymd = location.pathname.split('/').pop()
  url  = "#{CONFIG.monitor_uri}/socket".replace 'http', 'ws'
  sock = new ReconnectingWebSocket url, null, { debug: false }
  sock.onopen = (e) ->
    sock.send '/subscribe order'
  sock.onmessage = (e) ->
    data = JSON.parse(e.data)

    return if data.order.booking.date.substr(0, 10) isnt ymd

    from = parseInt(data.from)
    to   = parseInt(data.to)

    if from in RANGE
      $("#list-fitting-room-repair li[data-order-id=#{data.order.id}]").remove()

    if to in RANGE
      if to in REPAIR_RANGE
        data.order.status_name = '수선'
      if to in ROOM_RANGE
        num = to - 19
        if num < 10 then num = '0' + num
        data.order.status_name = '탈의' + num

      template = JST['rental/fitting-room-repair-item']
      html     = template(data)
      $('#list-fitting-room-repair').append(html)

  sock.onerror = (e) ->
    location.reload()

  #
  # 주문서 검색 자동완성
  #
  suggestion = new Bloodhound
    datumTokenizer: Bloodhound.tokenizers.obj.whitespace('phone')
    queryTokenizer: Bloodhound.tokenizers.whitespace
    remote:
      url: "#{location.pathname}/search?q=%QUERY"
      wildcard: '%QUERY'

  $('#query.typeahead').typeahead null,
    name: 'q'
    display: 'phone'
    source: suggestion
    limit: 10
    templates:
      empty: [
        '<div class="empty-message">',
          'oops, order not found',
        '</div>'
      ].join('\n')
      suggestion: (data) ->
        template = JST['rental/typeahead-query']
        html     = template(data)
        return html

  $('#query.typeahead').on 'typeahead:select', (e, data) ->
    data.status =
      visited:         OpenCloset.status['방문'].id
      prepare_clothes: OpenCloset.status['의류준비'].id

    only_shoes_or_tie = true
    contain_shoes     = false
    for c in data.pre_category.split(",")
      if c == "shoes"
        contain_shoes = true
        continue
      continue if c == "tie"
      only_shoes_or_tie = false
      break
    data.only_shoes_or_tie = only_shoes_or_tie
    data.contain_shoes     = contain_shoes

    template = JST['rental/typeahead-select']
    html     = template(data)
    $('#selected').html(html)

  #
  # 방문예약 -> 방문 버튼
  # 방문예약 -> 의류준비 버튼
  #
  changeOrderStatus = ($jqElem, statusId) ->
    $.ajax $jqElem.prop("href"),
      type: "PUT"
      data: { status_id: statusId }
      success: (data, textStatus, jqXHR) ->
        $("#query").val("")
        $("#selected").empty()
      error: (jqXHR, textStatus, errorThrown) ->
      complete: (jqXHR, textStatus) ->
        $(".btn-update-status").removeClass("disabled")

  $("#selected").on "click", ".btn-update-status:not(.disabled)", (e) ->
    e.preventDefault()

    $(".btn-update-status").addClass("disabled")
    $this = $(@)
    status_id = $this.data("status-id")

    #
    # 의류준비면서 구두가 있을 경우 구두 사이즈를 입력 받음
    #
    if status_id == OpenCloset.status["의류준비"].id
      pre_category = $this.data("pre-category")
      if /shoes/.test( pre_category )
        footSize    = $("#foot-size").val()
        urlFootSize = $("#foot-size").data("url")
        unless footSize
          OpenCloset.alert "warning", "발 크기를 입력하세요."
          $(".btn-update-status").removeClass("disabled")
          return
        unless /^\d+$/.test( footSize )
          OpenCloset.alert "warning", "유효하지 않은 발 크기 입니다."
          $(".btn-update-status").removeClass("disabled")
          return
        $.ajax urlFootSize,
          type: "PUT"
          data: { foot: footSize }
          success: (data, textStatus, jqXHR) ->
            changeOrderStatus($this, status_id)
          error: (jqXHR, textStatus, errorThrown) ->
            OpenCloset.alert "warning", "발 크기 입력에 실패했습니다. 다시 시도해주세요."
            $(".btn-update-status").removeClass("disabled")
            return
          complete: (jqXHR, textStatus) ->
        return
    changeOrderStatus($this, status_id)

  #
  # 바지길이 수정
  #
  editableOn = ($el) ->
    params =
      mode:        'inline'
      showbuttons: 'true'
      emptytext:   '바지길이'
      pk:          1
      url: (params) ->
        data = {}
        data[params.name] = params.value
        $.ajax "/api/order/#{$el.data('order-id')}",
          type: 'PUT'
          dataType: 'json'
          data: data
        $.ajax "/api/user/#{$el.data('user-id')}",
          type: 'PUT'
          dataType: 'json'
          data: data

    $el.editable params

  $('.editable').each (i, el) ->
    $el = $(el)
    editableOn($el)

  #
  # 대여희망품목의 수정
  #
  $('#order-table').on 'click', '.label-category', (e) ->
    $(@).toggleClass('label-default label-success')
    $td = $(@).closest('.pre_category')
    user_id = $td.data('user-id')

    categories = []
    $td.find('.label-success').each ->
      categories.push $(@).data('category')

    preCategory = categories.join(',')
    $td.data('pre-category', preCategory)
    $td.find('.category-cnt').text(categories.length)

    $.ajax "/api/user/#{user_id}",
      type: 'PUT'
      dataType: 'json'
      data: { pre_category: preCategory }
      success: (data, textStatus, jqXHR) ->
      error: (jqXHR, textStatus, errorThrown) ->
        location.reload()
      complete: (jqXHR, textStatus) ->
