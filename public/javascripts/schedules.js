$(function(){
    // Pagination helper function
    var get_page_size = function() {
        var table = $("#game-listing table");

        if (table.length == 0) {
            return false;
        }

        return table.data('page-size');
    };

    var get_page_num = function() {
        var table = $("#game-listing table");

        if (table.length == 0) {
            return 0;
        }

        return table.data('page-num');
    };

    var get_game_count = function() {
        var table = $("#game-listing table");

        if (table.length == 0) {
            return 0;
        }

        return table.data('game-count');
    };

    var get_last_page_num = function() {
        var game_count = get_game_count();

        if (game_count > 0) {
            var page_size = get_page_size();

            if (page_size >= game_count) {
                return 1;
            }

            return Math.ceil(game_count/page_size);
        }
    };

    var update_fragment = function(new_hash) {
        if ($('#schedule-form').data('persist-params') == 'yes') {
            window.location.hash = new_hash
        }
    };

    $("#pagination a").on('click', function(e) {
        e.preventDefault();
        var link = $(this);

        var table = $("#game-listing table");

        if (table.length == 0) {
            $("#pagination").hide();
            return;
        }

        var page_size = table.data('page-size');
        var page_num = table.data('page-num');

        if (link.parent().hasClass('next')) {
            $("#page_num").val(page_num+1);
            $("#schedule-form").trigger('submit');
        } else if (link.parent().hasClass('previous')) {
            $("#page_num").val(page_num-1);
            $("#schedule-form").trigger('submit');
        }
    });

   $("#clear-filters").on('click', function(e) {
        e.preventDefault();

        $("#on_date").val('');
        $("#league_id").val('');
        $("#fieldsite_id").val('');
    });

    $("#schedule-form").on('submit', function(e) {
        e.preventDefault();
        var target_element = $("#game-listing");
        var has_filters = false;
        var query_data = {}

        var on_date = $("#on_date").val();
        if (on_date) {
            has_filters = true;
            query_data['on_date'] = on_date;
        }

        var start_date = $("#start_date").val();
        if (start_date) {
            has_filters = true;
            query_data['start_date'] = start_date;
        }

        var league_id = $("#league_id").val();
        if (league_id) {
            has_filters = true;
            query_data['league_id'] = league_id;
        }

        var team_id = $("#team_id").val();
        if (team_id) {
            has_filters = true;
            query_data['team_id'] = team_id;   
        }

        var fieldsite_id = $("#fieldsite_id").val();
        if (fieldsite_id) {
            has_filters = true;
            query_data['fieldsite_id'] = fieldsite_id;
        }

        var page_num = $("#page_num").val();
        if (page_num) {
            query_data['page_num'] = page_num;
        }

        var sort_dir = $("#sort_dir").val();
        if (sort_dir) {
            query_data['sort_dir'] = sort_dir;
        }


        if (has_filters) {
            update_fragment($.param(query_data));
            $("#pagination").hide();
            target_element.html('<div style="text-align: center"><img src="/images/loader.gif" /></div>');
            var xhr = $.ajax({
                url: '/schedules/show',
                data: query_data
            }).done(function(data) {
                target_element.html(data);

                var table = $("#game-listing table");

                if (table.length == 0) {
                    $("#pagination").hide();
                } else {
                    $("#pagination").show();

                    if (get_page_num() <= 1) {
                        $("#pagination li.previous").hide();
                    } else {
                        $("#pagination li.previous").show();
                    }

                    if (get_page_num() >= get_last_page_num()) {
                        $("#pagination li.next").hide();
                    } else {
                        $("#pagination li.next").show();
                    }
                }
            });            
        } else {
            $("#pagination").hide();
            update_fragment('');
            target_element.html('<div class="alert">No game selection criteria found.</div>');
        }
    });
});