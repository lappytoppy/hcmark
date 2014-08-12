$(document).ready(function(){
    var multiselects = ['#user_feat','#properties'];
    
    var msgs = {
        del_a: '{{ Lang::get("ui.confirm_delete") }}',
        no_selected: '{{ Lang::get("labels.no_selected") }}',
        edit_user_head: '{{ Lang::get("headings.edit_user") }}',
        delete: '{{ Lang::get("ui.delete") }}',
        cancel: '{{ Lang::get("ui.cancel") }}'
    }

     //add user from admin
    $('#add_user').bind('click', function(){
        full_name_obj = $('#admin_user_add input#full_name');
        email_obj = $('#admin_user_add input#email');
        group_obj = $('#admin_user_add select#group');
        password_obj = $('#admin_user_add input#password');
        password_confirmation_obj = $('#admin_user_add input#password_confirmation');
        org_name_obj = $('#admin_user_add input#org_name');
        telephone_obj = $('#admin_user_add input#telephone');
        notes_obj = $('#admin_user_add textarea#notes');
        feat_obj = $('#admin_user_add select#user_feat');
        prop_obj = $('#admin_user_add select#properties');
        
        //removing all errors 
        full_name_obj.parent().removeClass('has-error');
        email_obj.parent().removeClass('has-error');
        password_obj.parent().removeClass('has-error');
        password_confirmation_obj.parent().removeClass('has-error');
        
        //adding validation on fields
        if(full_name_obj.val().length < 2) {
            full_name_obj.parent().addClass('has-error');
            return false;
        }
        if(email_obj.val().length < 6) {
            email_obj.parent().addClass('has-error');
            return false;
        }
        if(password_obj.val().length < 5) {
            password_obj.parent().addClass('has-error');
            return false;
        }
        if(password_obj.val() != password_confirmation_obj.val()) {
            password_confirmation_obj.parent().addClass('has-error');
            return false;
        }
        //preparing data for post
        data = {
            'full_name' : full_name_obj.val(),
            'email'     : email_obj.val(),
            'group'     : group_obj.val(),
            'password'  : password_obj.val(),
            'org_name'  : org_name_obj.val(),
            'telephone' : telephone_obj.val(),
            'notes'  	: notes_obj.val(),
            'features'  : feat_obj.val(),
            'properties': prop_obj.val()
        };
        $.ajax({
            url:window.location.protocol+'//'+window.location.host+'/admin/add_user',
            type: 'POST',
            data: data,
            beforeSend: function() {
                spinner.hover('#admin_user_add .modal-content');
            },
            error: function(){
                spinner.remove('#admin_user_add .modal-content');
                __alert.error('#add-user-message');
            },
            success: function(data) {  
                spinner.remove('#admin_user_add .modal-content');  
                data = $.parseJSON(data);
                if(data['response']['type'] == 'danger') {
                    __alert.error('#add-user-message', data['response']['message'], data['response']['type']);
                } else {
                    //refreshing datatable content
                    var user = $('#datatable-user').dataTable();
                    user.fnClearTable(0);
                    user.fnDraw();
                    
                    //closing model box
                    //$('#admin_add_close').trigger('click');
                    
                    __alert.insert('#add-user-message', data['response']['message'], data['response']['type'])
                    
                    //resetting value of form
                    $('#form_user_add').find('input.form-control,textarea.form-control').val('');
                    
                    //multiselects = ['#user_feat','#properties'];
                    $('option', $(multiselects)).each(function(element) {
                        $(this).removeAttr('selected').prop('selected', false);
                    });
                    
                    $.each(multiselects, function(index,value){
                        $('option', $(value)).each(function(element) {
                            $(this).removeAttr('selected').prop('selected', false);
                        });
                        $(value).multiselect('refresh');
                    });
                }
            }                     
        }); 
    });
    
     //edit user from admin
    $('#datatable-user').on('click','.admin-edit-user',  function(){
        /*img_load = $('#edit-user-pre-content');
        $('#admin_user_edit .modal-dialog').html(img_load.html());
        $.ajax({
            url: window.location.protocol+'//'+window.location.host+'/admin/edit_user',
            type: 'POST',
            data: {'id' : $(this).attr('data-id')},
            success: function(data) {
               $('#admin_user_edit .modal-dialog').html(data);
            }
        });*/
        
        var id = $(this).data('id');
        modal.open(
            msgs.edit_user_head,
            urls.editUser,
            {'id':id},
            function(data){
                return data;
            }
        );
    });
    
    
    //edit user from admin
    $('#uni-modal').on('click', '#edit_user',  function(e){
        e.preventDefault();
        modal.spin();
        $.ajax({
            url: window.location.protocol+'//'+window.location.host+'/admin/store_user',
            type: 'POST',
            data: $('#admin_edit_form').serialize(),
            error: function(){
              modal.unspin();
              modal.error();
            },
            success: function(data) {
              modal.unspin();
              
              var user = $('#datatable-user').dataTable();
              user.fnClearTable(0);
              user.fnDraw();
              
              id = $('#admin_edit_form [name="id"]').val();
              
              if ('undefined' == typeof id){
                  alert('{{ Lang::get("messages.general") }}')
              } else {
                  modal.open(
                      msgs.edit_user_head,
                      urls.editUser,
                      {'id':id},
                      function(data){
                          return data;
                      }
                  );
              }
            }
        });
    });
     
    $('#datatable-user').on('click', '.loggin-as', function(){
        window.location = $(this).data('url');
    });
     
    $('#datatable-user').on('click', '.suspend', function(){
        var id = $(this).data('id'),
             set = $(this).data('set');
        $(this).removeClass('suspend').addClass('disabled');
        $.ajax({
            type: "POST",
            url: window.location.protocol+'//'+window.location.host+'/admin/suspend',
            data: { 'id': id, 'set': set }
        })
        .success(function(data) {
            var list = $('#datatable-user').dataTable();
            list.fnClearTable(0);
            list.fnDraw();
        });
    });
    
    $('#datatable-user').on('click', '.usr-customize', function(){
        var id = $(this).data('id');
        modal.open(
            '{{ Lang::get("headings.customisations") }}',
            urls.usrCustomize,
            {'id':id},
            function(data){
                return data;
            }
        );
    });
    
    $('#add-user-button').on('click',function(){
        $('#add-user-message').html('');
    })
    
    $.each(multiselects, function(index,value) {
        $(value).multiselect({
            nonSelectedText: msgs.no_selected,
            buttonWidth: '265px',
            maxHeight: 400,
            buttonContainer: '<span class="dropdown" />',
            checkboxName: $(value).data('checkboxname'),
            selectAllText: true,
            enableFiltering: true
        });
    });
    
    $('#datatable-user').on('click', '.user-delete', function(){
        var id = $(this).data('id');
        bootbox.dialog({
          message: msgs.del_a,
          buttons: {
            cancel: {
              label: msgs.cancel,
              className: "btn",
              callback: function() {
              }
            },
            confirm: {
              label: msgs.delete,
              className: "btn btn-danger",
              callback: function() {
                var table = '#datatable-user_wrapper';
                $.ajax({
                    url: window.location.protocol+'//'+window.location.host+'/admin/delete_user',
                    type: 'POST',
                    data: {'id':id},
                    dataType: 'json',
                    beforeSend: function(){
                      spinner.hover(table);
                    },
                    error: function(){
                      modal.error();
                      spinner.remove(table);
                    },
                    success: function(data) {
                      var list = $('#datatable-user').dataTable();
                      list.fnClearTable(0);
                      list.fnDraw();
                      spinner.remove(table);
                      __alert.insert('#message',data.message,data.type);
                    }
                });
              }
            }
          }
        });
    });

    //data table for user-list

     $.fn.dataTableExt.sErrMode = 'throw';

     // Email list
     var list = $('#datatable-user').dataTable({
       "iDisplayLength": 10,
       "bLengthChange": true,
       "bProcessing" : true,
       "bServerSide": true,
       "bAutoWidth": false,

       "aoColumns": [
           { "asSorting": [ "asc", "desc" ] },
           { "asSorting": [ "asc", "desc" ] },
           { "asSorting": [ "asc", "desc" ] }, 
           { "asSorting": [ "asc", "desc" ] },
           { "bSortable": false , "sWidth": "160px" },
       ],
       "fnRowCallback": function( nRow, aData, iDisplayIndex, iDisplayIndexFull ) {
          $('td:eq(4)', nRow).addClass( "action" );
        },
       "sAjaxSource": '/admin/user_list'
     });
});
