$changes = Get-Content -Path "%system.teamcity.build.changedFiles.file%"

write $changes

[System.Collections.ArrayList]$buildOrder = @()

foreach($obj in $changes)
{

    $name = $obj.Substring(0,$obj.IndexOf(":"))

    $arr =$name.Split("/")    
    
    $dbName = $arr[1]

    if(-not($buildOrder -contains $dbName))
    {
        $buildOrder += $dbName
    }

}

    $resetPendingDBChangesSQL = "truncate table refPendingDBChanges"
   


foreach($dbName in $buildOrder)
{
        $insertPendingDBChangeSQL = "exec spInsertPendingDBChanges " + "'" +$dbName + "'"
       
        
}