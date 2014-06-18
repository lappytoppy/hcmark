<!-- /. add-user -->
<div aria-hidden="true" aria-labelledby="DefaultModalColorLabel" role="dialog" tabindex="-1" id="admin_user_add" class="modal fade" style="display: none;">
    <div class="modal-dialog">
          <div class="modal-content modal-no-shadow modal-no-border">
           {{ Form::open(array('route' => 'admin.add_user', 'class' => 'form-horizontal', 'id' => 'form_user_add')) }} 
            <div class="modal-header">
                  <button aria-hidden="true" data-dismiss="modal" class="close" type="button">×</button>
                  <h4 id="DefaultModalColorLabel" class="modal-title">{{ Lang::get('headings.add_user') }}</h4>
            </div>
            <div class="modal-body">
                <div id="add-user-message"></div>
                <div class="row">
                    <div class="col-md-6">
                        <div class="form-group">
                               <label>{{ Lang::get('ui.group') }}</label>
                                {{ Form::select(
                                    'group', 
                                    $group, 
                                    null,
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
                                    null,
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
                                    null,
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
            </div>
            <div class="modal-footer">
                  <button data-dismiss="modal" class="btn btn-default" type="button" id="admin_add_close">{{ Lang::get('ui.close') }}</button>
                  {{ Form::button(
                     Lang::get('ui.add_user'),
                        array('class' => 'btn btn-primary', 'name' => 'add_user', 'id' => 'add_user' )) 
                   }}
            </div><!-- /.modal-footer -->
            {{ Form::close() }}
          </div><!-- /.modal-content .modal-no-shadow .modal-no-border -->
    </div><!-- /.modal-dialog -->
</div> 
<!-- /. add-user -->