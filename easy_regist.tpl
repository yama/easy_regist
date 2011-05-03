<?php
$default_tpl = default_tpl();

$entry_form     = ($tpl_entry_form)     ? $modx->getChunk($tpl_entry_form)  : $modx->parseDocumentSource($default_tpl['entry_form']);
$entry_now      = ($tpl_entry_now)      ? $modx->getChunk($tpl_entry_now)   : $modx->parseDocumentSource($default_tpl['entry_now']);
$regist_form    = ($tpl_regist_form)    ? $modx->getChunk($tpl_regist_form) : $modx->parseDocumentSource($default_tpl['regist_form']);
$act_mail       = ($tpl_act_mail)       ? $modx->parseDocumentSource($modx->getChunk($tpl_act_mail))    : $modx->parseDocumentSource($default_tpl['act_mail']);
$regist_welcome = ($tpl_regist_welcome) ? $modx->getChunk($tpl_regist_welcome): $modx->parseDocumentSource($default_tpl['regist_welcome']);


$tbl_web_users           = $modx->getFullTableName('web_users');
$tbl_web_user_settings   = $modx->getFullTableName('web_user_settings');
$tbl_web_user_attributes = $modx->getFullTableName('web_user_attributes');

if(isset($_POST['email']))
{
	$_POST['email'] = trim($_POST['email']);
	$username              = $modx->db->escape($_POST['email']);
//	$modx->sendRedirect($modx->makeUrl($modx->documentIdentifier), 0, 'REDIRECT_HEADER', 'HTTP/1.1 301 Moved Permanently');
	$web_users = $modx->db->select('id', $tbl_web_users, "username='{$username}'");
	
	if($modx->db->getRecordCount($web_users) > 0) $output = 'すでに登録されています。';
	else
	{
		$a_key_string          = uniqid();
		$tmp_password          = substr(uniqid(),0,7);
		$fields['username']    = $username;
		$fields['password']    = md5($tmp_password);
		$fields['cachepwd']    = $a_key_string;
		$modx->db->insert( $fields, $tbl_web_users);
		$key                   = mysql_insert_id();
		unset($fields);
		
		$fields['internalKey'] = $key;
		$fields['fullname']    = $username;
		$fields['email']       = $username;
		$fields['blocked']     = '1';
		$modx->db->insert($fields, $tbl_web_user_attributes);
		unset($fields);
		
		send_actmail($username,$a_key_string,$act_mail);
		
		$output = $entry_now;
		
	}
}
elseif(isset($_POST['mode']))
{
	$key       = $modx->db->escape($_POST['key']);
	$password  = md5($modx->db->escape($_POST['password']));
	$web_users = $modx->db->select('id', $tbl_web_users, "cachepwd='{$key}'");
	if($modx->db->getRecordCount($web_users)==1)
	{
		$uid = $modx->db->getValue($web_users);
		
		$fields['id']       = $uid;
		$fields['password'] = $password;
		$modx->db->update($fields, $tbl_web_users, "'id={$uid}'");
		unset($fields);
		$fields['blocked']     = '0';
		$modx->db->update($fields, $tbl_web_user_attributes, "internalKey='{$uid}'");
		

/*
		$snip_path = MODX_BASE_PATH . 'assets/snippets/';
		include_once $snip_path . 'weblogin/weblogin.common.inc.php';
		include_once ($modx->config['base_path'] . 'manager/includes/crypt.class.inc.php');
		include_once $modx->config['base_path'] . 'manager/includes/log.class.inc.php';
		include_once $snip_path . 'weblogin/weblogin.processor.inc.php';
		include_once $snip_path . 'weblogin/weblogin.inc.php';
*/

		$web_users = $modx->db->select('username', $tbl_web_users, "id='{$uid}'");
		$username  = $modx->db->getValue($web_users);

		$_SESSION['webShortname']   = $username;
		$_SESSION['webFullname']    =$username;
		$_SESSION['webEmail']       =$username;
		$_SESSION['webValidated']   =1;
		$_SESSION['webInternalKey'] =$uid;
//		$_SESSION['userid'] = $uid;
		$output = $regist_welcome;
		
	}
}
elseif(isset($_GET['key']))
{
	$key = $modx->db->escape($_GET['key']);
	$web_users = $modx->db->select('id', $tbl_web_users, "cachepwd='{$key}'");
	if($modx->db->getRecordCount($web_users)==1)
	{
		$add_field['key']  = '<input type="hidden" name="key" value="' . $key . '" />';
		$add_field['mode'] = '<input type="hidden" name="mode" value="do_regist" />';
		$add_fields = join("\n",$add_field);
		$output = str_replace('</form>', $add_fields . "\n</form>", $regist_form);
	}
}
else $output = $entry_form;

return $output;



function send_actmail($email,$a_key_string,$message)
{
	global $modx;
	$message = str_replace('[+act_key+]', $a_key_string, $message);
	$message = str_replace('{act_key}',   $a_key_string, $message);
	mb_language('Japanese');
	mb_internal_encoding($modx->config['modx_charset']);
	$from_name = mb_encode_mimeheader($modx->config['site_name']);
	$from      = $modx->config['emailsender'];
	$subject   = '登録メール';
	$header[] = 'Content-type: text/plain; charset="iso-2022-jp"';
	$header[] = "From: {$from_name}<{$from}>";
	$header[] = 'Date: ' . date('r');
	$headers = join("\n", $header);
	mb_send_mail($email, $subject, $message, $headers);
}

function default_tpl()
{
	global $modx;
	$site_url = $modx->config['site_url'];
	$url   = $site_url . ltrim($modx->makeUrl($modx->documentIdentifier),'/');
	$delim = (strpos($_SERVER['REQUEST_URI'],'?')!==false) ? '&' : '?';
	
	$tpl['entry_form']     = '<form action="[(site_url)][~[*id*]~]" method="POST"> メールアドレス <input type="text" name="email" /> <input type="submit" val="regist" /></form>';
	$tpl['entry_now']      = 'アクティベーションメールを送信しました。';
	$tpl['regist_form']    = '<form action="' . $url . '" method="POST"> パスワードを設定 <input type="password" name="password" /> <input type="hidden" name="mode" value="do_regist" /> <input type="hidden" name="key" value="{key}" /> <input type="submit" val="regist" /></form>';
	$tpl['regist_welcome'] = '[(site_url)][~22~]<br />利用者登録が完了しました。上記のURLからログインしてください。';
	$tpl['act_mail']       = $url . $delim . 'key={act_key}' . "\n" . '上記URLにアクセスしてください';
	
	return $tpl;
}
?>