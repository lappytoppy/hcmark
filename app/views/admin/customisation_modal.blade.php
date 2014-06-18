<?php

$dir = "uploads";

?>
{{
Form::open(
    array(
        'method' => 'post',
        'route' => 'admin.custm_save',
        'files' => true,
        'role' => 'form',
        'id' => 'user-customisation-form',
        'files' => true
        )
)
}}
<input type="hidden" name="usr_id" value="{{ $user->id }}" />
<div class="row">
    <div class="col-md-6">
        <div class="form-group">
            <label>{{ $user->full_name }}</label>
            <div class="clearfix"></div>
            <div id="cust-usr-img-wrp">
                @if ($image)
                <img id="cust-usr-img" style="background-image:url('/uploads/images/{{ $image->logo }}')" alt="" class="">
                @else
                <img id="cust-usr-img" style="background-image:url('/uploads/images/placeholder.jpg')" alt="" class="">
                @endif
            </div>
        </div>
    </div>
    <div class="col-md-6">
        <div class="form-group">
            <label for="image_file">{{ Lang::get('ui.new_image_file') }}</label>
            <span class="btn btn-success btn-block fileinput-button">
                <i class="glyphicon glyphicon-plus"></i>
                <span>{{ Lang::get('messages.select_image') }}</span>
                <input type="file" id="image_file" name="image_file" accept="image/*">
            </span>
            <p class="help-block">{{ Lang::get('ui.image_file_note') }}</p>
        </div>
        <div class="form-group">
            <div class="progress">
                <div class="progress-bar progress-bar-success">
                </div>
            </div>
            <p class="progress-status"></p>
        </div>
        <div class="form-group">
            <p class="progress-response"></p>
        </div>
    </div>
</div>  
<div class="row">
    <div class="modal-footer">
    <button data-dismiss="modal" class="btn btn-default" type="button" id="imageFile_close">{{ Lang::get('ui.close') }}</button>
    {{ Form::button(
       Lang::get('ui.submit'),
          array('class' => 'btn btn-primary', 'id' => 'imageFileSubmit', 'disabled' => 'disabled' )) 
    }}
    </div>
</div>
{{ Form::close() }}

<style>
.fileinput-button{
margin-top: 11px;
}
.progress{
margin-bottom:0;
}
#cust-usr-img-wrp{
padding: 10px 0;
position: relative;
}
#cust-usr-img{
width: 100%;
height: 266px;
background-position: center;
background-size: cover;
background-repeat: no-repeat;
border-radius: 8px;
-moz-border-radius: 8px;
-webkit-border-radius: 8px;
}
</style>

<script>
    (function(){
        var progress = $('#user-customisation-form .progress');
        var status = $('#user-customisation-form .progress-status');
        var resp = $('#user-customisation-form .progress-response');
        var imgElem = $('#cust-usr-img');
        var imgWrp = $('#cust-usr-img-wrp');
        var lng = {
            complete : '{{ Lang::get("messages.complete") }}',
            accept_file_types: '{{ Lang::get("messages.jquery_image_uploader.accept_file_types") }}',
            max_file_size: '{{ Lang::get("messages.jquery_image_uploader.max_file_size") }}'
        };
       
       $('#user-customisation-form').fileupload({
            url: $(this).attr('url'),
            dataType: 'json',
            paramName: 'image_file',
            disableImageResize: /Android(?!.*Chrome)|Opera/
                .test(window.navigator.userAgent),
            autoUpload: false,
            previewMaxWidth: 500,
            previewMaxHeight: 500,
            previewCrop: true,
            add: function (e, data) {
                var uploadErrors = [];
                var acceptFileTypes = /^image\/(gif|jpe?g|png)$/i;
                resp.html(null);
                if(data.originalFiles[0]['type'].length && !acceptFileTypes.test(data.originalFiles[0]['type'])) {
                    uploadErrors.push(lng.accept_file_types);
                }
                if(data.originalFiles[0]['size'].length && data.originalFiles[0]['size'] > 5000000) {
                    uploadErrors.push(lng.max_file_size);
                }
                if(uploadErrors.length > 0) {
                    __alert.error(resp,uploadErrors.join("\n"));
                } else {
                    fname = data.files[0].name;
                    status.text(fname);
                    data.context = $('#imageFileSubmit').removeAttr('disabled')
                        .click(function () {
                            $('#user-customisation-form .progress .progress-bar').remove();
                            progress.prepend($('<div class="progress-bar progress-bar-success"/>'));
                            data.context = $(this).attr('disabled','disabled');
                            data.submit();
                        });
                }
            },
            progressall: function (e, data) {
                var progress = parseInt(data.loaded / data.total * 100, 10);
                spinner.hover(imgWrp);
                $('#user-customisation-form .progress .progress-bar').css('width',progress + '%');
                status.text(progress + '%');
            },
            done: function (e, data) {
                spinner.remove(imgWrp);
                status.text(lng.complete);
                if ('success' == data.result.type)
                    imgElem.css('background-image','url(' + data.result.url + ')');
                __alert.insert(resp,data.result.message,data.result.type);
            }
        });
        /*
        $(image.mdlFrmId).on('change', image.imgFrmId, function(e) {
            var file = $(image.imgFrmId).prop('files')[0],
                filename = file.name,
                allowed = ['jpg','jpeg','gif','png','bmp'],
                extension = (/[.]/.exec(filename)) ? /[^.]+$/.exec(filename).toString() : '';
                
            if (allowed.indexOf(extension.toLowerCase()) < 0)
            {
                alert(image.extErrMsg);
                $(this.imgFrmId).val(null);
                return;
            }
            
            image.checkImgDim(file);
        });*/
    })()
</script>