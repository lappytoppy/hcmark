<?php
/**
 * Messages Library Class
 *
 * @package Laravel
 * @subpackage Library
 * @category Shared Libraries
 */
class Messages {

    // --------------------------------------------------------------------

    /**
     * set: Set a message
     *
     * @param  string  $message
     * @param  string  $type (success, info, warning, danger)
     */
    public static function set($message, $type, $v1 = '', $v2 = '', $v3 = '')
    {
        $message = str_replace('$1', $v1, $message);
        $message = str_replace('$2', $v2, $message);
        $message = str_replace('$3', $v2, $message);

        $messages = array();
        if (Session::has('messages'))
        {
            $messages = Session::get('messages');
            $messages[] = array('msg' => $message, 'type' => $type);
        }
        else
        {
            $messages[] = array('msg' => $message, 'type' => $type);
        }

        Session::put('messages', $messages);
    }

    // --------------------------------------------------------------------

    /**
     * show: Show messages
     *
     * @return string
     */
    public static function show()
    {
        $html = '';

        if (Session::has('messages'))
        {
            $messages = Session::get('messages');

            foreach($messages as $message)
            {
                $html .= <<<EOF
<div class="alert alert-{$message['type']} alert-bold-border fade in alert-dismissable">
  <button aria-hidden="true" data-dismiss="alert" class="close" type="button">&times;</button>
  {$message['msg']}
</div>
EOF;
            }
        }

        Session::forget('messages');
        return $html;
    }

    // --------------------------------------------------------------------

}