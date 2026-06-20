Import-LocalizedData -BindingVariable StringTable -FileName SConfigStrings.psd1 -ErrorAction:SilentlyContinue
$PageWidth = 80

function Get-SCfLocalizedStringTable
{
    [CmdletBinding()]
    param()

    return $StringTable
}

<#
    Creates a lookup table for all single-character inputs possible for the various prompts containing keywords
    Returns lookup table
#>
function Get-SCfSingleCharLookupTable
{
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param(
        [Parameter(Mandatory=$true)]
        $StringTable
    )

    $LookupTable = @{}
    foreach ($Key in $StringTable.Keys)
    {
        # find all localization strings containing '&' one or more times
        if ($StringTable[$Key] -like '*&*')
        {
            $LookupTable[$Key] = @()
            $Words = $StringTable[$Key].Split()

            for ($i = 0; $i -lt $Words.Length; $i++)
            {
                $Word = $Words[$i]
                # for every word with a character marked by '&', process the localization character and rewrite the word
                if ($Word -like '*&*' -and $Word.Length -gt 1)
                {
                    $Parts = $Word.Split('&')
                    $LocalizationCharacter = $Parts[1].Substring(0, 1)
                    $LookupTable[$Key] += $LocalizationCharacter
                }
            }

            # Since this table's values are used to validate inputs, adding "blank" option
            $LookupTable[$Key] += [String]::Empty
        }
    }

    return $LookupTable
}

<#
    Calculates padding to the right of the main menu options
    Inputs:
        OptionId: numerical menu option id
        Text: option label
    Output: a string of spaces to separate the text of the two columns in the main menu UI
#>
function Get-SCfMenuColumnPadding
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        $Text
    )

    $ColumnWidth = $PageWidth / 2
    $ColumnWidth -= 4 # The option number will always occupy 4 characters (e.g. '1)  ' or '10) ')
    $ColumnWidth -= $Text.Length
    if ($ColumnWidth -lt 1) { $ColumnWidth = 1 }

    $Padding = ' ' * $ColumnWidth
    return $Padding
}

<#
    Calculates padding to the right of a column value, with respect to the width of the column's label
    Inputs:
        Label: the column label
        Value: the column value
        MaxValueLength: needed in case the max value length exceeds the label length
        LabelPadding: switch parameter -- including this argument returns the padding for the column label
            instead of the column value. With localized column labels, the label might not always be longer
            than the value.
#>
function Get-SCfColumnValuePadding
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [String]
        $Label,

        [Parameter(Mandatory=$true)]
        [Object]
        $Value,

        [Parameter(Mandatory=$true)]
        [Int]
        $MaxValueLength,

        [Parameter(Mandatory=$false)]
        [Switch]
        $GetLabelPadding
    )

    $LabelLength = $Label.length

    if ($Value.GetType() -ne [System.String]) { $Value = $Value.ToString() }
    $ValueLength = $Value.length

    if ($GetLabelPadding.IsPresent -and $MaxValueLength -gt $ValueLength)
    {
        $ValueLength = $MaxValueLength
    }
    elseif (-not $GetLabelPadding.IsPresent -and $MaxValueLength -gt $LabelLength)
    {
        $LabelLength = $MaxValueLength
    }

    # Padding length includes one trailing space
    $PaddingLength = [Math]::Abs($LabelLength - $ValueLength) + 1
    $LabelIsLonger = $($LabelLength -ge $ValueLength)

    if (($GetLabelPadding.IsPresent -and $LabelIsLonger) -or
        (-not $GetLabelPadding.IsPresent -and -not $LabelIsLonger))
    {
        $PaddingLength = 1
    }

    return $(' ' * $PaddingLength)
}

<#
    Calculates padding for a set of labels
    Input: an array of column labels
    Output: an array with the corresponding padding strings (strings with varying number of spaces)
#>
function Get-SCfLabelPaddingArray
{
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param(
        [Parameter(Mandatory=$true)]
        [String[]]
        $Labels
    )

    $ColumnWidth = 0
    foreach ($Label in $Labels)
    {
        $ColumnWidth = ($ColumnWidth,$($Label.length + 1) | Measure-Object -Max).Maximum
    }

    $PaddingTable = @{}
    foreach ($Label in $Labels)
    {
        $PaddingLength = $ColumnWidth - $Label.length
        $PaddingString = ' ' * $PaddingLength
        $PaddingTable[$Label] = $PaddingString
    }

    return $PaddingTable
}

<#
    Creates the header, with a centered title
    Input: page title
    Output: a here-string containing the title centered between two horizontal lines
