<?php
/**
 * Messages Controller Class
 *
 * @package Laravel
 * @subpackage Controllers
 * @category Message Controllers
 */
class MessagesController extends BaseController {
            
            
    // --------------------------------------------------------------------

    /**
     * provide value of assoicated key
     * 
     * @param null
     *
     * @return $value string
     */
    public function get_value()
    {
        //prepare data for validation
        $data = array(
            'key' => Request::get('key'),
            'type' => Request::get('type'),
        );
        
        //validation rule for data
        $rules = array( 
            'key' => 'required|between:1,100', 
            'type' => 'required'
        );
        
        //add validation for data and rules
        $validator = Validator::make($data, $rules);
        if($validator->fails()) {
            exit;
        }
       
        //exporting varible from associated array
        extract($data); 
        return View::make('messages.get_value')->with('value', Lang::get($key))
                                   ->with('type', $type);
    } 
}
