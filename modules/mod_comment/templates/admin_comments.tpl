{% extends "admin_base.tpl" %}

{% block title %}
{_ Recent Comments _}
{% endblock %}

{% block content %}
<div class="edit-header">

    <div class="pull-right">
        <a class="btn btn-default btn-sm" href="{% url admin_comments_settings %}">{_ Settings _}</a>
    </div>

    <h2>{_ Recent comments _}</h2>

    <table class="table table-striped do_adminLinkedTable">
        <thead>
            <tr>
                <th width="15%">{_ Added on _}</th>
                <th width="15%">{_ Page _}</th>
                <th width="35%">{_ Message _}</th>
                <th width="35%">{_ Name _} / {_ Email _}</th>
            </tr>
        </thead>

        <tbody>
            {% with m.search.paged[{recent_comments page=q.page}] as result %}
            {% for comment in result %}
            {% with comment.id as id %}
            <tr id="{{ #comment.id }}" {% if not comment.is_visible %}class="unpublished" {% endif %} data-href="{{ m.rsc[comment.rsc_id].page_url }}#comment-{{ id }}">
                <td>{{ comment.created|date:_"d M Y, H:i" }}</td>
                <td>{{ m.rsc[comment.rsc_id].title|truncate:20 }}</td>
                <td>{{ comment.message|striptags|truncate:40 }}</td>
                <td title="{{ comment.email }}">
                    <div class="pull-right">
                        {% button class="btn btn-default btn-xs" text=_"view" action={redirect location=[m.rsc[comment.rsc_id].page_url,"#comment-",id|format_integer]|join } %}
                        {% include "_admin_comments_toggledisplay.tpl" element=#comment.id %}
                        {% button class="btn btn-default btn-xs"
                           text=_"delete"
                           action={confirm text=_"Are you sure you wish to delete that comment?"
                           action={postback delegate="controller_admin_comments"
                                            postback={comment_delete id=id on_success={slide_fade_out target=#comment.id}}}} %}
                    </div>
                    {% if comment.user_id %}
                    {{ m.rsc[comment.user_id].title }} (#{{ comment.user_id }})
                    {% else %}
                    {{ comment.name|truncate:20 }} &ndash;
                    {{ comment.email|truncate:20|escape }}
                    {% endif %}
                </td>
            </tr>
            {% endwith %}
            {% empty %}
            <tr>
                <td colspan="4">
                    {_ There are no comments. _}
                </td>
            </tr>
            {% endfor %}
        </tbody>
    </table>
    {% pager result=result dispatch="admin_comments" qargs %}
    {% endwith %}

</div>
{% endblock %}
