$(function() {
  var beforeSendSMS, signup, validateSMS, visitError;
  signup = false;
  $(".purpose .clickable.label").click(function() {
    var new_purpose, old_purpose;
    old_purpose = $("input[name=purpose]").val();
    new_purpose = $(this).text();
    return $("input[name=purpose]").prop("value", $.trim("" + old_purpose + " " + new_purpose));
  });
  $("#btn-service-disagree").click(function(e) {
    $("input[name=service]").prop("checked", false);
    $("#modal-service .modal-body").scrollTop(0);
    return $("#modal-service").modal('hide');
  });
  $("#btn-service-agree").click(function(e) {
    $("input[name=service]").prop("checked", true);
    $("#modal-service .modal-body").scrollTop(0);
    return $("#modal-service").modal('hide');
  });
  $("input[name=service]").click(function(e) {
    if ($(this).prop("checked")) {
      $(this).prop("checked", false);
      return $("#modal-service").modal('show');
    }
  });
  $("#btn-privacy-disagree").click(function(e) {
    $("input[name=privacy]").prop("checked", false);
    $("#modal-privacy .modal-body").scrollTop(0);
    return $("#modal-privacy").modal('hide');
  });
  $("#btn-privacy-agree").click(function(e) {
    $("input[name=privacy]").prop("checked", true);
    $("#modal-privacy .modal-body").scrollTop(0);
    return $("#modal-privacy").modal('hide');
  });
  $("input[name=privacy]").click(function(e) {
    if ($(this).prop("checked")) {
      $(this).prop("checked", false);
      return $("#modal-privacy").modal('show');
    }
  });
  setTimeout(function() {
    return $('.alert').remove();
  }, 5000);
  visitError = function(msg) {
    $('#visit-alert').prepend("<div class=\"alert alert-danger\"><button class=\"close\" type=\"button\" data-dismiss=\"alert\">&times;</button>" + msg + "</div>");
    return setTimeout(function() {
      return $('.alert').remove();
    }, 5000);
  };
  beforeSendSMS = function() {
    $(".sms").removeClass('block').hide();
    $("#btn-sms-confirm-label").html('SMS 인증번호 전송');
    return $("#btn-sms-confirm").prop("disabled", false);
  };
  beforeSendSMS();
  $(".signup").removeClass('block').hide();
  $('#btn-sms-reset').click(function(e) {
    return beforeSendSMS();
  });
  validateSMS = function(phone) {
    var timer, validate_end;
    OpenCloset.sendSMSValidation(phone);
    $(".sms").addClass('block').show();
    $("#btn-sms-confirm-label").html('SMS 인증하기');
    validate_end = moment().add('m', 5);
    $("#sms-remain-seconds").html(validate_end.diff(moment(), 'seconds'));
    return timer = setInterval(function() {
      var validate_remain;
      validate_remain = validate_end.diff(moment(), 'seconds');
      if (validate_remain > 0) {
        return $("#sms-remain-seconds").html(validate_remain);
      } else {
        $("#sms-remain-seconds").html(0);
        $("#btn-sms-confirm").prop("disabled", true);
        return clearInterval(timer);
      }
    }, 500);
  };
  $('#btn-sms-confirm').click(function(e) {
    var address, birth, email, gender, name, phone, privacy, service, sms;
    e.preventDefault();
    name = $("input[name=name]").val();
    phone = $("input[name=phone]").val();
    service = $("input[name=service]").prop("checked");
    privacy = $("input[name=privacy]").prop("checked");
    sms = $("input[name=sms]").val();
    gender = $("input[name=gender]:checked").val();
    email = $("input[name=email]").val();
    address = $("input[name=address]").val();
    birth = $("input[name=birth]").val();
    if (name && phone && service && privacy && sms) {
      return $('#visit-form').submit();
    } else {
      if (!name) {
        visitError('이름을 입력해주세요.');
        return;
      }
      if (!phone) {
        visitError('휴대전화를 입력해주세요.');
        return;
      }
      if (!/^\d+$/.test(phone)) {
        visitError('유효하지 않은 휴대전화입니다.');
        return;
      }
      if (/^999/.test(phone)) {
        visitError('전송 불가능한 휴대전화입니다.');
        return;
      }
      if (!service) {
        visitError('서비스 이용약관을 확인해주세요.');
        return;
      }
      if (!privacy) {
        visitError('개인정보 이용안내를 확인해주세요.');
        return;
      }
      if (signup) {
        if (!gender) {
          visitError('성별을 입력해주세요.');
          return;
        }
        if (!email) {
          visitError('전자우편을 입력해주세요.');
          return;
        }
        if (!address) {
          visitError('주소를 입력해주세요.');
          return;
        }
        if (!birth) {
          visitError('생년을 입력해주세요.');
          return;
        }
        if (!/^(19|20)|\d\d$/.test(birth)) {
          visitError('유효하지 않은 생년입니다.');
          return;
        }
        return $.ajax("/api/user.json", {
          type: 'POST',
          data: {
            name: name,
            email: email,
            address: address,
            gender: gender,
            phone: phone,
            birth: birth
          },
          success: function(data, textStatus, jqXHR) {
            signup = false;
            return validateSMS(phone);
          },
          error: function(jqXHR, textStatus, errorThrown) {
            return visitError('서버 오류가 발생했습니다.');
          }
        });
      } else {
        return $.ajax("/api/search/user.json", {
          type: 'GET',
          data: {
            q: phone
          },
          success: function(data, textStatus, jqXHR) {
            var user;
            if (data.length !== 1) {
              visitError('휴대전화가 중복되었습니다.');
              return;
            }
            user = data[0];
            if (user.name !== name) {
              visitError('이름과 휴대전화가 일치하지 않습니다.');
              return;
            }
            return validateSMS(phone);
          },
          error: function(jqXHR, textStatus, errorThrown) {
            var type, _ref;
            type = (_ref = jqXHR.status === 404) != null ? _ref : {
              'warning': 'danger'
            };
            if (jqXHR.status === 404) {
              visitError('사용자 등록이 필요합니다. 추가 정보를 입력해주세요.');
              $(".signup").addClass('block').show();
              return signup = true;
            } else {
              return visitError('서버 오류가 발생했습니다.');
            }
          }
        });
      }
    }
  });
  $('#btn-booking-cancel').click(function(e) {
    var name, phone, sms;
    e.preventDefault();
    name = $("input[name=name]").val();
    phone = $("input[name=phone]").val();
    sms = $("input[name=sms]").val();
    if (name && phone && sms) {
      $("input[name=booking]").prop("value", '-1');
      return $('#visit-info-form').submit();
    } else {
      if (!name) {
        visitError('이름을 입력해주세요.');
        return;
      }
      if (!phone) {
        visitError('휴대전화를 입력해주세요.');
        return;
      }
      if (!/^\d+$/.test(phone)) {
        visitError('유효하지 않은 휴대전화입니다.');
        return;
      }
      if (/^999/.test(phone)) {
        visitError('전송 불가능한 휴대전화입니다.');
        return;
      }
      if (!sms) {
        visitError('인증번호를 입력해주세요.');
      }
    }
  });
  $('#btn-info').click(function(e) {
    var address, birth, booking, company, email, gender, height, name, phone, purpose, sms, weight;
    e.preventDefault();
    name = $("input[name=name]").val();
    phone = $("input[name=phone]").val();
    sms = $("input[name=sms]").val();
    gender = $("input[name=gender]:checked").val();
    email = $("input[name=email]").val();
    address = $("input[name=address]").val();
    birth = $("input[name=birth]").val();
    height = $("input[name=height]").val();
    weight = $("input[name=weight]").val();
    booking = $("input[name=booking]").val();
    purpose = $("input[name=purpose]").val();
    company = $("input[name=company]").val();
    if (name && phone && sms && gender && email && address && birth && height && weight && booking && purpose && company) {
      return $('#visit-info-form').submit();
    } else {
      if (!name) {
        visitError('이름을 입력해주세요.');
        return;
      }
      if (!phone) {
        visitError('휴대전화를 입력해주세요.');
        return;
      }
      if (!/^\d+$/.test(phone)) {
        visitError('유효하지 않은 휴대전화입니다.');
        return;
      }
      if (/^999/.test(phone)) {
        visitError('전송 불가능한 휴대전화입니다.');
        return;
      }
      if (!sms) {
        visitError('인증번호를 입력해주세요.');
        return;
      }
      if (!gender) {
        visitError('성별을 입력해주세요.');
        return;
      }
      if (!email) {
        visitError('전자우편을 입력해주세요.');
        return;
      }
      if (!address) {
        visitError('주소를 입력해주세요.');
        return;
      }
      if (!birth) {
        visitError('생년을 입력해주세요.');
        return;
      }
      if (!/^(19|20)|\d\d$/.test(birth)) {
        visitError('유효하지 않은 생년입니다.');
        return;
      }
      if (!height) {
        visitError('키를 입력해주세요.');
        return;
      }
      if (!/^\d+$/.test(height)) {
        visitError('유효하지 않은 키입니다.');
        return;
      }
      if (!weight) {
        visitError('몸무게를 입력해주세요.');
        return;
      }
      if (!/^\d+$/.test(weight)) {
        visitError('유효하지 않은 몸무게입니다.');
        return;
      }
      if (!booking) {
        visitError('방문 일자를 선택해주세요.');
        return;
      }
      if (!purpose) {
        visitError('대여 목적을 입력해주세요.');
        return;
      }
      if (!company) {
        visitError('응시 기업 및 분야를 입력해주세요.');
      }
    }
  });
  $('#btn-booking').click(function(e) {
    var gender, old_booking_id;
    e.preventDefault();
    gender = $("input[name=gender]:checked").val();
    old_booking_id = $("input[name=booking]").prop("value");
    return $.ajax("/api/gui/booking-list.json", {
      type: 'GET',
      data: {
        gender: gender
      },
      success: function(data, textStatus, jqXHR) {
        var booking, compiled, _i, _len, _results;
        $("#booking-list").html('');
        _results = [];
        for (_i = 0, _len = data.length; _i < _len; _i++) {
          booking = data[_i];
          compiled = _.template($('#tpl-booking').html());
          $("#booking-list").append($(compiled(booking)));
          _results.push($("input[type='radio'][name='booking_id'][value='" + old_booking_id + "']").prop("checked", true));
        }
        return _results;
      },
      error: function(jqXHR, textStatus, errorThrown) {
        return console.log(jqXHR.status);
      }
    });
  });
  $("#btn-booking-modal-cancel").click(function(e) {
    $("#modal-booking .modal-body").scrollTop(0);
    return $("#modal-booking").modal('hide');
  });
  $("#btn-booking-modal-confirm").click(function(e) {
    var booking;
    booking = $("input[type='radio'][name='booking_id']:checked");
    if (booking) {
      $("input[name=booking]").prop("value", booking.data('id'));
      $("#lbl-booking").html(" - " + (booking.data('ymd')) + " " + (booking.data('hm')));
      $("#modal-booking .modal-body").scrollTop(0);
      return $("#modal-booking").modal('hide');
    }
  });
  return $("input[name=gender]").click(function(e) {
    $("input[name=booking]").prop("value", '');
    return $("#lbl-booking").html('');
  });
});
