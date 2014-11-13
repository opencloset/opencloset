$(function() {
  var addRegisteredUserAndDonation, clear_clothes_form, color, color_str, donationID, k, userID, v, validation;
  userID = void 0;
  donationID = void 0;
  addRegisteredUserAndDonation = function() {
    var query;
    query = $('#user-search').val();
    if (!query) {
      return;
    }
    $("input[name=user-donation-id]").parent().removeClass("highlight");
    $.ajax("/api/search/user.json", {
      type: 'GET',
      data: {
        q: query
      },
      success: function(data, textStatus, jqXHR) {
        var compiled;
        compiled = _.template($('#tpl-user-id').html());
        _.each(data, function(user) {
          var $html;
          if (!$("#user-search-list input[data-user-id='" + user.id + "']").length) {
            $html = $(compiled(user));
            $html.find('input').attr('data-json', JSON.stringify(user));
            return $("#user-search-list").prepend($html);
          }
        });
        if (data[0]) {
          return $("input[name=user-donation-id][data-type=user][value=" + data[0].id + "]").click();
        }
      },
      error: function(jqXHR, textStatus, errorThrown) {
        var type, _ref;
        type = (_ref = jqXHR.status === 404) != null ? _ref : {
          'warning': 'danger'
        };
        return OpenCloset.alert(type, jqXHR.responseJSON.error.str);
      },
      complete: function(jqXHR, textStatus) {}
    });
    return $.ajax("/api/search/donation.json", {
      type: 'GET',
      data: {
        q: query
      },
      success: function(data, textStatus, jqXHR) {
        var compiled;
        compiled = _.template($('#tpl-donation-id').html());
        return _.each(data, function(donation) {
          var $html;
          if (!$("#user-search-list input[data-donation-id='" + donation.id + "']").length) {
            $html = $(compiled(donation));
            $html.find('input').attr('data-json', JSON.stringify(donation));
            return $("#user-search-list").prepend($html);
          }
        });
      },
      error: function(jqXHR, textStatus, errorThrown) {
        var type, _ref;
        type = (_ref = jqXHR.status === 404) != null ? _ref : {
          'warning': 'danger'
        };
        return OpenCloset.alert(type, jqXHR.responseJSON.error.str);
      },
      complete: function(jqXHR, textStatus) {}
    });
  };
  $('#user-search-list').on('click', ':radio', function(e) {
    var donation, user;
    userID = $(this).data('user-id');
    donationID = $(this).data('donation-id');
    if ($(this).val() === '0') {
      return;
    }
    if (donationID) {
      donation = $(this).data('json');
      user = donation.user;
      $("#donation-message").val(donation.message);
      $("#donation-message").prop('disabled', true);
    } else {
      user = $(this).data('json');
      $("#donation-message").prop('disabled', false);
    }
    return _.each(['name', 'email', 'phone', 'address', 'gender', 'birth'], function(name) {
      var $input;
      $input = $("input[name=" + name + "]");
      if ($input.attr('type') === 'radio' || $input.attr('type') === 'checkbox') {
        return $input.each(function(i, el) {
          if ($(el).val() === user[name]) {
            return $(el).attr('checked', true);
          }
        });
      } else {
        return $input.val(user[name]);
      }
    });
  });
  $('#user-search').keypress(function(e) {
    if (e.keyCode === 13) {
      return addRegisteredUserAndDonation();
    }
  });
  $('#btn-user-search').click(function() {
    return addRegisteredUserAndDonation();
  });
  addRegisteredUserAndDonation();
  clear_clothes_form = function(show) {
    if (show) {
      _.each(['bust', 'waist', 'hip', 'belly', 'thigh', 'arm', 'length', 'foot'], function(name) {
        return $("#display-clothes-" + name).show();
      });
    } else {
      _.each(['bust', 'waist', 'hip', 'belly', 'thigh', 'arm', 'length', 'foot'], function(name) {
        return $("#display-clothes-" + name).hide();
      });
    }
    $('#clothes-code').val('');
    $('input[name=clothes-gender]').prop('checked', false);
    $('#clothes-color').select2('val', '');
    return _.each(['bust', 'waist', 'hip', 'belly', 'thigh', 'arm', 'length', 'foot'], function(name) {
      return $("#clothes-" + name).prop('disabled', true).val('');
    });
  };
  $('#clothes-category').select2({
    dropdownCssClass: 'bigdrop',
    data: (function() {
      var _ref, _results;
      _ref = OpenCloset.category;
      _results = [];
      for (k in _ref) {
        v = _ref[k];
        _results.push({
          id: k,
          text: v.str
        });
      }
      return _results;
    })()
  }).on('change', function(e) {
    var type, types, _i, _len, _results;
    clear_clothes_form(false);
    types = [];
    switch (e.val) {
      case 'jacket':
        types = ['bust', 'arm', 'belly'];
        break;
      case 'pants':
        types = ['waist', 'hip', 'thigh', 'length'];
        break;
      case 'shirt':
        types = ['bust', 'arm', 'belly'];
        break;
      case 'waistcoat':
        types = ['waist', 'belly'];
        break;
      case 'coat':
        types = ['bust', 'arm', 'length'];
        break;
      case 'onepiece':
        types = ['bust', 'waist', 'hip', 'arm', 'length'];
        break;
      case 'skirt':
        types = ['waist', 'hip', 'length'];
        break;
      case 'blouse':
        types = ['bust', 'arm'];
        break;
      case 'belt':
        types = ['length'];
        break;
      case 'shoes':
        types = ['foot'];
        break;
      default:
        types = [];
    }
    _results = [];
    for (_i = 0, _len = types.length; _i < _len; _i++) {
      type = types[_i];
      $("#display-clothes-" + type).show();
      _results.push($("#clothes-" + type).prop('disabled', false));
    }
    return _results;
  });
  $('#clothes-color').select2({
    dropdownCssClass: 'bigdrop',
    data: (function() {
      var _ref, _results;
      _ref = OpenCloset.color;
      _results = [];
      for (color in _ref) {
        color_str = _ref[color];
        _results.push({
          id: color,
          text: color_str
        });
      }
      return _results;
    })()
  });
  $('#clothes-category').select2('val', '');
  clear_clothes_form(true);
  $('#btn-clothes-reset').click(function() {
    $('#clothes-category').select2('val', '');
    return clear_clothes_form(true);
  });
  $('#btn-clothes-add').click(function() {
    var count, data, valid_count;
    data = {
      user_id: userID,
      clothes_code: $('#clothes-code').val(),
      clothes_category: $('#clothes-category').val(),
      clothes_category_str: $('#clothes-category option:selected').text(),
      clothes_gender: $('input[name=clothes-gender]:checked').val(),
      clothes_gender_str: $('input[name=clothes-gender]:checked').next().text(),
      clothes_color: $('#clothes-color').val(),
      clothes_color_str: $('#clothes-color option:selected').text(),
      clothes_bust: $('#clothes-bust').val(),
      clothes_waist: $('#clothes-waist').val(),
      clothes_hip: $('#clothes-hip').val(),
      clothes_belly: $('#clothes-belly').val(),
      clothes_thigh: $('#clothes-thigh').val(),
      clothes_arm: $('#clothes-arm').val(),
      clothes_length: $('#clothes-length').val(),
      clothes_foot: $('#clothes-foot').val()
    };
    if (!data.clothes_category) {
      return;
    }
    count = 0;
    valid_count = 0;
    if ($('#clothes-color').val()) {
      count++;
      valid_count++;
    } else {
      count++;
    }
    $('#step3 input:enabled').each(function(i, el) {
      if (!/^clothes-/.test($(el).attr('id'))) {
        return;
      }
      count++;
      switch ($(el).attr('id')) {
        case 'clothes-code':
          if (/^[a-z0-9]{4,5}$/i.test($(el).val())) {
            return valid_count++;
          }
          break;
        case 'clothes-color':
          if ($(el).val()) {
            return valid_count++;
          }
          break;
        case 'clothes-category':
          if ($(el).val()) {
            return valid_count++;
          }
          break;
        default:
          if ($(el).val() > 0) {
            return valid_count++;
          }
      }
    });
    if (count !== valid_count) {
      OpenCloset.alert('warning', '빠진 항목이 있습니다.');
      return;
    }
    return $.ajax("/api/clothes/" + data.clothes_code + ".json", {
      type: 'GET',
      dataType: 'json',
      success: function(data, textStatus, jqXHR) {
        return OpenCloset.alert('warning', '이미 존재하는 의류 코드입니다.');
      },
      error: function(jqXHR, textStatus, errorThrown) {
        var compiled, html;
        if (jqXHR.status !== 404) {
          OpenCloset.alert('warning', '의류 코드 오류입니다.');
          return;
        }
        compiled = _.template($('#tpl-clothes-item').html());
        html = $(compiled(data));
        $('#display-clothes-list').append(html);
        $('#btn-clothes-reset').click();
        return $('#clothes-category').focus();
      },
      complete: function(jqXHR, textStatus) {}
    });
  });
  $('#btn-clothes-select-all').click(function() {
    var checked, count, _ref;
    count = 0;
    checked = 0;
    $('input[name=clothes-list]').each(function(i, el) {
      count++;
      if ($(el).prop('checked')) {
        return checked++;
      }
    });
    return $('input[name=clothes-list]').prop('checked', (_ref = checked < count) != null ? _ref : {
      "true": false
    });
  });
  validation = false;
  return $('#fuelux-wizard').ace_wizard().on('change', function(e, info) {
    var ajax, createGroupClothes;
    if (info.step === 1 && validation) {
      if (!$('#validation-form').valid()) {
        return false;
      }
    }
    if (info.direction !== 'next') {
      return true;
    }
    ajax = {};
    switch (info.step) {
      case 2:
        if (userID) {
          ajax.type = 'PUT';
          ajax.path = "/api/user/" + userID + ".json";
        } else {
          ajax.type = 'POST';
          ajax.path = '/api/user.json';
        }
        return $.ajax(ajax.path, {
          type: ajax.type,
          data: $('form').serialize(),
          success: function(data, textStatus, jqXHR) {
            userID = data.id;
            return true;
          },
          error: function(jqXHR, textStatus, errorThrown) {
            OpenCloset.alert('danger', jqXHR.responseJSON.error);
            return false;
          },
          complete: function(jqXHR, textStatus) {}
        });
      case 3:
        if (!$("input[name=clothes-list]:checked").length) {
          return;
        }
        createGroupClothes = function(donationID) {
          return $.ajax("/api/group.json", {
            type: 'POST',
            success: function(group, textStatus, jqXHR) {
              return $("input[name=clothes-list]:checked").each(function(i, el) {
                return $.ajax("/api/clothes.json", {
                  type: 'POST',
                  data: {
                    donation_id: donationID,
                    group_id: group.id,
                    code: $(el).data('clothes-code'),
                    category: $(el).data('clothes-category'),
                    gender: $(el).data('clothes-gender'),
                    color: $(el).data('clothes-color'),
                    bust: $(el).data('clothes-bust'),
                    waist: $(el).data('clothes-waist'),
                    hip: $(el).data('clothes-hip'),
                    belly: $(el).data('clothes-belly'),
                    thigh: $(el).data('clothes-thigh'),
                    arm: $(el).data('clothes-arm'),
                    length: $(el).data('clothes-length'),
                    foot: $(el).data('clothes-foot'),
                    price: OpenCloset.category[$(el).data('clothes-category')].price
                  },
                  success: function(data, textStatus, jqXHR) {},
                  error: function(jqXHR, textStatus, errorThrown) {
                    return OpenCloset.alert('warning', jqXHR.responseJSON.error.str);
                  },
                  complete: function(jqXHR, textStatus) {}
                });
              });
            },
            error: function(jqXHR, textStatus, errorThrown) {
              return OpenCloset.alert('warning', jqXHR.responseJSON.error.str);
            },
            complete: function(jqXHR, textStatus) {}
          });
        };
        if (donationID) {
          return createGroupClothes(donationID);
        } else {
          return $.ajax("/api/donation.json", {
            type: 'POST',
            data: {
              user_id: userID,
              message: $('#donation-message').val()
            },
            success: function(donation, textStatus, jqXHR) {
              return createGroupClothes(donation.id);
            },
            error: function(jqXHR, textStatus, errorThrown) {
              return OpenCloset.alert('warning', jqXHR.responseJSON.error.str);
            },
            complete: function(jqXHR, textStatus) {}
          });
        }
        break;
    }
  }).on('finished', function(e) {
    location.href = "/";
    return false;
  }).on('stepclick', function(e) {});
});
