var items_per_page = 25;
var current_page = 1;
var do_render;
var render_registrant_details;
var registrant_list = [];
var filtered_registrant_list = [];
var registrant_data = [];

var refresh_registrant_data = function(path) {
    return $.ajax({
      type: 'GET',
      url: path,
      dataType: 'json'
    }).done(function(data){
      registrant_data = data['reg_data'];
      registrant_list = data['reg_list'];
      filtered_registrant_list = registrant_list;
    });
}

// Rendering thingy
$(function(){
  var registrant_template = _.template($('#registrant-row-template').html());
  var dom_target = $('#registrants');
  do_render = function(object_id) {
    var object_fragment = $("#"+object_id);
    if (object_fragment.length > 0) {
      object_fragment.show();
    } else {
      dom_target.append(registrant_template(registrant_data[object_id]));
    }
  }
});

// Filters
$(function(){
  var matches_text_filter = function(obj) {
    var text = $('#search-text').val();
    var re = new RegExp(text,"gi");
    return !(obj.name.match(re) == null);
  }

  var matches_gender_filter = function(obj) {
    var gender = $('#gender').val();
    return (gender == '' || gender == obj.gender)
  }

  var matches_status_filter = function(obj) {
    var status = $('#status').val();
    return (status == '' || status == obj.status)
  }

  var matches_rank_filter = function(obj) {
    var rank_range = $("#rank-range").slider("values");
    return (obj.rank >= rank_range[0] && obj.rank <= rank_range[1]);
  }

  var matches_paired_filter = function(obj) {
    if ($('#show-paired:checked').length > 0) {
      return true;
    }
    return (obj.pair_id == null);
  }

  var filter_registrants = function() {
    filtered_registrant_list = [];
    for (var i = 0; i < registrant_list.length; i++) {
      var obj = registrant_data[registrant_list[i]];
      if (matches_text_filter(obj) && matches_gender_filter(obj) && matches_status_filter(obj) && matches_rank_filter(obj) && matches_paired_filter(obj)) {
        filtered_registrant_list.push(registrant_list[i]);
      }
    }
  };

  var show_results = function() {
    $('#registrants li').hide();
    var rendered = 0;
    var start_index = (current_page-1)*items_per_page
    var end_index = start_index + items_per_page
    for (var i = (start_index); i < filtered_registrant_list.length; i++) {
      if (i >= end_index) { break; }
      do_render(filtered_registrant_list[i]);
    }

    if (filtered_registrant_list.length == 0) {
      if ($('#registrants li.no-results').length > 0) {
        $('#registrants li.no-results').show();
      } else {
        var no_results_li = '<li class="no-results">' + $('#no-results').html() + '</li>';
        $('#registrants').append(no_results_li);
      }
    }

    show_pagination();
  };

  $('#apply-filters').on('click', function() {
    current_page = 1;
    items_per_page = $('#items-per-page').val();
    filter_registrants();
    show_results();
  });

  $('#clear-filters').on('click', function(){
    $('#search-text').val('');
    $('#gender').val('');
    $('#status').val('');
    $('#rank-range').slider("values", 0, 0);
    $('#rank-range').slider("values", 1, 10);
    filter_registrants();
    show_results();
  });

  var pagination_link = _.template('<li class="<% if (disabled) { print("disabled"); } %> <% if (active) { print("active"); } %>"><a href="#" data-page-num="<%=page%>" title="Page <%=page%>"><%=text%></a></li>');
  var show_pagination = function() {
    var last_page = Math.ceil(filtered_registrant_list.length/items_per_page)
    // Empty pagination list
    $('.pagination ul').html('');

    if (last_page == 0) {
      return;
    }

    // Populate first page link
    $('.pagination ul').append(pagination_link({page: current_page, active: false, disabled: (current_page==1), text: '&laquo;'}));


    for (var p = Math.max(1, current_page-5); p <= Math.min(last_page, current_page+5); p++) {
      $('.pagination ul').append(pagination_link({page: p, active: (current_page==p), disabled: false, text: p}));
    }

    // Populate last page link

    $('.pagination ul').append(pagination_link({page: last_page, active: false, disabled: (current_page==last_page), text: '&raquo;'}));

    $('.pagination').show();
  }

  $('.pagination ul').on('click', 'a', function(e) {
    e.preventDefault();
    current_page = $(this).data('page-num');
    show_results();
    $('.page-header').ScrollTo()
  });

  var updateSliderLabel = function(event, ui) {
      $("#rank_min").html(ui.values[0]);
      $("#rank_max").html(ui.values[1]);
  };

  $("#rank-range").slider({
    range: true,
    min: 0,
    max: 10,
    values: [0,10],
    slide: updateSliderLabel,
    change: updateSliderLabel
  });
});

