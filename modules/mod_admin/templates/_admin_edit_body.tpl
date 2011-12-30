{% extends "admin_edit_widget_i18n.tpl" %}

{% block widget_title %}{_ Content _}{% endblock %}
{% block widget_show_minimized %}false{% endblock %}


{% block widget_content %}
{% with m.rsc[id] as r %}
<fieldset class="admin-form">
	{% button action={zmedia id=id media_div_id=#media subject_id=id} text=_"Add media to body" id="zmedia-open-dialog" style="display:none" %}
	{% wire action={event type='named' name="zmedia" action={zmedia id=id media_div_id=#media subject_id=id}} %}
	{% wire action={event type='named' name="zlink" action={dialog_open title="Add link" template="_action_dialog_zlink.tpl"}} %}

	<div class="form-item clearfix">
	    {% with is_i18n|if:r.translation[lang_code].body:r.body  as  body %}
		{% if is_editable %}
		    <textarea rows="10" cols="10" id="rsc-body{{ lang_code_with_dollar }}" name="body{{ lang_code_with_dollar }}" class="body tinymce-init">{{ body|escape }}</textarea>
		{% else %}
		    {{ body }}
		{% endif %}
	    {% endwith %}
	</div>
</fieldset>

{% include "_admin_save_buttons.tpl" %}
{% endwith %}
{% endblock %}


{# some tinymce js #}
{% block widget_after %}
<script type="text/javascript" src="/lib/js/modules/tinymce3.4.3.2/tiny_mce.js"></script>
<script type="text/javascript" src="/lib/js/modules/tinymce3.4.3.2/jquery.tinymce.js"></script>
<script type="text/javascript">
$(document).ready(function(){
	{% all catinclude "_admin_tinymce_overrides_js.tpl" id %}
	/* Initialize translation tabs, select correct language */
	if ($(".translations").length) {
		$(".translations").tabs();
		$(".translations").bind('tabsshow', function(event, ui) {
			$(".tinymce-init", ui.panel).each(function() { 
			    var self = $(this);
			    setTimeout(function() { self.tinymce(tinyInit); }, 200);
			}).removeClass('tinymce-init').addClass('tinymce');
			$(".translations").tabs("select", ui.index);
		});

		var tab_index = $(".translations ul.ui-tabs-nav .tab-{{ z_language }}:visible").attr('data-index');
		if (typeof(tab_index) == 'undefined') {
			tab_index = $(".translations ul.ui-tabs-nav li:visible").attr('data-index');
		}
		if (typeof(tab_index) != "undefined") {
			$(".translations").tabs("select", parseInt(tab_index));
		}
	}

	/* Initialize all non-initialized tinymce controls */
	$(".tinymce-init:visible").each(function() { 
	    var self = $(this);
	    setTimeout(function() { self.tinymce(tinyInit); }, 200);
	}).removeClass('tinymce-init').addClass('tinymce');
});
</script>
{% endblock %}
