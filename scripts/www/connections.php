<?php
$host = $_GET['host'];
$max = $_GET['max'];

$res = shell_exec("/usr/bin/curl --max-time 3 -L ".$host);
$count = explode(" ", $res);

if ($count[2] >= $max) header("HTTP/1.0 403 Forbidden");
else echo "ok!";
?>
