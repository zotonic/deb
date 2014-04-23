{% extends "admin_edit_widget_i18n.tpl" %}

{% block widget_title %}{_ Block _}{% endblock %}
{% block widget_show_minimized %}false{% endblock %}
{% block widget_id %}edit-block-{{ name }}{% endblock %}
{% block widget_header %}{% endblock %}

{% block widget_content %}
{% with m.rsc[id] as r %}
    {% if is_editable %}
    <div class="control-group">
        <input type="text" id="block-{{name}}-prompt{{ lang_code_for_id }}" name="block-{{name}}-prompt{{ lang_code_with_dollar }}" 
               class="input-block-level" value="{{ blk.prompt[lang_code]  }}"
               placeholder="{_ Fill in the missing parts. _} ({{ lang_code }})" />
    </div>
    <div class="control-group view-expanded">
       <textarea id="block-{{name}}-narrative{{ lang_code_for_id }}" name="block-{{name}}-narrative{{ lang_code_with_dollar }}" 
              class="input-block-level" rows="4"
              placeholder="{_ I am [age] years old. I like [icecream=vanilla|strawberry|chocolate|other] ice cream and my favorite color is [color      ]. _} ({{ lang_code }})" >{{ blk.narrative[lang_code]  }}</textarea>
              
        <p class="help-block"><strong>{_ Example: _}</strong> {_ I am [age] years old. I like [icecream=vanilla|strawberry|chocolate|other] ice cream and my favorite color is [color      ]._}</p>
    </div>

    <div class="control-group view-expanded">
        <textarea id="block-{{name}}-explanation{{ lang_code_for_id }}" name="block-{{name}}-explanation{{ lang_code_with_dollar }}" 
               class="input-block-level" rows="2"
               placeholder="{_ Explanation _} ({{ lang_code }})" >{{ blk.explanation[lang_code]  }}</textarea>
    </div>
    {% else %}
        <p>{{ blk.narrative[lang_code]  }}</p>
    {% endif %}
{% endwith %}
{% endblock %}

{% block widget_content_nolang %}
    <div class="control-group view-expanded">
        <label class="checkbox">
            <input type="checkbox" id="block-{{name}}-is_required" name="block-{{name}}-is_required" value="1" {% if blk.is_required or is_new %}checked="checked"{% endif %} />
            {_ Required, this question must be answered. _}
        </label>
    </div>
{% endblock %}
