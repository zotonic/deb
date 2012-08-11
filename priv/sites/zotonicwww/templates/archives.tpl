{% extends "base.tpl" %}

{% block title %}{_ Archive for _} {% if q.month %}{{ q.month|escape }}, {% endif %}{{ q.year|escape }}{% endblock %}

{% block page_class %}page{% endblock %}


{% block content %}
{% cache 3600 cat='article' vary=[q.month,q.year] %}
<article id="content" class="{% block content_class %}zp-67{% endblock %}">
    <div class="padding">
        <h1>{_ Archive for _} {% if q.month %}{{ q.month|escape }}, {% endif %}{{ q.year|escape }}</h1>
        
        {% with m.search.paged[{query publication_year=q.year publication_month=q.month sort='-publication_start' cat=cat page=q.page pagelen=10}] as result %}
		
	{% for id in result %}
	{% include "_article_summary.tpl" id=id %}
	{% endfor %}
	
	{% pager result=result dispatch=zotonic_dispatch year=q.year month=q.month %}

	{% endwith %}
    </div>
</article>
{% endcache %}
{% endblock %}

{% block sidebar %}
<aside id="sidebar" class="zp-33">
    {% include "_sidebar.article.tpl" %}
</aside>
{% endblock %}
