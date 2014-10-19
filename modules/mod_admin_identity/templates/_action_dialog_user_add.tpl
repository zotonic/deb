
{% wire id=#form type="submit" postback={user_add on_success=on_success} delegate=delegate %}
<form id="{{ #form }}" method="POST" action="postback" class="form">

    <h4>{_ Name and e-mail address _}</h4>
    <p>
	    {_ Give the name and the e-mail address of the new user. A <em>person</em> page will be created for this user. _}
    </p>

    <div class="form-group row">
	    <label class="control-label col-md-3" for="{{ #name_first }}">{_ First _}</label>
        <div class="col-md-6">
	        <input type="text" id="{{ #name_first }}" name="name_first" value="" class="do_autofocus form-control" />
	        {% validate id=#name_first name="name_first" type={presence} %}
	    </div>
    </div>

    <div class="form-group row">
	    <label class="control-label col-md-3" for="{{ #name_surname_prefix }}">{_ Sur. prefix _}</label>
        <div class="col-md-9">
	        {# below we do not use name_surename_prefix because it confuses the autofill of browsers #}
	        <input class="form-control" type="text" id="{{ #name_surname_prefix }}" name="surprefix" value="" style="width: 50px"/>
	    </div>
    </div>

    <div class="form-group row">
	    <label class="control-label col-md-3" for="{{ #name_surname }}">{_ Surname _}</label>
        <div class="col-md-9">
	        <input class="form-control" type="text" id="{{ #name_surname }}" name="name_surname" value="" />
	        {% validate id=#name_surname name="name_surname" type={presence} %}
	    </div>
    </div>

    <div class="form-group row">
	    <label class="control-label col-md-3" for="{{ #email }}">{_ E-mail _}</label>
        <div class="col-md-9">
	        <input class="form-control" type="text" id="{{ #email }}" name="email" value="" />
	        {% validate id=#email name="email" type={presence} type={email} %}
	    </div>
    </div>

    <hr />

    <h4>{_ Username and password _}</h4>
    <p>
	    {_ Enter a unique username and a password. Usernames and passwords are case sensitive, so be careful when entering them. _}
    </p>

	
    <div class="form-group row">
	    <label class="control-label col-md-3" for="new_username">{_ Username _}</label>
        <div class="col-md-9">
	        <input class="form-control" type="text" id="new_username" name="new_username" value="" />
	        {% validate id="new_username" wait=400 type={presence} type={username_unique} %}
	    </div>
    </div>

    <div class="form-group row">
	    <label class="control-label col-md-3" for="new_password">{_ Password _}</label>
        <div class="col-md-9">
	        <input class="form-control" type="password" id="new_password" name="new_password" value="" />
	        {% validate id="new_password" type={presence} %}
	    </div>
    </div>

    <div class="form-group row">
        <div class="col-md-9 col-md-offset-3">
            <div class="checkbox">
                <label>
                    <input type="checkbox" name="send_welcome" /> {_ Send welcome e-mail _}
                </label>
            </div>
        </div>
    </div>

    <div class="modal-footer">
	    {% button class="btn btn-default" action={dialog_close} text=_"Cancel" tag="a" %}
	    <button class="btn btn-primary" type="submit">{_ Add user _}</button>
    </div>
</form>

