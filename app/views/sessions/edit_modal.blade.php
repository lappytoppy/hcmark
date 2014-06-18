<?php
Form::macro('static_input', function($name)
{
    $value = Form::getValueAttribute($name);
    return '<p class="form-control-static">' . $value . '</p>';
});
?>

<div class="modal-dialog">
    <div class="modal-content modal-no-shadow modal-no-border">
        {{ Form::model($user, array('method' => 'post', 'route' => array('user.update', $user->id), 'role' => 'form', 'id'=>'global-edit-form')) }}
            <div class="modal-header">
                <button aria-hidden="true" data-dismiss="modal" class="close" type="button">&times;</button>
                <h4 id="" class="modal-title">{{ Lang::get('headings.account_detail') }}</h4>
            </div>
            <div class="modal-body">
                {{ Form::hidden ('email') }}
                {{ Form::hidden ('notes') }}
                
                <div id="message">
                    {{ Messages::show() }} 
                </div>
                
                <div class="row"> 
                    <div class="col-sm-6">
                        <div class="form-group">
                            <label>{{ Lang::get('ui.email_add') }}</label>
                            {{ Form::static_input('email') }} 
                        </div>
                        <div class="form-group">
                              <label>{{ Lang::get('ui.password') }}</label>
                              {{ Form::password(
                                  'password',
                                  array(
                                      'class' => 'form-control',
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
                              <label>{{ Lang::get('ui.full_name_p') }}</label>
                              {{ Form::text(
                                  'full_name',
                                  null,
                                  array(
                                      'class' => 'form-control',
                                      'placeholder' => Lang::get('ui.full_name_p'),
                                      'title' => Lang::get('ui.full_name_p'),
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
                    </div>
                </div>
            </div>
            <div class="modal-footer">
                <button id="" data-dismiss="modal" class="btn btn-default" type="button">{{ Lang::get('ui.close') }}</button>
                {{ Form::button(
                 Lang::get('ui.update'),
                    array('class' => 'btn btn-primary', 'name' => 'g-account-update', 'id' => 'g-account-update', 'type' => 'submit')) 
               }}
            </div>
        {{ Form::close() }}
    </div>
</div>