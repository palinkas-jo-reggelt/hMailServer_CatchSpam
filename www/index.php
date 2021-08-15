<?php include("head.php") ?>

<?php
	include_once("config.php");
	include_once("functions.php");

	if (isset($_GET['page'])) {
		$page = $_GET['page'];
		$display_pagination = 1;
	} else {
		$page = 1;
		$total_pages = 1;
		$display_pagination = 0;
	}
	if (isset($_GET['submit'])) {$button = $_GET['submit'];} else {$button = "";}
	if (isset($_GET['search'])) {$search = trim($_GET['search']);} else {$search = "";}

	// echo "<br>";
	echo "<div class='section'>";
	echo "	<form action='./' method='GET'>";
	echo "		<input type='text' size='20' name='search' placeholder='Search...' value='".$search."'>";
	echo "		<input type='submit' name='submit' value='Search' >";
	echo "	</form>";
	echo "</div>";

	echo "<div class='section'>";

	$offset = ($page-1) * $no_of_records_per_page;
	
	$total_pages_sql = $pdo->prepare("
		SELECT COUNT(*) AS count 
		FROM hm_catchspam 
		WHERE domain LIKE '%".$search."%'
	");
	$total_pages_sql->execute();
	$total_rows = $total_pages_sql->fetchColumn();
	$total_pages = ceil($total_rows / $no_of_records_per_page);

	$sql = $pdo->prepare("
		SELECT 
			domain, 
			timestamp, 
			hits,
			safe
		FROM hm_catchspam 
		WHERE domain LIKE '%".$search."%'
		ORDER BY DATE(timestamp) DESC, hits DESC 
		LIMIT ".$offset.", ".$no_of_records_per_page
	);
	$sql->execute();

	if ($search==""){
		$search_res="";
	} else {
		$search_res=" for search term \"<b>".$search."</b>\"";
	}
	
	if ($total_pages < 2){
		$pagination = "";
	} else {
		$pagination = "(Page: ".number_format($page)." of ".number_format($total_pages).")";
	}

	if ($total_rows == 1){$singular = '';} else {$singular= 's';}
	if ($total_rows == 0){
		if ($search == ""){
			echo "Please enter a search term";
		} else {
			echo "No results ".$search_res;
		}	
	} else {
		echo "Results ".$search_res.": ".number_format($total_rows)." Domain".$singular." ".$pagination."<br>";
		echo "<table class='section' width='100%'>
			<tr>
				<th colspan='4' style='text-align:center;'>SEARCH OR BROWSE CATCHSPAM DOMAINS</th>
			</tr>
			<tr>
				<th>Domain</th>
				<th>Last Hit</th>
				<th>Hits</th>
				<th>Safe</th>
			</tr>";
		while($row = $sql->fetch(PDO::FETCH_ASSOC)){
			if (($row['hits'] > 2) && ($row['safe'] == 0)) {
				echo "<tr style='text-align:center;background-color:red;'>";
			} elseif (($row['hits'] == 2) && ($row['safe'] == 0)) {
				echo "<tr style='text-align:center;background-color:yellow;'>";
			} else {
				echo "<tr style='text-align:center;'>";
			}
				echo "<td style='text-align:left;'><a onClick=\"window.open('./domain.php?domain=".$row['domain']."','Domain','resizable,height=200,width=480'); return false;\">".$row['domain']."</a><noscript>You need Javascript to use the previous link or use <a href=\"domain.php?domain=".$row['domain']."\" target=\"_blank\">Domain/detail</a></noscript>";
				echo "<td>".date("y/n/j G:i:s", strtotime($row['timestamp']))."</td>";
				echo "<td>".$row['hits']."</td>";
				if ($row['safe']==0){
					echo "<td>No</td>";
				} elseif ($row['safe']==1){
					echo "<td style='font-weight:bold;background:#00e600;'>YES</td>";
				} else {
					echo "<td>ERR</td>";
				}
			echo "</tr>";
		}
		echo "</table>";

		if ($total_pages == 1){
			echo "";
		} else {
			echo "<ul>";
			if($page <= 1){echo "<li>First </li>";} else {echo "<li><a href=\"?submit=Search&search=".$search."&page=1\">First </a><li>";}
			if($page <= 1){echo "<li>Prev </li>";} else {echo "<li><a href=\"?submit=Search&search=".$search."&page=".($page - 1)."\">Prev </a></li>";}
			if($page >= $total_pages){echo "<li>Next </li>";} else {echo "<li><a href=\"?submit=Search&search=".$search."&page=".($page + 1)."\">Next </a></li>";}
			if($page >= $total_pages){echo "<li>Last</li>";} else {echo "<li><a href=\"?submit=Search&search=".$search."&page=".$total_pages."\">Last</a></li>";}
			echo "</ul>";
		}
	}
?>

<br>
</div> <!-- end of section -->

<?php include("foot.php") ?>