// Generated by CoffeeScript 1.6.3
(function() {
  $(function() {
    var add_registered_guest, validation, why;
    $('#input-phone').ForceNumericOnly();
    add_registered_guest = function() {
      var query;
      query = $('#guest-search').val();
      if (!query) {
        return;
      }
      return $.ajax("/new-borrower.json", {
        type: 'GET',
        data: {
          q: query
        },
        success: function(guests, textStatus, jqXHR) {
          var compiled;
          compiled = _.template($('#tpl-new-borrower-guest-id').html());
          return _.each(guests, function(guest) {
            var $html;
            if (!$("#guest-search-list input[data-guest-id='" + guest.id + "']").length) {
              $html = $(compiled(guest));
              $html.find('input').attr('data-json', JSON.stringify(guest));
              return $("#guest-search-list").prepend($html);
            }
          });
        },
        error: function(jqXHR, textStatus, errorThrown) {
          return alert('error', jqXHR.responseJSON.error);
        },
        complete: function(jqXHR, textStatus) {}
      });
    };
    $('#guest-search-list').on('click', ':radio', function(e) {
      var g;
      if ($(this).val() === '0') {
        return;
      }
      g = JSON.parse($(this).attr('data-json'));
      return _.each(['name', 'email', 'gender', 'phone', 'age', 'address', 'height', 'weight', 'purpose', 'chest', 'waist', 'arm', 'length', 'domain'], function(name) {
        var $input;
        $input = $("input[name=" + name + "]");
        if ($input.attr('type') === 'radio' || $input.attr('type') === 'checkbox') {
          return $input.each(function(i, el) {
            if ($(el).val() === g[name]) {
              return $(el).attr('checked', true);
            }
          });
        } else {
          return $input.val(g[name]);
        }
      });
    });
    $('#guest-search').keypress(function(e) {
      if (e.keyCode === 13) {
        return add_registered_guest();
      }
    });
    $('#btn-guest-search').click(function() {
      return add_registered_guest();
    });
    $('.clickable.label').click(function() {
      return $('#input-purpose').val($(this).text());
    });
    $('#input-target-date').datepicker({
      startDate: "-0d",
      language: 'kr',
      format: 'yyyy-mm-dd',
      autoclose: true
    });
    $('#btn-sendsms:not(.disabled)').click(function(e) {
      var $this, to;
      e.preventDefault();
      $this = $(this);
      $this.addClass('disabled');
      to = $('#input-phone').val();
      if (!to) {
        return;
      }
      return $.ajax("/sms.json", {
        type: 'POST',
        data: {
          to: to
        },
        success: function(data, textStatus, jqXHR) {
          return alert('success', "" + to + " 번호로 SMS 가 발송되었습니다");
        },
        error: function(jqXHR, textStatus, errorThrown) {
          return alert('error', jqXHR.responseJSON.error);
        },
        complete: function(jqXHR, textStatus) {
          return $this.removeClass('disabled');
        }
      });
    });
    validation = false;
    $('#fuelux-wizard').ace_wizard().on('change', function(e, info) {
      var guestID, path, type;
      if (info.step === 1 && validation) {
        if (!$('#validation-form').valid()) {
          return false;
        }
      }
      if (info.step !== 4) {
        return;
      }
      type = 'POST';
      path = '/guests.json';
      guestID = $('input[name=guest-id]:checked').val();
      if (guestID && guestID !== '0') {
        type = 'PUT';
        path = "/guests/" + guestID + ".json";
      }
      return $.ajax(path, {
        type: type,
        data: $('form').serialize(),
        success: function(data, textStatus, jqXHR) {
          return true;
        },
        error: function(jqXHR, textStatus, errorThrown) {
          alert('error', jqXHR.responseJSON.error);
          return false;
        },
        complete: function(jqXHR, textStatus) {}
      });
    }).on('finished', function(e) {
      var chest, guestID, waist;
      e.preventDefault();
      guestID = $('input[name=guest-id]:checked').val();
      chest = $("input[name=chest]").val();
      waist = $("input[name=waist]").val();
      location.href = "/search?q=" + (parseInt(chest) + 3) + "/" + waist + "//1/&gid=" + guestID;
      return false;
    }).on('stepclick', function(e, step) {});
    why = $('#guest-why').tag({
      placeholder: $('#guest-why').attr('placeholder'),
      source: ['입사면접', '사진촬영', '결혼식', '장례식', '입학식', '졸업식', '세미나', '발표']
    });
    return $('.guest-why .clickable.label').click(function() {
      var e, text;
      text = $(this).text();
      e = $.Event('keydown', {
        keyCode: 13
      });
      return why.next().val(text).trigger(e);
    });
  });

}).call(this);
