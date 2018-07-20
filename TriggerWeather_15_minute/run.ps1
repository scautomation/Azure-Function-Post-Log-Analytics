Write-Output "PowerShell Timer trigger function executed at:$(get-date)";

# Create the function to create the authorization signature
Function Build-Signature ($customerId, $sharedKey, $date, $contentLength, $method, $contentType, $resource)
{
    $xHeaders = "x-ms-date:" + $date
    $stringToHash = $method + "`n" + $contentLength + "`n" + $contentType + "`n" + $xHeaders + "`n" + $resource

    $bytesToHash = [Text.Encoding]::UTF8.GetBytes($stringToHash)
    $keyBytes = [Convert]::FromBase64String($sharedKey)

    $sha256 = New-Object System.Security.Cryptography.HMACSHA256
    $sha256.Key = $keyBytes
    $calculatedHash = $sha256.ComputeHash($bytesToHash)
    $encodedHash = [Convert]::ToBase64String($calculatedHash)
    $authorization = 'SharedKey {0}:{1}' -f $customerId,$encodedHash
    return $authorization
}


# Create the function to create and post the request
Function Post-LogAnalyticsData($customerId, $sharedKey, $body, $logType)
{
    $method = "POST"
    $contentType = "application/json"
    $resource = "/api/logs"
    $rfc1123date = [DateTime]::UtcNow.ToString("r")
    $contentLength = $body.Length
    $signature = Build-Signature `
        -customerId $customerId `
        -sharedKey $sharedKey `
        -date $rfc1123date `
        -contentLength $contentLength `
        -fileName $fileName `
        -method $method `
        -contentType $contentType `
        -resource $resource
    $uri = "https://" + $customerId + ".ods.opinsights.azure.com" + $resource + "?api-version=2016-04-01"

    $headers = @{
        "Authorization" = $signature;
        "Log-Type" = $logType;
        "x-ms-date" = $rfc1123date;
        "time-generated-field" = $TimeStampField;
    }

    $response = Invoke-WebRequest -Uri $uri -Method $method -ContentType $contentType -Headers $headers -Body $body -UseBasicParsing
    return $response.StatusCode

}

# Replace with your Workspace ID
$CustomerId = $env:LogAnalyticsID 
$invokeID = $env:InvokeID

# Replace with your Primary Key
$SharedKey = $env:LogAnalyticsKey
$invokekey = $env:InvokeKey

# Specify the name of the record type that you'll be creating
$LogType = "Current_Conditions"

# Specify a field with the created time for the records
$TimeStampField = get-date
$TimeStampField = $TimeStampField.GetDateTimeFormats(115)


# Gets WEather Data via Weather Underground from my Personal Weather Station Outside myself
$URL = $env:WeatherURL

#get weather from weather underground
$JSONResult = Invoke-RestMethod -Uri $URL

#select fields to upload
$weather = $jsonresult.current_observation | Select-Object station_id, temp_f, relative_humidity, dewpoint_f, feelslike_f, feelslike_c, wind_dir, wind_mph, wind_string, uv, weather, precip_1hr_in, precip_today_in, heat_index_f, pressure_in, windchill_f, visibility_mi 
$location = $JSONResult.current_observation.display_location
$weather | add-member -name Full -value $location.full -MemberType NoteProperty
$weather | add-member -name City -value $location.city -MemberType NoteProperty
$weather | add-member -name State -value $location.state -MemberType NoteProperty
$weather | add-member -name State_Name -value $location.state_name -MemberType NoteProperty
$weather | add-member -name Country -value $location.country -MemberType NoteProperty
$weather | add-member -name Zip -value $location.zip -MemberType NoteProperty
$weather | add-member -name Magic -value $location.magic -MemberType NoteProperty
$weather | add-member -name Latitude -value $location.latitude -MemberType NoteProperty
$weather | add-member -name Longitude -value $location.longitude -MemberType NoteProperty
$weather | add-member -name Elevation -value $location.elevation -MemberType NoteProperty
$weather = ConvertTo-Json $weather



# Submit the data to the API endpoint
Post-LogAnalyticsData -customerId $customerId -sharedKey $sharedKey -body ([System.Text.Encoding]::UTF8.GetBytes($weather)) -logType $logType
Post-LogAnalyticsData -customerId $invokeID -sharedKey $invokekey -body ([System.Text.Encoding]::UTF8.GetBytes($weather)) -logType $logType


$response = invoke-restmethod -uri $env:CosmosTrigger -Method Post -Body $weather
return $response.StatusCode