{% extends "admin_edit_widget_std.tpl" %}

{# Admin controls for the survey #}


{% block widget_title %}{_ Survey _}{% endblock %}
{% block widget_show_minimized %}false{% endblock %}


{% block widget_before %}
{% lib "css/admin_survey.css" %}
{% endblock %}


{% block widget_content %}
<fieldset class="admin-form survey-editor">
	<div class="notification notice">
		{_ Below you can define your survey. Drag items from the left to the right. _} <a href="javascript:void(0)" class="do_dialog" data-dialog="title: '{{ _"Help about surveys"|escapejs }}', text: '{{ _"You can create your survey by dragging the Question templates to the survey on the right."|escapejs }}', width: '450px'">{_ Need more help? _}</a>
	</div>

	<div class="admin-form form-item">
		<label>
			{% if id.is_a.poll %}
				<input type="hidden" name="survey_show_results" id="survey_show_results" value="1" />
				<input type="checkbox" disabled="disabled" checked="checked" />
			{% else %}
				<input type="checkbox" name="survey_show_results" id="survey_show_results" value="1" {% if id.survey_show_results %}checked="checked"{% endif %} />
			{% endif %}
			{_ Show results to user after completion of survey. _}
		</label>
		<label>
			<input type="checkbox" name="survey_multiple" id="survey_multiple" value="1" {% if id.survey_multiple %}checked="checked"{% endif %} />
			{_ Allow multiple entries per user/browser. _}
		</label>
	</div>

	<p>
        <a href="{% url survey_results id=id %}">{_ Show survey results _}</a> |
        <a href="{% url admin_survey_editor id=id %}">{_ Survey results editor _}</a>
    </p>

	<hr/>

	<div class="zp-30">
		<h4>{_ Question Templates _}</h4>
		<ul id="survey-qs" style="cursor: move;">
			{% include "_admin_survey_questions.tpl" %}
		</ul>
	</div>

	<div class="zp-70 last">
		<h4>{_ Your survey _}</h4>
		{% sorter id="survey" tag={survey id=id} group="survey" delegate="mod_survey" %}
		<ul id="survey" style="cursor: move;" style="min-height:400px">
			{% include "_admin_survey_questions_edit.tpl" id=id %}
		</ul>
	</div>

	<hr style="clear:left" />
	{% include "_admin_save_buttons.tpl" %}
</fieldset>
{% endblock %}
