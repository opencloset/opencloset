$ ->
  #
  # 입력창에 포커스
  #
  $('#query').focus()

  #
  # 입력창 키코드 맵핑
  #
  $('#query').keyup (e) ->
    switch e.keyCode
      when 13 then $('#btn-search').click()
      when 27 then $('#query').val('')

  #
  # 검색 버튼 클릭
  #
  $('#btn-search').click (e) ->
    url = "#{window.location.pathname}?#{$.param( { q: $('#query').val() } )}"
    window.location.assign url
  #
  # 지우기 버튼 클릭
  #
  $('#btn-clear').click (e) ->
    $('#query').val('')
    $('#query').focus()

  $('#donation-table tbody').on 'dblclick', 'span', (e) ->
    e.preventDefault()
    $this = $(@)
    code = $this.data('clothes-code')
    donation_id = $this.data('donation-id')
    unless donation_id
      OpenCloset.alert 'danger', '기증 ID 를 찾을 수 없습니다'
      return
    $.ajax "/api/clothes/#{code}.json",
      type: 'PUT'
      data: { donation_id: null }
      success: (data, textStatus, jqXHR) ->
        localStorage.setItem(code, donation_id)
        $this.parent().appendTo('#clothes-bucket ul')
      error: (jqXHR, textStatus, errorThrown) ->
        console.log textStatus
      complete: (jqXHR, textStatus) ->

  $('#clothes-bucket').on 'dblclick', 'span', (e) ->
    e.preventDefault()
    $this = $(@)
    code = $this.data('clothes-code')
    donation_id = $this.data('donation-id') or localStorage.getItem(code)
    unless donation_id
      OpenCloset.alert 'danger', '기증 ID 를 찾을 수 없습니다(새로고침을 해보세요)'
      return
    $this.attr('data-donation-id', donation_id)
    $.ajax "/api/clothes/#{code}.json",
      type: 'PUT'
      data: { donation_id: donation_id }
      success: (data, textStatus, jqXHR) ->
        $this.parent().appendTo("#donation-#{donation_id} td:nth-child(4) ul")
      error: (jqXHR, textStatus, errorThrown) ->
        console.log textStatus
      complete: (jqXHR, textStatus) ->