// Do sorting
$(function(){
  $('#do-sort').on('click', function(e){
    var sort_type = $('#sort-field').val();

    if (sort_type == '') {
      return;
    }

    switch(sort_type) {
      case 'availability':
        registrant_list.sort(function(a,b){
          var a_obj = registrant_data[a];
          var b_obj = registrant_data[b];

          return (parseInt(b_obj['gen_availability']) - parseInt(a_obj['gen_availability']));
        });
        break;
      case 'rank':
        registrant_list.sort(function(a,b){
          var a_obj = registrant_data[a];
          var b_obj = registrant_data[b];

          return (b_obj['rank'] - a_obj['rank']);
        });
        break;
    }

    // Blank out cache of rendered registrants
    $('#registrants').html('');

    $('#apply-filters').trigger('click');
  });
});

// Display larger details link
$(function(){
  var registrant_profile = _.template($('#registrant-detail-template').html());
  var pair_invite_button = _.template($('#pair-invite-button').html());
  var target_dom = $('#player-details');
  var user_reg = registrant_data[current_user['registration_id']];

  render_registrant_details = function(registrant_id) {
    var reg = registrant_data[registrant_id];
    target_dom.data('id', registrant_id);
    target_dom.html(registrant_profile(reg));

    // Lots of different conditions for showing the pair button. geez.
    if (pairs_allowed && user_reg
        && reg['user_id'] != current_user['_id']
        && reg['status'] == 'active'
        && user_reg['status'] == 'active'
        && !user_reg['pair_id']
        && !reg['pair_id']
        && current_user['pair_invite_count'] == 0) {
      target_dom.append(pair_invite_button(reg));
    }

    $(".details-grank").popover({
      html: true,
      placement: 'left',
      trigger: 'hover',
      title: 'gRank Answers',
      container: '#details-column',
      content: function() {
        var id = target_dom.data('id');
        var questions = _.keys(reg['grank']['answers']);
        var result = '<ul>';
        _.each(questions, function(q){
          var a = reg['grank']['answers'][q];
          if (a) {
            result += "<li><strong>" + q + ":</strong> " + a + "</li>";
          }
        });
        result += '<li><strong>Score History:</strong> <span class="grank-history">' + reg['grank']['history'].join(",") + '</span></li>';
        result += '</ul>';
        return result;
      }
    }).on('shown', function(e){
      $('.grank-history').sparkline('html', {
        type: 'bar',
        chartRangeMin: 0,
        chartRangeMax: 10,
        disableHiddenCheck: true,
      });
    });
  }

  $('#registrants').on('click', 'li.registrant-row', function(e){
    render_registrant_details($(this).attr('id'));
  });

  $('.container').on('click', 'a.show-reg', function(e) {
    e.preventDefault();
    render_registrant_details($(this).data('registration-id'));
  });
});

// Handle Collapsing Left Sidebar Sections
$(function(){
  $('.collapser').on('click', function(e){
    $(this).toggleClass('icon-collapse-top icon-collapse', 100);
  });
});

// Pair Stuff
$(function(){
  if (pairs_allowed != true) { return; }

  $("#player-details").on('click', 'button.add-pair', function(e){
    var reg_id = $(this).data('registration-id');

    var xhr = $.ajax({
      type: 'GET',
      url: pair_invite_path,
      data: {target_registration_id: reg_id},
      dataType: 'json'
    }).done(function(data){
      $("#player-details").append('<div class="alert alert-success">Pair invite sent!</div>');
      current_user['pair_invite_count'] += 1;
      $("#player-details button.add-pair").remove();
    }).error(function(jqXHR, textStatus, errorThrown){
      try {
        errors = $.parseJSON(jqXHR.responseText);
      } catch (e) {
        errors = ['An unknown error occurred on the server.'];
      }

      var error_msg = '<div class="alert alert-error"><ul class="unstyled">';

      for (var i = 0; i < errors.length; i++) {
        error_msg += '<li>' + errors[i] + '</li>';
      }

      error_msg += '</ul></div>';
      $("#player-details").append(error_msg);
      $("#player-details button.add-pair").remove();
    });
  });
});

// Page Start Logic
$(function(){
  $("#registrants").html('<div style="text-align: center; margin: 20px 10px; font-size: 128px;"><i class="icon-spinner icon-spin"></i></div>');
  refresh_registrant_data(registrant_data_path).done(function () {
    $("#registrants").html('');
    $('#apply-filters').trigger('click');
  });
});
