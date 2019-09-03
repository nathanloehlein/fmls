$Players = @()
$playerRounds = @()
$playersOutFile = "Players.csv"
$playerRoundFile = "playerbyRound.csv"

$excludes = @(13356,248938,426797,224651, 227656, 248397, 234177, 424258, 445236, 234410, 471798, 427386) 

$URL = "https://fgp-data-us.s3.amazonaws.com/json/mls_mls/players.json"
$playerURL = "https://fgp-data-us.s3.amazonaws.com/json/mls_mls/stats/players/{0}.json"
$squadURL = "https://fgp-data-us.s3.amazonaws.com/json/mls_mls/squads.json"
$roundURL = "https://fgp-data-us.s3.amazonaws.com/json/mls_mls/rounds.json"
$schedule = @{}

$squadResponse = Invoke-WebRequest $squadURL
if($squadResponse.StatusCode -eq 200)
{
    $squads = $squadResponse.Content | ConvertFrom-Json
}

$roundsResponse = Invoke-WebRequest $roundURL
if($roundsResponse.StatusCode -eq 200)
{
    $rounds = $roundsResponse.Content | ConvertFrom-Json
}

foreach( $round in $rounds)
{
    foreach($squad in $squads)
    {
        $matches = @($round.matches | Where-Object { $_.home_squad_id -EQ $squad.id -OR $_.away_squad_id -EQ  $squad.id })

        if($matches.Count -eq 1) {
            #SGW
            if($schedule.ContainsKey($round.id))
            {
                $schedule[$round.id].Add($squad.id,"SGW")
            }else {
                $schedule[$round.id]=@{$squad.id="SGW"}
            }
        }
        elseif($matches.Count -gt 1) {
            #DGW
            if($schedule.ContainsKey($round.id))
            {
                $schedule[$round.id].Add($squad.id,"DGW")
            }else {
                $schedule[$round.id]=@{$squad.id="DGW"}
            }
        }
        else {
            #BYE
            if($schedule.ContainsKey($round.id))
            {
                $schedule[$round.id].Add($squad.id,"BYE")
            }else {
                $schedule[$round.id]=@{$squad.id="BYE"}
            }
        }
    }
}

$response = Invoke-WebRequest $URL
if($response.StatusCode -eq 200)
{
    $playersJson = $response.Content | ConvertFrom-Json
    
    for ($i = 0; $i -lt $playersJson.Count; $i++) {
        $player = $playersJson[$i]
        if(-not $excludes.Contains($player.id))
        {
            Write-Progress -Activity 'Processing players' -Status ("{0} {1}" -f $player.first_name, $player.last_name) -PercentComplete (($i / $playersJson.Count) * 100)
        
            #Create player object
            $obj = [pscustomobject] [ordered] @{
                "id" = $player.id;
                "first_name" = $player.first_name;
                "last_name" = $player.last_name;
                "known_name" = $player.known_name;
                "squad" = ($squads | where-object id -eq $player.squad_id).short_name;
                "total_points" = $player.stats.total_points;
                "avg_points" = $player.stats.avg_points;
                "last_3_avg" = $player.stats.last_3_avg;
                "last_5_avg" = $player.stats.last_5_avg;
                "high_score" = $player.stats.high_score;
                "low_score" = $player.stats.low_score;
                "last_match_points" = $player.stats.last_match_points;
                "owned_by" = $player.stats.owned_by;
            }
            $Players += $obj;

            $progressPreference = 'silentlyContinue'
            try{
                $response2 = Invoke-WebRequest ($playerURL -f $player.id)
            }
            catch
            {
                write-host ("403 error querying {0} {1} {2}" -f $player.id, $player.first_name, $player.last_name) -ForegroundColor Yellow
            }
            $progressPreference = 'Continue'

            if($response2.StatusCode -eq 200)
            {
                $playerMatches = $response2.Content | ConvertFrom-Json            
                foreach($playerMatch in $playerMatches)
                {
                    if($null -ne $playerMatch.match_id)
                    {
                        $match = ($rounds.matches | where-object id -eq $playerMatch.match_id)
                        
                        if($null -ne $match)
                        {
                            $roundNumber = $match.round;
                        }
                        else {
                            $roundNumber = "?";
                        }
                        
                        #Create round object
                        $obj = [pscustomobject] [ordered] @{
                            "id" = $player.id;
                            "first_name" = $player.first_name;
                            "known_name" = $player.known_name;
                            "last_name" = $player.last_name;
                            "Round" = $roundNumber;
                            "price" = $player.stats.prices.($roundNumber);
                            "week_type" = $schedule[$roundNumber][$player.squad_id];
                            "match_id" = $playerMatch.match_id;
                            "match_score" = $player.stats.match_scores.($playerMatch.match_id);
                            "squad" = ($squads | where-object id -eq $player.squad_id).short_name;
                            "Home Team" = $match.home_squad_id -eq $player.squad_id;
                            "position" = $player.positions[0];
                            "Minutes" = $playerMatch.stats.MIN;
                            "Goals" = $playerMatch.stats.GL;
                            "Assists" = $playerMatch.stats.ASS;
                            "Clean Sheet" = $playerMatch.stats.CS;
                            "Saves" = $playerMatch.stats.SV;
                            "Penalties Earned" = $playerMatch.stats.PE;
                            "Penalties Saved" = $playerMatch.stats.PS;
                            "Penalties Missed" = $playerMatch.stats.PM;
                            "Goals Conceded" = $playerMatch.stats.GC;
                            "Yellow Cards" = $playerMatch.stats.YC;
                            "Red Cards" = $playerMatch.stats.RC;
                            "Own Goals" = $playerMatch.stats.OG;
                            "Own Goal Assists" = $playerMatch.stats.OGA;
                            "Shots" = $playerMatch.stats.SH;
                            "Was Fouled" = $playerMatch.stats.WF;
                            "Passes" = $playerMatch.stats.PSS;
                            "Passes Completed" = $playerMatch.stats.APS;
                            "Crosses" = $playerMatch.stats.CRS;
                            "Key Passes" = $playerMatch.stats.KP;
                            "Big Chances" = $playerMatch.stats.BC;
                            "Clearances" = $playerMatch.stats.CL;
                            "Blocks" = $playerMatch.stats.BLK;
                            "Interceptions" = $playerMatch.stats.INT;
                            "Tackles" = $playerMatch.stats.TCK;
                            "Balls Recovered" = $playerMatch.stats.BR;
                            "Errors Leading to a Goal" = $playerMatch.stats.ELG;
                        }
                        $playerRounds += $obj;
                    }
                }
            }
        }
        else {
            Write-Host ("skipped {0} {1} {2}" -f $player.id, $player.first_name, $player.last_name) -ForegroundColor DarkYellow
        }
    }
}

if($playerRounds.Count -gt 0)
{
    $playerRounds | Export-CSV -Path $playerRoundFile -NoTypeInformation
}
if($Players.Count -gt 0)
{
    $Players | Export-CSV -Path $playersOutFile -NoTypeInformation
}