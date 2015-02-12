$ ->
  ## Global variable
  userID     = undefined
  donationID = undefined

  #
  # step1 - 기증자 검색과 기증자 선택을 연동합니다.
  #
  addRegisteredUserAndDonation = ->
    query = $('#user-search').val()

    return unless query

    $("input[name=user-donation-id]").parent().removeClass("highlight")

    $.ajax "/api/search/user.json",
      type: 'GET'
      data: { q: query }
      success: (data, textStatus, jqXHR) ->
        compiled = _.template($('#tpl-user-id').html())
        _.each data, (user) ->
          unless $("#user-search-list input[data-user-id='#{user.id}']").length
            $html = $(compiled(user))
            $html.find('input').attr('data-json', JSON.stringify(user))
            $("#user-search-list").prepend($html)
        $("input[name=user-donation-id][data-type=user][value=#{ data[0].id }]").click() if data[0]
      error: (jqXHR, textStatus, errorThrown) ->
        type = jqXHR.status is 404 ? 'warning' : 'danger'
        OpenCloset.alert(type, jqXHR.responseJSON.error.str)
      complete: (jqXHR, textStatus) ->

    $.ajax "/api/search/donation.json",
      type: 'GET'
      data: { q: query }
      success: (data, textStatus, jqXHR) ->
        compiled = _.template($('#tpl-donation-id').html())
        _.each data, (donation) ->
          return if donation.user.id is "1"
          unless $("#user-search-list input[data-donation-id='#{donation.id}']").length
            $html = $(compiled(donation))
            $html.find('input').attr('data-json', JSON.stringify(donation))
            $("#user-search-list").prepend($html)
      error: (jqXHR, textStatus, errorThrown) ->
        type = jqXHR.status is 404 ? 'warning' : 'danger'
        OpenCloset.alert(type, jqXHR.responseJSON.error.str)
      complete: (jqXHR, textStatus) ->

  $('#user-search-list').on 'click', ':radio', (e) ->
    userID     = $(@).data('user-id')
    donationID = $(@).data('donation-id')

    return if $(@).val() is '0'

    if donationID
      donation = $(@).data('json')
      user     = donation.user
      $("#create-date").val(donation.create_date.ymd).prop('readonly', 'readonly')
      $("#donation-message").val(donation.message).prop('readonly', 'readonly')
    else
      user = $(@).data('json')
      $("#create-date").val('').removeProp('readonly')
      $("#donation-message").val('').removeProp('readonly')

    _.each [
      'name',
      'email',
      'phone',
      'address',
      'gender',
      'birth',
    ], (name) ->
      $input = $("input[name=#{name}]")
      if $input.attr('type') is 'radio' or $input.attr('type') is 'checkbox'
        $input.each (i, el) ->
          $(el).attr('checked', true) if $(el).val() is user[name]
      else
        $input.val(user[name])

      #
      # http://stackoverflow.com/questions/1953017/why-cant-radio-buttons-be-readonly
      #
      $("input[name=#{name}], input[name=gender]:not(:checked)").attr('disabled', true)

  $('#user-search').keypress (e) -> addRegisteredUserAndDonation() if e.keyCode is 13
  $('#btn-user-search').click -> addRegisteredUserAndDonation()
  addRegisteredUserAndDonation()

  #
  # step3 - 의류 종류 선택 콤보박스
  #
  clear_clothes_form = (show) ->
    if show
      _.each [ 'bust', 'waist', 'hip', 'topbelly', 'belly', 'thigh', 'arm', 'length', 'foot' ], (name) ->
        $("#display-clothes-#{name}").show()
    else
      _.each [ 'bust', 'waist', 'hip', 'topbelly', 'belly', 'thigh', 'arm', 'length', 'foot' ], (name) ->
        $("#display-clothes-#{name}").hide()

    $('#clothes-code').val('')
    $('input[name=clothes-gender]').prop('checked', false)
    $('#clothes-color').select2('val', '')
    _.each [ 'bust', 'waist', 'hip', 'topbelly', 'belly', 'thigh', 'arm', 'length', 'foot' ], (name) ->
      $("#clothes-#{name}").prop('disabled', true).val('')

  $('#clothes-category').select2({
    dropdownCssClass: 'bigdrop'
    data:             ( { id: k, text: v.str } for k, v of OpenCloset.category )
  })
    .on 'change', (e) ->
      clear_clothes_form false
      types = []
      switch e.val
        when 'jacket'    then types = [ 'bust', 'arm', 'topbelly', 'belly'      ]
        when 'pants'     then types = [ 'waist', 'hip', 'thigh', 'length'       ]
        when 'shirt'     then types = [ 'bust', 'arm', 'topbelly', 'belly'      ]
        when 'waistcoat' then types = [ 'waist', 'topbelly', 'belly'            ]
        when 'coat'      then types = [ 'bust', 'arm', 'length'                 ]
        when 'onepiece'  then types = [ 'bust', 'waist', 'hip', 'arm', 'length' ]
        when 'skirt'     then types = [ 'waist', 'hip', 'length'                ]
        when 'blouse'    then types = [ 'bust', 'arm'                           ]
        when 'belt'      then types = [ 'length'                                ]
        when 'shoes'     then types = [ 'foot'                                  ]
        else                  types = [                                         ]
      for type in types
        $("#display-clothes-#{type}").show()
        $("#clothes-#{type}").prop('disabled', false)
  $('#clothes-color').select2({
    dropdownCssClass: 'bigdrop'
    data:             ( { id: i, text: OpenCloset.color[i] } for i in [ 'black', 'navy', 'gray', 'white', 'brown', 'blue', 'red', 'orange', 'yellow', 'green', 'purple', 'pink', 'charcoalgray' ] )
  })

  $('#clothes-category').select2('val', '')
  clear_clothes_form true

  #
  # step3 - 의류 폼 초기화
  #
  $('#btn-clothes-reset').click ->
    $('#clothes-category').select2('val', '')
    clear_clothes_form true

  #
  # step3 - 의류 추가
  #
  $('#btn-clothes-add').click ->
    data =
      user_id:              userID
      clothes_code:         $('#clothes-code').val().toUpperCase()
      clothes_category:     $('#clothes-category').val()
      clothes_category_str: $('#clothes-category option:selected').text()
      clothes_gender:       $('input[name=clothes-gender]:checked').val()
      clothes_gender_str:   $('input[name=clothes-gender]:checked').next().text()
      clothes_color:        $('#clothes-color').val()
      clothes_color_str:    OpenCloset.color[ $('#clothes-color').val() ]
      clothes_bust:         $('#clothes-bust').val()
      clothes_waist:        $('#clothes-waist').val()
      clothes_hip:          $('#clothes-hip').val()
      clothes_topbelly:     $('#clothes-topbelly').val()
      clothes_belly:        $('#clothes-belly').val()
      clothes_thigh:        $('#clothes-thigh').val()
      clothes_arm:          $('#clothes-arm').val()
      clothes_length:       $('#clothes-length').val()
      clothes_foot:         $('#clothes-foot').val()

    return unless data.clothes_category

    #
    # 입력한 의류 정보 검증
    #
    count = 0
    valid_count = 0
    if $('#clothes-color').val()
      count++
      valid_count++
    else
      count++
    $('#step3 input:enabled').each (i, el) ->
      return unless /^clothes-/.test( $(el).attr('id') )
      count++
      switch $(el).attr('id')
        when 'clothes-code'     then valid_count++ if /^[a-z0-9]{4,5}$/i.test( $(el).val() )
        when 'clothes-color'    then valid_count++ if $(el).val()
        when 'clothes-category' then valid_count++ if $(el).val()
        else                         valid_count++ if $(el).val() > 0
    unless count == valid_count
      OpenCloset.alert('warning', '빠진 항목이 있습니다.')
      return

    $.ajax "/api/clothes/#{ data.clothes_code }.json",
      type: 'GET'
      dataType: 'json'
      success: (data, textStatus, jqXHR) ->
        OpenCloset.alert('warning', '이미 존재하는 의류 코드입니다.')
      error: (jqXHR, textStatus, errorThrown) ->
        unless jqXHR.status is 404
          OpenCloset.alert('warning', '의류 코드 오류입니다.')
          return

        compiled = _.template($('#tpl-clothes-item').html())
        html = $(compiled(data))
        $('#display-clothes-list').append(html)

        $('#btn-clothes-reset').click()
        $('#clothes-category').focus()
      complete: (jqXHR, textStatus) ->

  #
  # step3 - 추가한 모든 의류 선택 또는 해제
  #
  $('#btn-clothes-select-all').click ->
    count   = 0
    checked = 0
    $('input[name=clothes-list]').each (i, el) ->
      count++
      checked++ if $(el).prop('checked')
    $('input[name=clothes-list]').prop( 'checked', ( checked < count ? true : false ) )

  #
  # 마법사 위젯
  #
  validation = false
  $('#fuelux-wizard').ace_wizard()
    .on 'change', (e, info) ->
      if info.step is 1 && validation
        return false unless $('#validation-form').valid()

      # "다음"으로 움직일 때만 Ajax 호출을 수행하고
      # "이전"으로 움직일 때는 아무 동작도 수행하지 않습니다.
      return true unless info.direction is 'next'

      ajax = {}
      switch info.step
        when 1
          unless userID or donationID
            OpenCloset.alert('warning', '기증자나 기증 행위를 선택하지 않았습니다.')
            e.preventDefault()
            return
        when 2
          unless /^\d{4}-\d{2}-\d{2}$/.test( $('#create-date').val() )
            OpenCloset.alert('warning', '기증 날짜가 올바르지 않습니다.')
            e.preventDefault()
            return
        when 3
          ###
          #
          # #211 - 개별 옷을 등록하지 않고 기증행위가 등록이 가능해야 함
          #
          # 개별 옷 등록 없이 기증행위를 등록할 수 있기를 바라므로 추가할
          # 의류를 선택했는지 여부를 확인하는 코드를 주석 처리합니다.
          #
          unless $("input[name=clothes-list]:checked").length
            OpenCloset.alert('warning', '추가할 의류를 선택하지 않았습니다.')
            e.preventDefault()
            return
          ###

          #
          # FIXME do we need a single API for transaction?
          #

          createGroupClothes = (donationID) ->
            #
            # create group
            #
            $.ajax "/api/group.json",
              type: 'POST'
              success: (group, textStatus, jqXHR) ->
                #
                # create clothes
                #
                $("input[name=clothes-list]:checked").each (i, el) ->
                  $.ajax "/api/clothes.json",
                    type: 'POST'
                    data:
                      donation_id: donationID
                      group_id:    group.id
                      code:        $(el).data('clothes-code')
                      category:    $(el).data('clothes-category')
                      gender:      $(el).data('clothes-gender')
                      color:       $(el).data('clothes-color')
                      bust:        $(el).data('clothes-bust')
                      waist:       $(el).data('clothes-waist')
                      hip:         $(el).data('clothes-hip')
                      topbelly:    $(el).data('clothes-topbelly')
                      belly:       $(el).data('clothes-belly')
                      thigh:       $(el).data('clothes-thigh')
                      arm:         $(el).data('clothes-arm')
                      length:      $(el).data('clothes-length')
                      foot:        $(el).data('clothes-foot')
                      price:       OpenCloset.category[ $(el).data('clothes-category') ].price
                    success: (data, textStatus, jqXHR) ->
                    error: (jqXHR, textStatus, errorThrown) ->
                      OpenCloset.alert('warning', jqXHR.responseJSON.error.str)
                    complete: (jqXHR, textStatus) ->
              error: (jqXHR, textStatus, errorThrown) ->
                OpenCloset.alert('warning', jqXHR.responseJSON.error.str)
              complete: (jqXHR, textStatus) ->

          if donationID
            createGroupClothes donationID
          else
            create_date = $('#create-date').val()

            #
            # create donation
            #
            $.ajax "/api/donation.json",
              type: 'POST'
              data:
                user_id:     userID
                message:     $('#donation-message').val()
                create_date: moment(create_date).unix()
              success: (donation, textStatus, jqXHR)  -> createGroupClothes donation.id
              error: (jqXHR, textStatus, errorThrown) ->
                OpenCloset.alert('warning', jqXHR.responseJSON.error.str)
              complete: (jqXHR, textStatus) ->
        else return

    .on 'finished', (e) ->
      location.href = "/new-clothes"
      false
    .on 'stepclick', (e) ->
      # false
