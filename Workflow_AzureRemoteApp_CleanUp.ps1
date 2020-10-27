workflow AzureRemoteApp_CleanUp_AD
{
 param ( 
    # Mandatory parameter for the name of the Active Directory OU 
    [parameter(Mandatory=$true)] 
    [string]$AD_OU_DN, 
 
   # Mandatory parameter for the name of the RemoteApp Collection
   [parameter(Mandatory=$true)] 
   [string]$RA_Collection,
       
   # Mandatory parameter for the email address where the results will be send to
   [parameter(Mandatory=$true)] 
   [string]$Mail_Destination,
         
   # Mandatory parameter for the name of the Automation Account Name
   [parameter(Mandatory=$true)] 
   [string]$AutomationAccountName        
  )
#Load the Azure Credentials
$Cred = Get-AutomationPSCredential -Name 'Azure_Subscription'
     
#Select the Azure Subscription and connect
Add-AzureAccount -Credential $Cred
Select-AzureSubscription -SubscriptionID '<ENTER AZURE SUBSCRIPTION ID>'
     
#Get All active Azure RemoteApp instances
$vms = Get-AzureRemoteAppVM -CollectionName $RA_Collection
     
#Start the Child Runbook/PowerShell Script on the Hybrid Worker
$params = @{"VMS"=[array]$vms;"AD_OU_DN"=$AD_OU_DN}
$job    = Start-AzureAutomationRunbook –AutomationAccountName $AutomationAccountName –Name "CleanUp_LocalAD" –Parameters $params -Runon "< HYBRID WORKER GROUP>"
 
#Check the progress of the Child Runbook
$doLoop = $true
While ($doLoop) {
  $job = Get-AzureAutomationJob –AutomationAccountName $AutomationAccountName -Id $job.Id
  $status = $job.Status
  $doLoop = (($status -ne "Completed") -and ($status -ne "Failed") -and ($status -ne "Suspended") -and ($status -ne "Stopped"))
}
 
#Get the Ouput of the Childrunbook
$output = Get-AzureAutomationJobOutput –AutomationAccountName $AutomationAccountName -Id $job.Id –Stream Output 
    
if ( ($output.count -gt 0) ) {
   Write-Output "Mail send start"
         
  $MailCred   = "Mail_credentials" 
  $subject    = "Azure RemoteApp AD Cleanup"
  $userid     = '<< Mail User ID>>'
  $Cred       = Get-AutomationPSCredential -Name $MailCred
         
  $html = "<table><tr><td style='font-family:Arial; font-weight:bold;font-size:12px;'><b>AD CleanUp Results:</b><td></tr>"
  foreach ($row in $output) { 
     $html += "<tr><td style='font-family:Arial;font-size:11px;'>" + $row.text + "</td></tr>"
  }
  $html += "</table><br />"
      
  $Body       = "<p style='font-family:Arial; font-weight:bold;font-size:11px;'>The following Azure RemoteApp AD Clean-Up changes are made:</p><br /> " + $html
         
  if ($Cred -eq $null) { 
     Write-Output "Credential entered: $MailCred does not exist in the automation service. Please create one `n"   
  } else { 
     $CredUsername = $Cred.UserName 
     $CredPassword = $Cred.GetNetworkCredential().Password 
          
     Send-MailMessage -To $Mail_Destination -Subject $subject -Body $Body -Port <PORT NUMBER> -SmtpServer '< MAILSERVER >' -From $userid -BodyAsHtml -Credential $Cred
   }
 }   
}
