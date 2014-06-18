<?php 

class Features extends Eloquent {

    /**
     * The database table used by the model.
     *
     * @var string
     */
    protected $table = 'features';  

    public $timestamps = false;
    
    public function users()
    {
        $this->belongsToMany('Users');
    }
    
    public static function g_list() 
    {
        $groups = Features::all(array('id', 'name'));
        $list = array();
        foreach($groups as $group)
        {
            $list[$group->id] = ucfirst($group->name);
        }
        return $list;
    }
    
    public static function saveByUser($userId, $featIds = array())
    {
        $featIds = array_unique($featIds);
        
        DB::delete('DELETE from user_features where user_id =' . $userId);
        
        $insert = array();
        
        if (count($featIds))
        {
            foreach ($featIds as $id)
            {
                $insert[] = array('user_id' => $userId, 'feature_id' => $id);
            }
            
            DB::table('user_features')->insert($insert);
        }
    }
    
    public static function clearByUser($userId)
    {
        DB::delete('DELETE from user_features where user_id =' . $userId);
    }

    public static function user_features($user_id)
    {
        $features = DB::table('features')
            ->join('user_features', 'user_features.feature_id', '=', 'features.id')
            ->select('features.name', 'features.template', 'features.slug')
            ->where('user_features.user_id', $user_id)
            ->get();

        return $features;
    }
}