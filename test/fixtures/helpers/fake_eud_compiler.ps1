param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$SettingsPath,

    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$RemainingArguments
)

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
[Console]::InputEncoding = [System.Text.UTF8Encoding]::new($false)

if ($RemainingArguments.Count -ne 0) {
    [Console]::Error.WriteLine("unexpected-arguments=$($RemainingArguments -join ',')")
    exit 91
}

$caseName = [string]$env:FAKE_EUD_SCENARIO
if ([string]::IsNullOrWhiteSpace($caseName)) {
    $caseName = [System.IO.Path]::GetFileNameWithoutExtension($SettingsPath)
}

function Get-SettingsValue {
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string[]]$Lines,

        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    $pattern = '^\s*' + [Regex]::Escape($Name) + '\s*:\s*(.+?)\s*$'
    foreach ($line in $Lines) {
        $match = [Regex]::Match($line, $pattern)
        if ($match.Success) {
            return $match.Groups[1].Value
        }
    }
    throw "missing-settings-value=$Name"
}

switch ($caseName) {
    'build-output' {
        $settingsLines = [IO.File]::ReadAllLines(
            $SettingsPath,
            [Text.Encoding]::UTF8
        )
        $baseMapPath = Get-SettingsValue -Lines $settingsLines -Name 'input'
        $outputMapPath = Get-SettingsValue -Lines $settingsLines -Name 'output'
        $entrySection = $settingsLines |
            Where-Object { $_ -match '^\[(.+\.eps)\]$' } |
            Select-Object -First 1

        if ([string]::IsNullOrWhiteSpace($entrySection)) {
            throw 'missing-eps-entry-section'
        }
        $entrySourcePath = $entrySection.Substring(1, $entrySection.Length - 2)
        if (-not [IO.Path]::IsPathRooted($baseMapPath) -or
            -not [IO.Path]::IsPathRooted($outputMapPath) -or
            -not [IO.Path]::IsPathRooted($entrySourcePath)) {
            throw 'manifest-path-is-not-absolute'
        }
        if (-not [IO.File]::Exists($baseMapPath)) {
            throw "missing-input=$baseMapPath"
        }
        if (-not [IO.File]::Exists($entrySourcePath)) {
            throw "missing-entry=$entrySourcePath"
        }
        if ([IO.File]::Exists($outputMapPath)) {
            throw "output-already-exists=$outputMapPath"
        }

        [IO.File]::Copy($baseMapPath, $outputMapPath, $false)
        [Console]::Out.WriteLine("manifest-input=$baseMapPath")
        [Console]::Out.WriteLine("manifest-output=$outputMapPath")
        [Console]::Out.WriteLine("manifest-entry=$entrySourcePath")
        $koreanLog = [string]::Concat(
            [char]0xD55C,
            [char]0xAE00,
            [char]0x20,
            [char]0xB85C,
            [char]0xADF8
        )
        [Console]::Out.WriteLine("stdout=fake $koreanLog")
        [Console]::Error.WriteLine('stderr=fake compiler warning')
        exit 0
    }
    'success' {
        $koreanLog = [string]::Concat(
            [char]0xD55C,
            [char]0xAE00,
            [char]0x20,
            [char]0xB85C,
            [char]0xADF8
        )
        [Console]::Out.WriteLine("settings=$SettingsPath")
        [Console]::Out.WriteLine("stdout=$koreanLog")
        [Console]::Error.WriteLine("stderr=compiler warning")
        exit 0
    }
    'failure' {
        [Console]::Out.WriteLine('stdout=before failure')
        [Console]::Error.WriteLine('stderr=compile failed')
        exit 7
    }
    'hang' {
        [Console]::Out.WriteLine('stdout=waiting')
        Start-Sleep -Seconds 30
        exit 0
    }
    'large-output' {
        $line = 'x' * 4096
        for ($index = 0; $index -lt 128; $index++) {
            [Console]::Out.WriteLine($line)
            [Console]::Error.WriteLine($line)
        }
        exit 0
    }
    'environment' {
        [Console]::Out.WriteLine("visible=$env:VISIBLE_TOKEN")
        [Console]::Out.WriteLine("secret=$env:SECRET_TOKEN")
        exit 0
    }
    default {
        [Console]::Error.WriteLine("unknown-case=$caseName")
        exit 92
    }
}
