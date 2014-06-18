<?php
    $myFeat = array();
    $myProp = array();
    
    foreach ($user->features as $feat) {
        $myFeat[] = $feat->id;
    }
    
    foreach ($user->properties as $prop) {
        $myProp[] = $prop->id;
    }
?>
{{ Form::model($user, array('method' => 'post', 'route' => array('user.update', $user->id), 'role' => 'form', 'id' => 'admin_edit_form')) }}
  {{ Form::hidden('id') }}
  
  <div id="message">
    {{ Messages::show() }} 
  </div>
  
  <div class="row">
     <div class="col-md-6">
          <div class="form-group">
                 <label>{{ Lang::get('ui.group') }}</label>
                  {{ Form::select(
                      'group', 
                      $group,
                      $user->group->first()->name,
                       array(
                          'class' => 'form-control',
                          'id' => 'group'
                       )
                      )
                  }}  
          </div>
          <div class="form-group">
                 <label>{{ Lang::get('ui.full_name_p') }}</label>
                  {{ Form::text(
                      'full_name',
                      null,
                      array(
                          'class' => 'form-control',
                          'id' => 'full_name',
                          'placeholder' => Lang::get('ui.full_name_p'),
                          'title' => Lang::get('ui.full_name_p'),
                          'autofocus'
                          )
                      ) 
                  }}  
          </div>
          <div class="form-group">
                <label>{{ Lang::get('ui.email_add') }}</label>
                  {{ Form::text(
                      'email',
                      null,
                      array(
                          'class' => 'form-control',
                          'id' => 'email',
                          'placeholder' => Lang::get('ui.email_p'),
                          'title' => Lang::get('ui.email_p'),
                          'autofocus'
                          )
                      ) 
                 }}  
          </div>
          <div class="form-group">
                <label>{{ Lang::get('ui.password') }}</label>
                  {{ Form::password(
                      'password',
                      array(
                          'class' => 'form-control',
                          'id' => 'password', 
                          'placeholder' => Lang::get('ui.password_p'),
                          'title' => Lang::get('ui.password_p'),
                          'autofocus'
                          )
                      ) 
                  }}  
          </div>
          <div class="form-group">
              <label>{{ Lang::get('ui.re_password') }}</label>
              {{ Form::password(
                      'password_confirmation',
                      array(
                          'class' => 'form-control',
                          'id' => 'password_confirmation', 
                          'placeholder' => Lang::get('ui.repassword_p'),
                          'title' => Lang::get('ui.repassword_p'),
                          'autofocus'
                          )
                      ) 
              }}  
          </div> 
     </div>
     <div class="col-md-6">
            <div class="form-group">
                   <label>{{ Lang::get('labels.feat') }}</label>
                    {{ Form::select(
                        'features[]',
                        $features,
                        $myFeat,
                        array(
                            'class' => 'form-control multiselect',
                            'id' => 'user_feat',
                            'placeholder' => Lang::get('labels.feat_p'),
                            'title' => Lang::get('labels.feat_p'),
                            'multiple' => 'multiple',
                            'data-checkboxname' => 'features[]',
                            'autofocus'
                            )
                        ) 
                    }}  
            </div>
            <div class="form-group">
                   <label>{{ Lang::get('labels.properties') }}</label>
                    {{ Form::select(
                        'properties[]',
                        $properties,
                        $myProp,
                        array(
                            'class' => 'form-control multiselect',
                            'id' => 'properties',
                            'placeholder' => Lang::get('labels.properties_p'),
                            'title' => Lang::get('labels.properties_p'),
                            'multiple' => 'multiple',
                            'data-checkboxname' => 'properties[]',
                            'autofocus'
                            )
                        ) 
                    }}  
            </div>
            <div class="form-group">
                   <label>{{ Lang::get('labels.org_name') }}</label>
                    {{ Form::text(
                        'org_name',
                        null,
                        array(
                            'class' => 'form-control',
                            'id' => 'org_name',
                            'placeholder' => Lang::get('labels.org_name_p'),
                            'title' => Lang::get('labels.org_name_p'),
                            'autofocus'
                            )
                        ) 
                    }}	
            </div>
            <div class="form-group">
                   <label>{{ Lang::get('labels.telephone') }}</label>
                    {{ Form::text(
                        'telephone',
                        null,
                        array(
                            'class' => 'form-control',
                            'id' => 'telephone',
                            'placeholder' => Lang::get('labels.telephone_p'),
                            'title' => Lang::get('labels.telephone_p'),
                            'autofocus'
                            )
                        ) 
                    }}	
            </div>
            <div class="form-group">
                   <label>{{ Lang::get('labels.notes') }}</label>
                    {{ Form::textarea(
                        'notes',
                        null,
                        array(
                            'class' => 'form-control',
                            'id' => 'notes',
                            'placeholder' => Lang::get('labels.notes_p'),
                            'title' => Lang::get('labels.notes_p'),
                            'autofocus',
                            'rows' => '4',
                            'style' => 'min-height: 109px'
                            )
                        ) 
                    }}	
            </div>
        </div>
   </div>
  <div class="row">
      <div class="modal-footer">
            <button data-dismiss="modal" class="btn btn-default" type="button" id="admin_edit_close">{{ Lang::get('ui.close') }}</button>
            {{ Form::button(
               Lang::get('ui.update'),
                  array('class' => 'btn btn-primary', 'name' => 'update', 'id' => 'edit_user' )) 
             }}
      </div>
   </div>
{{ Form::close() }}
<script>
    jQuery('#admin_edit_form .multiselect').each(function(){
        var cName = jQuery(this).data('checkboxname');
        jQuery(this).multiselect({
            nonSelectedText: '{{ Lang::get("labels.no_selected") }}',
            buttonWidth: '265px',
            maxHeight: 400,
            buttonContainer: '<span class="dropdown" />',
            checkboxName: cName,
            selectAllText: true,
            enableFiltering: true
        })
    });
</script>