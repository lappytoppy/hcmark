<?php

$propertyList = array();

if ($properties)
{
    if (!$id)
    {
        foreach ($properties as $p)
        {
            $propertyList[] = array(
                $p->property_name,
                $p->full_name,
                $p->email,
                $p->telephone,
                $p->id
            );
        }
    }
    else
    {
        $propertyList = array(
            $properties->property_name,
            $properties->full_name,
            $properties->email,
            $properties->telephone,
            $properties->notes,
            $properties->id,
            array($properties->property_type_id),
            array($properties->star_rating_id),
            array($properties->pms_config_id),
            $properties->pms_account_ref
        );
    }
}
else
{
	$propertyList = array('','','','','');
}

echo json_encode($propertyList);