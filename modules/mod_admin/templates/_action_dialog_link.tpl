
<p>{_ Type the title of the page you want to connect to.  Click “Make a new connection” when the page does not yet exist. _}</p>

{% button text=_"Make a new connection" class="left" action={dialog_close} action={dialog_new_rsc redirect=false subject_id=subject_id predicate=predicate cat=predicate_cat edge_template=edge_template} %}

<p>{_ or use the autocompleter to search the site. _}</p>

<div class="form-item autocomplete-wrapper clear">
	<input id="{{#input}}" class="autocompleter" type="text" value="" />
	<ul id="{{#suggestions}}" class="suggestions-list"></ul>
</div>

{% wire id=#input
	type="keyup" 
	action={typeselect
				target=#suggestions 
				action_with_id={with_args action={link subject_id=subject_id predicate=predicate element_id=element_id edge_template=edge_template} arg={object_id select_id}}
				action={dialog_close}
				action=action
				cat=m.predicate.object_category[predicate]
			}
%}
