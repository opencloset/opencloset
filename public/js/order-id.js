$(function() {
  var autoSetByAdditionalDay, countSelectedOrderDetail, refreshReturnButton, returnClothesReal, returnOrder, selectSearchedClothes, setOrderDetailFinalPrice, updateOrder;
  updateOrder = function() {
    var order_id;
    order_id = $('#order').data('order-id');
    return $.ajax("/api/order/" + order_id + ".json", {
      type: 'GET',
      success: function(data, textStatus, jqXHR) {
        var compiled;
        $('#order').data('order-clothes-price', data.clothes_price);
        $('#order').data('order-late-fee', data.late_fee);
        $('#order').data('order-late-fee-discount', 0);
        $('#order').data('order-late-fee-final', data.late_fee);
        $('#order').data('order-late-fee-pay-with', data.late_fee_pay_with);
        $('#order').data('order-overdue', data.overdue);
        $('#order').data('order-parent-id', data.parent_id);
        $(".order-stage0-price").html(OpenCloset.commify(data.stage0_price) + '원');
        $(".order-price").html(OpenCloset.commify(data.price) + '원');
        compiled = _.template($('#tpl-late-fee').html());
        $("#late-fee").html($(compiled(data)));
        compiled = _.template($('#tpl-late-fee-discount').html());
        $("#late-fee-discount").html($(compiled(data)));
        $('#order-late-fee-discount').editable({
          display: function(value, sourceData, response) {
            return $(this).html(OpenCloset.commify(value));
          },
          success: function(response, newValue) {
            var late_fee_discount, late_fee_final;
            late_fee_discount = parseInt(newValue);
            late_fee_final = data.late_fee + late_fee_discount;
            $('.late-fee-final').html(OpenCloset.commify(late_fee_final) + '원');
            $('#order').data('order-late-fee-discount', late_fee_discount);
            return $('#order').data('order-late-fee-final', late_fee_final);
          }
        });
        if (data.price === data.stage0_price) {
          return $('.late-fee-final').html(OpenCloset.commify(data.late_fee) + '원');
        } else {
          return $('.late-fee-final').html(OpenCloset.commify(data.price - data.stage0_price) + '원');
        }
      },
      error: function(jqXHR, textStatus, errorThrown) {},
      complete: function(jqXHR, textStatus) {}
    });
  };
  updateOrder();
  $('span.order-status.label').each(function(i, el) {
    return $(el).addClass(OpenCloset.status[$(el).data('order-detail-status')].css);
  });
  $('#order-staff-name').editable();
  $('#order-additional-day').editable({
    source: function() {
      var m, _i, _results;
      _results = [];
      for (m = _i = 0; _i <= 20; m = ++_i) {
        _results.push({
          value: m,
          text: "" + (m + 3) + "박 " + (m + 4) + "일"
        });
      }
      return _results;
    },
    success: function(response, newValue) {
      $(this).data('value', newValue);
      return autoSetByAdditionalDay();
    }
  });
  $('#order-rental-date').editable({
    mode: 'inline',
    showbuttons: 'true',
    type: 'combodate',
    emptytext: '비어있음',
    format: 'YYYY-MM-DD',
    viewformat: 'YYYY-MM-DD',
    template: 'YYYY-MM-DD',
    combodate: {
      minYear: 2013
    },
    url: function(params) {
      var data, url;
      url = $('#order').data('url');
      data = {};
      data[params.name] = params.value;
      return $.ajax(url, {
        type: 'PUT',
        data: data
      });
    },
    success: function(response, newValue) {
      return updateOrder();
    }
  });
  $('#order-target-date').editable({
    mode: 'inline',
    showbuttons: 'true',
    type: 'combodate',
    emptytext: '비어있음',
    format: 'YYYY-MM-DD',
    viewformat: 'YYYY-MM-DD',
    template: 'YYYY-MM-DD',
    combodate: {
      minYear: 2013
    },
    url: function(params) {
      var data, url;
      url = $('#order').data('url');
      data = {};
      data[params.name] = params.value + ' 23:59:59';
      return $.ajax(url, {
        type: 'PUT',
        data: data
      });
    },
    success: function(response, newValue) {
      return updateOrder();
    }
  });
  $('#order-user-target-date').editable({
    mode: 'inline',
    showbuttons: 'true',
    type: 'combodate',
    emptytext: '비어있음',
    format: 'YYYY-MM-DD',
    viewformat: 'YYYY-MM-DD',
    template: 'YYYY-MM-DD',
    combodate: {
      minYear: 2013
    },
    url: function(params) {
      var data, url;
      url = $('#order').data('url');
      data = {};
      data[params.name] = params.value + ' 23:59:59';
      return $.ajax(url, {
        type: 'PUT',
        data: data
      });
    }
  });
  $('#order-price-pay-with').editable({
    source: function() {
      var m, _i, _len, _ref, _results;
      _ref = OpenCloset.payWith;
      _results = [];
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        m = _ref[_i];
        _results.push({
          value: m,
          text: m
        });
      }
      return _results;
    }
  });
  $('#order-late-fee-pay-with').editable({
    source: function() {
      var m, _i, _len, _ref, _results;
      _ref = OpenCloset.payWith;
      _results = [];
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        m = _ref[_i];
        _results.push({
          value: m,
          text: m
        });
      }
      return _results;
    },
    success: function(response, newValue) {
      return $('#order').data('order-late-fee-pay-with', newValue);
    }
  });
  $('.order-detail').editable();
  setOrderDetailFinalPrice = function(order_detail_id) {
    var day, final_price, is_clothes, is_pre_paid, price;
    is_clothes = $("#order-detail-price-" + order_detail_id).data('is-clothes');
    is_pre_paid = $("#order-detail-price-" + order_detail_id).data('is-pre-paid');
    day = parseInt($('#order-additional-day').data('value'));
    price = parseInt($("#order-detail-price-" + order_detail_id).data('value'));
    if (is_pre_paid) {
      return;
    }
    if (is_clothes) {
      final_price = price + price * 0.2 * day;
    } else {
      final_price = price * day;
    }
    $("#order-detail-final-price-" + order_detail_id).editable('setValue', final_price);
    return $("#order-detail-final-price-" + order_detail_id).editable('submit');
  };
  $('.order-detail-price').each(function(i, el) {
    return $(el).editable({
      display: function(value, sourceData, response) {
        return $(this).html(OpenCloset.commify(value));
      },
      success: function(response, newValue) {
        $(el).data('value', newValue);
        updateOrder();
        return setOrderDetailFinalPrice($(el).data('pk'));
      }
    });
  });
  $('#order-desc').editable();
  $('.order-detail-final-price').editable({
    display: function(value, sourceData, response) {
      return $(this).html(OpenCloset.commify(value));
    },
    success: function(response, newValue) {
      return updateOrder();
    }
  });
  $('#btn-order-confirm').click(function(e) {
    var order_id, redirect_url, url;
    order_id = $('#order').data('order-id');
    url = $(e.target).data('url');
    redirect_url = $(e.target).data('redirect-url');
    if (!url) {
      return;
    }
    if (!order_id) {
      return;
    }
    return $.ajax("/api/order/" + order_id + ".json", {
      type: 'GET',
      success: function(data, textStatus, jqXHR) {
        if (!data.staff_id) {
          OpenCloset.alert('danger', '담당자를 입력하세요.');
          return;
        }
        if (!(data.additional_day >= 0)) {
          OpenCloset.alert('danger', '대여 기간을 입력하세요.');
          return;
        }
        if (!data.rental_date) {
          OpenCloset.alert('danger', '대여일을 입력하세요.');
          return;
        }
        if (!data.target_date) {
          OpenCloset.alert('danger', '반납 예정일을 입력하세요.');
          return;
        }
        if (!data.price_pay_with) {
          OpenCloset.alert('danger', '대여비 납부 여부를 확인하세요.');
          return;
        }
        return $.ajax(url, {
          type: 'POST',
          data: {
            id: order_id,
            name: 'status_id',
            value: 2,
            pk: order_id
          },
          success: function(data, textStatus, jqXHR) {
            return window.location.href = redirect_url;
          },
          error: function(jqXHR, textStatus, errorThrown) {
            return OpenCloset.alert('danger', jqXHR.responseJSON.error);
          },
          complete: function(jqXHR, textStatus) {}
        });
      },
      error: function(jqXHR, textStatus, errorThrown) {},
      complete: function(jqXHR, textStatus) {}
    });
  });
  autoSetByAdditionalDay = function() {
    var day, new_date, parent_id, rental_date;
    if ($('#order-additional-day').data('disabled')) {
      return;
    }
    day = parseInt($('#order-additional-day').data('value'));
    parent_id = parseInt($('#order').data('order-parent-id'));
    if (parent_id) {
      rental_date = $('#order-rental-date').editable('getValue', true);
      new_date = moment(rental_date).add('days', day + 3).endOf('day');
      $('#order-target-date').editable('setValue', new_date.format('YYYY-MM-DD HH:mm:ss'), true);
      $('#order-target-date').editable('submit');
      $('#order-user-target-date').editable('setValue', new_date.format('YYYY-MM-DD HH:mm:ss'), true);
      $('#order-user-target-date').editable('submit');
    } else {
      $('#order-rental-date').editable('setValue', moment().format('YYYY-MM-DD HH:mm:ss'), true);
      $('#order-rental-date').editable('submit');
      $('#order-target-date').editable('setValue', moment().add('days', day + 3).endOf('day').format('YYYY-MM-DD HH:mm:ss'), true);
      $('#order-target-date').editable('submit');
      $('#order-user-target-date').editable('setValue', moment().add('days', day + 3).endOf('day').format('YYYY-MM-DD HH:mm:ss'), true);
      $('#order-user-target-date').editable('submit');
    }
    $('#order table td:nth-child(6) span').html("4+" + day + "일");
    return $('.order-detail-price').each(function(i, el) {
      return setOrderDetailFinalPrice($(el).data('pk'));
    });
  };
  autoSetByAdditionalDay();
  $('#btn-return-process').click(function(e) {
    $(".return-process input[data-clothes-code]").prop('checked', 0);
    $('.return-process').show();
    $('.return-process-reverse').hide();
    $('#clothes-search').val('').focus();
    return $('#order-late-fee-pay-with').editable('enable');
  });
  $('#btn-return-cancel').click(function(e) {
    $(".return-process input[data-clothes-code]").prop('checked', 0);
    $('.return-process').hide();
    $('.return-process-reverse').show();
    $('#order-late-fee-pay-with').editable('disable');
    $('#order-late-fee-pay-with').editable('setValue', '');
    return $('#order-late-fee-pay-with').html('미납');
  });
  returnClothesReal = function(is_part, redirect_url, order_id, late_fee_pay_with) {
    var code, data, order_detail_id, order_detail_status_id, url;
    if (is_part) {
      order_detail_id = [];
      $("input[data-clothes-code]").each(function(i, el) {
        if (!$(el).prop('checked')) {
          return;
        }
        return order_detail_id.push($(el).data('id'));
      });
      url = "/api/order/" + order_id + "/return-part.json";
      data = {
        status_id: 9,
        return_date: moment().format('YYYY-MM-DD HH:mm:ss'),
        return_method: '직접방문',
        late_fee_pay_with: late_fee_pay_with,
        order_detail_id: order_detail_id
      };
    } else {
      order_detail_id = [];
      $("input[data-clothes-code]").each(function(i, el) {
        return order_detail_id.push($(el).data('id'));
      });
      order_detail_status_id = (function() {
        var _i, _len, _results;
        _results = [];
        for (_i = 0, _len = order_detail_id.length; _i < _len; _i++) {
          code = order_detail_id[_i];
          _results.push(9);
        }
        return _results;
      })();
      url = "/api/order/" + order_id + ".json";
      data = {
        status_id: 9,
        return_date: moment().format('YYYY-MM-DD HH:mm:ss'),
        return_method: '직접방문',
        late_fee_pay_with: late_fee_pay_with,
        order_detail_id: order_detail_id,
        order_detail_status_id: order_detail_status_id
      };
    }
    return $.ajax(url, {
      type: 'PUT',
      data: $.param(data, 1),
      success: function(data, textStatus, jqXHR) {
        return window.location.href = redirect_url;
      }
    });
  };
  returnOrder = function(is_part, redirect_url) {
    var clothes_price, late_fee, late_fee_discount, late_fee_final, late_fee_pay_with, order_id, overdue;
    order_id = $('#order').data('order-id');
    clothes_price = $('#order').data('order-clothes-price');
    late_fee = $('#order').data('order-late-fee');
    late_fee_discount = $('#order').data('order-late-fee-discount');
    late_fee_final = $('#order').data('order-late-fee-final');
    late_fee_pay_with = $('#order').data('order-late-fee-pay-with');
    overdue = $('#order').data('order-overdue');
    if (late_fee_final > 0 && !late_fee_pay_with) {
      OpenCloset.alert('danger', '연체료를 납부받지 않았습니다.');
      return;
    }
    return $.ajax("/api/order_detail.json", {
      type: 'POST',
      data: {
        order_id: order_id,
        name: '연체료',
        price: clothes_price * 0.2,
        final_price: late_fee,
        stage: 1,
        desc: "" + (OpenCloset.commify(clothes_price)) + "원 x 20% x " + overdue + "일"
      },
      success: function(data, textStatus, jqXHR) {
        if (late_fee_final > 0 && late_fee_pay_with) {
          return $.ajax("/api/order_detail.json", {
            type: 'POST',
            data: {
              order_id: order_id,
              name: '연체료 에누리',
              price: Math.round(late_fee_discount / overdue),
              final_price: late_fee_discount,
              stage: 1
            },
            success: function(data, textStatus, jqXHR) {
              return returnClothesReal(is_part, redirect_url, order_id, late_fee_pay_with);
            }
          });
        } else {
          return returnClothesReal(is_part, redirect_url, order_id, late_fee_pay_with);
        }
      }
    });
  };
  $('#btn-return-all').click(function(e) {
    var count, redirect_url;
    redirect_url = $(e.target).data('redirect-url');
    count = countSelectedOrderDetail();
    if (!(count.selected > 0 && count.selected === count.total)) {
      OpenCloset.alert('error', "반납할 항목을 선택하지 않았습니다.");
      return;
    }
    return returnOrder(0, redirect_url);
  });
  $('#btn-return-part').click(function(e) {
    var count, redirect_url;
    redirect_url = $(e.target).data('redirect-url');
    count = countSelectedOrderDetail();
    if (!(count.selected > 0)) {
      OpenCloset.alert('error', "반납할 항목을 선택하지 않았습니다.");
      return;
    }
    return returnOrder(1, redirect_url);
  });
  countSelectedOrderDetail = function() {
    var selected, total;
    selected = 0;
    total = 0;
    $(".return-process input[data-clothes-code]").each(function(i, el) {
      if ($(el).prop('checked')) {
        ++selected;
      }
      return ++total;
    });
    return {
      selected: selected,
      total: total
    };
  };
  refreshReturnButton = function() {
    var count;
    count = countSelectedOrderDetail();
    if (count.selected > 0) {
      if (count.selected === count.total) {
        $('#btn-return-all').removeClass('disabled');
        return $('#btn-return-part').addClass('disabled');
      } else {
        $('#btn-return-all').addClass('disabled');
        return $('#btn-return-part').removeClass('disabled');
      }
    } else {
      $('#btn-return-all').addClass('disabled');
      return $('#btn-return-part').addClass('disabled');
    }
  };
  $(".return-process input[data-clothes-code]").click(function() {
    return refreshReturnButton();
  });
  selectSearchedClothes = function() {
    var clothes_code;
    clothes_code = OpenCloset.trimClothesCode($('#clothes-search').val());
    $('#clothes-search').val('').focus();
    $(".return-process input[data-clothes-code=" + clothes_code + "]").click();
    return refreshReturnButton();
  };
  $('#clothes-search').keypress(function(e) {
    if (e.keyCode === 13) {
      return $('#btn-clothes-search').click();
    }
  });
  return $('#btn-clothes-search').click(function() {
    return selectSearchedClothes();
  });
});
