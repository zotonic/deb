<ul class="ui-tabs-nav">
{% for code,lang in m.config.i18n.language_list.list|default:[[z_language,[]]] %}
	<li class="tab-{{ code }}" {% if not code|member:r_language or not lang.is_enabled %}style="display: none"{% endif %} data-index="{{ forloop.counter0 }}" {% include "_language_attrs.tpl" language=code %}><a href="#{{ prefix }}-{{ code }}">{{ lang.language|default:z_language }}</a></li>
{% endfor %}
</ul>
