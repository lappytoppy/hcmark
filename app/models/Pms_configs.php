<?php 

class Pms_configs extends Eloquent {

    /**
     * The database table used by the model.
     *
     * @var string
     */
    protected $table = 'pms_configs';

    public $timestamps = false;
    
    public static function g_list() 
    {
        $results = Pms_configs::all(array('id', 'name'));
        $list = array();
        foreach($results as $result)
        {
            $list[$result->id] = ucfirst($result->name);
        }
        return $list;
    }
}