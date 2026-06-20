# .ExternalHelp ServerCore.psm1-help.xml
function Get-DisplayResolution
{
	[CmdletBinding( HelpURI="https://go.microsoft.com/fwlink/?LinkId=247822" )]
	Param ()

	End { setres -i }
}

# .ExternalHelp ServerCore.psm1-help.xml
function Set-DisplayResolution
{
	[CmdletBinding( HelpURI="https://go.microsoft.com/fwlink/?LinkId=247822" )]
	Param
	(
		# Display Width
		[Parameter( Mandatory=$true, Position=0 )]
		$Width,

		# Display Height
		[Parameter( Mandatory=$true, Position=1,
			ValueFromPipelineByPropertyName=$true )]
		$Height,

		# Suppresses the confirmation prompt
		[Switch]
		$Force
	)

	End
	{
		if ($Force)
		{
			Setres.exe -W $Width -H $Height -F
		}
		elseif ($host.Name -in "ConsoleHost","ServerRemoteHost")
		{
			Start-Process "Setres.exe" -ArgumentList "-W $Width -H $Height" -Wait
		}
		else
		{
			Setres.exe -W $Width -H $Height
		}
	}
}

<#
setres [-w # -h #] [-f] [-i]
Description:
    This tool configures the display settings.

-w <width>     Specify the screen width in pixels.
-h <height>    Specify the screen height in pixels.
-f			   Do not ask for confirmation upon resolution change.
-i			   Display the current screen resolution.
#>
