$(document).ready(function() {
  $("#edit_section_form .cancel_button").click(function() {
    $("#edit_section_form").hide();
  });
  $(".edit_section_link").click(function(event) {
    event.preventDefault();
    $("#edit_section_form").toggle();
    $("#edit_section_form :text:visible:first").focus().select();
  });
  $(".unenroll_user_link").click(function(event) {
    event.preventDefault();
    $(this).parents(".user").confirmDelete({
      message: "Are you sure you want to delete this enrollment permanently?",
      url: $(this).attr('href'),
      success: function() {
        $(this).slideUp(function() {
          $(this).remove();
        });
      }
    });
  });
  $(".datetime_field").datetime_field();
  $(".uncrosslist_link").click(function(event) {
    event.preventDefault();
    $("#uncrosslist_form").dialog('close').dialog({
      autoOpen: false,
      width: 400
    }).dialog('open');
  });
  $("#uncrosslist_form .cancel_button").click(function(event) {
    $("#uncrosslist_form").dialog('close');
  }).submit(function() {
    $(this).find("button").attr('disabled', true).filter(".submit_button").text("De-Cross-Listing Section...");
  });
  $(".crosslist_link").click(function(event) {
    event.preventDefault();
    $("#crosslist_course_form").dialog('close').dialog({
      autoOpen: false,
      width: 450
    }).dialog('open');
    $("#crosslist_course_form .submit_button").attr('disabled', true);
    $("#course_autocomplete_id_lookup").val("");
    $("#course_id").val("").change();
  });
  $("#course_autocomplete_id_lookup").autocomplete({
    serviceUrl: $("#course_autocomplete_url").attr('href'),
    onSelect: function(value, data){
      $("#course_id").val("");
      $("#crosslist_course_form").triggerHandler('id_entered', data.course);
    }
  });
  $("#course_id").keycodes('return', function(event) {
    event.preventDefault();
    $(this).change();
  });
  $("#course_id").bind('change', function() {
    $("#course_autocomplete_id_lookup").val("");
    $("#crosslist_course_form").triggerHandler('id_entered', {id: $(this).val()});
  });
  $("#crosslist_course_form .cancel_button").click(function() {
    $("#crosslist_course_form").dialog('close');
  });
  var latest_course_id = null;
  $("#crosslist_course_form").bind('id_entered', function(event, course) {
    if(course.id == latest_course_id) { return; }
    $("#crosslist_course_form .submit_button").attr('disabled', true);
    $("#course_autocomplete_id").val("");
    if(!course.id) { 
      $("#sis_id_holder,#account_name_holder").hide();
      $("#course_autocomplete_name").text("");
      return; 
    }
    course.name = course.name || "Course ID \"" + course.id + "\"";
    $("#course_autocomplete_name_holder").show();
    $("#course_autocomplete_name").text("Confirming " + course.name + "...");
    $("#sis_id_holder,#account_name_holder").hide();
    $("#course_autocomplete_account_name").hide();
    var url = $.replaceTags($("#course_confirm_crosslist_url").attr('href'), 'id', course.id);
    latest_course_id = course.id;
    var course_id_before_get = latest_course_id;
    $.ajaxJSON(url, 'GET', {}, function(data) {
      if(course_id_before_get != latest_course_id) { return; }
      if(data && data.allowed) {
        var template_data = {
          sis_id: data.course && data.course.sis_source_id,
          account_name: data.account && data.account.name
        };
        $("#course_autocomplete_name_holder").fillTemplateData({data: template_data})
        $("#course_autocomplete_name").text(data.course.name);
        $("#sis_id_holder").showIf(template_data.sis_id);
        $("#account_name_holder").showIf(template_data.account_name);
        
        $("#course_autocomplete_id").val(data.course.id);
        $("#crosslist_course_form .submit_button").attr('disabled', false);
      } else {
        $("#course_autocomplete_name").text(course.name + " not authorized for cross-listing");
        $("#sis_id_holder,#account_name_holder").hide();
      }
    }, function(data) {
      $("#course_autocomplete_name").text("Confirmation Failed");
    });
  });
});
