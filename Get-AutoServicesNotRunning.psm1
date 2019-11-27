<#
.SYNOPSIS
The template gives a good starting point for creating powershell functions and tools.
Start your design with writing out the examples as a functional spesification.
.DESCRIPTION
.PARAMETER
.EXAMPLE
#>

function Get-AutoServicesNotRunning {
    [CmdletBinding()]
    #^ Optional ..Binding(SupportShouldProcess=$True,ConfirmImpact='Low')
    param (
    [Parameter(Mandatory=$True,
        ValueFromPipeline=$True,
        ValueFromPipelineByPropertyName=$True)]
    [Alias('CN','MachineName','HostName','Name')]
    [string[]]$ComputerName,

    [Parameter(Mandatory=$False)]
    [string]$Service,

    [Parameter(Mandatory=$False)]
    [string[]]$Exclude

    )

    

BEGIN {
        #Set variable for incrementing foreach number
        [int]$number = 0
}

PROCESS {
    #Create our regex by exclude parameter and our default exclude variable
    $DefaultExclude = 'gupdate','MapsBroker','RemoteRegistry','sppsvc','WbioSrvc'
    $AllExclude = $Exclude + $DefaultExclude
    $AllExclude = $AllExclude -join '|'    
    $Reg_Exclued = "^("+$AllExclude+")"

    foreach($computer in $ComputerName){
        #Add additional information to get a sens of progress status
        $number = $number+1
        Write-Verbose "***** $computer is object $number of $($ComputerName.Count)"
            
        #Set our prefered start protocol, if this is changed it will break the foreach computer+do loop.
        $Protocol = 'Wsman'

        Do{
            try{
                #Establish session protocol
                if ($Protocol -eq 'Dcom'){
                    $option = New-CimSessionOption -Protocol Dcom
                } else {
                    $option = New-CimSessionOption -Protocol Wsman
                } #else
                
                #Open session to computer
                Write-Verbose "Connecting to $computer over $Protocol."
                $session = New-CimSession -ComputerName $computer -SessionOption $option -ErrorAction Stop -ErrorVariable ErrorSession
                 
                #Query data
                $ciminstance_parameters = @{'Namespace'='root\CIMV2'
                                            'ClassName'='Win32_Service'
                                            'CimSession'=$session
                                            'Filter'="StartMode='Auto' and State='Stopped'"
                                            'ErrorAction'='Stop'
                                            'ErrorVariable'='ErrorInstance'}

                Get-CimInstance @ciminstance_parameters | Where-Object {$_.Name -notmatch $Reg_Exclued}   

                Write-Verbose "Closing connection to $computer."
                $session | Remove-CimSession

            } #Try
            Catch{
                # Catch error creating new session
                if($ErrorSession){
                    Write-Warning "$computer : Could not connect over WSMAN."
                    $NextComputer = $true
                }

                # Catch error getting CimInstance, and close connection
                if($ErrorInstance){
                    Write-Warning "$computer : Could not retrive info about services."
                    Write-Verbose "Closing connection to $computer."
                    $session | Remove-CimSession
                    $NextComputer = $true
                }

            } #Catch
        } Until ($NextComputer)
    
    } #Foreach

} #Process


END {
    # Intentionaly left empty.
    # This block is used to provide one-time post-processing for the function.
}

} #Function