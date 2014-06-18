<?php
/**
 * Upload Library Class
 * 
 * @package Laravel
 * @subpackage Library
 */
 
class Upload {
    
    public function __construct()
    {
        
    }
}

class UploadController extends BaseController
{
    public $restful = true;
    
    public function index(){
        $valid_exts = array('jpeg', 'jpg', 'png', 'gif'); // valid extensions
        $max_size = 2000 * 1024; // max file size (200kb)
        $path = public_path() . '/img/'; // upload directory
        $fileName = NULL;
        
        if ( $_SERVER['REQUEST_METHOD'] === 'POST' )
        {
            $file = Input::file('uploaded_img');
            // get uploaded file extension
            //$ext = $file['extension'];
            $ext = $file->guessClientExtension();
            // get size
            $size = $file->getClientSize();
            // looking for format and size validity
            $name = $file->getClientOriginalName();
            
            if (in_array($ext, $valid_exts) AND $size < $max_size)
            {
                // move uploaded file from temp to uploads directory
                if ($file->move($path,$name))
                {
                    $status = 'Image successfully uploaded!';
                    $fileName = $name;
                }
                else
                {
                    $status = 'Upload Fail: Unknown error occurred!';
                }
            }
            else
            {
            $status = 'Upload Fail: Unsupported file format or It is too large to upload!';
            }
        }
        else
        {
            $status = 'Bad request!';
        }
        // echo out json encoded status
        return header('Content-type: application/json') . json_encode(array('status' => $status,
        'fileName' => $fileName));
    }
}