<?php 

class Customisation extends Eloquent {

    /**
     * The database table used by the model.
     *
     * @var string
     */
    protected $table = 'customisations';  
    
    public function users()
    {
        $this->belongsToMany('Users');
    }
}