#>
function Get-SCfHeader
{
    [CmdletBinding()]
    [OutputType([String])]
    param(
        [Parameter(Mandatory=$true)]
        $Title
    )

    $ColumnWidth = $PageWidth / 2
    $Border = '=' * ($ColumnWidth * 2)
    $TitlePadding = ' ' * ($ColumnWidth - ($Title.Length / 2))

    return @"

  $Border
  $TitlePadding$Title
  $Border

"@
}

<#
    Splits a long string into substrings of a fixed width. Splits strings only between complete words, some overrun is possible
    Input: string to be split
    Output: the input string, as an array of lines of text of roughly equal length
#>
function Get-SCfWrappedText
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [String]
        $InputListtring
    )

    $LineWidth = $PageWidth - 5 # Full line width - 5 characters to allow for some overrun
    $CharArray = $InputListtring.ToCharArray()
    $Line = [String]::Empty
    $Lines = @()

    foreach ($Character in $CharArray)
    {
        <#
            Cut off a line only if the line has reached the max width and
            it doesn't wrap in the middle of a word (i.e. the next char is a space)
        #>
        if (-not ($Line.length -eq 0 -and $Character -eq ' '))
        {
            if ($Line.length -ge $LineWidth -and $Character -eq ' ' )
            {
                $Lines += $Line
                $Line = [String]::Empty
            }
            else
            {
                $Line += $Character
            }
        }
    }

    # Add final (incomplete) line
    if ($Line) { $Lines += $Line }

    return $Lines
}

<#
    Converts ampersand (&) preceding a character to parentheses around the letter
    The ampersand is a special character for localization, but should not be displayed to user
    Input: hash table of localized strings
    Output: localized strings with words like '&Manual' converted to '(M)anual'
#>
function Convert-SCfAmpersandToParentheses
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        $StringTable
    )

    $StringTableUpdates = @{}
    foreach ($Key in $StringTable.Keys)
    {
        # Find all localization strings containing '&' one or more times
        if ($StringTable[$Key] -like '*&*')
        {
            $Words = $StringTable[$Key].Split()

            for ($i = 0; $i -lt $Words.Length; $i++)
            {
                $Word = $Words[$i]
                # For every word with a character marked by '&', process the localization character and rewrite the word
                if ($Word -like '*&*' -and $Word.Length -gt 1)
                {
                    $Parts = $Word.Split('&')
                    $LocalizationCharacter = $Parts[1].Substring(0, 1)
                    $Word = $Parts[0] + '(' + $LocalizationCharacter + ')' + $Parts[1].Substring(1)
                    $Words[$i] = $Word
                }
            }

            # Store updates in $StringTableUpdates table (cannot update $StringTable while iterating through $StringTable.Keys)
            $UpdatedString = $Words -join ' '
            $StringTableUpdates[$Key] = $UpdatedString
        }
    }

    # Apply updates outside of the $StringTable.Keys foreach
    foreach ($Key in $StringTableUpdates.Keys)
    {
        $StringTable[$Key] = $StringTableUpdates[$Key]
    }

    return $StringTable
}

<#
    Reads from the host, displaying the provided message and indented by two spaces by default
    Inputs:
        Prompt: input prompt to write to host
        Indent: number of indentations, 1 by default (an indentation is defined as two spaces)
#>
function Read-SCfHost
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false)]
        [Object]
        $Prompt,

        [Parameter(Mandatory=$false)]
        [Int]
        $Indent,

        [Parameter(Mandatory=$false)]
        [Switch]
        $AsSecureString
    )

    $Padding = '  '
    if ($PSBoundParameters.ContainsKey('Indent'))
    {
       $Padding *= $Indent
    }

    if ($Prompt -and $Padding)
    {
        $Prompt = $Padding + $Prompt
    }

    Read-Host -Prompt $Prompt -AsSecureString:$AsSecureString.IsPresent
}


<#
    Writes to host, indented by two spaces by default
    Inputs:
        Object: input object to write to host
        Indent: number of indentations, 1 by default (an indentation is defined as two spaces)
#>
function Write-SCfHost
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false)]
        [Object]
        $Object,

        [Parameter(Mandatory=$false)]
        [Int]
        $Indent
    )

    $Padding = '  '
    if ($PSBoundParameters.ContainsKey('Indent'))
    {
       $Padding *= $Indent
    }

    if ($Object -and $Padding)
    {
        $Object = @($Padding, $Object)
    }

    Write-Host -Object $Object -Separator $null
}

