<?php
	include_once("config.php");

	if (isset($_COOKIE['username']) && isset($_COOKIE['password'])) {
		if (!(($_COOKIE['username'] === $user_name) && ($_COOKIE['password'] === md5($pass_word)))) {
			header('Location: login.php');
		}
	} else {
		header('Location: login.php');
	}
?>

<!DOCTYPE html> 
<html>
<head>
<title>hMailServer CatchSpam</title>
<meta http-equiv="Content-Type" content="text/html; charset=UTF-8" />
<meta http-equiv="Content-Style-Type" content="text/css">
<meta name="viewport" content="width=device-width, initial-scale=1">
<link rel="stylesheet" type="text/css" media="all" href="stylesheet.css">
<link href="https://fonts.googleapis.com/css?family=Roboto" rel="stylesheet">
<link href="https://fonts.googleapis.com/css?family=Oswald" rel="stylesheet"> 
</head>
<body>

<?php
	include_once("config.php");
	include_once("functions.php");

	if (isset($_GET['domain'])) {$domain = $_GET['domain'];} else {$domain = "";}
	if (isset($_GET['makesafe'])){
		$pdo->exec("UPDATE hm_catchspam SET safe=1 WHERE domain='".$domain."';");
		header("Location: ./domain.php?domain=".$domain);
	}
	if (isset($_GET['makeunsafe'])){
		$pdo->exec("UPDATE hm_catchspam SET safe=0 WHERE domain='".$domain."';");
		header("Location: ./domain.php?domain=".$domain);
	}

	echo "<div class='section'>";

	$sql = $pdo->prepare("
		SELECT 
			domain, 
			timestamp, 
			hits, 
			safe 
		FROM hm_catchspam
		WHERE domain = '".$domain."';
	");
	$sql->execute();
	echo "<table class='section'>";
	while($row = $sql->fetch(PDO::FETCH_ASSOC)){
		echo "<tr>
				<td>Domain:</td>
				<td style='text-align:center;'>".$row['domain']."</td>
			</tr>";
		echo "<tr>
				<td>Last Seen:</td>
				<td style='text-align:center;'>".$row['timestamp']."</td>
			</tr>";
		echo "<tr>
				<td>Hits:</td>
				<td style='text-align:center;'>".$row['hits']."</td>
			</tr>";
		if ($row['safe']==0){
			echo "<tr>
					<td>Safe Status:</td>
					<td style='text-align:center;'>NOT SAFE</td>
				 </tr>
				 <tr>
					<td colspan='2' style='text-align:center;'>
						<form action='domain.php' method='GET' onsubmit='return confirm(\"Are you sure you want to mark the domain SAFE?\");'>
							<input type='hidden' name='domain' value='".$row['domain']."'>
							<input type='submit' name='makesafe' value='Mark Safe' >
						</form>
					</td>
				</tr>";
		} else {
			echo "<tr>
					<td>Safe Status:</td>
					<td style='text-align:center;'>SAFE</td>
				 </tr>
				 <tr>
					<td colspan='2' style='text-align:center;'>
						<form action='domain.php' method='GET' onsubmit='return confirm(\"Are you sure you want to mark the domain UNSAFE?\");'>
							<input type='hidden' name='domain' value='".$row['domain']."'>
							<input type='submit' name='makeunsafe' value='Mark Unsafe' >
						</form>
					</td>
				</tr>";
		}
	}
	echo "</table>";
	echo "<br><br>";
	echo "</div>";

?>

</body>