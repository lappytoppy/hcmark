<?php
  /* 
   * Paging
   */
  $current_user_id = Sentry::getUser()->id;
  $json = array(
            "iTotalRecords"=> $user['total'],
             "iTotalDisplayRecords"=> $user['total'], 
              "sEcho"=> Input::get('sEcho'),
            );

        if (count($user['search'])){
            foreach($user['search'] as $row)
            {
                $own = ($current_user_id == $row->id ? true : false);
                $en = ($current_user_id == $row->id || 'admin' == $row->name ? false : true);
                $json['aaData'][] = array(
                    ucwords($row->full_name),
                    $row->email,
                    ucfirst($row->name),
                    ($row->suspended ? Lang::get("labels.suspended") : Lang::get("labels.active")),
                    '<div style="width:315px">
                    <button class="btn btn-info btn-xs admin-edit-user" data-id="' . $row->id . '"><i class="fa fa-pencil"></i> ' .  Lang::get("ui.edit")  . ' </button>
                    <button style="width:71px" class="btn btn-xs'. (!$own ? ' suspend' : ' disabled') . (!$row->suspended ? ' btn-warning' : ' btn-success') .'" data-id="' .(!$own ? $row->id : '').'" data-set="' . (!$row->suspended ? '0' : '1') .'"><i class="fa fa-ban"></i>' . Lang::get((!$row->suspended ? "ui.suspend" : "ui.unsuspend")) . ' </button>
                    <button class="btn btn-primary btn-xs '. ($en ? 'loggin-as' : 'disabled') . '" data-url="' . ($en ? route('admin.loggin_as', $row->id) : '') . '"><i class="fa fa-user"></i>' . Lang::get("ui.login_as") . '</button>
                    <button class="btn btn-xs usr-customize" data-id="' . $row->id . '"><i class="fa fa-cog"></i>' . Lang::get("ui.customize") . '</button>
                    <button class="btn btn-xs btn-danger'.(!$own ? ' user-delete' : ' disabled').'" data-id="' . (!$own ? $row->id : '') . '"><i class="fa fa-trash-o"></i> Delete</button>
                    </div>'
                    );
            }
        } else {
            $json['aaData'] = array();
        }
  
  echo json_encode($json);
?>