<#
    Writes nicely-formatted SConfig user settings item
    Inputs:
        Label: setting name
        Padding: standard padding
        Value: setting value
        Description: setting description
#>
function Write-SCfFormattedSettingInfo
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [String]
        $Label,

        [Parameter(Mandatory=$true)]
        [String]
        $Padding,

        [Parameter(Mandatory=$true)]
        $Value,

        [Parameter(Mandatory=$true)]
        [String]
        $Description
    )

    $Label += ':'

    Write-SCfHost -Indent 0 -Object "$Label$Padding$Value"
    $WrappedLines = Get-SCfWrappedText $Description
    foreach ($Line in $WrappedLines) { Write-SCfHost -Indent 2 -Object $Line }
    Write-SCfHost -Indent 0
}

# Pretty-print SConfig settings
function Write-SConfig
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [System.Collections.Hashtable]
        $Settings
    )

    $Labels = @(
        $StringTable.SConfigSettings_DebugOutput,
        $StringTable.SConfigSettings_AutoLaunch,
        $StringTable.SConfigSettings_AutoLaunchHint,
        $StringTable.SConfigSettings_AutoUpdate
    )
    $Padding = Get-SCfLabelPaddingArray $Labels

    $DebugOutputArgs = @{
        Label       = $StringTable.SConfigSettings_DebugOutput
        Padding     = $Padding[$StringTable.SConfigSettings_DebugOutput]
        Value       = $Settings['DebugOutput']
        Description = $StringTable.SConfigSettings_DebugOutput_Description
    }
    $AutoLaunchArgs = @{
        Label       = $StringTable.SConfigSettings_AutoLaunch
        Padding     = $Padding[$StringTable.SConfigSettings_AutoLaunch]
        Value       = $Settings['AutoLaunch']
        Description = $StringTable.SConfigSettings_AutoLaunch_Description
    }
    $AutoLaunchHintArgs = @{
        Label       = $StringTable.SConfigSettings_AutoLaunchHint
        Padding     = $Padding[$StringTable.SConfigSettings_AutoLaunchHint]
        Value       = $Settings['AutoLaunchHint']
        Description = $StringTable.SConfigSettings_AutoLaunchHint_Description
    }
    $AutoUpdateArgs = @{
        Label       = $StringTable.SConfigSettings_AutoUpdate
        Padding     = $Padding[$StringTable.SConfigSettings_AutoUpdate]
        Value       = $Settings['AutoUpdate']
        Description = $StringTable.SConfigSettings_AutoUpdate_Description
    }

    # Start with empty line
    Write-SCfHost -Indent 0
    Write-SCfFormattedSettingInfo @DebugOutputArgs
    Write-SCfFormattedSettingInfo @AutoLaunchArgs
    Write-SCfFormattedSettingInfo @AutoLaunchHintArgs
    Write-SCfFormattedSettingInfo @AutoUpdateArgs
}

<#
    Result text parser for CIM methods
    Inputs:
        ResultCode: numerical codes
        MethodName: Cim Method identifer
        SuccessMessage: message to show if result is successful
        FailureMessage: message to show if result is failed
    Output: return true if the operation should be terminated (error occured)
#>
 function Write-SCfResultText
 {
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param(
        [Parameter(Mandatory=$true)]
        $ResultCode,

        [Parameter(Mandatory=$true)]
        $MethodName,

        [Parameter(Mandatory=$true)]
        $SuccessMessage,

        [Parameter(Mandatory=$true)]
        $FailureMessage
    )

    if ([int]$ResultCode -lt 2)
    {
        Write-SCfHost -Object $SuccessMessage
        return $false
    }

    Write-SCfHost -Object $FailureMessage

    # Handle common result codes
    switch ([int]$ResultCode)
    {
        70 { Write-SCfHost -Object $StringTable.NetworkSettings_ResultCode_70 }
        71 { Write-SCfHost -Object $StringTable.NetworkSettings_ResultCode_71 }
        default {
            Write-SCfHost -Indent 0 -Object @"
  $($StringTable.Win32ResultCode) $ResultCode
  $($StringTable.Win32MethodName) $MethodName
"@
        }
    }

    Read-SCfHost -Prompt $StringTable.Continue
    return $true
}

# Writes standard error information to the terminal.
function Invoke-SCfErrorHandler
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        $Error,

        [Parameter(Mandatory=$false)]
        $Message
    )

    if (-not $Message) { $Message = $StringTable.Error }
    Write-SCfHost -Object $Message
    Write-SCfHost -Object $Error
    Read-SCfHost -Prompt $StringTable.Continue
}

Export-ModuleMember -Function *
