$(function() {
  $('.order-status').each(function(i, el) {
    $(el).addClass(OpenCloset.status[$(el).data('status')].css);
    if ($(el).data('late-fee') > 0) {
      return $(el).find('.order-status-str').html('연체중');
    }
  });
  return $('.editable').each(function(i, el) {
    var params;
    params = {
      mode: 'inline',
      showbuttons: 'true',
      emptytext: '비어있음',
      pk: $('#profile-user-info-data').data('pk'),
      url: function(params) {
        var data, url;
        url = $('#profile-user-info-data').data('url');
        data = {};
        data[params.name] = params.value;
        return $.ajax(url, {
          type: 'PUT',
          data: data
        });
      }
    };
    switch ($(el).attr('id')) {
      case 'user-name':
        params.type = 'text';
        params.success = function(response, newValue) {
          return $('.user-name').each(function(i, el) {
            return $(el).html(newValue);
          });
        };
        break;
      case 'user-gender':
        params.type = 'select';
        params.source = [
          {
            value: 'male',
            text: '남자'
          }, {
            value: 'female',
            text: '여자'
          }
        ];
        params.display = function(value) {
          var value_str;
          switch (value) {
            case 'male':
              value_str = '남자';
              break;
            case 'female':
              value_str = '여자';
              break;
            default:
              value_str = '';
          }
          return $(this).html(value_str);
        };
        break;
      case 'user-staff':
        params.type = 'select';
        params.source = [
          {
            value: '0',
            text: '고객'
          }, {
            value: '1',
            text: '직원'
          }
        ];
        params.display = function(value) {
          var value_str;
          if (typeof value === 'number') {
            value = value.toString();
          }
          switch (value) {
            case '0':
              value_str = '고객';
              break;
            case '1':
              value_str = '직원';
              break;
            default:
              value_str = '';
          }
          return $(this).html(value_str);
        };
        break;
      default:
        params.type = 'text';
    }
    return $(el).editable(params);
  });
});
